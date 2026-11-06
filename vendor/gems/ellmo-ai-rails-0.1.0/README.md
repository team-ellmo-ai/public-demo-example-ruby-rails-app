# ellmo-ai-rails

Add [eLLMo AI](https://www.tryellmo.ai?utm_source=rubygems&utm_medium=package&utm_campaign=ellmo-ai-rails)'s content to the HTML your Rails app serves: **structured data** (schema.org JSON-LD) and **semantic HTML**, written and kept up to date by eLLMo, so search engines and AI assistants understand your pages. Page views (AI crawlers included) are reported to eLLMo in the background.

Works with Rails 7.1+ and any Rack app (Sinatra, Hanami) on Ruby 3.2+.

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

Outside Rails, add the middleware yourself: `use EllmoAi::Middleware` (Sinatra: `use EllmoAi::Middleware` in the app; configure with `EllmoAi.configure`).

## How it behaves

- **Server-side.** Content is in the HTML the server sends, so crawlers and AI assistants see it on the first request.
- **Cached, never in the way.** Content is cached in `Rails.cache` (10 minutes by default). Stale content is served while it's refreshed in the background. A page with nothing cached yet waits at most `cold_wait` (1 s) for it, while it renders, and otherwise goes out without it. The content request is made from a background thread, so a slow or unreachable eLLMo API never holds a page longer than that.
- **Page views in the background, in batches.** Each page view is queued in memory and the request goes on at once. A background thread sends the queue every 5 seconds (or at 100 views) as one compressed request. If eLLMo can't be reached, views are dropped, never queued without limit (at most 10,000 held per process). Works with Puma's cluster mode: each worker process runs its own thread.
- **What counts as a page view.** Full page loads and Turbo Drive visits. Turbo Frame loads and prefetches (Turbo's hover prefetch, `Sec-Purpose: prefetch`) are not counted. A prefetched page that is then shown isn't requested again, so it isn't counted either.
- **What it touches.** Only `GET`/`HEAD` requests for paths without a file extension that return `text/html`. Content is added only to `200` responses that aren't compressed or streamed. Anything else passes through unchanged. An error in the gem never breaks a page; errors from your app are not caught.
- **Where content goes without the helpers.** Structured data at `<!--ELLMO_JSONLD-->` or else before `</head>`; semantic HTML at `<!--ELLMO_SUMMARY-->` or else right after `<body>`.
- **Visitor cookie.** First-time visitors get a first-party `ellmo_ext_vid` cookie (random ID, `HttpOnly`, `SameSite=Lax`, 400 days) so returning visitors are recognized. Turn off with `config.visitor_cookie = false`.
- **What's sent to eLLMo.** For each page view: the URL, the request headers except `Authorization` and `Proxy-Authorization` (cookies included), the visitor's IP, the response status and how long the page took.
- **eLLMo can pause this client.** eLLMo can switch off page-view reporting or content for a client ID, each on its own. The gem checks once every 30 minutes per app process, from a background thread: while page views are off it discards them without sending, and while content is off it fetches and serves none. A check that fails is skipped (the last answer stands; before any answer, both count as on); two failures in a row count as off until a check succeeds. eLLMo's servers enforce both switches regardless.
- **Test environment.** Off by default when `Rails.env.test?`, so your test suite makes no network calls. Set `config.enabled = true` to turn it on.

## Settings

All optional except the client ID. In `config/initializers/ellmo.rb`:

| Setting | Default | |
|---|---|---|
| `client_id` | `ENV["ELLMO_CLIENT_ID"]` | Nothing happens without one |
| `enabled` | on, except in `test` | |
| `inject` | `true` | Add content automatically |
| `cache_store` | `Rails.cache` | Any `ActiveSupport::Cache` store. A `:null_store` (Rails' development default) is replaced with an in-memory cache |
| `cache_ttl` | `600` | Seconds content stays fresh |
| `stale_ttl` | `86_400` | Seconds stale content may still be served while refreshing |
| `cold_wait` | `1.0` | Seconds a page waits for content when nothing is cached (`0`: never wait) |
| `fetch_timeout` | `3.0` | Seconds per content request (in the background) |
| `report_visits` | `true` | |
| `visitor_cookie` | `true` | |
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
BUNDLE_GEMFILE=gemfiles/rails_7_1.gemfile bundle exec rake test  # against another Rails
```

Released by publishing a GitHub release tagged `rails@<version>` (matching `lib/ellmo_ai/version.rb`); see the root README.

## License

See [LICENSE](LICENSE).
