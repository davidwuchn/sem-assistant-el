#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_FILE="$REPO_ROOT/docker-compose.yml"
COMPOSE_OVERRIDE="$SCRIPT_DIR/docker-compose.webdav-httpd.test.yml"
TEST_DATA_DIR="$REPO_ROOT/test-data-httpd"
TEST_CERTS_DIR="$REPO_ROOT/test-data-httpd-certs"

WEBDAV_PORT="${WEBDAV_PORT:-16066}"
WEBDAV_DOMAIN="${WEBDAV_DOMAIN:-webdav-test.local}"
WEBDAV_USERNAME="${WEBDAV_USERNAME:-orgzly}"
WEBDAV_PASSWORD="${WEBDAV_PASSWORD:-changeme}"
WEBDAV_UID="${WEBDAV_UID:-$(id -u)}"
WEBDAV_GID="${WEBDAV_GID:-$(id -g)}"
WEBDAV_BASE_URL="https://localhost:${WEBDAV_PORT}"

export WEBDAV_PORT
export WEBDAV_DOMAIN
export WEBDAV_USERNAME
export WEBDAV_PASSWORD
export WEBDAV_UID
export WEBDAV_GID

COMPOSE_CMD=""
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif command -v podman-compose >/dev/null 2>&1; then
  COMPOSE_CMD="podman-compose"
else
  echo "ERROR: neither 'docker compose' nor 'podman-compose' is available." >&2
  exit 1
fi

cleanup() {
  echo ""
  echo "== Cleanup =="
  $COMPOSE_CMD -f "$COMPOSE_FILE" -f "$COMPOSE_OVERRIDE" down -v >/dev/null 2>&1 || true
}
trap cleanup EXIT

assert_status() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $label (expected HTTP $expected, got $actual)"
    exit 1
  fi
  echo "PASS: $label (HTTP $actual)"
}

