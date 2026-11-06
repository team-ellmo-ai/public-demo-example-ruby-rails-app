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

[`dist/ellmo-ai-rails-0.1.0.gem`](dist/ellmo-ai-rails-0.1.0.gem) adds eLLMo's content (schema.org structured data and semantic HTML) to the HTML your Rails app serves, so search engines and AI assistants understand your pages. It also reports page views, AI crawler visits included, to eLLMo in the background. It works with Rails 7.1+ and any Rack app on Ruby 3.2+.

The gem is included with an eLLMo AI subscription, and you need the client ID eLLMo issues for your site. Install it by following the [Rails SDK docs](https://docs.tryellmo.ai/developers/rails/overview?utm_source=github&utm_medium=repo&utm_campaign=public-demo-example-ruby-rails-app).

SHA-256 of `ellmo-ai-rails-0.1.0.gem`:

```text
eab8fd5ce3957e8e01e6a3950860fb5e86b92f88af31202e02f27b00fff2f727
```

This demo app has the gem installed: it is vendored in `vendor/gems/ellmo-ai-rails-0.1.0`, and `config/initializers/ellmo.rb` reads the client ID from `ELLMO_CLIENT_ID`.

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
bin/rails test           # models, controllers
bin/rails test:system    # browser-driven (Capybara + headless Chrome)
```

## License

**Copyright © 2026 eLLMo AI. All rights reserved.**

This is proprietary software, not open source. The demo app and the `ellmo-ai-rails` gem in [`dist/`](dist/) are licensed under [`LICENSE.md`](LICENSE.md) and the eLLMo AI [Terms & Conditions](https://www.tryellmo.ai/legal/terms): a limited, revocable license for eLLMo AI subscribers, for the websites their subscription covers, that ends when the subscription does. The source is public so you can inspect it before you install it. That doesn't grant any right to use, copy or redistribute it.

If you use the gem, you're responsible for disclosing eLLMo and the `ellmo_ext_vid` cookie to your visitors and for any consent the law requires (see License §12).

Licensing questions: armando@tryellmo.ai.
