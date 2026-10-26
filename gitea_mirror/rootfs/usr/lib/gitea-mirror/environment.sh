#!/usr/bin/env bash
# shellcheck shell=bash
# Turns the app options into the environment of the application.
#
# Every option that is filled in becomes one variable, named in env-map.json. An option that is
# left empty sets nothing, so the application keeps what is stored in its own settings. A filled
# option is applied at every start and wins over a change made in the application.

# The application listens here; Home Assistant's ingress forwards to it (ingress_port).
APP_PORT=8099
# What Home Assistant adds to ingress requests for the signed-in user.
HA_USER_HEADER="X-Remote-User-Name"
HA_NAME_HEADER="X-Remote-User-Display-Name"

# apply_option_map
# Writes one variable for every filled-in option of env-map.json.
apply_option_map() {
  local name value
  while IFS= read -r -d '' name && IFS= read -r -d '' value; do
    set_env "$name" "$value"
  done < <(jq -j --slurpfile map "$ENV_MAP" '
    . as $options
    | $map[0][] | . as [$path, $name]
    | ($options | getpath($path | split("."))) as $raw
    | select($raw != null)
    | ($raw | tostring | gsub("^\\s+|\\s+$"; "")) as $value
    | select($value != "")
    | $name, "\u0000", $value, "\u0000"
  ' "$OPTIONS_FILE")
}

# apply_addresses
# Web addresses go in without trailing slashes, and the Gitea address without /api/v1 (the
# application adds that itself).
apply_addresses() {
  local name value
  for name in GITEA_URL GITEA_EXTERNAL_URL SOURCE_URL GH_API_URL BETTER_AUTH_URL MCP_INTERNAL_URL; do
    value="$(get_env "$name")"
    [[ -n "$value" ]] || continue
    value="$(trim_url "$value")"
    [[ "$name" == GITEA_URL ]] && value="${value%/api/v1}"
    set_env "$name" "$value"
  done
}

# apply_sign_in
# Home Assistant tells the application who is looking at the page. With header sign-in switched
# on, that person is signed in and gets an account. Only Home Assistant can reach the
# application (see ingress-server.ts), so nobody else can send these headers.
apply_sign_in() {
  if [[ "$(option authentication.sign_in_with_home_assistant true)" == "true" ]]; then
    set_env HEADER_AUTH_ENABLED true
    set_env HEADER_AUTH_USER_HEADER "$HA_USER_HEADER"
    set_env HEADER_AUTH_NAME_HEADER "$HA_NAME_HEADER"
    # Home Assistant sends no e-mail address; the application makes one up for the account.
    set_env HEADER_AUTH_EMAIL_HEADER "X-Remote-User-Email"
    set_env HEADER_AUTH_AUTO_PROVISION true
  fi
  # The sign-in page calls the same address from the browser.
  if [[ -n "$(get_env BETTER_AUTH_URL)" ]]; then
    set_env PUBLIC_BETTER_AUTH_URL "$(origin_of "$(get_env BETTER_AUTH_URL)")"
    set_env BETTER_AUTH_URL "$(origin_of "$(get_env BETTER_AUTH_URL)")"
  fi
}

# generate_secret <file> <bytes>
# A random secret, created once and kept next to the database (the names are the ones the
# official image uses, so data from there keeps working).
generate_secret() {
  local file="$1" bytes="$2"
  if [[ ! -s "$file" ]]; then
    (umask 077 && head -c "$bytes" /dev/urandom | od -An -tx1 | tr -d ' \n' >"$file")
  fi
  cat "$file"
}

# apply_secrets <data-dir>
apply_secrets() {
  local data="$1"
  if [[ -z "$(get_env BETTER_AUTH_SECRET)" ]]; then
    set_env BETTER_AUTH_SECRET "$(generate_secret "${data}/.better_auth_secret" 32)"
  fi
  if [[ -z "$(get_env ENCRYPTION_SECRET)" ]]; then
    set_env ENCRYPTION_SECRET "$(generate_secret "${data}/.encryption_secret" 36)"
  fi
}

# apply_fixed_settings <ingress-entry> <upstream-version>
# What this app decides itself: where it listens, under which path it is served and where it
# keeps its files.
apply_fixed_settings() {
  local entry="$1" version="$2"
  set_env HOST 0.0.0.0
  set_env PORT "$APP_PORT"
  # The path Home Assistant serves the page under; it is part of every link the application builds.
  set_env BASE_URL "$entry"
  set_env HOME /data/home
  set_env npm_package_version "$version"
  if [[ "$(get_env GITEA_SKIP_TLS_VERIFY)" == "true" ]]; then
    set_env NODE_TLS_REJECT_UNAUTHORIZED 0
    log_warning "Certificate errors of the destination are ignored. Use this only inside your own network."
  fi
}

# render_environment <ingress-entry> <upstream-version> <data-dir>
# Fills ENV_DIR, which s6-envdir hands to the application.
render_environment() {
  rm -rf "$ENV_DIR"
  mkdir -p "$ENV_DIR"
  chmod 700 "$ENV_DIR"
  apply_option_map
  apply_addresses
  apply_sign_in
  apply_secrets "$3"
  apply_fixed_settings "$1" "$2"
}

# has_connection_settings
# True when a source or destination setting is filled in: the application then writes its
# configuration from the environment at start (the official image does the same).
has_connection_settings() {
  local name
  for name in GITHUB_USERNAME GITHUB_TOKEN GITEA_URL GITEA_USERNAME GITEA_TOKEN; do
    [[ -n "$(get_env "$name")" ]] && return 0
  done
  return 1
}
