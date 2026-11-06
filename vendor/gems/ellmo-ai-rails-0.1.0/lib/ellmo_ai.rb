# frozen_string_literal: true

require "ellmo_ai/version"
require "ellmo_ai/configuration"
require "ellmo_ai/http"
require "ellmo_ai/client_access"
require "ellmo_ai/visitor"
require "ellmo_ai/content_store"
require "ellmo_ai/visit_reporter"
require "ellmo_ai/injector"
require "ellmo_ai/middleware"
require "ellmo_ai/helpers"

# eLLMo AI for Ruby on Rails (and any Rack app): adds eLLMo's content (structured data and
# semantic HTML) to the HTML your app serves, and reports page views to eLLMo in the background.
module EllmoAi
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
      reset!
      config
    end

    # This client's switches (page views, content), checked every 30 minutes per process.
    def client_access
      @client_access ||= ClientAccess.new(config)
    end

    # The process-wide content cache. Rebuilt after `configure`.
    def content_store
      @content_store ||= ContentStore.new(config, access: client_access)
    end

    # The process-wide visit reporter. Fork-safe: each process (Puma worker) gets its own thread.
    def visit_reporter
      @visit_reporter ||= VisitReporter.new(config, access: client_access)
    end

    # Drop the cache and reporter so they pick up new configuration. Pending visits are flushed.
    def reset!
      @visit_reporter&.shutdown
      @visit_reporter = nil
      @content_store = nil
      @client_access = nil
    end
  end
end

require "ellmo_ai/railtie" if defined?(Rails::Railtie)
