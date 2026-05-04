# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/mssql/server:2025-CU4-ubuntu-22.04

ARG DB_USER

ENV ACCEPT_EULA=Y

# SQL Server 2025 ships all features (including Full-Text Search) bundled in
# the base image via .sfp packages – no separate mssql-server-fts apt install
# is needed.  FTS is enabled at the database level after the .bacpac import.

COPY src/startup.sh /startup.sh

# One-time build-time initialisation:
#   Start SQL Server, create the application SQL login, then shut it down.
#   The SA password and DB password are injected via BuildKit secret mounts so
#   they are never stored in any image layer (see `docker buildx build --secret`
#   and the `secrets:` section in docker-compose.yml).
#   create_database.sql is bind-mounted only during the build – it is not
#   copied into the final image.
RUN --mount=type=secret,id=sa_password,required=true,mode=0444 \
    --mount=type=secret,id=db_password,required=true,mode=0444 \
    --mount=type=bind,source=src/create_database.sql,target=/tmp/create_database.sql \
    set -e; \
    SA_PWD="$(cat /run/secrets/sa_password)"; \
    DB_PWD="$(cat /run/secrets/db_password)"; \
    MSSQL_SA_PASSWORD="$SA_PWD" /opt/mssql/bin/sqlservr & \
    echo "Waiting for SQL Server to accept connections…"; \
    for i in $(seq 1 30); do \
        /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PWD" -C -Q "SELECT 1" > /dev/null 2>&1 && break; \
        echo "  attempt $i/30 – retrying in 3 s"; sleep 3; \
    done; \
    /opt/mssql-tools18/bin/sqlcmd \
        -v DB_USER="$DB_USER" -v DB_PASSWORD="$DB_PWD" \
        -b -S localhost -U sa -P "$SA_PWD" -C \
        -i /tmp/create_database.sql; \
    pkill sqlservr || true; \
    sleep 5

CMD ["bash", "/startup.sh"]
