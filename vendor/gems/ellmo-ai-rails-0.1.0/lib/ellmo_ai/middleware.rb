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
    # Set by FinalStatus: hand the page view to it (VISIT) instead of reporting it here.
    DEFER = "ellmo_ai.defer"
    VISIT = "ellmo_ai.visit"
    # Set by the first EllmoAi::Middleware a request passes: a second one (installed twice by
    # hand) leaves it alone, so content is added and the view counted once.
    HANDLED = "ellmo_ai.handled"

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
      return nil if env[HANDLED]
      return nil unless config.enabled?
      return nil unless %w[GET HEAD].include?(env["REQUEST_METHOD"])

      env[HANDLED] = true
      client_id = config.client_id_for(env)
      return nil unless client_id

      path = Visitor.normalize_path("#{env['SCRIPT_NAME']}#{env['PATH_INFO']}")
      return nil unless Visitor.page_path?(path)

      kind = Visitor.kind(env)
      # Re-read this client's switches in the background when 30 minutes have passed.
      EllmoAi.client_access(client_id).check_async
      # Prefetches get content too (Turbo shows a prefetched page on click); they aren't counted.
      # Requests that don't take HTML (APIs, assets) cost no lookup.
      env[LOOKUP] = EllmoAi.content_store(client_id).lookup(path) if config.inject && Visitor.accepts_html?(env)
      { path: path, kind: kind, client_id: client_id }
    rescue StandardError => e
      warn_once(e)
      nil
    end

    # After the app ran: add content, set the visitor cookie, queue the page view.
    def finish(env, prepared, status, headers, body, latency_ms)
      return [status, headers, body] unless html?(headers) || not_modified_page?(env, status)
      return [status, headers, body] if health_check?(env)

      body = add_content(env, status, headers, body)
      visitor_id = Visitor.visitor_id(env)
      if visitor_id.nil? && set_cookie?(env, prepared, headers)
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
      return body unless utf8_page?(headers)               # eLLMo's content is UTF-8
      return body unless readable?(body)                   # streamed: leave it

      rendered = env[RENDERED] || {}
      content = lookup.value
      return body if content.nil? || content.empty?

      structured = rendered[:structured] ? nil : JsonLdCleanup.apply(content.structured, config, env)
      semantic = rendered[:semantic] ? nil : content.semantic
      return body unless structured || semantic

      parts = read_body(body)
      html = Injector.inject(parts.join, structured: structured, semantic: semantic)
      return parts unless html

      set_header(headers, "content-length", html.bytesize.to_s) if header(headers, "content-length")
      [html]
    end

    # Whether the whole body can be read without waiting on a stream.
    def readable?(body)
      rails_body = legacy_rails_body(body)
      rails_body ? buffered?(rails_body) : body.respond_to?(:to_ary)
    end

    # The body's parts. Closes the body: the gem returns a new one, so this is the only chance
    # for the close callbacks of the middleware below (Rack::BodyProxy) to run. Rack 3's
    # BodyProxy#to_ary closes too; Rack 2's and Rails' own RackBody#to_ary don't, and closing a
    # BodyProxy twice is safe.
    def read_body(body)
      parts = legacy_rails_body(body) ? [].tap { |out| body.each { |part| out << part } } : body.to_ary
      body.close if body.respond_to?(:close)
      parts
    end

    # Rails before 7.1 has no usable RackBody#to_ary (6.1 returns nil, 7.0 doesn't define it).
    # Returns the RackBody, unwrapped from any Rack::BodyProxy, so the caller can check it's
    # buffered and read it with `each`; nil for any other body.
    def legacy_rails_body(body)
      return nil unless defined?(ActionDispatch::Response::RackBody) && defined?(ActionPack)
      return nil unless ActionPack.gem_version < Gem::Version.new("7.1")

      body = body.instance_variable_get(:@body) while body.is_a?(Rack::BodyProxy)
      body if body.is_a?(ActionDispatch::Response::RackBody)
    end

    def buffered?(rails_body)
      stream = rails_body.instance_variable_get(:@response)&.stream
      # Live::Buffer subclasses Buffer, so match the class exactly. A template streamed with
      # `stream: true` is a Buffer around a lazy body rather than an Array.
      stream.instance_of?(ActionDispatch::Response::Buffer) &&
        stream.instance_variable_get(:@buf).is_a?(Array)
    end

    def report(env, prepared, status, latency_ms, visitor_id)
      return unless config.report_visits
      return unless %w[document navigation].include?(prepared[:kind])

      request = Rack::Request.new(env)
      event = {
        "url" => Visitor.utf8(request.url),
        "method" => env["REQUEST_METHOD"],
        "headers" => Visitor.headers(env, cookies: config.forward_cookies),
        "cf" => {},
        "status" => status.to_i,
        "latencyMs" => latency_ms,
        "source" => "rails-sdk",
        "sdkVersion" => VERSION,
        "clientId" => prepared[:client_id],
        "visitorId" => visitor_id,
        "visitId" => SecureRandom.uuid,
        "kind" => prepared[:kind],
        "ip" => Visitor.ip(env),
        "ts" => (Time.now.to_f * 1000).round
      }
      env[DEFER] ? env[VISIT] = event : EllmoAi.visit_reporter.report(event)
    end

    # Whether to give a first-time visitor the eLLMo cookie. Not when nothing is reported (the ID
    # would serve nothing), and not on responses a CDN or proxy may cache for everyone: a
    # Set-Cookie there stops most of them caching the page, or hands one ID to every visitor.
    def set_cookie?(env, prepared, headers)
      return false unless config.report_visits && EllmoAi.client_access(prepared[:client_id]).visits?
      return false unless config.visitor_cookie_for?(env)

      cache_control = header(headers, "cache-control").to_s.downcase
      shared = cache_control.include?("public") || cache_control.include?("s-maxage")
      !(shared && !cache_control.include?("private") && !cache_control.include?("no-store"))
    end

    # A page with no charset, or UTF-8. Content added to a page in another charset would be garbled.
    def utf8_page?(headers)
      charset = header(headers, "content-type").to_s[/;\s*charset\s*=\s*"?([^";\s]+)/i, 1]
      charset.nil? || %w[utf-8 utf8].include?(charset.downcase)
    end

    # Rails' health check (`get "up" => "rails/health#show"`, generated since Rails 7.1). Load
    # balancers and uptime monitors call it every few seconds: those aren't page views.
    def health_check?(env)
      env["action_dispatch.request.path_parameters"]&.dig(:controller) == "rails/health"
    end

    def html?(headers)
      header(headers, "content-type").to_s.start_with?("text/html")
    end

    # A 304 (`fresh_when` / `stale?`) has no content type, but it's still a page view: the
    # visitor's cached copy of the page was current. Count it unless the request asked for
    # something other than HTML.
    def not_modified_page?(env, status)
      return false unless status.to_i == 304

      accept = env["HTTP_ACCEPT"].to_s
      accept.empty? || accept.include?("text/html") || accept.include?("*/*")
    end

    def https?(env)
      env["HTTPS"] == "on" || env["rack.url_scheme"] == "https" || env["HTTP_X_FORWARDED_PROTO"] == "https"
    end

    # Rack 3 uses lower-case header names; Rack 2 apps may not.
    def header(headers, name)
      headers[name] || headers.find { |key, _| key.to_s.downcase == name }&.last
    end

    def set_header(headers, name, value)
      headers[header_key(headers, name)] = value
    end

    def append_cookie(headers, cookie)
      key = header_key(headers, "set-cookie")
      existing = headers[key]
      headers[key] =
        case existing
        when nil, "" then cookie
        when Array then existing + [cookie]
        else Rack.release.to_i >= 3 ? [existing, cookie] : "#{existing}\n#{cookie}"
        end
    end

    # The existing key for this header, or a new one: lower-case on Rack 3, capitalized on
    # Rack 2 (where Rails and Rack::MockResponse look headers up as "Set-Cookie").
    def header_key(headers, name)
      headers.keys.find { |k| k.to_s.downcase == name } ||
        (Rack.release.to_i >= 3 ? name : name.split("-").map(&:capitalize).join("-"))
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

  # Outermost middleware in Rails. Middleware above EllmoAi::Middleware can change the status:
  # Rack::ConditionalGet answers 304 when the visitor's copy is current. This one holds the page
  # view until the whole stack has answered, so it carries the status the visitor got.
  class FinalStatus
    def initialize(app)
      @app = app
    end

    def call(env)
      env[Middleware::DEFER] = true
      status, headers, body = @app.call(env)
      deliver(env, status)
      [status, headers, body]
    end

    private

    def deliver(env, status)
      event = env.delete(Middleware::VISIT)
      return unless event

      event["status"] = status.to_i
      EllmoAi.visit_reporter.report(event)
    rescue StandardError
      nil
    end
  end
end
