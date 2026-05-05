# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/mssql/server:2025-CU4-ubuntu-24.04

# Full-Text Search package version ("mssql-server-fts")
ARG FTS_VERSION=17.0.4035.5-1

ENV ACCEPT_EULA=Y

# Install Full-Text Search from the repository "mssql-server-2025".
# Avoid 'apt install' because it would pull in "mssql-server" as a package dependency,
# which is already included in the base image. Instead download the .deb and install it
# with dpkg --force-depends, ignoring the mssql-server dependency.
USER root
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/24.04/mssql-server-2025 noble main" \
       > /etc/apt/sources.list.d/mssql-server-2025.list \
    && apt-get update -qq \
    && apt-get download mssql-server-fts=${FTS_VERSION} \
    && dpkg --force-depends -i mssql-server-fts_*.deb \
    && rm -f mssql-server-fts_*.deb \
    && rm -rf /var/lib/apt/lists/*
USER mssql
