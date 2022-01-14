FROM 458132236648.dkr.ecr.us-east-1.amazonaws.com/master/clutch-java:latest

USER root

RUN apt-get update && apt-get install -y --no-install-recommends && \
    apt-get install -y "postgresql-client-13"

COPY lib/* /tmp/

RUN mkdir liquibase && \
    tar -xzf /tmp/liquibase-4.7.0.tar.gz -C liquibase && \
    chmod +x liquibase/liquibase && \
    mkdir jdbc_drivers && \
    mv /tmp/postgresql-42.3.1.jar jdbc_drivers && \
    mkdir migrations

WORKDIR migrations

COPY bin/ecs-set-desired /app/ecs-set-desired

COPY update.sh /app
COPY shutdown.sh /app

CMD bash /app/update.sh
