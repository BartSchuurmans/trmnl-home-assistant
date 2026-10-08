#!/usr/bin/env bash
# Boots the built add-on the way the Supervisor would (a /data with options.json, a
# Supervisor token, the ingress proxy's address) and checks what it adds to LaraPaper:
# the bundled framework, the options, the Home Assistant proxy at each access level,
# ingress and that a restart keeps the app key.
#
# Needs Docker, curl and python3 on the host. A fake Home Assistant (fake-ha.py) runs
# next to it.
#
# Usage: trmnl-larapaper/tests/smoke.test.sh [image]
set -uo pipefail

IMAGE="${1:-trmnl-larapaper:dev}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK=$(mktemp -d)
FAILED=0
APP=larapaper-smoke
HA_PORT=18123

# shellcheck disable=SC2329 # run by the trap
cleanup() {
    [ "$FAILED" = 0 ] || docker logs "$APP" 2>&1 | tail -80
    docker rm -f "$APP" >/dev/null 2>&1
    [ -z "${HA_PID:-}" ] || kill "$HA_PID" 2>/dev/null
    rm -rf "$WORK"
}
trap cleanup EXIT

ok() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILED=1; }
check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else fail "$name"; fi; }

# HTTP status of a request made from inside the add-on: <method> <url> [header]
status_in() {
    # shellcheck disable=SC2016 # PHP code
    docker exec "$APP" php -r '$h = isset($argv[3]) ? ["header" => $argv[3]] : [];
        $c = stream_context_create(["http" => ["method" => $argv[1], "ignore_errors" => true] + $h]);
        @file_get_contents($argv[2], false, $c); echo explode(" ", $http_response_header[0] ?? "x 000")[1];' "$@"
}
# Body of a GET from inside the add-on
body_in() {
    docker exec "$APP" php -r 'echo @file_get_contents($argv[1]);' "$1"
}
expect_status() {
    local name="$1" expected="$2" actual; shift 2
    actual=$(status_in "$@")
    if [ "$actual" = "$expected" ]; then ok "$name"; else fail "$name (got $actual, expected $expected)"; fi
}

wait_up() {
    for _ in $(seq 1 90); do
        curl -fsS -o /dev/null http://localhost:4567/up 2>/dev/null && return 0
        sleep 2
    done
    return 1
}

# Starts (or restarts) the add-on with these options
start() {
    printf '%s' "$1" > "$WORK/data/options.json"
    if docker inspect "$APP" >/dev/null 2>&1; then
        docker restart "$APP" >/dev/null
    else
        docker run -d --name "$APP" -p 4567:8080 -p 127.0.0.1:8099:8099 -e TZ=Europe/Amsterdam \
            -e SUPERVISOR_TOKEN=smoke-supervisor-token \
            -e HA_API_URL="http://homeassistant:$HA_PORT/api" \
            -e HA_INGRESS_PROXY=172.16.0.0/12 \
            --add-host homeassistant:host-gateway -v "$WORK/data:/data" "$IMAGE" >/dev/null
    fi
    wait_up || { fail "add-on became healthy"; exit 1; }
}

mkdir -p "$WORK/data"
python3 "$HERE/fake-ha.py" "$HA_PORT" & HA_PID=$!

start '{"app_url": "http://localhost:4567/", "registration_enabled": false, "home_assistant_access": "calendars"}'
ok "add-on became healthy"
key="$(cat "$WORK/data/app_key")"

# --- Bundled framework -------------------------------------------------------------
for path in /trmnl-framework/3.3.1/plugins.min.css /trmnl-framework/3.3.1/plugins.min.js \
            /fonts/Inter.ttf /fonts/TRMNL16-Regular.woff2; do
    check "serves $path" curl -fsS -o /dev/null "http://localhost:4567$path"
done
# Screens render from a file:// page, so the files must also be at the filesystem root
check "framework at the filesystem root" docker exec "$APP" sh -c 'test -s /trmnl-framework/3.3.1/plugins.min.css && test -s /fonts/Inter.ttf'
# shellcheck disable=SC2016 # expands in the container
check "license texts next to the files" docker exec "$APP" sh -c 'for f in /trmnl-framework/3.3.1/LICENSE /fonts/OFL-trmnl.txt /fonts/OFL-classic.txt /fonts/CC-BY-3.0.txt; do test -s "$f" || exit 1; done'
check "no fonts.bunny.net in screens" docker exec "$APP" sh -c '! grep -q fonts.bunny.net /var/www/html/resources/views/vendor/trmnl/components/screen.blade.php'
check "LaraPaper uses the bundled framework" docker exec "$APP" sh -c 'printenv TRMNL_BLADE_FRAMEWORK_CSS_URL | grep -qx /trmnl-framework/3.3.1/plugins.min.css'

# --- Options and /data -------------------------------------------------------------
check "App URL from the options" docker exec "$APP" grep -qx 'APP_URL=http://localhost:4567' /var/www/html/.env
check "registration from the options" docker exec "$APP" grep -qx 'REGISTRATION_ENABLED=0' /var/www/html/.env
check "time zone from Home Assistant" docker exec "$APP" grep -qx 'APP_TIMEZONE=Europe/Amsterdam' /var/www/html/.env
check "app key in /data" test -s "$WORK/data/app_key"
check "database in /data" test -s "$WORK/data/database/database.sqlite"

