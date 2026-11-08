# frozen_string_literal: true

require "securerandom"

module EllmoAi
  # What eLLMo learns about a visitor from the request. Mirrors ellmo-ai-react (docs/content-api.md).
  module Visitor
    COOKIE = "ellmo_ext_vid"
    COOKIE_MAX_AGE = 400 * 24 * 60 * 60 # 400 days, the browser maximum
    CREDENTIAL_HEADERS = %w[authorization proxy-authorization].freeze
    # What this gem's (and the React SDK's) visitor IDs look like. Anything else in the cookie is
    # ignored, and the visitor gets a new ID.
    VISITOR_ID = /\A[A-Za-z0-9-]{1,64}\z/

    module_function

    # Reduce a path to the pathname content is keyed by (no query string or fragment).
    def normalize_path(path)
      path = path.to_s.split(/[?#]/, 2).first.to_s
      path.empty? ? "/" : path
    end

    # File types that are never pages. A dot alone doesn't make a file: /users/jane.doe and
    # /blog/v1.2 are pages, and so are /about.html and /index.php.
    FILE_EXTENSIONS = %w[
      png jpg jpeg gif svg webp avif ico bmp tif tiff heic woff woff2 ttf otf eot js mjs cjs css map
      json jsonld xml txt csv rss atom webmanifest yaml yml pdf doc docx xls xlsx ppt pptx zip gz tgz
      rar 7z mp4 webm mov mp3 wav ogg m4a avi wasm exe dmg apk
    ].to_set.freeze

    # Whether a path is a page rather than a file (an image, script, feed, robots.txt...).
    def page_path?(path)
      last = path.to_s.split("/").last.to_s
      extension = last.include?(".") ? last.split(".").last.to_s.downcase : nil
      extension.nil? || !FILE_EXTENSIONS.include?(extension)
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

    # Every request header, lower-case and dashed, minus credentials, eLLMo's own headers and (unless
    # `cookies`) the visitor's cookies: they hold the site's session cookies.
    def headers(env, cookies: false)
      env.each_with_object({}) do |(key, value), out|
        next unless key.start_with?("HTTP_") && value.is_a?(String)

        name = key.delete_prefix("HTTP_").downcase.tr("_", "-")
        next if CREDENTIAL_HEADERS.include?(name) || name.start_with?("x-ellmo-")
        next if name == "cookie" && !cookies

        out[name] = utf8(value)
      end
    end

    # The string as valid UTF-8 (invalid bytes replaced), so a page view always serializes.
    def utf8(value)
      return value if value.encoding == Encoding::UTF_8 && value.valid_encoding?

      value.dup.force_encoding(Encoding::UTF_8).scrub("\uFFFD")
    end

    # Whether the request is for a page a person or crawler reads: no Accept header, */* or HTML.
    # API and asset requests (Accept: application/json, image/*) aren't.
    def accepts_html?(env)
      accept = env["HTTP_ACCEPT"].to_s
      accept.empty? || accept.include?("text/html") || accept.include?("application/xhtml+xml") || accept.include?("*/*")
    end

    def ip(env)
      forwarded = env["HTTP_X_FORWARDED_FOR"].to_s.split(",").first.to_s.strip
      found = [forwarded, env["HTTP_X_REAL_IP"], env["HTTP_CF_CONNECTING_IP"], env["REMOTE_ADDR"]]
              .find { |value| value && !value.to_s.strip.empty? }
      found && utf8(found.to_s)
    end

    def visitor_id(env)
      cookie = env["HTTP_COOKIE"].to_s
      cookie.split(";").each do |part|
        key, value = part.strip.split("=", 2)
        next unless key == COOKIE && value && !value.empty?

        id = URI.decode_www_form_component(value.to_s)
        return id.match?(VISITOR_ID) ? id : nil
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
