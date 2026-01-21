#!/usr/bin/env bash

TOKEN_FILE=$1
TOKEN_PIPE=$2

# Remove any existing pipe, create FIFO, and stream token into it in background
rm "${TOKEN_PIPE}" 2>/dev/null ||:
mkfifo "${TOKEN_PIPE}"
cat "${TOKEN_FILE}" > "${TOKEN_PIPE}" &
