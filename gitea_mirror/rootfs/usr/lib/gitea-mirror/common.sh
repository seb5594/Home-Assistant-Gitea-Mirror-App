#!/usr/bin/env bash
# shellcheck shell=bash
# Helpers shared by the start script and the tests.
#
# The caller may define log_info, log_warning and log_error before sourcing this file
# (the start script maps them to bashio); the fallbacks print to stderr.

OPTIONS_FILE="${OPTIONS_FILE:-/data/options.json}"
# The image records its own version here (see the Dockerfile).
VERSION_FILE="${VERSION_FILE:-/etc/gitea-mirror/version}"
# One file per variable of the application's environment (see render_environment).
ENV_DIR="${ENV_DIR:-/run/gitea-mirror/env}"
ENV_MAP="${ENV_MAP:-/usr/share/gitea-mirror/env-map.json}"

declare -F log_info >/dev/null || log_info() { printf '[INFO] %s\n' "$*" >&2; }
declare -F log_warning >/dev/null || log_warning() { printf '[WARNING] %s\n' "$*" >&2; }
declare -F log_error >/dev/null || log_error() { printf '[ERROR] %s\n' "$*" >&2; }

# option <dotted.path> [default]
# Value of an app option. Empty values count as "not set" and give the default.
option() {
  jq -r --arg path "$1" --arg fallback "${2:-}" '
    getpath($path | split(".")) as $value
    | if $value == null or $value == "" then $fallback else ($value | tostring) end
  ' "$OPTIONS_FILE"
}

# trim_url <url>
# The URL without surrounding blanks and trailing slashes.
trim_url() {
  local url="${1//[[:space:]]/}"
  while [[ "$url" == */ ]]; do
    url="${url%/}"
  done
  printf '%s' "$url"
}

# origin_of <url>
# Scheme, host and port of a URL: https://ha.example.com/some/path -> https://ha.example.com
origin_of() {
  [[ "$1" =~ ^(https?://[^/[:space:]]+) ]] && printf '%s' "${BASH_REMATCH[1]}"
}

is_http_url() {
  [[ "$1" =~ ^https?://[^/[:space:]]+(/[^[:space:]]*)?$ ]]
}

# set_env <name> <value>
# Sets one variable of the application's environment. An empty value removes it.
set_env() {
  printf '%s' "$2" >"${ENV_DIR}/$1"
}

# get_env <name>
# The value set with set_env; empty when there is none.
get_env() {
  if [[ -f "${ENV_DIR}/$1" ]]; then
    cat "${ENV_DIR}/$1"
  fi
}
