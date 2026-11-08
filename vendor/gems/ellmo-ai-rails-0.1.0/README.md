# ellmo-ai-rails

Add [eLLMo AI](https://www.tryellmo.ai?utm_source=rubygems&utm_medium=package&utm_campaign=ellmo-ai-rails)'s content to the HTML your Rails app serves: **structured data** (schema.org JSON-LD) and **semantic HTML**, written and kept up to date by eLLMo, so search engines and AI assistants understand your pages. Page views (AI crawlers included) are reported to eLLMo in the background.

Works with Rails 6.1+ and any Rack app (Sinatra, Hanami) on Ruby 3.2+.

Customer implementation guide, with a flow diagram: [docs/implementation-guide.md](docs/implementation-guide.md).

## Install

```bash
bundle add ellmo-ai-rails
bin/rails g ellmo:install YOUR_CLIENT_ID   # or set ELLMO_CLIENT_ID and omit it
```

That's all: every HTML page now gets eLLMo's content, with no template changes. You need a **client ID** from eLLMo.

To choose where the content goes, add the helpers to your layout. Each piece is then left where you put it and never added twice:

```erb
<head>
  ...
  <%= ellmo_structured %>
</head>
<body>
  <%= ellmo_semantic %>
  ...
```

Outside Rails, add the middleware yourself: `use EllmoAi::Middleware` (Sinatra: `use EllmoAi::Middleware` in the app; configure with `EllmoAi.configure`). If other middleware can change the status (`Rack::ConditionalGet`), also put `use EllmoAi::FinalStatus` first, so page views carry the status the visitor got. Rails installs both.

## How it behaves

- **Server-side.** Content is in the HTML the server sends, so crawlers and AI assistants see it on the first request.
- **Cached, never in the way.** Content is cached in `Rails.cache` (10 minutes by default). Stale content is served while it's refreshed in the background. A page with nothing cached yet waits at most `cold_wait` (1 s) for it, while it renders, and otherwise goes out without it. The content request is made from a background thread, so a slow or unreachable eLLMo API never holds a page longer than that.
- **Page views in the background, in batches.** Each page view is queued in memory and the request goes on at once. A background thread sends the queue every 5 seconds (or at 100 views) as one compressed request. A batch that gets no answer or a `5xx` is retried once, a second later, then dropped; one the receiver refuses (`4xx`) is dropped at once. Views are never queued without limit (at most 10,000 held per process). A value that isn't valid UTF-8 (a crafted `Referer`, say) is repaired, so it can't lose the batch. Works with Puma's cluster mode: each worker process runs its own thread.
- **What counts as a page view.** Full page loads and Turbo Drive visits. Turbo Frame loads and prefetches (Turbo's hover prefetch, `Sec-Purpose: prefetch`) are not counted, and neither is Rails' health check (`/up`, `rails/health#show`), which load balancers and uptime monitors call every few seconds; it gets no content either. A prefetched page that is then shown isn't requested again, so it isn't counted either.
- **What it touches.** Only `GET`/`HEAD` requests for pages that return `text/html`. Paths ending in a file type (`.png`, `.js`, `.css`, `.txt`, `.xml`, `.pdf`...) are files and left alone; other dots are fine (`/users/jane.doe`, `/about.html`). Content is looked up only for requests that take HTML (an `Accept` with `text/html` or `*/*`, or none), and added only to `200` responses that aren't compressed or streamed and are UTF-8 (no other `charset` in `Content-Type` or `<meta>`). Anything else passes through unchanged, and the response body is always closed. An error in the gem never breaks a page; errors from your app are not caught.
- **Where content goes without the helpers.** Structured data at `<!--ELLMO_JSONLD-->` or else before `</head>`; semantic HTML at `<!--ELLMO_SUMMARY-->` or else right after `<body>`. A `</head>` or `<body>` inside a comment, `<script>`, `<style>` or `<template>` isn't the page's own and is skipped. Installed twice by hand, the middleware still adds content and counts the view once.
- **Visitor cookie.** First-time visitors get a first-party `ellmo_ext_vid` cookie (random ID, `HttpOnly`, `SameSite=Lax`, 400 days) so returning visitors are recognized. It isn't set on responses a CDN or proxy may cache for everyone (`Cache-Control: public` or `s-maxage`, without `private` / `no-store`), since a `Set-Cookie` there stops most of them caching the page; nor while page views are off (`report_visits`, or eLLMo's switch), when the ID would serve nothing. A cookie value that isn't a visitor ID (letters, digits, `-`) is ignored and replaced. Turn it off with `config.visitor_cookie = false`: page views are then sent without a visitor ID (`visitorId: null`) unless the visitor already has the cookie, so eLLMo counts them as views but not as returning visitors. List eLLMo and this cookie in your privacy and cookie policy.
- **What's sent to eLLMo.** For each page view: the URL, the request headers except `Authorization`, `Proxy-Authorization` and `Cookie` (your session cookies stay with you; `config.forward_cookies = true` sends cookies too), the visitor's IP (the first `X-Forwarded-For` entry, else `X-Real-IP`, else `CF-Connecting-IP`, else the connection's address), the status the visitor got (a `304` when their cached copy was current) and how long the page took.
- **Consent.** `config.visitor_cookie` also takes a callable, so the cookie is set only for visitors who agreed: `->(request) { request.cookies["consent"] == "yes" }`. One that raises counts as no.
- **Several sites in one app.** Each has its own client ID: give `config.client_id` a callable, `->(request) { IDS[request.host] }`. Each client gets its own content cache and its own switches; a request with no client ID is left alone. (The analytics receiver drops page views whose client ID doesn't match the site's hostname, so one ID can't serve unrelated sites.)
- **eLLMo can pause this client.** eLLMo can switch off page-view reporting or content for a client ID, each on its own. The gem checks once every 30 minutes per app process, from a background thread (each check gives up after `fetch_timeout`, 3 s): while page views are off it discards them without sending, and while content is off it fetches and serves none. A check that fails is skipped (the last answer stands; before any answer, both count as on); two failures in a row count as off until a check succeeds. eLLMo's servers enforce both switches regardless.
- **Test environment.** Off by default when `Rails.env.test?`, so your test suite makes no network calls. Set `config.enabled = true` to turn it on.

## Settings

All optional except the client ID. In `config/initializers/ellmo.rb`. Settings with an environment variable read it once, as their default: setting them in the initializer overrides it. A number that's missing, not a number or out of range falls back to its default.

| Setting | Default | |
|---|---|---|
| `client_id` | `ENV["ELLMO_CLIENT_ID"]` | Nothing happens without one. Or a callable of the request, for several sites |
| `enabled` | on, except in `test` | |
| `inject` | `true` | Add content automatically |
| `cache_store` | `Rails.cache` | Any `ActiveSupport::Cache` store. A `:null_store` (Rails' development default) is replaced with an in-memory cache |
| `cache_ttl` | `600` | Seconds content stays fresh |
| `stale_ttl` | `86_400` | Seconds stale content may still be served while refreshing |
| `cold_wait` | `1.0` | Seconds a page waits for content when nothing is cached (`0`: never wait) |
| `fetch_timeout` | `3.0` | Seconds per content request (in the background) |
| `hide_other_json_ld` | `false` | In the browser, set `type="application/ld+json+hidden"` on the page's other JSON-LD when eLLMo's is present. Only crawlers that run JavaScript see the change; it can cost you your own rich results. After a Turbo visit to a page without eLLMo content, your JSON-LD is shown again. Uses the page's CSP nonce when the app sets a nonce generator |
| `report_visits` | `true` | |
| `visitor_cookie` | `true` | Or a callable of the request (consent) |
| `forward_cookies` | `false` | Send the visitor's `Cookie` header to eLLMo (it holds your session cookies) |
| `flush_interval` | `5` | Seconds between batches |
| `batch_size` | `100` | Send early at this many views (max 250) |
| `max_queue` | `10_000` | Views held per process before new ones are dropped |
| `api_url` / `analytics_url` / `access_url` | eLLMo production | Or `ELLMO_API_URL` / `ELLMO_ANALYTICS_URL` / `ELLMO_ACCESS_URL` |
| `access_interval` | `1800` | Seconds between checks of this client's switches |
| `debug` | `ENV["ELLMO_DEBUG"] == "1"` | Logs every call to eLLMo and its answer, prefixed `[ellmo-ai http]`. Page-view uploads are logged in full, visitors' cookies and IPs included: keep it out of shared logs |
| `debug_body_limit` | `2000` | Response characters logged per call (`0`: all). Or `ELLMO_DEBUG_BODY` |

## Development

```bash
bundle install
bundle exec rake test                                         # unit + Rails integration tests
BUNDLE_GEMFILE=gemfiles/rails_6_1.gemfile bundle exec rake test  # against another Rails
```

Released by publishing a GitHub release tagged `rails@<version>` (matching `lib/ellmo_ai/version.rb`); see the root README.

## License

See [LICENSE](LICENSE).
