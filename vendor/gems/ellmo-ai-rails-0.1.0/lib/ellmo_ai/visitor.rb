# frozen_string_literal: true

require "securerandom"

module EllmoAi
  # What eLLMo learns about a visitor from the request. Mirrors ellmo-ai-react (docs/content-api.md).
  module Visitor
    COOKIE = "ellmo_ext_vid"
    COOKIE_MAX_AGE = 400 * 24 * 60 * 60 # 400 days, the browser maximum
    CREDENTIAL_HEADERS = %w[authorization proxy-authorization].freeze

    module_function

    # Reduce a path to the pathname content is keyed by (no query string or fragment).
    def normalize_path(path)
      path = path.to_s.split(/[?#]/, 2).first.to_s
      path.empty? ? "/" : path
    end

    # Paths with a dot are static files (images, robots.txt, ...): never pages.
    def page_path?(path)
      !path.include?(".")
    end

    # document | navigation | frame | prefetch
    # - prefetch: browser or Turbo speculative prefetch (Sec-Purpose / X-Sec-Purpose / Purpose).
    # - frame: a Turbo Frame load: part of a page, not a page view.
    # - navigation: a Turbo Drive visit (fetch(), marked Sec-Fetch-Dest: empty).
    # - document: everything else, including crawlers, which don't send Sec-Fetch-*.
    def kind(env)
      purpose = [env["HTTP_PURPOSE"], env["HTTP_SEC_PURPOSE"], env["HTTP_X_SEC_PURPOSE"]].compact.join(" ")
      return "prefetch" if purpose.include?("prefetch")
      return "frame" if env["HTTP_TURBO_FRAME"]
      return "navigation" if env["HTTP_SEC_FETCH_DEST"] == "empty"

      "document"
    end

    # Every request header, lower-case and dashed, minus credentials and eLLMo's own headers.
    def headers(env)
      env.each_with_object({}) do |(key, value), out|
        next unless key.start_with?("HTTP_") && value.is_a?(String)

        name = key.delete_prefix("HTTP_").downcase.tr("_", "-")
        next if CREDENTIAL_HEADERS.include?(name) || name.start_with?("x-ellmo-")

        out[name] = value
      end
    end

    def ip(env)
      forwarded = env["HTTP_X_FORWARDED_FOR"].to_s.split(",").first.to_s.strip
      [forwarded, env["HTTP_X_REAL_IP"], env["HTTP_CF_CONNECTING_IP"], env["REMOTE_ADDR"]]
        .find { |value| value && !value.to_s.strip.empty? }
    end

    def visitor_id(env)
      cookie = env["HTTP_COOKIE"].to_s
      cookie.split(";").each do |part|
        key, value = part.strip.split("=", 2)
        return URI.decode_www_form_component(value.to_s) if key == COOKIE && value && !value.empty?
      end
      nil
    rescue ArgumentError
      nil
    end

    def new_visitor_id
      SecureRandom.uuid
    end

    def cookie(visitor_id, secure)
      parts = ["#{COOKIE}=#{visitor_id}", "Path=/", "Max-Age=#{COOKIE_MAX_AGE}", "SameSite=Lax", "HttpOnly"]
      parts << "Secure" if secure
      parts.join("; ")
    end
  end
end
