# frozen_string_literal: true

require "rack"

module EllmoAi
  # Rack middleware: adds eLLMo content to HTML pages and reports page views.
  #
  # Nothing here can break or slow a page beyond `cold_wait`: content comes from the
  # ContentStore (cached), visits are queued for a background thread, and any error in the
  # gem's own code leaves the response exactly as the app produced it.
  class Middleware
    LOOKUP = "ellmo_ai.lookup"
    RENDERED = "ellmo_ai.rendered" # set by the view helpers: { structured: true, semantic: true }

    def initialize(app, config = nil)
      @app = app
      @config = config
    end

    def call(env)
      prepared = prepare(env)
      started = monotonic
      status, headers, body = @app.call(env)
      return [status, headers, body] unless prepared

      finish(env, prepared, status, headers, body, ((monotonic - started) * 1000).round)
    end

    private

    def config
      @config || EllmoAi.config
    end

    # Before the app runs: decide whether this is a page, and start the content lookup so it
    # overlaps with rendering. Returns nil to leave the request alone.
    def prepare(env)
      return nil unless config.enabled?
      return nil unless %w[GET HEAD].include?(env["REQUEST_METHOD"])

      path = Visitor.normalize_path("#{env['SCRIPT_NAME']}#{env['PATH_INFO']}")
      return nil unless Visitor.page_path?(path)

      kind = Visitor.kind(env)
      # Re-read this client's switches in the background when 30 minutes have passed.
      EllmoAi.client_access.check_async
      # Prefetches get content too (Turbo shows a prefetched page on click); they aren't counted.
      env[LOOKUP] = EllmoAi.content_store.lookup(path) if config.inject
      { path: path, kind: kind }
    rescue StandardError => e
      warn_once(e)
      nil
    end

    # After the app ran: add content, set the visitor cookie, queue the page view.
    def finish(env, prepared, status, headers, body, latency_ms)
      return [status, headers, body] unless html?(headers)

      body = add_content(env, status, headers, body)
      visitor_id = Visitor.visitor_id(env)
      if visitor_id.nil? && config.visitor_cookie
        visitor_id = Visitor.new_visitor_id
        append_cookie(headers, Visitor.cookie(visitor_id, https?(env)))
      end
      report(env, prepared, status, latency_ms, visitor_id)
      [status, headers, body]
    rescue StandardError => e
      warn_once(e)
      [status, headers, body]
    end

    def add_content(env, status, headers, body)
      lookup = env[LOOKUP]
      return body unless lookup && status.to_i == 200
      return body if header(headers, "content-encoding") # already compressed: leave it
      return body unless body.respond_to?(:to_ary)        # streamed: leave it

      rendered = env[RENDERED] || {}
      content = lookup.value
      return body if content.nil? || content.empty?

      structured = rendered[:structured] ? nil : content.structured
      semantic = rendered[:semantic] ? nil : content.semantic
      return body unless structured || semantic

      parts = body.to_ary # also closes the body (Rack SPEC)
      html = Injector.inject(parts.join, structured: structured, semantic: semantic)
      return parts unless html

      set_header(headers, "content-length", html.bytesize.to_s) if header(headers, "content-length")
      [html]
    end

    def report(env, prepared, status, latency_ms, visitor_id)
      return unless config.report_visits
      return unless %w[document navigation].include?(prepared[:kind])

      request = Rack::Request.new(env)
      EllmoAi.visit_reporter.report(
        "url" => request.url,
        "method" => env["REQUEST_METHOD"],
        "headers" => Visitor.headers(env),
        "cf" => {},
        "status" => status.to_i,
        "latencyMs" => latency_ms,
        "source" => "rails-sdk",
        "sdkVersion" => VERSION,
        "clientId" => config.client_id,
        "visitorId" => visitor_id,
        "visitId" => SecureRandom.uuid,
        "kind" => prepared[:kind],
        "ip" => Visitor.ip(env),
        "ts" => (Time.now.to_f * 1000).round
      )
    end

    def html?(headers)
      header(headers, "content-type").to_s.start_with?("text/html")
    end

    def https?(env)
      env["HTTPS"] == "on" || env["rack.url_scheme"] == "https" || env["HTTP_X_FORWARDED_PROTO"] == "https"
    end

    # Rack 3 uses lower-case header names; Rack 2 apps may not.
    def header(headers, name)
      headers[name] || headers.find { |key, _| key.to_s.downcase == name }&.last
    end

    def set_header(headers, name, value)
      key = headers.keys.find { |k| k.to_s.downcase == name } || name
      headers[key] = value
    end

    def append_cookie(headers, cookie)
      key = headers.keys.find { |k| k.to_s.downcase == "set-cookie" } || "set-cookie"
      existing = headers[key]
      headers[key] =
        case existing
        when nil, "" then cookie
        when Array then existing + [cookie]
        else Rack.release.to_i >= 3 ? [existing, cookie] : "#{existing}\n#{cookie}"
        end
    end

    def warn_once(error)
      return if @warned

      @warned = true
      config.logger&.warn("[ellmo-ai] skipped: #{error.class}: #{error.message}")
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
