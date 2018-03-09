#!/bin/sh -e
# Run liquibase, posting result to slack webhook if $SLACK_WEBHOOK is set

# Prefix stdout with 'SEV=WARN' to help delimit log messages
warnify() {
	awk 'BEGIN {print "SEV=WARN"} {print $0}'
}

# Function to ensure the schema exists, in case this is the schema
# initialization run, we need it to exist for liquibase to use it as
# the default schema
ensure_schema() {
	PGPASSWORD="${PGS_PASSWORD}" psql \
		--host="${PGS_HOST}" \
		--port="${PGS_PORT}" \
		--dbname="${PGS_DB}" \
		--username="${PGS_USERNAME}" \
		--command="CREATE SCHEMA IF NOT EXISTS ${SCHEMA};" 2>&1
}

# Base liquibase helper
liquibase() {
  /app/liquibase/liquibase \
		--changeLogFile=changelog.xml \
		--driver=org.postgresql.Driver \
		--classpath=/app/jdbc_drivers/postgresql-42.1.4.jar \
		--url=jdbc:postgresql://${PGS_HOST}:${PGS_PORT}/${PGS_DB} \
		--defaultSchemaName=${SCHEMA} \
		--username=${PGS_USERNAME} \
		--password=${PGS_PASSWORD} \
		"$@" \
		2>&1
}

# Function to describe the any unexpected change sets that will be run
diff_unexpected() {
	liquibase unexpectedChangeSets --verbose
}

# Function to describe the change sets that will be run
diff_status() {
	liquibase status --verbose
}

# Function to output the SQL that will be run
update_sql() {
	liquibase updateSQL
}

# Function to actually run the liquibase command
run_liquibase() { 
	liquibase update
}

# Init the log file
touch LOGFILE
# Initialize our pipe for redirection
if [[ -p "my_pipe" ]]; then
	rm my_pipe
fi
mkfifo my_pipe

# Tee to stdout and capture in log file
tee -a LOGFILE < my_pipe | warnify &

# Ensure the schem exists
echo '
SEV=WARN
**************************************************************
Ensure schema with psql
**************************************************************' | tee -a LOGFILE
ensure_schema > my_pipe

echo '
SEV=WARN
**************************************************************
Unexpected Change Set Overview:
**************************************************************' | tee -a LOGFILE

# Run diff status to see output of change sets to run
tee -a LOGFILE < my_pipe | warnify & diff_unexpected > my_pipe

echo '
SEV=WARN
**************************************************************
Change Set Overview:
**************************************************************' | tee -a LOGFILE

# Run diff status to see output of change sets to run
tee -a LOGFILE < my_pipe | warnify & diff_status > my_pipe

# Just log the update sql, don't put in log for slack message
echo '
SEV=WARN
**************************************************************
Liquibase update SQL
**************************************************************'
update_sql | warnify

# Delimiter in logfile
echo '
SEV=WARN
**************************************************************
Liquibase run output:
**************************************************************' | tee -a LOGFILE
tee -a LOGFILE < my_pipe | warnify &

# Run the liquibase command through the pipe
run_liquibase > my_pipe
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

