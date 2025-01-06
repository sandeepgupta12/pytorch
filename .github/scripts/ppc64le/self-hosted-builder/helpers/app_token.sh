#!/usr/bin/env bash
#
# Request an ACCESS_TOKEN to be used by a GitHub APP
# Environment variable that need to be set up:
# * APP_ID, the GitHub's app ID
# * INSTALL_ID, the Github's app's installation ID
# * APP_PRIVATE_KEY, the content of GitHub app's private key in PEM format.
#
# https://github.com/orgs/community/discussions/24743#discussioncomment-3245300
#

set -o pipefail

APP_ID=$(cat $1)         # Path to appid.env
PRIVATE_KEY_PATH=$2      # Path to key_private.pem

# Generate JWT
header='{"alg":"RS256","typ":"JWT"}'
payload="{\"iat\":$(date +%s),\"exp\":$(( $(date +%s) + 600 )),\"iss\":${APP_ID}}"

header_base64=$(echo -n "$header" | openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
payload_base64=$(echo -n "$payload" | openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

signature=$(echo -n "${header_base64}.${payload_base64}" | \
  openssl dgst -sha256 -sign "$PRIVATE_KEY_PATH" | \
  openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

jwt="${header_base64}.${payload_base64}.${signature}"
echo "ACCESS_TOKEN=${jwt}" > "${DST_FILE}"