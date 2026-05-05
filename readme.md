# ICM Database, Solr and Dev SMTP Mail Server

This Docker Compose stack starts three local developer services:

- Microsoft SQL Server with Full-Text Search
- Apache Solr
- smtp4dev for test email delivery

All published ports are bound to `127.0.0.1`, so the services are only reachable from the local machine unless you change the port bindings in [docker-compose.yml](docker-compose.yml).

Data is persisted in named volumes. Delete the according volumes to reset the database, Mail server and Solr state.

## Initial Setup

1. Create your local SA password file from the sample at [secrets/sa_password.txt.sample](secrets/sa_password.txt.sample):

```bash
cp -n secrets/sa_password.txt.sample secrets/sa_password.txt
```

2. Edit [secrets/sa_password.txt](secrets/sa_password.txt) to replace the standard password with the password you want to use locally.

3. Zookeeper needs to access Solr from the host machine by its configured hostname. Add this entry to your hosts file:

```text
127.0.0.1 solr
```

4. (Also after deleting the volume.) After the database is up and running, import an ICM database bacpac file into the SQL Server instance. Then adapt the parameters in the last lines of the [update restored DB.sql](update%20restored%20DB.sql) and run it to set up the imported database for ICM and an according user. This is the user used in the ISH `orm.properties`.

## Start the Stack

Build and start all services:

```bash
docker compose up -d
```

The database image is built locally on first use and then reused on later `docker compose up` runs.

## Start a Single Service

If you only want one service, start it explicitly:

```bash
docker compose up -d database
docker compose up -d solr
docker compose up -d mail_server
```

## Refresh the Database Image

Rebuild the local database image on demand, e.g. for version updates:

```bash
docker compose build database
docker compose up -d database
```

## Check Running Containers

```bash
docker ps -a
```

## Connect to the Database

Use these connection settings for SQL Server:

- Host: `127.0.0.1`
- Port: `1433`
- User: `sa`
- Password: the value stored in your [secrets/sa_password.txt](secrets/sa_password.txt)

## Update Versions

- For direct images, like mail and solr, simply change the version of the images in [docker-compose.yml](docker-compose.yml) and restart the services.
- For the database there are 3 versions to manage:
    - MSSQL version + CU:
        - Update the base image in [Dockerfile](Dockerfile) for the SQL Server version.
        - For major version updates, you also need to update the package repository to the new version.  
          i.e. given `https://packages.microsoft.com/ubuntu/24.04/mssql-server-2025 noble main` and `/etc/apt/sources.list.d/mssql-server-2025.list`, for MSSQL 2025, the repository is `mssql-server-2025` and the target file is `mssql-server-2025.list`.
    - Full-Text Search package version:
        - Update the `FTS_VERSION` ARG in [Dockerfile](Dockerfile).
    - Ubuntu version:
        - Update the version of the base image in [Dockerfile](Dockerfile).
        - You also need to update the package repository.
            - i.e. given `https://packages.microsoft.com/ubuntu/24.04/mssql-server-2025 noble main`,  
              update the version in the URL  
              and update the codename. e.g. "noble" is the code name for Ubuntu 24, Ubuntu 22 is "jammy", etc.

## Stop the Stack

```bash
docker compose down
```

## Remove Containers, Volumes, and Images

This removes the containers first, then deletes the named volumes and the local images used by this stack:

```bash
docker compose down
docker volume rm ish_dev_mssql_2025_icm_db
docker volume rm ish_dev_solr_data
docker volume rm mail_server_data
docker image rm ish_dev:mssql_2025_icm_db
docker image rm solr:8.11.2
docker image rm rnwood/smtp4dev:3.15.0
```
