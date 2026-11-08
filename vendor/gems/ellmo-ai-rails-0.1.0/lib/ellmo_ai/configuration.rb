# frozen_string_literal: true

require "logger"

module EllmoAi
  # Every setting, with its default. Set them in config/initializers/ellmo.rb (see the generator).
  class Configuration
    DEFAULT_API_URL = "https://api-s.tryellmo.ai/functions/v1"
    DEFAULT_ANALYTICS_URL = "https://analytics-v2.tryellmo.com/"
    DEFAULT_ACCESS_URL = "https://analytics-v2.tryellmo.com/access"

    # The client ID eLLMo gave you. Nothing happens without one. An app that serves several sites,
    # each with its own client ID, gives a callable instead: ->(request) { IDS[request.host] }
    # (a Rack::Request; nil for a request with no client).
    attr_accessor :client_id
    # nil (default): on when client_id is set, except in the Rails test environment.
    attr_writer :enabled
    attr_accessor :api_url, :analytics_url, :access_url
    attr_accessor :access_interval # seconds between checks of this client's switches (1800)

    # Content
    attr_accessor :inject          # add content to HTML responses automatically (default true)
    attr_accessor :cache_store     # an ActiveSupport::Cache store; default Rails.cache, else in-memory
    attr_accessor :cache_ttl       # seconds content is fresh; then served stale while refreshed (600)
    attr_accessor :stale_ttl       # seconds stale content may still be served (86_400)
    attr_accessor :cold_wait       # seconds a page waits for content nothing is cached for yet (1.0)
    attr_accessor :fetch_timeout   # seconds per content API call (3.0)
    attr_accessor :error_backoff   # seconds before retrying after the API failed (60)
    attr_accessor :max_refreshes   # content fetches in flight at once, per process (8)
    # In the browser, hide the page's other JSON-LD when eLLMo's is present (default false).
    # Only JavaScript-running consumers see the change; it can cost the page its own rich results.
    attr_accessor :hide_other_json_ld

    # Visits
    attr_accessor :report_visits   # report page views to eLLMo (default true)
    # Set the first-party ellmo_ext_vid cookie (default true). Or a callable deciding per request,
    # e.g. only after consent: ->(request) { request.cookies["consent"] == "yes" }. One that
    # raises counts as false.
    attr_accessor :visitor_cookie
    # Include the visitor's Cookie header in the headers sent to eLLMo (default false): it holds
    # your session cookies, and eLLMo doesn't need them (the visitor ID is sent on its own).
    attr_accessor :forward_cookies
    attr_accessor :flush_interval  # seconds between batches (5)
    attr_accessor :batch_size      # send early once this many are queued (100; max 250)
    attr_accessor :max_queue       # visits held in memory before new ones are dropped (10_000)
    attr_accessor :report_timeout  # seconds per batch POST (2.0)

    # Log every call to eLLMo and its answer ("[ellmo-ai http]", info level). Page-view uploads
    # are logged in full: visitors' headers (cookies included) and IPs. Default: ELLMO_DEBUG=1.
    attr_accessor :debug
    attr_accessor :debug_body_limit # response characters logged (2000; 0 = all). ELLMO_DEBUG_BODY

    # Default: Rails.logger in Rails, else warnings to stderr.
    attr_writer :logger

    def logger
      @logger || (defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger) ||
        (@default_logger ||= Logger.new($stderr, level: Logger::WARN))
    end

    def initialize
      @client_id = ENV["ELLMO_CLIENT_ID"]
      @enabled = nil
      @api_url = ENV.fetch("ELLMO_API_URL", DEFAULT_API_URL)
      @analytics_url = ENV.fetch("ELLMO_ANALYTICS_URL", DEFAULT_ANALYTICS_URL)
      @access_url = ENV.fetch("ELLMO_ACCESS_URL", DEFAULT_ACCESS_URL)
      @access_interval = 1800
      @inject = true
      @cache_store = nil
      @cache_ttl = 600
      @stale_ttl = 86_400
      @cold_wait = 1.0
      @fetch_timeout = 3.0
      @error_backoff = 60
      @max_refreshes = 8
      @hide_other_json_ld = false
      @report_visits = true
      @visitor_cookie = true
      @forward_cookies = false
      @flush_interval = 5
      @batch_size = 100
      @max_queue = 10_000
      @report_timeout = 2.0
      @logger = nil
      @debug = ENV["ELLMO_DEBUG"] == "1"
      @debug_body_limit = Integer(ENV.fetch("ELLMO_DEBUG_BODY", "2000"), exception: false) || 2000
    end

    def enabled?
      return false if !client_id.respond_to?(:call) && client_id.to_s.strip.empty?
      return @enabled unless @enabled.nil?

      !(defined?(Rails) && Rails.respond_to?(:env) && Rails.env.test?)
    end

    # The client ID for this request (client_id, or what it returns when it's a callable), or nil.
    def client_id_for(env)
      id = client_id.respond_to?(:call) ? client_id.call(Rack::Request.new(env)) : client_id
      id = id.to_s.strip
      id.empty? ? nil : id
    rescue StandardError
      nil
    end

    # Whether to give this request's visitor the cookie (see visitor_cookie).
    def visitor_cookie_for?(env)
      setting = visitor_cookie
      setting.respond_to?(:call) ? !!setting.call(Rack::Request.new(env)) : !!setting
    rescue StandardError
      false
    end

    def content_endpoint
      "#{api_url.to_s.chomp('/')}/embedded-content_v2"
    end

    # The analytics receiver takes at most 250 events per request.
    def effective_batch_size
      batch_size.to_i.clamp(1, 250)
    end

    # The numbers the gem runs on: each setting, or its default when it's missing, not a number
    # or out of range. A nil or 0 interval would otherwise spin a thread or poll without pause.
    def seconds(name)
      min, default = SECONDS.fetch(name)
      value = public_send(name)
      number = value.is_a?(Numeric) ? value.to_f : Float(value.to_s, exception: false)
      number && number.finite? && number >= min ? number : default
    end

    def count(name)
      min, default = COUNTS.fetch(name)
      value = Integer(public_send(name).to_s, exception: false)
      value && value >= min ? value : default
    end

    # name => [minimum, default]
    SECONDS = {
      access_interval: [0, 1800.0], cache_ttl: [0, 600.0], stale_ttl: [0, 86_400.0], cold_wait: [0, 1.0],
      fetch_timeout: [0.01, 3.0], error_backoff: [0, 60.0], flush_interval: [0.01, 5.0], report_timeout: [0.01, 2.0]
    }.freeze
    COUNTS = { max_refreshes: [1, 8], max_queue: [1, 10_000] }.freeze
  end
end
