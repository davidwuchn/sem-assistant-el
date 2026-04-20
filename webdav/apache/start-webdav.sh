#!/bin/sh
set -eu

if [ -z "${WEBDAV_DOMAIN:-}" ]; then
  echo "[webdav] ERROR: WEBDAV_DOMAIN is required."
  exit 1
fi

if [ -z "${ORGANICE_DOMAIN:-}" ]; then
  echo "[webdav] ERROR: ORGANICE_DOMAIN is required."
  exit 1
fi

if [ -z "${ORGANICE_ORIGIN:-}" ]; then
  echo "[webdav] ERROR: ORGANICE_ORIGIN is required."
  exit 1
fi

if [ "$ORGANICE_ORIGIN" != "https://${ORGANICE_DOMAIN}" ]; then
  echo "[webdav] ERROR: ORGANICE_ORIGIN must be exactly https://${ORGANICE_DOMAIN}."
  echo "[webdav] Received ORGANICE_ORIGIN=${ORGANICE_ORIGIN}"
  exit 1
fi

if [ -z "${WEBDAV_USERNAME:-}" ] || [ -z "${WEBDAV_PASSWORD:-}" ]; then
  echo "[webdav] ERROR: WEBDAV_USERNAME and WEBDAV_PASSWORD are required."
  exit 1
fi

WEBDAV_RUNTIME_MODE="${WEBDAV_RUNTIME_MODE:-production}"

if [ "$WEBDAV_RUNTIME_MODE" = "production" ]; then
  password_len="${#WEBDAV_PASSWORD}"
  has_lower=0
  has_upper=0
  has_digit=0

  if printf '%s' "$WEBDAV_PASSWORD" | grep -Eq '[a-z]'; then
    has_lower=1
  fi
  if printf '%s' "$WEBDAV_PASSWORD" | grep -Eq '[A-Z]'; then
    has_upper=1
  fi
  if printf '%s' "$WEBDAV_PASSWORD" | grep -Eq '[0-9]'; then
    has_digit=1
  fi

  if [ "$password_len" -lt 20 ] || [ "$has_lower" -ne 1 ] || [ "$has_upper" -ne 1 ] || [ "$has_digit" -ne 1 ]; then
    echo "[webdav] ERROR: Production password policy validation failed."
    echo "[webdav] Remediation: set WEBDAV_PASSWORD to >=20 chars with lowercase, uppercase, and digit."
    exit 1
  fi
fi

WEBDAV_UID="${WEBDAV_UID:-1000}"
WEBDAV_GID="${WEBDAV_GID:-1000}"

CERT_FILE="/certs/live/${WEBDAV_DOMAIN}/fullchain.pem"
KEY_FILE="/certs/live/${WEBDAV_DOMAIN}/privkey.pem"
ORGANICE_CERT_FILE="/certs/live/${ORGANICE_DOMAIN}/fullchain.pem"
ORGANICE_KEY_FILE="/certs/live/${ORGANICE_DOMAIN}/privkey.pem"
ORGANICE_ROOT="/var/www/organice"

if [ ! -d "$ORGANICE_ROOT" ] || [ ! -r "$ORGANICE_ROOT/index.html" ]; then
  echo "[webdav] ERROR: Missing organice static assets under ${ORGANICE_ROOT}."
  echo "[webdav] Expected readable file: ${ORGANICE_ROOT}/index.html"
  exit 1
fi

if [ ! -r "$CERT_FILE" ] || [ ! -r "$KEY_FILE" ]; then
  echo "[webdav] ERROR: Missing TLS certificate files for WEBDAV_DOMAIN=${WEBDAV_DOMAIN}."
  echo "[webdav] Expected: $CERT_FILE and $KEY_FILE"
  exit 1
fi

if [ ! -r "$ORGANICE_CERT_FILE" ] || [ ! -r "$ORGANICE_KEY_FILE" ]; then
  echo "[webdav] ERROR: Missing TLS certificate files for ORGANICE_DOMAIN=${ORGANICE_DOMAIN}."
  echo "[webdav] Expected: $ORGANICE_CERT_FILE and $ORGANICE_KEY_FILE"
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "[webdav] ERROR: openssl binary not found in container image."
  exit 1
fi

