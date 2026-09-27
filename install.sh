#!/usr/bin/env bash
# figma-wire installer — copies the skill into ~/.agents/skills/figma-wire/
# and verifies the runtime dependencies. Idempotent; safe to re-run.
set -u

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}/.agents/skills/figma-wire"

fail() { echo "ERROR: $*" >&2; exit 1; }

echo "== figma-wire installer =="

# 1. dependencies
for dep in bash curl jq; do
  command -v "$dep" > /dev/null 2>&1 || fail "missing dependency: $dep (install it and re-run)"
done
echo "[ ok ] dependencies: bash, curl, jq"

# 2. sanity-check the source tree
[ -f "$SRC/SKILL.md" ]          || fail "SKILL.md not found next to install.sh"
[ -f "$SRC/scripts/figma-wire.sh" ] || fail "scripts/figma-wire.sh not found"
echo "[ ok ] source tree looks complete"

# 3. self-test before installing (offline mode; network tests need real endpoints)
echo "[ .. ] running self-tests (offline mode)"
if SKIP_NETWORK_TESTS=1 bash "$SRC/tests/run-tests.sh" > /dev/null 2>&1; then
  echo "[ ok ] self-tests passed"
else
  echo "self-test output:"
  SKIP_NETWORK_TESTS=1 bash "$SRC/tests/run-tests.sh" | tail -20
  fail "self-tests failed — not installing a broken copy"
fi

# 4. install (copy, don't move — the source dir stays usable as a repo checkout)
if [ "$(cd "$SRC" && pwd)" = "$(cd "$DEST" 2>/dev/null && pwd)" ]; then
  echo "[ ok ] already running from the install location — refreshing permissions only"
  chmod +x "$DEST/scripts/figma-wire.sh" "$DEST/tests/run-tests.sh" 2>/dev/null
else
  mkdir -p "$DEST" || fail "cannot create $DEST"
  cp -f "$SRC/install.sh" "$DEST/install.sh"   || fail "copy failed"
  cp -f "$SRC/SKILL.md" "$DEST/SKILL.md"       || fail "copy failed"
  cp -f "$SRC/README.md" "$DEST/README.md"     || fail "copy failed"
  cp -f "$SRC/LICENSE" "$DEST/LICENSE"         || fail "copy failed"
  mkdir -p "$DEST/scripts" "$DEST/references" "$DEST/tests"
  cp -f "$SRC/scripts/figma-wire.sh" "$DEST/scripts/" || fail "copy failed"
  cp -f "$SRC/references/"*.md "$DEST/references/"    || fail "copy failed"
  cp -f "$SRC/tests/"* "$DEST/tests/" 2>/dev/null || true
  chmod +x "$DEST/scripts/figma-wire.sh" "$DEST/tests/run-tests.sh" 2>/dev/null
fi

# 5. convenience symlink (works if ~/.local/bin or /usr/local/bin is on PATH)
BIN=""
for d in "$HOME/.local/bin" "/usr/local/bin" "$HOME/bin"; do
  [ -d "$d" ] && { BIN="$d"; break; }
done
if [ -n "$BIN" ]; then
  ln -sf "$DEST/scripts/figma-wire.sh" "$BIN/figma-wire"
  echo "[ ok ] symlinked: $(command -v figma-wire 2>/dev/null || echo "$BIN/figma-wire")"
else
  echo "[warn] no bin dir on PATH found — invoke via: bash $DEST/scripts/figma-wire.sh"
fi

# 6. post-install status
echo
echo "== installed at $DEST ="
echo "Next steps:"
echo "  1. Enable in Figma desktop: Preferences -> Enable Dev Mode MCP Server"
echo "  2. Run: figma-wire doctor        (or: bash $DEST/scripts/figma-wire.sh doctor)"
echo "  3. Restart your agent session so it picks up the MCP server"
