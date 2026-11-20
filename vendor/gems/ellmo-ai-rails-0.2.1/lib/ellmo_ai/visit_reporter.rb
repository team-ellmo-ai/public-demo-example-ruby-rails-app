# frozen_string_literal: true

module EllmoAi
  # Sends page views to the analytics receiver from a background thread, in batches.
  #
  # - `report` never blocks: it pushes onto a bounded in-memory queue. When the queue is full
  #   the visit is dropped (and counted), so a slow or unreachable receiver can never slow pages
  #   down or grow memory.
  # - The thread sends a batch every `flush_interval` seconds, or as soon as `batch_size` visits
  #   are queued, as one gzipped JSON array (at most 250: the receiver's per-request limit).
  #   A failed batch is retried once, then dropped.
  # - Fork-safe: a thread does not survive fork (Puma workers), so each process starts its own
  #   on first use. Pending visits are flushed at exit.
  class VisitReporter
    # dropped: lost (queue full, receiver failing). disabled: discarded because eLLMo has
    # switched this client's page views off.
    attr_reader :dropped, :sent, :disabled

    # `access_for`: the switches for a client ID, for apps with several clients. Default: `access`.
    def initialize(config, http: Http, access: nil, access_for: nil)
      @config = config
      @http = http
      @access = access || ClientAccess.new(config, http: http)
      @access_for = access_for || ->(_client_id) { @access }
      @disabled = 0
      @mutex = Mutex.new
      @pid = nil
      @dropped = 0
      @sent = 0
      @at_exit_registered = false
    end

    # Queue one visit (a Hash in the receiver's payload shape). Never blocks, never raises.
    def report(event)
      unless @access_for.call(event["clientId"]).visits?
        @mutex.synchronize { @disabled += 1 }
        return
      end

      ensure_started
      @queue.push(event, true)
    rescue ThreadError
      @mutex.synchronize { @dropped += 1 }
    rescue StandardError => e
      @config.logger&.warn("[ellmo-ai] visit not queued: #{e.class}: #{e.message}")
    end

    # Send what is queued now and stop the thread. Waits at most `timeout` seconds.
    def shutdown(timeout: 2.0)
      thread = nil
      @mutex.synchronize do
        return unless @pid == Process.pid && @thread

        @stopping = true
        thread = @thread
      end
      @queue.push(:flush, true) rescue nil # rubocop:disable Style/RescueModifier
      thread.join(timeout)
    end

    # Queued, not yet sent (this process).
    def pending
      @pid == Process.pid && @queue ? @queue.size : 0
    end

    private

    def ensure_started
      return if @pid == Process.pid && @thread&.alive?

      @mutex.synchronize do
        return if @pid == Process.pid && @thread&.alive?

        # After a fork the parent's queue and thread are copies we must not share.
        @queue = SizedQueue.new(@config.count(:max_queue))
        @stopping = false
        @pid = Process.pid
        @thread = Thread.new { run }
        @thread.name = "ellmo_ai-visits"
        @thread.report_on_exception = false
        unless @at_exit_registered
          @at_exit_registered = true
          at_exit { shutdown }
        end
      end
    end

    def run
      batch = []
      deadline = monotonic + @config.seconds(:flush_interval)
      loop do
        timeout = [deadline - monotonic, 0].max
        item = @queue.pop(timeout: timeout)
        batch << item if item.is_a?(Hash)

        full = batch.size >= @config.effective_batch_size
        due = monotonic >= deadline
        stop = item == :flush || @stopping
        if full || due || stop
          drain(batch) if stop
          flush(batch)
          batch = []
          deadline = monotonic + @config.seconds(:flush_interval)
        end
        break if stop && @queue.empty?
      end
    rescue StandardError => e
      @config.logger&.warn("[ellmo-ai] visit reporter stopped: #{e.class}: #{e.message}")
    end

    # One batch: never lets an error stop the thread; what can't be sent is counted as dropped.
    def flush(batch)
      # Per client: each has its own switches (one client in most apps)
      batch.group_by { |event| event["clientId"] }.each do |client_id, events|
        access = @access_for.call(client_id)
        access.check!
        if access.visits?
          send_batches(events)
        else
          @mutex.synchronize { @disabled += events.size }
        end
      end
    rescue StandardError => e
      @mutex.synchronize { @dropped += batch.size }
      @config.logger&.warn("[ellmo-ai] dropped #{batch.size} visits: #{e.class}: #{e.message}")
    end

    def drain(batch)
      loop do
        item = @queue.pop(true)
        batch << item if item.is_a?(Hash)
      end
    rescue ThreadError
      batch
    end

    def send_batches(events)
      events.each_slice(@config.effective_batch_size) { |slice| deliver(slice) }
    end

    def deliver(events)
      body = begin
        Http.gzip(JSON.generate(events))
      rescue StandardError => e # e.g. a value that isn't valid UTF-8
        @mutex.synchronize { @dropped += events.size }
        return @config.logger&.warn("[ellmo-ai] dropped #{events.size} visits: #{e.class}: #{e.message}")
      end
      headers = { "content-type" => "application/json", "content-encoding" => "gzip" }
      2.times do |attempt|
        sleep(1) if attempt.positive? && !@stopping
        begin
          response = Http.for(@config, @http.adapter).post(@config.analytics_url, body: body, headers: headers,
                                                                                  timeout: @config.seconds(:report_timeout))
          # The receiver answers 204 to everything it read. A 4xx means it refused the batch
          # (retrying won't help); only a 5xx is worth a retry.
          if response.status < 400
            @mutex.synchronize { @sent += events.size }
            return
          elsif response.status < 500
            break
          end
        rescue StandardError => e
          @config.logger&.debug("[ellmo-ai] visit batch failed: #{e.class}: #{e.message}")
        end
      end
      @mutex.synchronize { @dropped += events.size }
      @config.logger&.warn("[ellmo-ai] dropped #{events.size} visits: the analytics receiver did not accept them")
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
