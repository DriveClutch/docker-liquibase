FROM driveclutch/alpine-java:1.0

USER root
RUN apk --no-cache add curl

COPY lib/liquibase-3.5.3-bin.tar.gz /tmp/liquibase-3.5.3-bin.tar.gz
RUN mkdir liquibase
RUN tar -xzf /tmp/liquibase-3.5.3-bin.tar.gz -C liquibase
RUN chmod +x liquibase/liquibase

RUN mkdir jdbc_drivers
COPY lib/postgresql-42.1.4.jar jdbc_drivers/

RUN mkdir migrations
WORKDIR migrations

COPY update.sh /app

CMD /app/update.sh