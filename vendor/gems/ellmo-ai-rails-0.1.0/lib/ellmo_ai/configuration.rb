# frozen_string_literal: true

require "logger"

module EllmoAi
  # Every setting, with its default. Set them in config/initializers/ellmo.rb (see the generator).
  class Configuration
    DEFAULT_API_URL = "https://api-s.tryellmo.ai/functions/v1"
    DEFAULT_ANALYTICS_URL = "https://analytics-v2.tryellmo.com/"
    DEFAULT_ACCESS_URL = "https://analytics-v2.tryellmo.com/access"

    # The client ID eLLMo gave you. Nothing happens without one.
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

    # Visits
    attr_accessor :report_visits   # report page views to eLLMo (default true)
    attr_accessor :visitor_cookie  # set the first-party ellmo_ext_vid cookie (default true)
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
      @report_visits = true
      @visitor_cookie = true
      @flush_interval = 5
      @batch_size = 100
      @max_queue = 10_000
      @report_timeout = 2.0
      @logger = nil
      @debug = ENV["ELLMO_DEBUG"] == "1"
      @debug_body_limit = Integer(ENV.fetch("ELLMO_DEBUG_BODY", "2000"), exception: false) || 2000
    end

    def enabled?
      return false if client_id.to_s.strip.empty?
      return @enabled unless @enabled.nil?

      !(defined?(Rails) && Rails.respond_to?(:env) && Rails.env.test?)
    end

    def content_endpoint
      "#{api_url.to_s.chomp('/')}/embedded-content_v2"
    end

    # Analytics Engine takes at most 250 events per request.
    def effective_batch_size
      batch_size.to_i.clamp(1, 250)
    end
  end
end
