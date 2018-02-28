MSG=$(/app/liquibase/liquibase --changeLogFile=changelog.xml \
 --driver=org.postgresql.Driver \
 --classpath=/app/jdbc_drivers/postgresql-42.1.4.jar \
 --url=jdbc:postgresql://${PGS_HOST}:${PGS_PORT}/${PGS_DB} \
 --defaultSchemaName=vehicle_assignment \
 --username=${PGS_USERNAME} \
 --password=${PGS_PASSWORD} \
 update 2>&1)

ESCAPED_MSG=$(echo "$MSG" | sed 's/"/\"/g' | sed "s/'/\'/g" )

JSON="{\"channel\": \"$CHANNEL\", \"username\": \"deployinator\", \"icon_emoji\": \":rocket:\", \"attachments\": [{\"color\": \"danger\", \"text\": \"${HOSTNAME}\n\`\`\`${ESCAPED_MSG}\`\`\`\"}]}"

curl -s -d "payload=${JSON}" "$SLACK_WEBHOOK"