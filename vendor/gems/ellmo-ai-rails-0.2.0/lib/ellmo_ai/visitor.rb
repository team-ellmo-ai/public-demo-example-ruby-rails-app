# frozen_string_literal: true

require "securerandom"

module EllmoAi
  # What eLLMo learns about a visitor from the request. Mirrors ellmo-ai-react (docs/content-api.md).
  module Visitor
    COOKIE = "ellmo_ext_vid"
    COOKIE_MAX_AGE = 400 * 24 * 60 * 60 # 400 days, the browser maximum
    CREDENTIAL_HEADERS = %w[authorization proxy-authorization].freeze
    # The request headers sent to eLLMo by default (the same list as ellmo-ai-react).
    # Everything else needs config.forward_headers; Cookie needs config.forward_cookies.
    # - user-agent, referer, accept, accept-language: the basics of each visit.
    # - host, x-forwarded-host, x-forwarded-proto: the site's own address, not the visitor's.
    # - x-vercel-ip-country, x-vercel-ip-city, cf-ipcountry: the visitor's country and city, as
    #   the host already worked them out.
    DEFAULT_HEADERS = %w[
      user-agent referer accept accept-language host x-forwarded-host x-forwarded-proto
      x-vercel-ip-country x-vercel-ip-city cf-ipcountry
    ].to_set.freeze
    # Headers that carry the visitor's full IP address. While IPs are truncated (the default)
    # they're never sent, even with config.forward_headers: the IP travels truncated, on its own.
    IP_HEADERS = %w[
      x-forwarded-for x-real-ip cf-connecting-ip cf-connecting-ipv6 true-client-ip x-client-ip
      x-cluster-client-ip fastly-client-ip forwarded x-original-forwarded-for x-vercel-forwarded-for
      x-vercel-proxied-for x-envoy-external-address
    ].to_set.freeze
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

    # The request headers to share, lower-case and dashed: DEFAULT_HEADERS (every header with
    # `all`), the visitor's cookies only with `cookies` (they hold the site's session cookies),
    # never credentials or eLLMo's own headers, and no IP_HEADERS unless `full_ips`. Each option
    # works on its own.
    def headers(env, cookies: false, all: false, full_ips: false)
      env.each_with_object({}) do |(key, value), out|
        next unless key.start_with?("HTTP_") && value.is_a?(String)

        name = key.delete_prefix("HTTP_").downcase.tr("_", "-")
        next if CREDENTIAL_HEADERS.include?(name) || name.start_with?("x-ellmo-")
        if name == "cookie"
          next unless cookies
        elsif !DEFAULT_HEADERS.include?(name)
          next unless all
          next if IP_HEADERS.include?(name) && !full_ips
        end

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

    # The visitor's IP address, truncated unless `truncate` is false (see truncate_ip).
    def ip(env, truncate: true)
      forwarded = env["HTTP_X_FORWARDED_FOR"].to_s.split(",").first.to_s.strip
      found = [forwarded, env["HTTP_X_REAL_IP"], env["HTTP_CF_CONNECTING_IP"], env["REMOTE_ADDR"]]
              .find { |value| value && !value.to_s.strip.empty? }
      return nil unless found

      truncate ? truncate_ip(utf8(found.to_s)) : utf8(found.to_s)
    end

    IPV4 = /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\z/

    # An IP address with the part that identifies one device removed: IPv4 to its first 24 bits
    # (203.0.113.9 -> 203.0.113.0), IPv6 to its first 48 (2001:db8:85a3::8a2e:370:7334 ->
    # 2001:db8:85a3::), an IPv4-mapped IPv6 address as IPv4. Enough for country-level location,
    # not for one household. A port or an IPv6 zone is dropped first. nil for anything that isn't
    # an IP address, so it isn't sent. Same results as ellmo-ai-react.
    def truncate_ip(value)
      ip = value.to_s.strip
      if (bracketed = ip[/\A\[([^\]]+)\](?::\d+)?\z/, 1])
        ip = bracketed
      elsif ip.match?(/\A\d{1,3}(\.\d{1,3}){3}:\d+\z/)
        ip = ip[0...ip.rindex(":")]
      end
      ip = ip.sub(/%.*\z/m, "")

      if (v4 = ipv4(ip))
        return "#{v4[0]}.#{v4[1]}.#{v4[2]}.0"
      end

      groups = ipv6_groups(ip)
      return nil unless groups
      return "#{groups[6] >> 8}.#{groups[6] & 255}.#{groups[7] >> 8}.0" if groups[0, 5].all?(&:zero?) && groups[5] == 0xffff

      # The first three groups, then "::" for the zeroed rest (trailing zero groups fold into it)
      kept = groups[0, 3]
      kept.pop while kept.any? && kept.last.zero?
      "#{kept.map { |group| group.to_s(16) }.join(":")}::"
    end

    def ipv4(text)
      match = IPV4.match(text)
      return nil unless match

      octets = match.captures.map(&:to_i)
      octets.all? { |n| n <= 255 } ? octets : nil
    end

    # The eight 16-bit groups of an IPv6 address, or nil if it isn't one.
    def ipv6_groups(text)
      return nil unless text.include?(":") && text.match?(/\A[0-9a-f:.]+\z/i)

      halves = text.split("::", -1)
      return nil if halves.length > 2

      head = ipv6_part(halves[0], halves.length == 1)
      tail = halves.length == 2 ? ipv6_part(halves[1], true) : []
      return nil unless head && tail
      return (head.length == 8 ? head : nil) if halves.length == 1

      missing = 8 - head.length - tail.length
      missing >= 1 ? head + Array.new(missing, 0) + tail : nil
    end

    def ipv6_part(part, holds_end)
      return [] if part.empty?

      pieces = part.split(":", -1)
      groups = []
      pieces.each_with_index do |piece, i|
        if holds_end && i == pieces.length - 1 && piece.include?(".")
          # An IPv4 address in the last 32 bits (::ffff:203.0.113.9)
          v4 = ipv4(piece)
          return nil unless v4

          groups.push((v4[0] * 256) + v4[1], (v4[2] * 256) + v4[3])
        elsif piece.match?(/\A[0-9a-f]{1,4}\z/i)
          groups << piece.to_i(16)
        else
          return nil
        end
      end
      groups
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
