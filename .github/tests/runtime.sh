#!/usr/bin/env bash
set -Eeuo pipefail
# bashio starts the services with the same strictness; a library that only works without it fails
# in Home Assistant, not here.
shopt -s inherit_errexit

# Runs inside the built image (release pipeline). The libraries turn options into an environment,
# mocked Gitea servers answer the destination check, and the real application is started behind a
# fake ingress path, signed in with the headers Home Assistant adds, and given its configuration.
LIB="${LIB_DIR:-/usr/lib/gitea-mirror}"
APP_DIR="${APP_DIR:-/app}"
SERVER="${SERVER:-/usr/share/gitea-mirror/ingress-server.ts}"
SERVICE_RUN="${SERVICE_RUN:-/etc/s6-overlay/s6-rc.d/gitea-mirror/run}"

fixture=$(mktemp -d)
pids=()
cleanup() {
  if ((${#pids[@]} > 0)); then kill "${pids[@]}" 2>/dev/null || true; fi
  rm -rf -- "$fixture"
}
trap cleanup EXIT

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

expect_equal() { # expect_equal <what> <expected> <actual>
  [[ "$2" == "$3" ]] || fail "$1: expected '$2', got '$3'"
}

# wait_for <url>: until the server answers.
wait_for() {
  for _ in $(seq 1 100); do
    curl -fs -o /dev/null "$1" && return 0
    sleep 0.2
  done
  fail "$1 did not come up"
}

export OPTIONS_FILE="$fixture/options.json" VERSION_FILE="$fixture/version" ENV_DIR="$fixture/env"
ENV_MAP="${ENV_MAP:-/usr/share/gitea-mirror/env-map.json}"
export ENV_MAP
echo 1.0.0-alpha.99 >"$VERSION_FILE"

# shellcheck disable=SC2329  # called by the libraries
log_info() { :; }
# shellcheck disable=SC2329
log_warning() { LOGGED+="$*"$'\n'; }
# shellcheck disable=SC2329
log_error() { :; }
LOGGED=""

# options <json>: the app options as the Supervisor stores them (the default Gitea address is
# part of the defaults, the rest is empty).
options() {
  jq -n --argjson overrides "$1" '
    {source: {}, destination: {url: "http://db21ed7f-gitea:3000"}, content: {}, schedule: {},
     cleanup: {}, backup: {}, authentication: {sign_in_with_home_assistant: true}, advanced: {}}
    * $overrides' >"$OPTIONS_FILE"
}

# shellcheck source=/dev/null
source "$LIB/common.sh"
# shellcheck source=/dev/null
source "$LIB/environment.sh"
# shellcheck source=/dev/null
source "$LIB/gitea.sh"

render() { render_environment /api/hassio_ingress/TEST 3.46.0 "$fixture/data"; }
mkdir -p "$fixture/data"

# ---- the image ------------------------------------------------------------------------------

[[ "$(bun --version)" =~ ^1\.[0-9]+\.[0-9]+ ]] || fail 'bun does not report a version'
pass 'bun starts on this architecture'

git lfs version >/dev/null || fail 'git lfs is missing'
sqlite3 --version >/dev/null || fail 'sqlite3 is missing'
pass 'git, git-lfs and sqlite3 are installed'

for script in "$LIB"/*.sh "$SERVICE_RUN"; do bash -n "$script"; done
pass 'the shell scripts parse'

# The mapping names every variable the application reads. A release that renames or drops one fails
# here, which is the moment to adjust env-map.json, not after the update reached a Home Assistant.
# The certificate switch is handled by the start script instead of the application.
missing=()
while IFS= read -r name; do
  [[ "$name" == GITEA_SKIP_TLS_VERIFY ]] && continue
  grep -rqE "env(\.|\[[\"'\`])${name}\b" "$APP_DIR/dist" || missing+=("$name")
done < <(jq -r '.[][1]' "$ENV_MAP" | sort -u)
((${#missing[@]} == 0)) || fail "the application no longer reads: ${missing[*]}"
pass "the application reads all $(jq length "$ENV_MAP") variables of the option map"

# ---- from options to environment ------------------------------------------------------------

options '{}'
render
expect_equal 'default address' 'http://db21ed7f-gitea:3000' "$(get_env GITEA_URL)"
expect_equal 'nothing else set' '' "$(get_env SCHEDULE_ENABLED)$(get_env GITHUB_USERNAME)$(get_env MIRROR_RELEASES)"
pass 'empty options leave the settings of the application alone'

options '{"source":{"username":" octocat ","include_private":true,"skip_forks":false},
          "content":{"release_limit":25,"release_include_tags":"v1.*, /^v\\d{1,3}\\.\\d+$/"},
          "schedule":{"interval":"0 2 * * *"}}'
render
expect_equal 'text is trimmed' 'octocat' "$(get_env GITHUB_USERNAME)"
expect_equal 'true' 'true' "$(get_env PRIVATE_REPOSITORIES)"
expect_equal 'false is a value too' 'false' "$(get_env SKIP_FORKS)"
expect_equal 'number' '25' "$(get_env RELEASE_LIMIT)"
expect_equal 'patterns arrive unchanged' 'v1.*, /^v\d{1,3}\.\d+$/' "$(get_env RELEASE_INCLUDE_TAGS)"
expect_equal 'cron expression' '0 2 * * *' "$(get_env SCHEDULE_INTERVAL)"
pass 'options become variables of the right kind'

options '{"destination":{"url":" http://gitea.local:3000/api/v1/ ","external_url":"https://git.example.com/"}}'
render
expect_equal 'api path and slash removed' 'http://gitea.local:3000' "$(get_env GITEA_URL)"
expect_equal 'slash removed' 'https://git.example.com' "$(get_env GITEA_EXTERNAL_URL)"
pass 'addresses are cleaned up'

options '{}'
render
expect_equal 'header sign-in' 'true' "$(get_env HEADER_AUTH_ENABLED)"
expect_equal 'user header' 'X-Remote-User-Name' "$(get_env HEADER_AUTH_USER_HEADER)"
expect_equal 'accounts are created' 'true' "$(get_env HEADER_AUTH_AUTO_PROVISION)"
options '{"authentication":{"sign_in_with_home_assistant":false}}'
render
expect_equal 'header sign-in off' '' "$(get_env HEADER_AUTH_ENABLED)"
pass 'sign-in with Home Assistant can be switched off'

options '{"authentication":{"public_url":"https://ha.example.com/some/path/"}}'
render
expect_equal 'origin only' 'https://ha.example.com' "$(get_env BETTER_AUTH_URL)"
expect_equal 'same for the browser' 'https://ha.example.com' "$(get_env PUBLIC_BETTER_AUTH_URL)"
pass 'the public address is reduced to its origin'

options '{}'
render
first_secret="$(get_env BETTER_AUTH_SECRET)"
first_key="$(get_env ENCRYPTION_SECRET)"
[[ ${#first_secret} -ge 32 && ${#first_key} -ge 32 ]] || fail 'secrets are too short'
render
expect_equal 'session secret is kept' "$first_secret" "$(get_env BETTER_AUTH_SECRET)"
expect_equal 'encryption secret is kept' "$first_key" "$(get_env ENCRYPTION_SECRET)"
[[ "$(stat -c %a "$fixture/data/.better_auth_secret")" == "600" ]] || fail 'secret file is readable by others'
options '{"authentication":{"session_secret":"my-own-secret-of-some-length-1234567"}}'
render
expect_equal 'own secret wins' 'my-own-secret-of-some-length-1234567' "$(get_env BETTER_AUTH_SECRET)"
pass 'secrets are created once, kept and can be set'

options '{"destination":{"ignore_certificate_errors":true}}'
LOGGED=""
render
expect_equal 'tls check off' '0' "$(get_env NODE_TLS_REJECT_UNAUTHORIZED)"
[[ "$LOGGED" == *"Certificate errors"* ]] || fail 'no warning about ignored certificate errors'
expect_equal 'path of the page' '/api/hassio_ingress/TEST' "$(get_env BASE_URL)"
expect_equal 'port of the ingress' '8099' "$(get_env PORT)"
pass 'fixed settings and the certificate warning'

# ---- the destination check -------------------------------------------------------------------

# Three small servers on the runtime itself: a Gitea that knows the token, one that rejects every
# token and a web server that is not Gitea.
cat >"$fixture/mock.ts" <<'MOCK'
const kind = process.argv[2];
Bun.serve({
  hostname: "127.0.0.1",
  port: Number(process.argv[3]),
  fetch(request) {
    const path = new URL(request.url).pathname;
    if (kind === "other") return new Response("<html>hello</html>", { headers: { "content-type": "text/html" } });
    if (path === "/api/v1/version") return Response.json({ version: "1.24.0" });
    if (path === "/api/v1/user") {
      if (kind === "locked") return Response.json({ message: "token is invalid" }, { status: 401 });
      return Response.json({ login: "mirrorbot", html_url: "http://homeassistant.local:3000/mirrorbot" });
    }
    return new Response("not found", { status: 404 });
  },
});
MOCK
for mock in "gitea 3100" "locked 3101" "other 3102"; do
  # shellcheck disable=SC2086  # kind and port are two words
  bun "$fixture/mock.ts" $mock >/dev/null 2>&1 &
  pids+=($!)
done
wait_for http://127.0.0.1:3100/api/v1/version
export GITEA_ATTEMPTS=1

options '{"destination":{"url":"http://127.0.0.1:3100","token":"abc"}}'
render
LOGGED=""
check_destination
expect_equal 'user from the token' 'mirrorbot' "$(get_env GITEA_USERNAME)"
expect_equal 'address from Gitea' 'http://homeassistant.local:3000' "$(get_env GITEA_EXTERNAL_URL)"
expect_equal 'nothing to complain about' '' "$LOGGED"
pass 'the user and the browser address come from Gitea'

options '{"destination":{"url":"http://127.0.0.1:3100","token":"abc","username":"mine","external_url":"https://git.example.com"}}'
render
check_destination
expect_equal 'own user kept' 'mine' "$(get_env GITEA_USERNAME)"
expect_equal 'own address kept' 'https://git.example.com' "$(get_env GITEA_EXTERNAL_URL)"
pass 'values from the options are not replaced'

options '{"destination":{"url":"http://127.0.0.1:3101","token":"wrong"}}'
render
LOGGED=""
check_destination
[[ "$LOGGED" == *"does not accept the access token"* ]] || fail "rejected token not reported: $LOGGED"
expect_equal 'no user guessed' '' "$(get_env GITEA_USERNAME)"
pass 'a rejected token is reported'

options '{"destination":{"url":"http://127.0.0.1:3102"}}'
render
LOGGED=""
check_destination
[[ "$LOGGED" == *"does not look like Gitea"* ]] || fail "other server not reported: $LOGGED"
pass 'an address that is not Gitea is reported'

options '{"destination":{"url":"http://127.0.0.1:3109"}}'
render
LOGGED=""
check_destination
[[ "$LOGGED" == *"does not answer: the connection was refused"* ]] || fail "unreachable Gitea not reported: $LOGGED"
pass 'an unreachable Gitea is reported with the reason'

options '{"destination":{"provider":"github","url":"http://127.0.0.1:3109"}}'
render
LOGGED=""
check_destination
expect_equal 'GitHub destination is not probed' '' "$LOGGED"
pass 'GitHub and GitLab destinations are not probed as Gitea'

# ---- the application behind ingress ----------------------------------------------------------

# The application writes into data/ below its directory; give it a scratch copy of the layout.
workdir="$fixture/app"
mkdir -p "$workdir"
for entry in dist drizzle node_modules package.json; do ln -s "$APP_DIR/$entry" "$workdir/$entry"; done
mkdir -p "$fixture/appdata"
ln -s "$fixture/appdata" "$workdir/data"

options '{"destination":{"url":"http://127.0.0.1:3100","token":"abc"},
          "source":{"username":"octocat","token":"ghp_test"},
          "schedule":{"enabled":false},
          "content":{"releases":true}}'
render
check_destination

# app_environment: the rendered environment, as s6-envdir hands it to the application.
app_environment() {
  local file
  for file in "$ENV_DIR"/*; do export "$(basename "$file")=$(head -n1 "$file")"; done
  export DATABASE_URL=file:data/gitea-mirror.db APP_DIR="$workdir" HOME="$fixture/appdata"
}

# start_app <port> <host>: the application behind the ingress server; sets app_pid.
start_app() {
  (
    cd "$workdir"
    app_environment
    export PORT="$1" HOST="$2"
    exec bun "$SERVER" >"$fixture/app-$1.log" 2>&1
  ) &
  app_pid=$!
  pids+=("$app_pid")
}

start_app 8199 127.0.0.1
wait_for http://127.0.0.1:8199/api/health
pass 'the application starts'

BASE=/api/hassio_ingress/TEST
home_headers=(-H 'X-Forwarded-Host: ha.local:8123' -H 'X-Forwarded-Proto: http')

location="$(curl -s -o /dev/null -w '%{redirect_url}' "${home_headers[@]}" http://127.0.0.1:8199/)"
[[ "$location" == *"$BASE/"* ]] || fail "redirect does not carry the ingress path: $location"
page="$(curl -fsS "${home_headers[@]}" http://127.0.0.1:8199/signup)"
grep -qE "(href|src)=\"$BASE/" <<<"$page" || fail 'links on the page do not carry the ingress path'
pass 'links and redirects carry the ingress path'

expect_equal 'health with the path' '200' "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:8199$BASE/api/health")"
pass 'requests with the ingress path are accepted too (the application calls itself that way)'

reply="$(curl -sS -X POST "${home_headers[@]}" -H 'Origin: http://ha.local:8123' -H 'Content-Type: application/json' -d '{}' \
  -H 'X-Remote-User-Name: sebi' \
  -H 'X-Remote-User-Display-Name: Sebi' -D "$fixture/headers" "http://127.0.0.1:8199/api/auth/sign-in/header")"
grep -qi '^set-cookie: better-auth.session_token' "$fixture/headers" || fail "no session for the Home Assistant user: $reply"
expect_equal 'account name' 'sebi' "$(jq -r '.user.username' <<<"$reply")"
expect_equal 'one account' '1' "$(sqlite3 -readonly "$fixture/appdata/gitea-mirror.db" 'SELECT COUNT(*) FROM users')"
pass 'a Home Assistant user is signed in and gets an account'

expect_equal 'foreign origin refused' '403' "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Origin: http://evil.example' \
  -H 'Content-Type: application/json' -d '{"email":"a@b.cc","password":"Test-passw0rd!","name":"x"}' http://127.0.0.1:8199/api/auth/sign-up/email)"
pass 'sign-in requests from a foreign origin are refused'

# The options reach the configuration of the first account.
(
  cd "$workdir"
  app_environment
  bun dist/scripts/startup-env-config.js >"$fixture/config.log" 2>&1
) || { cat "$fixture/config.log" >&2; fail 'the configuration script failed'; }
config="$(sqlite3 -readonly "$fixture/appdata/gitea-mirror.db" 'SELECT github_config FROM configs LIMIT 1')"
expect_equal 'source user in the configuration' 'octocat' "$(jq -r '.owner' <<<"$config")"
config="$(sqlite3 -readonly "$fixture/appdata/gitea-mirror.db" 'SELECT gitea_config FROM configs LIMIT 1')"
expect_equal 'destination in the configuration' 'http://127.0.0.1:3100' "$(jq -r '.url' <<<"$config")"
expect_equal 'learned user in the configuration' 'mirrorbot' "$(jq -r '.defaultOwner' <<<"$config")"
expect_equal 'releases in the configuration' 'true' "$(jq -r '.mirrorReleases' <<<"$config")"
pass 'the options end up in the configuration of the first account'

# Only Home Assistant's ingress proxy may talk to the application (it trusts the user headers).
address="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)"
if [[ -n "$address" ]]; then
  kill "$app_pid"
  start_app 8198 0.0.0.0
  wait_for http://127.0.0.1:8198/api/health
  expect_equal 'other address refused' '403' "$(curl -s -o /dev/null -w '%{http_code}' "http://$address:8198/api/health")"
  expect_equal 'local address allowed' '200' "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8198/api/health)"
  pass 'only the ingress proxy and the container itself are served'
fi
