#!/usr/bin/env bash
# Set up (idempotent) and start the dev server on :3000, bound to all
# interfaces so a Conductor cloud workspace can reach it through the preview
# URL. Extra arguments go to `rails server`.
#   ./scripts/dev.sh [rails server options]
set -Eeuo pipefail

cd "$(dirname "$0")/.."

./scripts/setup.sh

# setup.sh ran in its own process; put the same pinned Ruby on our PATH.
# shellcheck source=lib/ruby.sh
source scripts/lib/ruby.sh
use_ruby

PORT="${PORT:-3000}"
exec bin/rails server -b 0.0.0.0 -p "$PORT" "$@"
