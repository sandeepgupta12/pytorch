#!/usr/bin/env bash

TOKEN_FILE=$1
TOKEN_PIPE=$2

echo "Starting gh_cat_token.sh with TOKEN_FILE=${TOKEN_FILE}, TOKEN_PIPE=${TOKEN_PIPE}"

# Validate inputs
if [[ ! -r "${TOKEN_FILE}" ]]; then
    echo "Error: Token file '${TOKEN_FILE}' does not exist or is not readable."
    exit 1
fi

if [[ -e "${TOKEN_PIPE}" ]]; then
    echo "Removing existing pipe ${TOKEN_PIPE}"
    rm -f "${TOKEN_PIPE}"
fi

mkfifo "${TOKEN_PIPE}"
echo "Created FIFO ${TOKEN_PIPE}"

# Write token file contents to pipe
cat "${TOKEN_FILE}" > "${TOKEN_PIPE}" &
echo "Token written to pipe ${TOKEN_PIPE}"
