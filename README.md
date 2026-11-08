# Ruby on Rails demo app, by eLLMo AI

A small, fully working Ruby on Rails app from [eLLMo AI](https://www.tryellmo.ai?utm_source=github&utm_medium=repo&utm_campaign=public-demo-example-ruby-rails-app): a SQLite-backed Tasks list with full CRUD (create, show, edit, delete).

It's also where you download **`ellmo-ai-rails`**, eLLMo's gem for Rails apps, until it's published on RubyGems. See [Download the eLLMo Rails gem](#download-the-ellmo-rails-gem).

## About eLLMo AI

[eLLMo AI](https://www.tryellmo.ai?utm_source=github&utm_medium=repo&utm_campaign=public-demo-example-ruby-rails-app) shows ecommerce brands why shoppers don't buy, then fixes it.

- **[Buyer simulation](https://www.tryellmo.ai/simulation?utm_source=github&utm_medium=repo&utm_campaign=public-demo-example-ruby-rails-app):** 10 to 50 simulated buyers, built from real buyer data and matched to your customers, shop your product page. In 15 minutes you see where they hesitate, in their own words, ranked by how many hit each problem.
- **[A/B testing](https://www.tryellmo.ai/ab-testing?utm_source=github&utm_medium=repo&utm_campaign=public-demo-example-ruby-rails-app):** eLLMo builds the fix as Shopify theme code, tests it on live traffic and ships the winner to your theme.
- **[AI Search](https://www.tryellmo.ai/search?utm_source=github&utm_medium=repo&utm_campaign=public-demo-example-ruby-rails-app):** eLLMo audits how AI answer engines like ChatGPT, Claude, Gemini and Perplexity read your site, and ranks the fixes that close the gap.

[Start now](https://app.tryellmo.ai/signup?utm_source=github&utm_medium=repo&utm_campaign=public-demo-example-ruby-rails-app) · [Book a demo](https://www.tryellmo.ai/get-demo?utm_source=github&utm_medium=repo&utm_campaign=public-demo-example-ruby-rails-app) · [Pricing](https://www.tryellmo.ai/pricing?utm_source=github&utm_medium=repo&utm_campaign=public-demo-example-ruby-rails-app) · [Docs](https://docs.tryellmo.ai?utm_source=github&utm_medium=repo&utm_campaign=public-demo-example-ruby-rails-app)

## Download the eLLMo Rails gem

[`dist/ellmo-ai-rails-0.1.0.gem`](dist/ellmo-ai-rails-0.1.0.gem) adds eLLMo's content (schema.org structured data and semantic HTML) to the HTML your Rails app serves, so search engines and AI assistants understand your pages. It also reports page views, AI crawler visits included, to eLLMo in the background. It works with Rails 6.1+ and any Rack app on Ruby 3.2+.

The gem is included with an eLLMo AI subscription, and you need the client ID eLLMo issues for your site. Install it by following the [Rails SDK docs](https://docs.tryellmo.ai/developers/rails/overview?utm_source=github&utm_medium=repo&utm_campaign=public-demo-example-ruby-rails-app).

SHA-256 of `ellmo-ai-rails-0.1.0.gem`:

```text
48a21d20bb41a06cb97ed3ee7ab2962a48ec0e206991feea5363227339f73f88
```

This demo app has the gem installed: it is vendored in `vendor/gems/ellmo-ai-rails-0.1.0`, and `config/initializers/ellmo.rb` reads the client ID from `ELLMO_CLIENT_ID`.

## eLLMo in this app

With a client ID, every Tasks page the app serves gets eLLMo's content, with no template changes:

- **Structured data** (schema.org JSON-LD) just before `</head>`.
- **Semantic HTML** right after `<body>`.

Page views are queued and sent to eLLMo from a background thread, in batches, so they never slow a page down. JSON responses (`/tasks.json`), files (`/robots.txt`) and the health check (`/up`) are left alone.

The settings this demo shows, in `config/initializers/ellmo.rb`:

| Setting | Default | Here |
|---|---|---|
| `visitor_cookie` | `true` | `ELLMO_VISITOR_COOKIE=false` turns off the first-party `ellmo_ext_vid` cookie that recognizes returning visitors. Page views are still reported, without a visitor ID. A callable can wait for consent instead. |
| `report_visits` | `true` | `ELLMO_REPORT_VISITS=false` stops page views. Pages still get content. |
| `forward_cookies` | `false` | Your visitors' `Cookie` header (your session cookies) is never sent to eLLMo unless you turn this on. |

eLLMo can also switch page views or content off for a client ID from its side; the gem checks every 30 minutes and follows.

### See it working, without a client ID

`./scripts/try-ellmo.sh` does four things:

1. It starts a local stand-in for eLLMo's API (`scripts/fake_ellmo_server.rb`).
2. It runs this app against that stand-in with `rails server`.
3. It loads `/tasks` like a browser.
4. It prints what the page got and what eLLMo received.

```bash
./scripts/try-ellmo.sh                              # defaults
ELLMO_VISITOR_COOKIE=false ./scripts/try-ellmo.sh   # visitor cookie off
ELLMO_REPORT_VISITS=false ./scripts/try-ellmo.sh    # page views off in the app
FAKE_ELLMO_VISITS=false ./scripts/try-ellmo.sh      # page views switched off by eLLMo
```

With the visitor cookie off:

```text
GET /tasks
  structured data: yes
  semantic HTML:   yes
  visitor cookie:  not set
eLLMo received:
  content request: u=/tasks s=static
  page views: 1
    http://127.0.0.1:3010/tasks status=200 visitorId=nil cookie header sent: false
```

### Tests

`test/integration/ellmo_test.rb` runs the whole app, the gem's middleware included, against the same stand-in (`test/support/fake_ellmo.rb`). It covers:

- **Visitor cookie off:** structured data and semantic HTML in the page, no cookie, and the page view is reported without a visitor ID.
- **Visitor cookie on:** a first-time visitor gets the cookie, and their page views carry its ID.
- **Page views switched off by eLLMo, or turned off in the app:** pages still get content, and nothing is reported.
- **Content switched off by eLLMo:** pages go out as the app rendered them, and views are still reported.
- **Your visitors' cookies aren't sent to eLLMo.**
- **JSON, files and the health check are left alone.**
- **Each page gets the content for its own path.**

## Stack

* Ruby 3.4
* Rails 8.1
* SQLite3
* Minitest (default Rails test suite)

## Quick start

```bash
./scripts/dev.sh
```

This installs the pinned Ruby (`.ruby-version`, via your existing
mise/rvm/rbenv/asdf — or installs mise if you have none) and the pinned
Bundler (`Gemfile.lock`), then installs gems, prepares the SQLite database, seeds a few example tasks,
and starts the server on :3000 (bound to 0.0.0.0, so it works in a Conductor
cloud workspace too). Visit http://localhost:3000 — it redirects to `/tasks`.

Run just the setup step on its own with `./scripts/setup.sh`.

## Manual setup

If you'd rather run the steps yourself:

```bash
bundle install
bin/rails db:prepare   # creates the database and runs migrations
bin/rails db:seed      # loads a few example tasks
bin/rails server
```

## Test

```bash
bin/rails test           # models, controllers, eLLMo (test/integration/ellmo_test.rb)
bin/rails test:system    # browser-driven (Capybara + headless Chrome)
```

## License

**Copyright © 2026 eLLMo AI. All rights reserved.**

This is proprietary software, not open source. The demo app and the `ellmo-ai-rails` gem in [`dist/`](dist/) are licensed under [`LICENSE.md`](LICENSE.md) and the eLLMo AI [Terms & Conditions](https://www.tryellmo.ai/legal/terms): a limited, revocable license for eLLMo AI subscribers, for the websites their subscription covers, that ends when the subscription does. Public source code doesn't grant any right to use, copy or redistribute it.

Licensing questions: sales@tryellmo.ai.
