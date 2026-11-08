#!/usr/bin/env bash
# See eLLMo working in this app, on your machine, without a client ID: starts a local stand-in
# for eLLMo's API (scripts/fake_ellmo_server.rb), runs the app against it with `rails server`,
# loads /tasks like a browser, and prints what the page got and what eLLMo received.
#
#   ./scripts/try-ellmo.sh                                  # defaults: cookie on, page views on
#   ELLMO_VISITOR_COOKIE=false ./scripts/try-ellmo.sh       # a site with the visitor cookie off
#   ELLMO_REPORT_VISITS=false ./scripts/try-ellmo.sh        # page views turned off in the app
#   FAKE_ELLMO_VISITS=false ./scripts/try-ellmo.sh          # page views switched off by eLLMo
set -euo pipefail
cd "$(dirname "$0")/.."

FAKE_PORT="${FAKE_ELLMO_PORT:-4010}"
APP_PORT="${APP_PORT:-3010}"
FAKE="http://127.0.0.1:${FAKE_PORT}"

ruby scripts/fake_ellmo_server.rb & FAKE_PID=$!
cleanup() { kill "$APP_PID" "$FAKE_PID" 2>/dev/null || true; }
trap cleanup EXIT

export ELLMO_CLIENT_ID="${ELLMO_CLIENT_ID:-9b596f7c-5762-4b23-8372-118728931b7f}"
export ELLMO_API_URL="${FAKE}/functions/v1" ELLMO_ANALYTICS_URL="${FAKE}/analytics" ELLMO_ACCESS_URL="${FAKE}/access"
bin/rails db:prepare >/dev/null
bin/rails server -p "$APP_PORT" -b 127.0.0.1 >log/try-ellmo.log 2>&1 & APP_PID=$!
for _ in $(seq 60); do curl -fs -o /dev/null -H "Accept: application/json" "http://127.0.0.1:${APP_PORT}/up" && break; sleep 0.5; done

page=$(curl -s -D /tmp/try-ellmo-headers -A "Mozilla/5.0 (try-ellmo)" -H "Accept: text/html" -H "Sec-Fetch-Dest: document" "http://127.0.0.1:${APP_PORT}/tasks")
echo
echo "GET /tasks"
grep -q 'application/ld+json' <<<"$page" && echo "  structured data: yes" || echo "  structured data: no"
grep -q 'data-ellmo="semantic"' <<<"$page" && echo "  semantic HTML:   yes" || echo "  semantic HTML:   no"
grep -qi '^set-cookie: ellmo_ext_vid=' /tmp/try-ellmo-headers && echo "  visitor cookie:  set" || echo "  visitor cookie:  not set"

echo "  waiting for the page-view batch (sent every 5 s)..."
sleep 6
echo
echo "eLLMo received:"
curl -s "${FAKE}/_received" | ruby -rjson -e '
  r = JSON.parse($stdin.read)
  r["content"].each { |q| puts "  content request: u=#{q["u"]} s=#{q["s"]}" }
  puts "  page views: #{r["pageViews"].size}"
  r["pageViews"].each { |v| puts "    #{v["url"]} status=#{v["status"]} visitorId=#{v["visitorId"].inspect} cookie header sent: #{v["headers"].key?("cookie")}" }'
