# RoR - tryellmo.ai Demo app

A small, fully working Ruby on Rails app: a SQLite-backed Tasks list with full
CRUD (create, show, edit, delete), used as a demo of a working Rails setup.

## Stack

* Ruby 3.4
* Rails 8.1
* SQLite3
* Minitest (default Rails test suite)

## Quick start

```bash
./scripts/dev.sh
```

This installs gems, prepares the SQLite database, seeds a few example tasks,
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
