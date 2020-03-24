FROM driveclutch/alpine-java:2.2

USER root

# RUN apk update && \
#     apk add curl "libpq@edge<9.7" "postgresql-client@edge<9.7" && \
#     rm -rf /var/cache/apk/*

RUN apt-get update -y && apt-get install -y libpq-dev postgresql-client curl

COPY lib/* /tmp/

RUN mkdir liquibase && \
    tar -xzf /tmp/liquibase-3.5.3-bin.tar.gz -C liquibase && \
    chmod +x liquibase/liquibase && \
    mkdir jdbc_drivers && \
    mv /tmp/postgresql-42.1.4.jar jdbc_drivers && \
    mkdir migrations

WORKDIR migrations

COPY bin/ecs-set-desired /app/ecs-set-desired

COPY update.sh /app

CMD /app/update.sh
