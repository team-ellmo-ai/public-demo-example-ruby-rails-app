# frozen_string_literal: true

require "test_helper"
require_relative "../support/fake_ellmo"

# What a customer gets from eLLMo on this app: the Tasks pages carry eLLMo's structured data and
# semantic HTML, and page views are reported in the background. Runs the whole app (the gem's
# Rack middleware included) against FakeEllmo, a local stand-in for eLLMo's endpoints.
class EllmoTest < ActionDispatch::IntegrationTest
  CLIENT_ID = "9b596f7c-5762-4b23-8372-118728931b7f"

  setup do
    @ellmo = FakeEllmo.new
    configure_ellmo
  end

  teardown do
    EllmoAi.visit_reporter.shutdown
    # Back to the app's own setting for the other tests: off in the test environment
    EllmoAi.configure { |c| c.enabled = false }
    @ellmo.stop
  end

  # The common case for a customer who turned eLLMo's visitor cookie off.
  test "visitor cookie off: the page gets structured data and semantic HTML, and the page view is reported" do
    configure_ellmo { |c| c.visitor_cookie = false }

    get "/tasks", headers: browser

    assert_response :ok
    assert_includes response.body, "#{FakeEllmo::STRUCTURED}</head>", "structured data at the end of <head>"
    assert_match(%r{<body[^>]*>\s*#{Regexp.escape(FakeEllmo::SEMANTIC)}}, response.body, "semantic HTML at the top of <body>")
    assert_no_visitor_cookie

    content = @ellmo.content_requests.first
    assert_equal({ "c" => CLIENT_ID, "u" => "/tasks", "v" => EllmoAi::VERSION, "s" => "static" }, content.query)

    view = wait_for_page_views(1).first
    assert_equal "http://www.example.com/tasks", view["url"]
    assert_equal [ 200, "GET", "document", "rails-sdk", CLIENT_ID ], view.values_at("status", "method", "kind", "source", "clientId")
    assert_nil view["visitorId"], "no cookie, so no visitor ID"
    assert_equal "Mozilla/5.0 (Macintosh) Safari/605.1.15", view["headers"]["user-agent"]
    assert_kind_of Integer, view["latencyMs"]
  end

  test "visitor cookie on (the default): first-time visitors get ellmo_ext_vid, and page views carry it" do
    get "/tasks", headers: browser

    cookie = response.headers["set-cookie"].to_s[/ellmo_ext_vid=([^;]+)/, 1]
    assert cookie, "ellmo_ext_vid set"
    assert_match(/HttpOnly/i, response.headers["set-cookie"].to_s)
    assert_equal cookie, wait_for_page_views(1).first["visitorId"]

    get "/tasks", headers: browser
    refute_match(/ellmo_ext_vid=/, response.headers["set-cookie"].to_s, "a returning visitor keeps their cookie")
    assert_equal [ cookie, cookie ], wait_for_page_views(2).map { |v| v["visitorId"] }
  end

  test "page views switched off by eLLMo: the page still gets content, and nothing is reported" do
    @ellmo.access = { "visits" => false, "content" => true }

    get "/tasks", headers: browser

    assert_includes response.body, FakeEllmo::STRUCTURED
    assert_includes response.body, FakeEllmo::SEMANTIC
    assert_no_visitor_cookie
    assert_no_page_views
  end

  test "page views turned off in the app (config.report_visits = false): content, but nothing reported" do
    configure_ellmo { |c| c.report_visits = false }

    get "/tasks", headers: browser

    assert_includes response.body, FakeEllmo::SEMANTIC
    assert_no_visitor_cookie
    assert_no_page_views
  end

  test "content switched off by eLLMo: the page is served as the app made it, and the view is still reported" do
    @ellmo.access = { "visits" => true, "content" => false }

    get "/tasks", headers: browser

    assert_response :ok
    refute_includes response.body, "application/ld+json"
    refute_includes response.body, "data-ellmo"
    assert_equal [ "/tasks" ], wait_for_page_views(1).map { |v| URI(v["url"]).path }
  end

  test "the visitor's cookies (the app's session) aren't sent to eLLMo" do
    get "/tasks", headers: browser.merge("Cookie" => "_demo_session=secret; other=1")

    headers = wait_for_page_views(1).first["headers"]
    refute headers.key?("cookie")
    assert_equal "Mozilla/5.0 (Macintosh) Safari/605.1.15", headers["user-agent"]
  end

  test "JSON requests and files are left alone: no content, no page view" do
    task = tasks(:one)
    get "/tasks/#{task.id}.json", headers: { "Accept" => "application/json" }
    assert_response :ok
    assert_equal task.title, JSON.parse(response.body)["title"]
    get "/robots.txt"

    assert_empty @ellmo.content_requests
    assert_no_page_views
  end

  test "the health check (/up, for load balancers) gets no content and isn't a page view" do
    get "/up"

    assert_response :ok
    refute_includes response.body, "data-ellmo"
    assert_no_visitor_cookie
    assert_no_page_views
  end

  test "every page of the app gets content keyed by its own path" do
    task = tasks(:one)
    get "/tasks/#{task.id}", headers: browser
    get "/tasks/new", headers: browser

    assert_includes response.body, FakeEllmo::SEMANTIC
    assert_equal [ "/tasks/#{task.id}", "/tasks/new" ], @ellmo.content_requests.map { |r| r.query["u"] }
    assert_equal [ "/tasks/#{task.id}", "/tasks/new" ], wait_for_page_views(2).map { |v| URI(v["url"]).path }
  end

  private

  def configure_ellmo
    EllmoAi.configure do |c|
      c.client_id = CLIENT_ID
      c.enabled = true            # the gem is off in the test environment unless turned on
      c.api_url = "#{@ellmo.url}/functions/v1"
      c.analytics_url = "#{@ellmo.url}/analytics"
      c.access_url = "#{@ellmo.url}/access"
      c.flush_interval = 0.1      # send page views at once
      c.logger = Logger.new(nil)
      # The settings these tests change, back to their defaults (EllmoAi.config is app-wide)
      c.report_visits = true
      c.visitor_cookie = true
      c.forward_cookies = false
      yield c if block_given?
    end
  end

  # What a browser sends for a page load
  def browser
    { "Accept" => "text/html,application/xhtml+xml", "User-Agent" => "Mozilla/5.0 (Macintosh) Safari/605.1.15",
      "Sec-Fetch-Dest" => "document" }
  end

  def wait_for_page_views(count, timeout: 3)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until @ellmo.page_views.size >= count
      flunk "expected #{count} page views, got #{@ellmo.page_views.size}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.05
    end
    @ellmo.page_views
  end

  def assert_no_page_views
    EllmoAi.visit_reporter.shutdown # sends anything still queued
    assert_empty @ellmo.page_views
  end

  def assert_no_visitor_cookie
    refute_match(/ellmo_ext_vid=/, response.headers["set-cookie"].to_s)
  end
end