if ! openssl x509 -in "$CERT_FILE" -noout >/dev/null 2>&1; then
  echo "[webdav] ERROR: Invalid certificate file for WEBDAV_DOMAIN=${WEBDAV_DOMAIN}: $CERT_FILE"
  exit 1
fi

if ! openssl pkey -in "$KEY_FILE" -noout >/dev/null 2>&1; then
  echo "[webdav] ERROR: Invalid private key file for WEBDAV_DOMAIN=${WEBDAV_DOMAIN}: $KEY_FILE"
  exit 1
fi

if ! openssl x509 -in "$ORGANICE_CERT_FILE" -noout >/dev/null 2>&1; then
  echo "[webdav] ERROR: Invalid certificate file for ORGANICE_DOMAIN=${ORGANICE_DOMAIN}: $ORGANICE_CERT_FILE"
  exit 1
fi

if ! openssl pkey -in "$ORGANICE_KEY_FILE" -noout >/dev/null 2>&1; then
  echo "[webdav] ERROR: Invalid private key file for ORGANICE_DOMAIN=${ORGANICE_DOMAIN}: $ORGANICE_KEY_FILE"
  exit 1
fi

if ! command -v htpasswd >/dev/null 2>&1; then
  echo "[webdav] ERROR: htpasswd binary not found in container image."
  exit 1
fi

HTPASSWD_FILE="/usr/local/apache2/conf/webdav.htpasswd"
htpasswd -bc "$HTPASSWD_FILE" "$WEBDAV_USERNAME" "$WEBDAV_PASSWORD"

CONF_TEMPLATE="/usr/local/apache2/conf/extra/httpd-webdav.conf.template"
CONF_OUTPUT="/usr/local/apache2/conf/extra/httpd-webdav.conf"

if [ ! -r "$CONF_TEMPLATE" ]; then
  echo "[webdav] ERROR: Missing Apache template: $CONF_TEMPLATE"
  exit 1
fi

sed "s|@@WEBDAV_DOMAIN@@|$WEBDAV_DOMAIN|g; s|@@ORGANICE_DOMAIN@@|$ORGANICE_DOMAIN|g; s|@@ORGANICE_ORIGIN@@|$ORGANICE_ORIGIN|g; s|@@WEBDAV_CERT_FILE@@|$CERT_FILE|g; s|@@WEBDAV_KEY_FILE@@|$KEY_FILE|g; s|@@ORGANICE_CERT_FILE@@|$ORGANICE_CERT_FILE|g; s|@@ORGANICE_KEY_FILE@@|$ORGANICE_KEY_FILE|g" "$CONF_TEMPLATE" > "$CONF_OUTPUT"

httpd_conf="/usr/local/apache2/conf/httpd.conf"
sed -i 's/^#\(LoadModule ssl_module modules\/mod_ssl.so\)$/\1/' "$httpd_conf"
sed -i 's/^#\(LoadModule socache_shmcb_module modules\/mod_socache_shmcb.so\)$/\1/' "$httpd_conf"
sed -i 's/^#\(LoadModule dav_module modules\/mod_dav.so\)$/\1/' "$httpd_conf"
sed -i 's/^#\(LoadModule dav_fs_module modules\/mod_dav_fs.so\)$/\1/' "$httpd_conf"
sed -i 's/^#\(LoadModule rewrite_module modules\/mod_rewrite.so\)$/\1/' "$httpd_conf"
sed -i 's/^#\(LoadModule headers_module modules\/mod_headers.so\)$/\1/' "$httpd_conf"
sed -i 's/^#\(LoadModule authn_file_module modules\/mod_authn_file.so\)$/\1/' "$httpd_conf"
sed -i 's/^#\(LoadModule auth_basic_module modules\/mod_auth_basic.so\)$/\1/' "$httpd_conf"
sed -i "s/^User .*/User #${WEBDAV_UID}/" "$httpd_conf"
sed -i "s/^Group .*/Group #${WEBDAV_GID}/" "$httpd_conf"

if ! grep -q '^Include conf/extra/httpd-webdav.conf$' "$httpd_conf"; then
  printf '\nInclude conf/extra/httpd-webdav.conf\n' >> "$httpd_conf"
fi

exec httpd -DFOREGROUND
