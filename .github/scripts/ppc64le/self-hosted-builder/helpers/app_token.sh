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

#APP_ID=$(cat $1)         # Path to appid.env
#PRIVATE_KEY_PATH=$2      # Path to key_private.pem
echo "APP_PRIVATE_KEY path: $APP_PRIVATE_KEY"

# Generate JWT
header='{"alg":"RS256","typ":"JWT"}'
payload="{\"iat\":$(date +%s),\"exp\":$(( $(date +%s) + 600 )),\"iss\":${APP_ID}}"

header_base64=$(echo -n "$header" | openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
payload_base64=$(echo -n "$payload" | openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

signature=$(echo -n "${header_base64}.${payload_base64}" | \
  openssl dgst -sha256 -sign "${APP_PRIVATE_KEY}" | \
  openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

echo "Contents of APP_PRIVATE_KEY:"
cat "$APP_PRIVATE_KEY"


generated_jwt="${header_base64}.${payload_base64}.${signature}"

echo $generated_jwt
# API_VERSION=v3
# API_HEADER="Accept: application/vnd.github+json"

# auth_header="Authorization: Bearer ${generated_jwt}"

# app_installations_response=$(curl -sX POST \
#         -H "${auth_header}" \
#         -H "${API_HEADER}" \
#         --url "https://api.github.com/app/installations/${INSTALL_ID}/access_tokens" \
#     )

# echo "$app_installations_response" | jq --raw-output '.token'

#echo "ACCESS_TOKEN=${jwt}" > "${DST_FILE}"