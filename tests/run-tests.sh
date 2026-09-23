#!/usr/bin/env bash
# mcp-call self-tests — hermetic against the local fake server.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MC="$HERE/../scripts/mcp-call.sh"
TMP="$(mktemp -d)"
PASS=0; FAIL=0
cleanup() { [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT

t()     { local n="$1"; shift; if "$@" > "$TMP/o" 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $n"; head -5 "$TMP/o" | sed 's/^/    /'; fi; }
tfail() { local n="$1"; shift; if "$@" > "$TMP/o" 2>&1; then FAIL=$((FAIL+1)); echo "FAIL (expected nonzero): $n"; else PASS=$((PASS+1)); fi; }

node "$HERE/fake-server.js" 0 > "$TMP/port" 2>/dev/null &
SERVER_PID=$!
for _ in $(seq 1 50); do [ -s "$TMP/port" ] && break; sleep 0.1; done
PORT="$(head -1 "$TMP/port")"
URL="http://127.0.0.1:${PORT}/mcp"

echo "== mcp-call test suite (fake server on ${URL}) =="

t "syntax"                          bash -n "$MC"
t "version"                         bash "$MC" --version
t "help"                            bash "$MC" --help
tfail "plain http refused by default" bash "$MC" "$URL" list
t "list with --allow-http"          bash "$MC" "$URL" list --allow-http
t "list shows echo tool"            bash "$MC" "$URL" list --allow-http
grep -q '^echo ::' "$TMP/o" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL: list output missing echo tool"; }
t "call echo tool"                  bash "$MC" "$URL" call echo '{"text":"hi"}' --allow-http
grep -q 'hello from fake tool' "$TMP/o" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL: call output missing tool text"; }
t "call with -o writes txt"         bash "$MC" "$URL" call echo '{"text":"x"}' -o "$TMP/out" --allow-http
t "-o file exists"                  test -f "$TMP/out.txt"
tfail "bad json args rejected"      bash "$MC" "$URL" call echo 'NOT-JSON' --allow-http
tfail "missing url rejected"        bash "$MC" list
tfail "unknown command rejected"    bash "$MC" "$URL" nope --allow-http

# --- sync-engine: vendoring into skills ------------------------------------------------
SKILL="$TMP/fake-skill"
mkdir -p "$SKILL/scripts"
t "sync: stamps engine into skill"  bash "$HERE/../scripts/sync-engine.sh" "$SKILL"
t "sync: copy matches engine"       cmp -s "$MC" "$SKILL/scripts/mcp-call.sh"
t "check: fresh copy passes"        bash "$HERE/../scripts/sync-engine.sh" --check "$SKILL"
printf 'stale' >> "$SKILL/scripts/mcp-call.sh"
tfail "check: stale copy fails"     bash "$HERE/../scripts/sync-engine.sh" --check "$SKILL"
tfail "sync: missing dir rejected"  bash "$HERE/../scripts/sync-engine.sh" "$TMP/does-not-exist"

echo "== results: ${PASS} passed, ${FAIL} failed =="
[ "$FAIL" -eq 0 ]
