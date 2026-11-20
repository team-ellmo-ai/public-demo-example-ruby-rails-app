# frozen_string_literal: true

require "monitor"
require "set"
require "ellmo_ai/version"
require "ellmo_ai/configuration"
require "ellmo_ai/http"
require "ellmo_ai/client_access"
require "ellmo_ai/visitor"
require "ellmo_ai/content_store"
require "ellmo_ai/visit_reporter"
require "ellmo_ai/injector"
require "ellmo_ai/json_ld_cleanup"
require "ellmo_ai/middleware"
require "ellmo_ai/helpers"

# eLLMo AI for Ruby on Rails (and any Rack app): adds eLLMo's content (structured data and
# semantic HTML) to the HTML your app serves, and reports page views to eLLMo in the background.
module EllmoAi
  # First use from two threads at once builds one of each, not two. Reentrant: the reporter is
  # built under it and asks for a client's switches.
  LOCK = Monitor.new

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
      reset!
      config
    end

    # A client's switches (page views, content), checked every 30 minutes per process. One per
    # client ID: the configured one, or each one a callable client_id returns.
    def client_access(client_id = default_client_id)
      LOCK.synchronize { (@client_accesses ||= {})[client_id.to_s] ||= ClientAccess.new(config, client_id: client_id) }
    end

    # A client's content cache. Rebuilt after `configure`.
    def content_store(client_id = default_client_id)
      LOCK.synchronize do
        (@content_stores ||= {})[client_id.to_s] ||= ContentStore.new(config, access: client_access(client_id), client_id: client_id)
      end
    end

    # The process-wide visit reporter (every client's page views). Fork-safe: each process (Puma
    # worker) gets its own thread.
    def visit_reporter
      @visit_reporter || LOCK.synchronize do
        @visit_reporter ||= VisitReporter.new(config, access: client_access, access_for: ->(id) { client_access(id || default_client_id) })
      end
    end

    # Drop the caches and reporter so they pick up new configuration. Pending visits are flushed.
    def reset!
      @visit_reporter&.shutdown
      @visit_reporter = nil
      LOCK.synchronize do
        @content_stores = nil
        @client_accesses = nil
      end
    end

    private

    # The configured client ID, when it's a string (a callable has no single one).
    def default_client_id
      config.client_id.respond_to?(:call) ? nil : config.client_id
    end
  end
end

require "ellmo_ai/railtie" if defined?(Rails::Railtie)
