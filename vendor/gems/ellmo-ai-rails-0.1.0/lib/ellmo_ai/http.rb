# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "zlib"
require "stringio"

module EllmoAi
  # The two HTTP calls the gem makes. Replaceable in tests (EllmoAi::Http.adapter = ...).
  module Http
    Response = Struct.new(:status, :body)

    class NetHttpAdapter
      def get(url, headers:, timeout:)
        uri = URI(url)
        request = Net::HTTP::Get.new(uri)
        headers.each { |k, v| request[k] = v }
        perform(uri, request, timeout)
      end

      def post(url, body:, headers:, timeout:)
        uri = URI(url)
        request = Net::HTTP::Post.new(uri)
        headers.each { |k, v| request[k] = v }
        request.body = body
        perform(uri, request, timeout)
      end

      private

      def perform(uri, request, timeout)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                        open_timeout: timeout, read_timeout: timeout, write_timeout: timeout) do |http|
          response = http.request(request)
          Response.new(response.code.to_i, response.body)
        end
      end
    end

    # Logs each call and its answer, "[ellmo-ai http]", at info level. On with `config.debug`.
    # A gzipped POST (the page-view upload) is logged decoded and in full before it's sent: it
    # holds visitors' headers (cookies included) and IPs, so keep this out of shared logs.
    class DebugAdapter
      def initialize(inner, logger:, body_limit:)
        @inner = inner
        @logger = logger
        @body_limit = body_limit.to_i
      end

      def get(url, headers:, timeout:)
        logged("GET", url, nil) { @inner.get(url, headers: headers, timeout: timeout) }
      end

      def post(url, body:, headers:, timeout:)
        @logger&.info("[ellmo-ai http] POST #{url} payload:\n#{payload(body, headers)}")
        logged("POST", url, body.to_s.bytesize) { @inner.post(url, body: body, headers: headers, timeout: timeout) }
      end

      private

      def logged(method, url, sent_bytes)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = yield
        ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        sent = sent_bytes ? " (sent #{sent_bytes} bytes)" : ""
        @logger&.info("[ellmo-ai http] #{method} #{url}#{sent} -> #{response.status} in #{ms}ms\n#{clip(response.body)}")
        response
      rescue StandardError => e
        @logger&.info("[ellmo-ai http] #{method} #{url} -> #{e.class}: #{e.message}")
        raise
      end

      def payload(body, headers)
        text = headers["content-encoding"] == "gzip" ? Zlib.gunzip(body.to_s) : body.to_s
        JSON.pretty_generate(JSON.parse(text))
      rescue StandardError
        text || body.to_s
      end

      def clip(text)
        text = text.to_s.dup.force_encoding(Encoding::UTF_8).scrub
        @body_limit.positive? && text.length > @body_limit ? "#{text[0, @body_limit]}… (#{text.length} chars)" : text
      end
    end

    class << self
      attr_writer :adapter

      def adapter
        @adapter ||= NetHttpAdapter.new
      end

      # The adapter to call with: `adapter`, wrapped in a DebugAdapter when `config.debug` is on.
      def for(config, adapter)
        return adapter unless config.debug

        DebugAdapter.new(adapter, logger: config.logger, body_limit: config.debug_body_limit)
      end
    end

    module_function

    def gzip(string)
      io = StringIO.new
      gz = Zlib::GzipWriter.new(io)
      gz.write(string)
      gz.close
      io.string
    end
  end
end
