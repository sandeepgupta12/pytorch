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
# Make token readable by the container process. Use 644 so non-root
# processes inside the container can read it. Token is stored in tmpfs.
chmod 644 "${TMP_DST}" || true
mv -f "${TMP_DST}" "${DST_FILE}"
