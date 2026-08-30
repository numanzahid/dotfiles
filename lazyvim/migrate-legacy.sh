#!/usr/bin/env bash
# Compatibility wrapper. Use cleanup-leftovers.sh (always idempotent).
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cleanup-leftovers.sh" "$@"
