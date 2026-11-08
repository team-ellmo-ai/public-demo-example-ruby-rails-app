# eLLMo AI: adds eLLMo's content to your pages and reports page views (in the background).
# Every setting and its default: see EllmoAi::Configuration (lib/ellmo_ai/configuration.rb in the gem).
EllmoAi.configure do |config|
  config.client_id = ENV["ELLMO_CLIENT_ID"]

  # This demo reads two switches from the environment, so you can try them without editing code
  # (scripts/try-ellmo.sh). In your app, set them here directly.
  #
  # The first-party ellmo_ext_vid cookie that recognizes returning visitors (default true). A
  # callable decides per request, e.g. after consent:
  #   config.visitor_cookie = ->(request) { request.cookies["cookie_consent"] == "yes" }
  config.visitor_cookie = ENV["ELLMO_VISITOR_COOKIE"] != "false"
  # Report page views to eLLMo (default true).
  config.report_visits = ENV["ELLMO_REPORT_VISITS"] != "false"

  # Off in the test environment unless you turn it on here.
  # config.enabled = true

  # Seconds content stays fresh before it's refreshed in the background.
  # config.cache_ttl = 600

  # Seconds a page waits for content when nothing is cached for it yet (0 = never wait).
  # config.cold_wait = 1.0

  # In the browser, hide your pages' other JSON-LD when eLLMo's is present, so eLLMo's is the only
  # active schema for crawlers that run JavaScript. Can cost you your own rich results.
  # config.hide_other_json_ld = true

  # Also send visitors' Cookie header to eLLMo (default false: it holds your session cookies).
  # config.forward_cookies = true

  # Log every call to eLLMo and its answer ("[ellmo-ai http]"). Or set ELLMO_DEBUG=1.
  # Page-view uploads are logged in full, visitors' IPs included.
  # config.debug = Rails.env.development?
end
