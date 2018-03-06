#!/bin/sh
# Run liquibase, posting result to slack webhook if $SLACK_WEBHOOK is set

# Prefix stdout with 'SEV=WARN' to help delimit log messages
warnify() {
	awk 'BEGIN {print "SEV=WARN"} {print $0}'
}

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

# Function to describe the change sets that will be run
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
if [[ -p "pipe0" ]]; then
	rm pipe0
fi
mkfifo pipe0

echo '
SEV=WARN
**************************************************************
Unexpected Change Set Overview:
**************************************************************' | tee -a LOGFILE
# Tee to stdout and capture in log file
tee -a LOGFILE < pipe0 | warnify &

# Run diff status to see output of change sets to run
diff_unexpected > pipe0

echo '
SEV=WARN
**************************************************************
Change Set Overview:
**************************************************************' | tee -a LOGFILE
# Tee to stdout and capture in log file
tee -a LOGFILE < pipe0 | warnify &

# Run diff status to see output of change sets to run
diff_status > pipe0

# Just log the update sql, don't put in log for slack message
echo '
SEV=WARN
**************************************************************
Liquibase update SQL
**************************************************************'
update_sql | warnify

# Initialize our pipe for redirection
if [[ -p "pipe1" ]]; then
	rm pipe1
fi
mkfifo pipe1
# Tee to stdout and capture in log file
tee -a LOGFILE < pipe1 | warnify &

# Delimiter in logfile
echo '
SEV=WARN
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

