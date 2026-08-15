#!/usr/bin/env bash
set -euo pipefail

# Catches issue #19: dyld missing _luaopen_base on launch.
# Prefer an explicit .app path; otherwise accept Aqloss.app or aqloss.app.

find_app() {
  if [ -n "${1:-}" ]; then
    echo "$1"
    return
  fi
  local candidate
  for candidate in \
    "build/macos/Build/Products/Release/Aqloss.app" \
    "build/macos/Build/Products/Release/aqloss.app"
  do
    if [ -d "$candidate" ]; then
      echo "$candidate"
      return
    fi
  done
  echo "build/macos/Build/Products/Release/Aqloss.app"
}

APP="$(find_app "${1:-}")"
BIN=""
if [ -x "${APP}/Contents/MacOS/aqloss" ]; then
  BIN="${APP}/Contents/MacOS/aqloss"
elif [ -d "${APP}/Contents/MacOS" ]; then
  BIN="$(find "${APP}/Contents/MacOS" -maxdepth 1 -type f -perm -111 | head -n 1)"
fi

if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
  echo "Missing macOS binary in $APP" >&2
  find "$(dirname "$APP")" -maxdepth 3 -type f 2>/dev/null | head -20 || true
  exit 1
fi

undefined_lua() {
  # Fat binaries need an explicit arch; also try the default nm -u view.
  local arch
  for arch in arm64 x86_64; do
    nm -u -arch "$arch" "$BIN" 2>/dev/null || true
  done
  nm -u "$BIN" 2>/dev/null || true
}

echo "Checking for undefined Lua symbols in $BIN ..."
if undefined_lua | grep -q 'luaopen_'; then
  echo "Undefined Lua symbols detected (likely launch crash on user machines):" >&2
  undefined_lua | grep 'luaopen_' || true
  exit 1
fi

echo "Launching $BIN for smoke test ..."
"$BIN" &
PID=$!
trap 'kill "$PID" 2>/dev/null || true' EXIT

for _ in $(seq 1 30); do
  if ! kill -0 "$PID" 2>/dev/null; then
    wait "$PID" || true
    echo "Aqloss exited during smoke test (crashed or failed to start)." >&2
    exit 1
  fi
  sleep 1
done

echo "macOS smoke test passed (process alive for 30s)."