extract_etag() {
  local path="$1"
  local etag
  etag=$(curl -k -sS -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" -I "${WEBDAV_BASE_URL}/${path}" | awk -F': ' 'tolower($1)=="etag"{gsub("\r", "", $2); print $2; exit}')
  if [[ -z "$etag" ]]; then
    echo "FAIL: missing ETag for ${path}" >&2
    exit 1
  fi
  printf '%s' "$etag"
}

extract_last_modified() {
  local path="$1"
  local last_modified
  last_modified=$(curl -k -sS -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" -I "${WEBDAV_BASE_URL}/${path}" | awk -F': ' 'tolower($1)=="last-modified"{gsub("\r", "", $2); print $2; exit}')
  if [[ -z "$last_modified" ]]; then
    echo "FAIL: missing Last-Modified for ${path}" >&2
    exit 1
  fi
  printf '%s' "$last_modified"
}

echo "== Preparing fixture data =="
rm -rf "$TEST_DATA_DIR" "$TEST_CERTS_DIR" 2>/dev/null || true
if [[ -d "$TEST_DATA_DIR" || -d "$TEST_CERTS_DIR" ]]; then
  if command -v podman >/dev/null 2>&1; then
    podman unshare rm -rf "$TEST_DATA_DIR" "$TEST_CERTS_DIR" >/dev/null 2>&1 || true
  fi
fi
mkdir -p "$TEST_DATA_DIR" "$TEST_CERTS_DIR/live/$WEBDAV_DOMAIN"
printf 'v1\n' > "$TEST_DATA_DIR/simple.txt"

openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "$TEST_CERTS_DIR/live/$WEBDAV_DOMAIN/privkey.pem" \
  -out "$TEST_CERTS_DIR/live/$WEBDAV_DOMAIN/fullchain.pem" \
  -days 1 \
  -subj "/CN=$WEBDAV_DOMAIN" >/dev/null 2>&1

echo "== Starting isolated WebDAV (Apache/mod_dav) =="
$COMPOSE_CMD -f "$COMPOSE_FILE" -f "$COMPOSE_OVERRIDE" up -d webdav >/dev/null

echo "== Waiting for WebDAV readiness =="
ready="false"
for attempt in $(seq 1 20); do
  status=$(curl -k -sS -o /dev/null -w '%{http_code}' -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" "${WEBDAV_BASE_URL}/simple.txt" || true)
  if [[ "$status" == "200" ]]; then
    ready="true"
    break
  fi
  sleep 1
done
if [[ "$ready" != "true" ]]; then
  echo "FAIL: WebDAV did not become ready"
  exit 1
fi

echo "== Check 1: data mount semantics (host -> WebDAV) =="
downloaded=$(curl -k -sS -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" "${WEBDAV_BASE_URL}/simple.txt")
if [[ "$downloaded" != $'v1' ]]; then
  echo "FAIL: WebDAV did not expose host-mounted /data content"
  exit 1
fi
echo "PASS: WebDAV reads host-mounted data"

echo "== Check 2: conditional PUT behavior =="
etag_v1=$(extract_etag "simple.txt")
echo "INFO: detected ETag: ${etag_v1}"

status_no_header=$(curl -k -sS -o /dev/null -w '%{http_code}' \
  -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
  -X PUT --data-binary $'v2-no-header\n' \
  "${WEBDAV_BASE_URL}/simple.txt" || true)
assert_status "428" "$status_no_header" "PUT rejected when If-Match missing"

if [[ "$etag_v1" =~ ^W/ ]]; then
  echo "INFO: weak ETag detected; using If-Unmodified-Since for positive conditional checks"

  lm_v1=$(extract_last_modified "simple.txt")
  lm_future_valid=$(date -u -d '+120 seconds' '+%a, %d %b %Y %H:%M:%S GMT' 2>/dev/null || true)
  if [[ -z "$lm_future_valid" ]]; then
    lm_future_valid="$lm_v1"
  fi
  status_valid=$(curl -k -sS -o /dev/null -w '%{http_code}' \
    -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
    -H "If-Unmodified-Since: ${lm_future_valid}" \
    -X PUT --data-binary $'v2\n' \
    "${WEBDAV_BASE_URL}/simple.txt" || true)
  if [[ ! "$status_valid" =~ ^20[0-9]$ ]]; then
    echo "FAIL: valid conditional PUT should succeed, got HTTP $status_valid"
    exit 1
  fi
  echo "PASS: valid conditional PUT accepted (HTTP $status_valid)"

  echo "== Check 3: stale conditional PUT rejection =="
  printf 'v3-host-side-change\n' > "$TEST_DATA_DIR/simple.txt"

  status_stale=$(curl -k -sS -o /dev/null -w '%{http_code}' \
    -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
    -H "If-Unmodified-Since: ${lm_v1}" \
    -X PUT --data-binary $'v4-stale-should-fail\n' \
    "${WEBDAV_BASE_URL}/simple.txt" || true)
  assert_status "412" "$status_stale" "stale conditional PUT rejected"

  sleep 1
  lm_v3=$(extract_last_modified "simple.txt")
  lm_future=$(date -u -d '+120 seconds' '+%a, %d %b %Y %H:%M:%S GMT' 2>/dev/null || true)
  if [[ -z "$lm_future" ]]; then
    lm_future="$lm_v3"
  fi
  status_fresh=$(curl -k -sS -o /dev/null -w '%{http_code}' \
    -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
    -H "If-Unmodified-Since: ${lm_future}" \
    -X PUT --data-binary $'v4-fresh\n' \
    "${WEBDAV_BASE_URL}/simple.txt" || true)
  if [[ ! "$status_fresh" =~ ^20[0-9]$ ]]; then
    echo "FAIL: fresh conditional PUT should succeed, got HTTP $status_fresh"
    exit 1
  fi
  echo "PASS: fresh conditional PUT accepted (HTTP $status_fresh)"
else
  status_valid=$(curl -k -sS -o /dev/null -w '%{http_code}' \
    -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
    -H "If-Match: ${etag_v1}" \
    -X PUT --data-binary $'v2\n' \
    "${WEBDAV_BASE_URL}/simple.txt" || true)
  if [[ ! "$status_valid" =~ ^20[0-9]$ ]]; then
    echo "FAIL: valid conditional PUT should succeed, got HTTP $status_valid"
    exit 1
  fi
  echo "PASS: valid conditional PUT accepted (HTTP $status_valid)"

  etag_v2=$(extract_etag "simple.txt")

  echo "== Check 3: stale conditional PUT rejection =="
  printf 'v3-host-side-change\n' > "$TEST_DATA_DIR/simple.txt"

  status_stale=$(curl -k -sS -o /dev/null -w '%{http_code}' \
    -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
    -H "If-Match: ${etag_v2}" \
    -X PUT --data-binary $'v4-stale-should-fail\n' \
    "${WEBDAV_BASE_URL}/simple.txt" || true)
  assert_status "412" "$status_stale" "stale conditional PUT rejected"

  sleep 1
  etag_v3=$(extract_etag "simple.txt")
  status_fresh=$(curl -k -sS -o /dev/null -w '%{http_code}' \
    -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
    -H "If-Match: ${etag_v3}" \
    -X PUT --data-binary $'v4-fresh\n' \
    "${WEBDAV_BASE_URL}/simple.txt" || true)
  if [[ ! "$status_fresh" =~ ^20[0-9]$ ]]; then
    echo "FAIL: fresh conditional PUT should succeed, got HTTP $status_fresh"
    exit 1
  fi
  echo "PASS: fresh conditional PUT accepted (HTTP $status_fresh)"
fi

echo "== Check 4: data mount semantics (WebDAV -> host) =="
host_content=$(cat "$TEST_DATA_DIR/simple.txt")
if [[ "$host_content" != $'v4-fresh' ]]; then
  echo "FAIL: WebDAV write did not persist to host-mounted /data"
  exit 1
fi
echo "PASS: WebDAV writes persist to host-mounted data"

echo ""
echo "All Apache WebDAV smoke checks passed."
