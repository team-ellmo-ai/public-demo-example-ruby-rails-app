#!/usr/bin/env bash
# One-time (and safe-to-repeat) setup for the RoR - tryellmo.ai Demo app.
# Everything the app needs lives in this repo and in SQLite files under
# storage/ — no Postgres, MySQL, or Redis to provision, in dev or in
# whatever's treated as staging here.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v ruby &>/dev/null; then
  echo "✗ Ruby is not installed. Install Ruby 3.4+ and re-run." >&2
  exit 1
fi
echo "✓ Ruby $(ruby -v | awk '{print $2}')"

if ! command -v bundle &>/dev/null; then
  echo "✗ Bundler is not installed. Run 'gem install bundler' and re-run." >&2
  exit 1
fi

echo "→ Installing gems..."
bundle check >/dev/null 2>&1 || bundle install
echo "✓ Gems installed"

echo "→ Preparing the SQLite database..."
bin/rails db:prepare
echo "✓ Database ready (storage/*.sqlite3)"

echo "→ Seeding example tasks..."
bin/rails db:seed
echo "✓ Seeded"

# Conductor cloud workspace (CONDUCTOR_IS_LOCAL=0): point the workspace's
# preview URL at the dev server. Not fatal if the CLI is missing or
# unauthenticated — ./scripts/dev.sh still works without it.
if [ "${CONDUCTOR_IS_LOCAL:-}" = "0" ] && command -v conductor &>/dev/null; then
  if PREVIEW_OUT=$(conductor preview set --port 3000 2>&1); then
    echo "✓ Preview URL: $(echo "$PREVIEW_OUT" | awk '/^URL/{print $2}')"
  else
    echo "⚠ Could not set the Conductor preview URL, continuing without it." >&2
    echo "$PREVIEW_OUT" >&2
  fi
fi

echo ""
echo "All done! Start the server with:"
echo "  ./scripts/dev.sh"
