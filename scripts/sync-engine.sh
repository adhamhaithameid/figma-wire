#!/usr/bin/env bash
# sync-engine.sh — vendor the mcp-wire engine into dependent skills.
#
# Bash has no linker: a skill that uses the engine must ship its own copy, or a
# standalone install breaks. This script is the bridge — the engine file
# (engine/mcp-wire.sh, the single source of truth) is stamped into each skill
# package at release time, so one engine commit propagates to every skill on the
# next release while distributed copies stay self-contained.
#
# Usage:
#   scripts/sync-engine.sh <skill-dir> [<skill-dir>...]   # stamp engine into skills
#   scripts/sync-engine.sh --check <skill-dir> [...]      # CI mode: exit 1 if stale
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$REPO/engine/mcp-wire.sh"
ENGINE_VERSION="$(grep -m1 '^VERSION=' "$ENGINE" | cut -d'"' -f2)"
CHECK=0

[ -f "$ENGINE" ] || { echo "FAIL: engine not found at $ENGINE" >&2; exit 1; }
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi
[ $# -ge 1 ] || { echo "usage: scripts/sync-engine.sh [--check] <skill-dir> [...]" >&2; exit 1; }

rc=0
for skill in "$@"; do
  [ -d "$skill" ] || { echo "FAIL: no such skill dir: $skill" >&2; rc=1; continue; }
  dest="$skill/scripts/mcp-wire.sh"
  mkdir -p "$skill/scripts"
  if [ "$CHECK" -eq 1 ]; then
    if [ ! -f "$dest" ]; then
      echo "STALE: $dest missing (engine v${ENGINE_VERSION})" >&2; rc=1
    elif ! cmp -s "$ENGINE" "$dest"; then
      echo "STALE: $dest differs from engine v${ENGINE_VERSION} — re-run sync-engine.sh" >&2; rc=1
    else
      echo "ok  : $dest (engine v${ENGINE_VERSION})"
    fi
  else
    cp -f "$ENGINE" "$dest" && echo "synced: $dest (engine v${ENGINE_VERSION})"
  fi
done
exit $rc
