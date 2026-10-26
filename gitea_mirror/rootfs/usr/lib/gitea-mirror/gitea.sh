#!/usr/bin/env bash
# shellcheck shell=bash
# Looks at the destination Gitea before the application starts, so that the log says what is
# wrong in plain words, and fills in what Gitea can tell: the account behind the token and the
# address the browser uses.

# The address under which the Gitea app by alexbelgium is reachable from other apps.
DEFAULT_GITEA_URL="http://db21ed7f-gitea:3000"
GITEA_ATTEMPTS="${GITEA_ATTEMPTS:-3}"
GITEA_RETRY_SECONDS="${GITEA_RETRY_SECONDS:-5}"

# gitea_get <path>
# Sets HTTP_CODE (000 when nothing answered), HTTP_BODY and CURL_RC for a request to the
# destination. The token goes in through stdin so that it never shows up in the process list.
gitea_get() {
  local url token insecure=() body
  url="$(get_env GITEA_URL)${1}"
  token="$(get_env GITEA_TOKEN)"
  if [[ "$(get_env GITEA_SKIP_TLS_VERIFY)" == "true" ]]; then
    insecure=(-k)
  fi
  body="$(mktemp)"
  CURL_RC=0
  HTTP_CODE="$(
    if [[ -n "$token" ]]; then
      printf 'header = "Authorization: token %s"\n' "$token"
    fi | curl -sS --max-time 6 -K - "${insecure[@]}" -o "$body" -w '%{http_code}' "$url" 2>/dev/null
  )" || CURL_RC=$?
  HTTP_BODY="$(cat "$body")"
  rm -f "$body"
  HTTP_CODE="${HTTP_CODE:-000}"
}

# describe_failure
# Why the last request got no answer, in words.
describe_failure() {
  case "$CURL_RC" in
    6) printf 'the host name is unknown' ;;
    7) printf 'the connection was refused (is the app started?)' ;;
    28) printf 'the request timed out' ;;
    35 | 51 | 58 | 60 | 77 | 83) printf 'the TLS certificate is not trusted (see "Ignore certificate errors")' ;;
    *) printf 'the connection failed (curl error %s)' "$CURL_RC" ;;
  esac
}

# wait_for_gitea
# Gitea may be starting at the same time; a few tries tell "not yet" from "not there".
wait_for_gitea() {
  local attempt
  for ((attempt = 1; attempt <= GITEA_ATTEMPTS; attempt++)); do
    gitea_get /api/v1/version
    [[ "$HTTP_CODE" != "000" ]] && return 0
    ((attempt < GITEA_ATTEMPTS)) && sleep "$GITEA_RETRY_SECONDS"
  done
  return 0
}

# learn_from_token
# The account behind the access token gives the user name; its profile link carries the address
# the browser uses for Gitea (its ROOT_URL), which the application needs for links.
learn_from_token() {
  local login html_url origin
  gitea_get /api/v1/user
  case "$HTTP_CODE" in
    200) ;;
    401 | 403)
      log_warning "Gitea does not accept the access token of the destination. Create a new one in Gitea (Settings > Applications)."
      return 0
      ;;
    *)
      log_warning "The access token of the destination could not be checked (HTTP ${HTTP_CODE})."
      return 0
      ;;
  esac
  login="$(jq -r '.login // ""' <<<"$HTTP_BODY" 2>/dev/null)" || login=""
  html_url="$(jq -r '.html_url // ""' <<<"$HTTP_BODY" 2>/dev/null)" || html_url=""
  log_info "The access token of the destination belongs to the Gitea user '${login}'."
  if [[ -z "$(get_env GITEA_USERNAME)" && -n "$login" ]]; then
    set_env GITEA_USERNAME "$login"
  fi
  origin="$(origin_of "$html_url" || true)"
  if [[ -z "$(get_env GITEA_EXTERNAL_URL)" && -n "$origin" && "$origin" != "$(get_env GITEA_URL)" ]]; then
    set_env GITEA_EXTERNAL_URL "$origin"
    log_info "Links to Gitea use ${origin}, the address Gitea announces for itself."
  fi
}

# check_destination
# Only for Gitea and Forgejo; GitHub and GitLab destinations are not looked at.
check_destination() {
  local provider url version
  provider="$(get_env DESTINATION_PROVIDER)"
  url="$(get_env GITEA_URL)"
  if [[ "$provider" == "github" || "$provider" == "gitlab" || -z "$url" ]]; then
    return 0
  fi
  if ! is_http_url "$url"; then
    log_warning "The destination address '${url}' is not a web address. Use the form ${DEFAULT_GITEA_URL}."
    return 0
  fi

  wait_for_gitea
  if [[ "$HTTP_CODE" == "000" ]]; then
    log_warning "Gitea at ${url} does not answer: $(describe_failure)."
    if [[ "$url" == "$DEFAULT_GITEA_URL" ]]; then
      log_warning "Install and start the Gitea app by alexbelgium, or enter the address of your Gitea in the options."
    fi
    return 0
  fi
  version="$(jq -r '.version // ""' <<<"$HTTP_BODY" 2>/dev/null)" || version=""
  if [[ "$HTTP_CODE" == "200" && -n "$version" ]]; then
    log_info "Gitea ${version} answers at ${url}."
  else
    log_warning "${url} answers with HTTP ${HTTP_CODE}, but it does not look like Gitea. Check the address."
    return 0
  fi

  if [[ -n "$(get_env GITEA_TOKEN)" ]]; then
    learn_from_token
  else
    log_info "No access token for the destination yet. Enter it in the options or on the configuration page of the app."
  fi
}
