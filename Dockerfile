FROM mcr.microsoft.com/mssql/server:2025-CU4-ubuntu-22.04

ENV ACCEPT_EULA=Y

# SQL Server 2025 bundles all features including Full-Text Search – no
# separate package installs needed.  FTS is enabled at database level after
# the .bacpac import via `update restored DB.sql`.
#
# SA password is read from the Docker secret file by startup.sh at runtime.
# On first start with an empty volume SQL Server initialises the data
# directory and sets the SA password from MSSQL_SA_PASSWORD.
# The application login is created by `update restored DB.sql` after the
# .bacpac import – no build-time SQL initialisation is required.

COPY src/startup.sh /startup.sh

CMD ["bash", "/startup.sh"]
