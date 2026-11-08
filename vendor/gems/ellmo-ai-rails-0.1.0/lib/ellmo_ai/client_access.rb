# frozen_string_literal: true

module EllmoAi
  # This client's two switches, set by eLLMo: whether it may report page views (`visits`)
  # and whether it is served content (`content`). eLLMo's servers enforce both; checking
  # here saves calls that would be refused.
  #
  # Read from GET <access_url>/<client_id> (the client ID is the customer's asset bucket ID)
  # at most once per `access_interval` (30 min) per app process, always from a background
  # thread, never during a page request.
  #
  # - An answer sets both switches (eLLMo answers "off" for a client it has no switches for).
  # - A check that fails (network error, timeout, non-2xx, any other body) is skipped: the last
  #   answer stands, and with no answer yet both count as on. A second failure in a row turns
  #   both off until a check succeeds.
  class ClientAccess
    attr_reader :failures

    def initialize(config, http: Http, client_id: config.client_id)
      @config = config
      @http = http
      @client_id = client_id
      @answer = nil       # { visits: bool, content: bool } from the last successful check
      @failures = 0       # failed checks in a row
      @checked_at = nil   # monotonic time of the last attempt
      @pid = Process.pid
      @mutex = Mutex.new
      @thread = nil
    end

    def visits?
      on?(:visits)
    end

    def content?
      on?(:content)
    end

    # True once a check has finished, whatever its outcome.
    def answered?
      !@answer.nil? || @failures.positive?
    end

    # Wait up to `timeout` seconds for a running first check (started by check_async). Never
    # performs a check itself, so it is safe on a request thread.
    def wait_for_answer(timeout)
      thread = @thread
      thread.join(timeout) if thread&.alive? && timeout.positive?
      answered?
    end

    # Check now if a check is due. Blocking: call only from background threads.
    def check!
      reset_after_fork
      @mutex.synchronize { perform if due? }
    end

    # Start a check in a background thread if one is due. Never blocks.
    def check_async
      reset_after_fork
      return unless due?
      return if @thread&.alive?

      @thread = Thread.new { check! }
      @thread.name = "ellmo_ai-access"
      @thread.report_on_exception = false
    end

    private

    def on?(switch)
      return false if @failures >= 2
      return true if @answer.nil?

      @answer[switch]
    end

    def due?
      @checked_at.nil? || monotonic - @checked_at >= @config.seconds(:access_interval)
    end

    def perform
      @checked_at = monotonic
      answer = fetch
      if answer
        @answer = answer
        @failures = 0
      else
        @failures += 1
        @config.logger&.warn("[ellmo-ai] access check failed (#{@failures} in a row)")
      end
    end

    def fetch
      url = "#{@config.access_url.to_s.chomp('/')}/#{URI.encode_www_form_component(@client_id.to_s)}"
      response = Http.for(@config, @http.adapter).get(url, headers: { "accept" => "application/json" },
                                                           timeout: @config.seconds(:fetch_timeout))
      return nil unless (200..299).cover?(response.status)

      body = JSON.parse(response.body.to_s)
      return nil unless body.is_a?(Hash)

      visits = body["visits"]
      content = body["content"]
      # Anything but two true/false values is a failed check, not an answer.
      return nil unless [true, false].include?(visits) && [true, false].include?(content)

      { visits: visits, content: content }
    rescue StandardError
      nil
    end

    # A forked child (Puma worker) keeps the last answer but not the parent's lock or thread.
    def reset_after_fork
      return if @pid == Process.pid

      @pid = Process.pid
      @mutex = Mutex.new
      @thread = nil
      # A first check still running at fork never answers here: check again instead of waiting
      # 30 minutes with no answer.
      @checked_at = nil unless answered?
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
