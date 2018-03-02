#!/bin/sh
# Run liquibase, posting result to slack webhook if $SLACK_WEBHOOK is set

# Function to actually run the liquibase command
run_liquibase() { 
  /app/liquibase/liquibase \
	  --changeLogFile=changelog.xml \
	  --driver=org.postgresql.Driver \
	  --classpath=/app/jdbc_drivers/postgresql-42.1.4.jar \
	  --url=jdbc:postgresql://${PGS_HOST}:${PGS_PORT}/${PGS_DB} \
	  --defaultSchemaName=${SCHEMA} \
	  --username=${PGS_USERNAME} \
	  --password=${PGS_PASSWORD} \
	  update 2>&1
}

# Initialize our pipe for redirection
mkfifo my_pipe
# Tee to stdout and capture in log file
tee liquibase.log < my_pipe &

# Run the liquibase command through the pipe
run_liquibase > my_pipe
# Capture exit code of liquibase command
MY_EXIT_CODE=$?

if [[ ! -z "$SLACK_WEBHOOK" ]]; then
    # Get ahold of log for slack message
    MY_OUTPUT=$(cat liquibase.log)

    ESCAPED_MSG=$(echo "$MY_OUTPUT" | sed 's/"/\"/g' | sed "s/'/\'/g" )

    JSON="{\"channel\": \"$CHANNEL\", \"username\": \"deployinator\", \"icon_emoji\": \":rocket:\", \"attachments\": [{\"color\": \"danger\", \"text\": \"<!here> ${HOSTNAME}\n\`\`\`${ESCAPED_MSG}\`\`\`\"}]}"

    curl -s -d "payload=${JSON}" "$SLACK_WEBHOOK"
fi

# Exit with the liquibase exit code
exit $MY_EXIT_CODE
