#!/bin/sh
# Run liquibase, posting result to slack webhook if $SLACK_WEBHOOK is set

# Function to describe the changelogs that will be run
diff_status() {
	/app/liquibase/liquibase \
		--changeLogFile=changelog.xml \
		--driver=org.postgresql.Driver \
		--classpath=/app/jdbc_drivers/postgresql-42.1.4.jar \
		--url=jdbc:postgresql://${PGS_HOST}:${PGS_PORT}/${PGS_DB} \
		--defaultSchemaName=${SCHEMA} \
		--username=${PGS_USERNAME} \
		--password=${PGS_PASSWORD} \
		status --verbose 2>&1
}

# Function to output the SQL that will be run
update_sql() {
	/app/liquibase/liquibase \
		--changeLogFile=changelog.xml \
		--driver=org.postgresql.Driver \
		--classpath=/app/jdbc_drivers/postgresql-42.1.4.jar \
		--url=jdbc:postgresql://${PGS_HOST}:${PGS_PORT}/${PGS_DB} \
		--defaultSchemaName=${SCHEMA} \
		--username=${PGS_USERNAME} \
		--password=${PGS_PASSWORD} \
		updateSQL 2>&1
}

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

# Init the log file
touch LOGFILE
# Initialize our pipe for redirection
mkfifo pipe0
echo '
**************************************************************
Changeset Overview:
**************************************************************' | tee -a LOGFILE
# Tee to stdout and capture in log file
tee -a LOGFILE < pipe0 &

# Run diff status to see output of changelogs to run
diff_status > pipe0

# Just log the update sql, don't put in log for slack message
echo '
**************************************************************
Liquibase update SQL
**************************************************************'
update_sql

# Initialize our pipe for redirection
mkfifo pipe1
# Tee to stdout and capture in log file
tee -a LOGFILE < pipe1 &
# Delimiter in logfile
echo '
**************************************************************
Liquibase run output:
**************************************************************' | tee -a LOGFILE
# Run the liquibase command through the pipe
run_liquibase > pipe1
# Capture exit code of liquibase command
MY_EXIT_CODE=$?

if [[ ! -z "$SLACK_WEBHOOK" ]]; then
    # Get ahold of log for slack message
    MY_OUTPUT=$(cat LOGFILE)

    ESCAPED_MSG=$(echo "$MY_OUTPUT" | sed 's/"/\"/g' | sed "s/'/\'/g" )

    JSON="{\"channel\": \"$CHANNEL\", \"username\": \"deployinator\", \"icon_emoji\": \":rocket:\", \"attachments\": [{\"color\": \"danger\", \"text\": \"<!here> ${HOSTNAME}\n\`\`\`${ESCAPED_MSG}\`\`\`\"}]}"

    curl -s -d "payload=${JSON}" "$SLACK_WEBHOOK"
fi

# Exit with the liquibase exit code
exit $MY_EXIT_CODE

