#!/usr/bin/env bash
# Set up (idempotent) and start the dev server on :3000, bound to all
# interfaces so a Conductor cloud workspace can reach it through the preview
# URL. Any server already running from this app is stopped first. Extra
# arguments go to `rails server`.
#   ./scripts/dev.sh [rails server options]
set -Eeuo pipefail

cd "$(dirname "$0")/.."
APP_DIR="$(pwd -P)"
PORT="${PORT:-3000}"
PIDFILE="tmp/pids/server.pid"

./scripts/setup.sh

# setup.sh ran in its own process; put the same pinned Ruby on our PATH.
# shellcheck source=lib/ruby.sh
source scripts/lib/ruby.sh
use_ruby

# True if $1 is a live process whose working directory is this app.
is_our_process() {
  local cwd
  kill -0 "$1" 2>/dev/null || return 1
  cwd="$(lsof -a -p "$1" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)"
  [ "$cwd" = "$APP_DIR" ]
}

stop_pid() {
  local pid=$1 i
  echo "→ Stopping existing dev server (pid $pid)..."
  kill -TERM "$pid" 2>/dev/null || return 0
  for i in {1..20}; do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 0.5
  done
  kill -KILL "$pid" 2>/dev/null || true
}

# 1. The server recorded in this app's pid file (any port).
if [ -f "$PIDFILE" ]; then
  pid="$(cat "$PIDFILE")"
  if is_our_process "$pid"; then stop_pid "$pid"; fi
  rm -f "$PIDFILE"
fi

# 2. Anything from this app still listening on $PORT (e.g. pid file lost).
for pid in $(lsof -nP -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true); do
  if is_our_process "$pid"; then stop_pid "$pid"; fi
done

# 3. Never kill another project's process — explain instead.
if holder="$(lsof -nP -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -1)" && [ -n "$holder" ]; then
  echo "✗ Port $PORT is in use by another app (pid $holder: $(ps -o command= -p "$holder" | cut -c1-80))." >&2
  echo "  Stop it, or run on another port: PORT=3001 ./scripts/dev.sh" >&2
  exit 1
fi

exec bin/rails server -b 0.0.0.0 -p "$PORT" "$@"
