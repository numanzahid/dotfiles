#!/usr/bin/env bash
# Shared -h/--help handling for installers that take no other options.
# Caller must define usage().

df_no_args_or_help() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
}
