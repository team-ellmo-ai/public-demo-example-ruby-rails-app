# frozen_string_literal: true

require "socket"
require "json"
require "zlib"
require "stringio"
require "uri"

# A stand-in for eLLMo's three endpoints, on a local port, so the tests can check what this app
# sends to eLLMo and what it serves back, without a network or a real client ID:
#
#   GET  /functions/v1/embedded-content_v2?c=&u=   the page's structured data and semantic HTML
#   GET  /access/<client id>                        this client's switches: page views, content
#   POST /analytics                                 page views, as a gzipped JSON array
#
# Point the gem at it with config.api_url / analytics_url / access_url (public settings).
class FakeEllmo
  Request = Struct.new(:method, :path, :query, :headers, :body, keyword_init: true)

  STRUCTURED = '<script type="application/ld+json">{"@context":"https://schema.org","@type":"WebPage","name":"Tasks"}</script>'
  SEMANTIC = '<section data-ellmo="semantic">Tasks: a demo to-do list by eLLMo AI.</section>'

  attr_accessor :access

  def initialize(port: 0)
    @access = { "visits" => true, "content" => true }
    @requests = []
    @mutex = Mutex.new
    @server = TCPServer.new("127.0.0.1", port)
    @thread = Thread.new { loop { handle(@server.accept) } rescue IOError }
  end

  def url
    "http://127.0.0.1:#{@server.addr[1]}"
  end

  def requests
    @mutex.synchronize { @requests.dup }
  end

  def content_requests
    requests.select { |r| r.path.end_with?("/embedded-content_v2") }
  end

  def access_requests
    requests.select { |r| r.path.start_with?("/access/") }
  end

  # Every page view received, decoded.
  def page_views
    requests.select { |r| r.method == "POST" }.flat_map do |r|
      body = r.headers["content-encoding"] == "gzip" ? Zlib::GzipReader.new(StringIO.new(r.body)).read : r.body
      JSON.parse(body)
    end
  end

  def clear
    @mutex.synchronize { @requests.clear }
  end

  def stop
    @server.close
    @thread.join(1)
  end

  private

  def handle(socket)
    Thread.new do
      request_line = socket.gets.to_s
      method, target = request_line.split(" ")
      headers = {}
      while (line = socket.gets) && line != "\r\n"
        name, value = line.split(":", 2)
        headers[name.strip.downcase] = value.to_s.strip
      end
      body = headers["content-length"] ? socket.read(headers["content-length"].to_i) : ""
      uri = URI.parse(target.to_s)
      request = Request.new(method: method, path: uri.path, query: URI.decode_www_form(uri.query.to_s).to_h,
                            headers: headers, body: body)
      @mutex.synchronize { @requests << request }
      status, json = answer(request)
      socket.write("HTTP/1.1 #{status} OK\r\nContent-Type: application/json\r\nContent-Length: #{json.bytesize}\r\nConnection: close\r\n\r\n#{json}")
    rescue StandardError
      nil
    ensure
      socket.close
    end
  end

  def answer(request)
    # For scripts/try-ellmo.sh: what this stand-in has received so far
    if request.path == "/_received"
      @mutex.synchronize { @requests.pop } # this request itself
      return [ 200, JSON.generate("content" => content_requests.map(&:query), "pageViews" => page_views) ]
    end
    return [ 200, JSON.generate(access) ] if request.path.start_with?("/access/")
    return [ 204, "" ] if request.method == "POST"

    # Like the real API: no content for a client whose content is switched off
    return [ 403, "{}" ] unless access["content"]

    [ 200, JSON.generate("structured" => STRUCTURED, "semantic" => SEMANTIC) ]
  end
end
