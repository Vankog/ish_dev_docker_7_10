# ICM Database, Solr and dev SMTP mail server

This Docker compose will create and run the MSSQL ICM Database, Solr and a developer mail server as a Docker container.

## Build and start the containers

**Build and run:**

```bash
docker compose up -d
```

### Standalone usage of single service

If you only want to use one of the containers, e.g. the database, simply define the service name:

```bash
docker compose up database -d
docker compose up solr -d
docker compose up mail_server -d
```

## Test connection

Now you should have running docker containers. Check Docker Desktop or

```bash
docker ps -a
```

For the ICM Database, try to connecto to localhost:1433 with the credentials entered in .env file.  

## Update SMTP mail server

Updating the `rnwood/smtp4dev:latest` image with latest version:  
* make sure the `mail_server` service is shut down (see further below)  
* pull the image:  
```bash
docker compose pull mail_server
docker compose up -d
```

## Shut down containers

```bash
docker compose down
```

## Uninstall and Cleanup Docker containers

```bash
docker compose down
docker volume rm ish_dev_mssql_2017_icm_db
docker volume rm solr_data
docker image rm ish_dev:mssql_2017_icm_db
docker image rm solr:{used-tag}
docker image rm rnwood/smtp4dev:latest
```
