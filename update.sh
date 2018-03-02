# Run liquibase, posting result to slack webhook if $SLACK_WEBHOOK is set

# Init fd 7 has duplicate of stdout
exec 7>&1

# Run the liquibase command, teed to stdout and captured in $MY_OUTPUT via fd 7
MY_OUTPUT=$(/app/liquibase/liquibase \
  --changeLogFile=changelog.xml \
  --driver=org.postgresql.Driver \
  --classpath=/app/jdbc_drivers/postgresql-42.1.4.jar \
  --url=jdbc:postgresql://${PGS_HOST}:${PGS_PORT}/${PGS_DB} \
  --defaultSchemaName=${SCHEMA} \
  --username=${PGS_USERNAME} \
  --password=${PGS_PASSWORD} \
  update 2>&1 | tee /dev/fd/7
)

# Capture exit code of liquibase command (although liquibase itself always returns 0 :( )
MY_EXIT_CODE=$?

if [[ ! -z "$SLACK_WEBHOOK" ]]; then
    ESCAPED_MSG=$(echo "$MY_OUTPUT" | sed 's/"/\"/g' | sed "s/'/\'/g" )

    JSON="{\"channel\": \"$CHANNEL\", \"username\": \"deployinator\", \"icon_emoji\": \":rocket:\", \"attachments\": [{\"color\": \"danger\", \"text\": \"<!here> ${HOSTNAME}\n\`\`\`${ESCAPED_MSG}\`\`\`\"}]}"

    curl -s -d "payload=${JSON}" "$SLACK_WEBHOOK"
fi

# close fd 7
exec 7>&-

# Exit with the liquibase exit code
exit $MY_EXIT_CODE
