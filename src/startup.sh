#!/bin/bash

# Load the SA password from the Docker secret file so SQL Server can use it.
# This keeps the password out of environment variables in docker-compose.yml.
if [ -f "/run/secrets/sa_password" ]; then
    export MSSQL_SA_PASSWORD="$(cat /run/secrets/sa_password)"
fi

trap 'pkill -x sqlservr || true' INT TERM

/opt/mssql/bin/sqlservr &

wait
