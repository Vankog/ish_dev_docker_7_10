FROM orbeon/mssql-server-linux-fts

ARG MSSQL_SA_PASSWORD
ARG DB_USER
ARG DB_PASSWORD
ARG DB_NAME

ENV ACCEPT_EULA=Y

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y curl wget unixodbc locales && \
    wget https://packages.microsoft.com/ubuntu/16.04/prod/pool/main/m/mssql-tools/mssql-tools_17.8.1.1-1_amd64.deb && \
    wget https://packages.microsoft.com/ubuntu/18.04/prod/pool/main/m/msodbcsql17/msodbcsql17_17.8.1.1-1_amd64.deb && \
    apt-get update &&  \
    dpkg -i msodbcsql17_17.8.1.1-1_amd64.deb && \
    dpkg -i mssql-tools_17.8.1.1-1_amd64.deb && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen && \
    rm -rf /var/lib/apt/lists/*

COPY src/ /

RUN (/opt/mssql/bin/sqlservr --reset-sa-password &) && \
    sleep 20 && \
    echo "start complete" && \
    /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -q quit && \
    /opt/mssql-tools/bin/sqlcmd -v DB_NAME=$DB_NAME -v DB_USER=$DB_USER -v DB_PASSWORD=$DB_PASSWORD -b -S localhost -U sa -P $MSSQL_SA_PASSWORD -i /create_database.sql && \
    sleep 10 && \
    ps -j -C sqlservr --no-headers | awk "{print \$1}" | xargs kill && \
    sleep 10

CMD [ "bash", "/startup.sh" ]
