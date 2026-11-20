# frozen_string_literal: true

require "digest"

module EllmoAi
  # Page content, cached so a page never waits on the eLLMo API once something is cached:
  # fresh content is served as is, stale content is served while it is refreshed in the
  # background, and a page with nothing cached waits at most `cold_wait` seconds.
  #
  # Content fetches are made with s=static, so the API does not count them as page views:
  # page views come only from the VisitReporter.
  class ContentStore
    Content = Struct.new(:structured, :semantic) do
      def empty?
        structured.nil? && semantic.nil?
      end
    end

    # One request's view of a page's content: resolved now, or after a refresh (bounded wait).
    class Lookup
      # `cache_fallback`: on timeout, serve what's cached. Off until this process has heard from
      # eLLMo's access check, so a switched-off client isn't served old content from a shared cache.
      def initialize(content: nil, thread: nil, deadline: nil, store: nil, path: nil, cache_fallback: true)
        @content = content
        @thread = thread
        @deadline = deadline
        @store = store
        @path = path
        @cache_fallback = cache_fallback
      end

      # The content, or nil. Waits for an in-flight refresh until the deadline, never longer.
      def value
        return @content unless @thread

        remaining = @deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        finished = remaining.positive? && @thread.join(remaining)
        @content = if finished then @thread.value
                   elsif @cache_fallback then @store.cached(@path)
                   end
        @thread = nil
        @content
      end
    end

    # A minimal thread-safe store for apps without Rails.cache.
    class MemoryStore
      def initialize(max_entries: 1_000)
        @max_entries = max_entries
        @data = {}
        @mutex = Mutex.new
      end

      def read(key)
        @mutex.synchronize do
          value, expires_at = @data[key]
          return nil unless value
          return value if expires_at > now

          @data.delete(key)
          nil
        end
      end

      def write(key, value, expires_in:)
        @mutex.synchronize do
          @data.delete(key)
          @data.shift while @data.size >= @max_entries
          @data[key] = [value, now + expires_in]
        end
      end

      private

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end

    def initialize(config, http: Http, access: nil, client_id: config.client_id)
      @config = config
      @http = http
      @client_id = client_id
      @access = access || ClientAccess.new(config, http: http, client_id: client_id)
      @inflight = {}
      @mutex = Mutex.new
      @pid = Process.pid
    end

    # Start looking up a page's content. Call before rendering; read Lookup#value after.
    def lookup(path)
      # eLLMo has switched this client's content off: serve none, cached or not.
      return Lookup.new unless @access.content?

      # One budget for the whole lookup: the access wait and the content wait share cold_wait.
      deadline = now_mono + @config.seconds(:cold_wait)

      # Until this process has heard from eLLMo, don't trust the cache (a shared Rails.cache may
      # hold content from before the client was switched off): wait for the first answer, within
      # the budget, and if it still hasn't come, ask the API, which enforces access.
      answered = @access.answered? || @access.wait_for_answer(deadline - now_mono)
      return Lookup.new unless @access.content?

      entry = answered ? read(path) : nil
      if entry
        refresh_async(path) if entry["fresh_until"] <= now_wall
        return Lookup.new(content: to_content(entry))
      end

      thread = refresh_async(path)
      return Lookup.new unless thread

      Lookup.new(thread: thread, deadline: deadline, store: self, path: path, cache_fallback: answered)
    end

    # What is cached for a page right now (fresh or stale), or nil.
    def cached(path)
      entry = read(path)
      entry && to_content(entry)
    end

    # Fetch now, in this thread, and cache the result. Returns the content now cached (or nil).
    # Used by refreshes; exposed for warming scripts.
    def refresh(path)
      # Uses the current answer; the check itself runs from the middleware (check_async).
      return nil unless @access.content?

      result = fetch(path)
      previous = read(path)
      if result == :refused
        # The API refused (this client is switched off, or unknown): drop what was cached.
        write(path, nil, nil, now_wall + @config.seconds(:error_backoff))
        nil
      elsif result
        write(path, result.structured, result.semantic, now_wall + @config.seconds(:cache_ttl))
        result
      elsif previous
        # Keep serving what we had; try again after the backoff.
        write(path, previous["structured"], previous["semantic"], now_wall + @config.seconds(:error_backoff))
        to_content(previous)
      else
        write(path, nil, nil, now_wall + @config.seconds(:error_backoff))
        nil
      end
    end

    private

    def refresh_async(path)
      reset_after_fork
      @mutex.synchronize do
        existing = @inflight[path]
        return existing if existing
        return nil if @inflight.size >= @config.count(:max_refreshes)

        thread = Thread.new do
          refresh(path)
        rescue StandardError => e
          @config.logger&.warn("[ellmo-ai] content refresh failed for #{path}: #{e.class}: #{e.message}")
          nil
        ensure
          @mutex.synchronize { @inflight.delete(path) }
        end
        # Named and set up here, not inside the thread, so they're in place as soon as it exists
        thread.name = "ellmo_ai-content"
        thread.report_on_exception = false
        @inflight[path] = thread
      end
    end

    # Refreshes running when the process forked (a warming script before Puma forks) don't exist
    # in the child: forget them, or they'd hold max_refreshes slots and block their paths forever.
    def reset_after_fork
      return if @pid == Process.pid

      @pid = Process.pid
      @mutex = Mutex.new
      @inflight = {}
    end

    # The content; :refused when the API said no (4xx: this client is off, or unknown); nil when
    # it couldn't be reached or answered 408 / 429 / 5xx / non-JSON (worth trying again later).
    def fetch(path)
      query = URI.encode_www_form(c: @client_id, u: path, v: VERSION, s: "static")
      response = Http.for(@config, @http.adapter).get("#{@config.content_endpoint}?#{query}",
                                                      headers: { "accept" => "application/json" },
                                                      timeout: @config.seconds(:fetch_timeout))
      unless (200..299).cover?(response.status)
        @config.logger&.warn("[ellmo-ai] content API returned #{response.status} for #{path}")
        return (400..499).cover?(response.status) && ![408, 429].include?(response.status) ? :refused : nil
      end

      body = JSON.parse(response.body.to_s)
      return Content.new(nil, nil) unless body.is_a?(Hash)

      Content.new(html(body["structured"]), html(body["semantic"]))
    rescue StandardError => e
      @config.logger&.warn("[ellmo-ai] content API failed for #{path}: #{e.class}: #{e.message}")
      nil
    end

    def html(value)
      value.is_a?(String) && !value.strip.empty? ? value : nil
    end

    def read(path)
      entry = store.read(key(path))
      entry.is_a?(Hash) && entry.key?("fresh_until") ? entry : nil
    end

    def write(path, structured, semantic, fresh_until)
      entry = { "structured" => structured, "semantic" => semantic, "fresh_until" => fresh_until }
      # "Nothing for this page" isn't worth keeping past its freshness: requests for random URLs
      # would otherwise fill a shared cache with a day's worth of empty entries.
      stale = structured || semantic ? @config.seconds(:stale_ttl) : 0
      ttl = [fresh_until - now_wall, 0].max + stale
      store.write(key(path), entry, expires_in: ttl)
    end

    def to_content(entry)
      Content.new(entry["structured"], entry["semantic"])
    end

    def key(path)
      id = path.bytesize > 200 ? Digest::SHA256.hexdigest(path) : path
      "ellmo_ai/v1/#{@client_id}/#{id}"
    end

    # The configured store, else Rails.cache, else our own. Rails' development and test default
    # (:null_store) keeps nothing, so content would never be served from it: use our own instead.
    def store
      @store ||= begin
        candidate = @config.cache_store || (defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache)
        null = defined?(ActiveSupport::Cache::NullStore) && candidate.is_a?(ActiveSupport::Cache::NullStore)
        candidate && !null ? candidate : MemoryStore.new
      end
    end

    def now_wall
      Time.now.to_f
    end

    def now_mono
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
