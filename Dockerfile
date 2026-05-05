FROM mcr.microsoft.com/mssql/server:2025-CU4-ubuntu-22.04

ENV ACCEPT_EULA=Y

# Install Full-Text Search from the SQL Server 2025 package repository.
# The base image only ships the database engine; FTS is a separate package.
# After the .bacpac import, run `update restored DB.sql` to enable FTS on the
# restored database.
USER root
RUN echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/22.04/mssql-server-2025 jammy main" \
       > /etc/apt/sources.list.d/mssql-server-2025.list \
    && apt-get update \
    && apt-get download mssql-server-fts \
    && dpkg --force-depends -i mssql-server-fts_*.deb \
    && rm -f mssql-server-fts_*.deb \
    && rm -rf /var/lib/apt/lists/*
USER mssql

COPY src/startup.sh /startup.sh

CMD ["bash", "/startup.sh"]
