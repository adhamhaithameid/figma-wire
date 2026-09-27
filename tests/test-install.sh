#!/usr/bin/env bash
# Back-compat shim: the setup e2e suite moved to e2e.sh.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/e2e.sh" "$@"
