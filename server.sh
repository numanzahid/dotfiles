#!/usr/bin/env bash
# Server / VPS / container copy-based installer (implementation in server/).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$ROOT/server/install.sh" "$@"
