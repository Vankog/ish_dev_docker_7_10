#!/bin/bash
set -euo pipefail

# Load the SA password from the Docker secret file so SQL Server can use it.
# This keeps the password out of environment variables in docker-compose.yml.
if [ ! -f "/run/secrets/sa_password" ]; then
    echo "ERROR: secret file /run/secrets/sa_password not found" >&2
    exit 1
fi
export MSSQL_SA_PASSWORD
MSSQL_SA_PASSWORD="$(cat /run/secrets/sa_password)"

/opt/mssql/bin/sqlservr &
SQLSERVR_PID=$!

# Forward SIGINT/SIGTERM to sqlservr so it can shut down gracefully.
trap 'kill "$SQLSERVR_PID" 2>/dev/null || true' INT TERM

wait "$SQLSERVR_PID"