# --- Home Assistant proxy: calendars -----------------------------------------------
cal=$(body_in 'http://127.0.0.1:8124/api/calendars/calendar.work?start=2026-10-01&end=2026-10-31')
check "calendars: forwards a calendar read with the Supervisor token" \
    grep -q '"method": "GET", "path": "/api/calendars/calendar.work?start=2026-10-01&end=2026-10-31", "auth": "Bearer smoke-supervisor-token"' <<<"$cal"
expect_status "calendars: lists calendars" 200 GET http://127.0.0.1:8124/api/calendars
weather=$(body_in http://127.0.0.1:8124/api/weather/weather.home)
check "calendars: a forecast GET becomes the weather.get_forecasts call" \
    grep -q '"method": "POST", "path": "/api/services/weather/get_forecasts?return_response"' <<<"$weather"
check "calendars: ... for that entity, daily" grep -q 'weather.home' <<<"$weather"
expect_status "calendars: no POST to calendars" 403 POST http://127.0.0.1:8124/api/calendars/calendar.work
expect_status "calendars: no POST to forecasts" 403 POST http://127.0.0.1:8124/api/weather/weather.home
expect_status "calendars: forecasts only for weather entities" 404 GET http://127.0.0.1:8124/api/weather/sensor.secret
expect_status "calendars: no way out of the weather path" 404 GET http://127.0.0.1:8124/api/weather/weather.home/../../states
expect_status "calendars: no states" 404 GET http://127.0.0.1:8124/api/states
expect_status "calendars: no history" 404 GET http://127.0.0.1:8124/api/history/period
expect_status "calendars: no services" 404 GET http://127.0.0.1:8124/api/services/light/turn_on
expect_status "calendars: no way out of the calendar path" 404 GET http://127.0.0.1:8124/api/calendars/../services/light/turn_on
check "the proxy isn't published" sh -c '! curl -fsS -o /dev/null --max-time 5 http://localhost:8124/api/calendars'

# --- Ingress -----------------------------------------------------------------------
expect_status "ingress: refuses anyone but the Supervisor" 403 GET http://127.0.0.1:8099/up 'X-Ingress-Path: /api/hassio_ingress/abc'
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
check "ingress: needs an ingress path" test "$(code http://127.0.0.1:8099/up)" = 400
check "ingress: needs a valid ingress path" test "$(code -H 'X-Ingress-Path: /elsewhere' http://127.0.0.1:8099/up)" = 400
check "ingress: answers with one" test "$(code -H 'X-Ingress-Path: /api/hassio_ingress/abc' http://127.0.0.1:8099/up)" = 200
check "ingress: answers at the prefix's root" test "$(code -H 'X-Ingress-Path: /api/hassio_ingress/abc' http://127.0.0.1:8099/)" = 200
check "ingress: redirects stay under the prefix" sh -c \
    "curl -s -o /dev/null -w '%{redirect_url}' -H 'X-Ingress-Path: /api/hassio_ingress/abc' http://127.0.0.1:8099/dashboard | grep -q '/api/hassio_ingress/abc/login'"
check "ingress: links carry the prefix" sh -c \
    "curl -s -H 'X-Ingress-Path: /api/hassio_ingress/abc' http://127.0.0.1:8099/login | grep -q '/api/hassio_ingress/abc/'"
check "ingress: loads ingress.js" sh -c \
    "curl -s -H 'X-Ingress-Path: /api/hassio_ingress/abc' http://127.0.0.1:8099/login | grep -q 'larapaper-ha/ingress.js'"

# --- Home Assistant proxy: read, then off ------------------------------------------
start '{"app_url": "http://localhost:4567/", "registration_enabled": false, "home_assistant_access": "read"}'
states=$(body_in http://127.0.0.1:8124/api/states/sun.sun)
check "read: forwards a state read with the Supervisor token" \
    grep -q '"method": "GET", "path": "/api/states/sun.sun", "auth": "Bearer smoke-supervisor-token"' <<<"$states"
expect_status "read: lists states" 200 GET http://127.0.0.1:8124/api/states
expect_status "read: history" 200 GET 'http://127.0.0.1:8124/api/history/period/2026-10-01T00:00:00Z?filter_entity_id=sun.sun'
expect_status "read: calendars still" 200 GET http://127.0.0.1:8124/api/calendars
expect_status "read: no POST to states" 403 POST http://127.0.0.1:8124/api/states/light.kitchen
expect_status "read: no services" 404 GET http://127.0.0.1:8124/api/services/light/turn_on
expect_status "read: no config" 404 GET http://127.0.0.1:8124/api/config

start '{"app_url": "http://localhost:4567/", "registration_enabled": false, "home_assistant_access": "off"}'
expect_status "off: no calendars" 000 GET http://127.0.0.1:8124/api/calendars

# --- Restarts (above) keep the app key -----------------------------------------------
check "restarts keep the app key" test "$(cat "$WORK/data/app_key")" = "$key"
check "... and LaraPaper uses it" docker exec "$APP" grep -qx "APP_KEY=$key" /var/www/html/.env

exit "$FAILED"
