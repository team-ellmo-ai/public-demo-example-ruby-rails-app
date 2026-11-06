#!/usr/bin/env bash
# One-time (and safe-to-repeat) setup for the RoR - tryellmo.ai Demo app.
# Everything the app needs lives in this repo and in SQLite files under
# storage/ — no Postgres, MySQL, or Redis to provision, in dev or in
# whatever's treated as staging here.
set -Eeuo pipefail

cd "$(dirname "$0")/.."

# Any failure stops the script immediately with the failing step named.
# Every step is idempotent, so fixing the cause and re-running is always safe.
STEP="starting"
trap 'echo "" >&2; echo "✗ Setup failed during: $STEP" >&2; echo "  Fix the error above and re-run ./scripts/setup.sh (safe to repeat)." >&2' ERR

STEP="installing Ruby toolchain"
# shellcheck source=lib/ruby.sh
source scripts/lib/ruby.sh
ensure_ruby

STEP="installing gems"
echo "→ Installing gems..."
bundle check >/dev/null 2>&1 || bundle install
echo "✓ Gems installed"

STEP="preparing the database"
echo "→ Preparing the SQLite database..."
bin/rails db:prepare
echo "✓ Database ready (storage/*.sqlite3)"

STEP="seeding"
echo "→ Seeding example tasks..."
bin/rails db:seed
echo "✓ Seeded"

STEP="setting the Conductor preview URL"
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

trap - ERR
echo ""
echo "All done! Start the server with:"
echo "  ./scripts/dev.sh"
