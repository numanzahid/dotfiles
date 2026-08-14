#!/usr/bin/env bash
# Architecture mapping for prebuilt LazyVim dependencies.
set -euo pipefail

LAZYVIM_ARCH=""
LAZYVIM_ARCH_LABEL=""

detect_lazyvim_arch() {
  case "$(uname -m)" in
    x86_64 | amd64)
      LAZYVIM_ARCH="x64"
      LAZYVIM_ARCH_LABEL="linux-x64"
      ;;
    aarch64 | arm64)
      LAZYVIM_ARCH="arm64"
      LAZYVIM_ARCH_LABEL="linux-arm64"
      ;;
    *)
      die "unsupported CPU architecture for prebuilt packages: $(uname -m)"
      ;;
  esac
}
