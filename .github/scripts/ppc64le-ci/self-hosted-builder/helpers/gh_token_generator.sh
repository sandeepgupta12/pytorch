#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$0")
APP_ID=$1
INSTALL_ID=$2
APP_PRIVATE_KEY=$3
DST_FILE="$4"

ACCESS_TOKEN="$(APP_ID="$(<"${APP_ID}")" INSTALL_ID="$(<"${INSTALL_ID}")" APP_PRIVATE_KEY="${APP_PRIVATE_KEY}" "${SCRIPT_DIR}/app_token.sh")"
# Write atomically: write to a temp file, set restrictive perms, then move into place.
TMP_DST="${DST_FILE}.tmp"
printf '%s' "${ACCESS_TOKEN}" > "${TMP_DST}"
chmod 600 "${TMP_DST}" || true
mv -f "${TMP_DST}" "${DST_FILE}"
