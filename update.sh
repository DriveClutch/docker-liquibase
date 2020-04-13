#!/bin/bash
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

# Function to post output to configured slack webhook, if exists
post_to_slack() {
	# Takes exit code as optional argument. Defaults to 1, with the effect of posting with `danger` color
	local my_ec=${1-1}
	local my_color="danger"
	if [ ! $my_ec -gt 0 ]; then
		my_color="good"
	fi
	if [ ! -z "$SLACK_WEBHOOK" ]; then
		echo 'SEV=WARN'
		echo "Posting to slack at $SLACK_WEBHOOK"
		# Get ahold of log for slack message
	       	MY_OUTPUT=$(cat LOGFILE)
		ESCAPED_MSG=$(echo "$MY_OUTPUT" | sed 's/"/\\"/g')
		JSON="{\"channel\": \"$CHANNEL\", \"username\": \"deployinator\", \"icon_emoji\": \":rocket:\", \"attachments\": [{\"color\": \"${my_color}\", \"text\": \"<!here> ${HOSTNAME}\n\`\`\`${ESCAPED_MSG}\`\`\`\"}]}"
		curl -s -S -w"\nSlack Response: Status %{http_code}, %{time_total} seconds, %{size_download} bytes\n" -d "payload=${JSON}" -XPOST "$SLACK_WEBHOOK" 2>&1
	else
		echo 'SEV=WARN'
		echo 'Not posting to Slack, no SLACK_WEBHOOK env var configured'
	fi
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
    --contexts=${LIQUIBASE_CONTEXTS} \
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
if [ -p "my_pipe" ]; then
	rm my_pipe
fi
mkfifo my_pipe

# Tee to stdout and capture in log file
tee -a LOGFILE < my_pipe | warnify &

# Ensure the schem exists
echo 'SEV=WARN'
echo '
**************************************************************
Ensure schema with psql
**************************************************************' | tee -a LOGFILE
ensure_schema > my_pipe
MY_EXIT_CODE=$?
wait
if [ $MY_EXIT_CODE -gt 0 ]; then
	post_to_slack
	exit $MY_EXIT_CODE
fi

echo 'SEV=WARN'
echo '
**************************************************************
Unexpected Change Set Overview:
**************************************************************' | tee -a LOGFILE

# Run diff status to see output of change sets to run
tee -a LOGFILE < my_pipe | warnify &
diff_unexpected > my_pipe
MY_EXIT_CODE=$?
wait
if [ $MY_EXIT_CODE -gt 0 ]; then
	post_to_slack
	exit $MY_EXIT_CODE
fi
wait

echo 'SEV=WARN'
echo '
**************************************************************
Change Set Overview:
**************************************************************' | tee -a LOGFILE

# Run diff status to see output of change sets to run
tee -a LOGFILE < my_pipe | warnify &
diff_status > my_pipe
MY_EXIT_CODE=$?
wait
if [ $MY_EXIT_CODE -gt 0 ]; then
	post_to_slack
	exit $MY_EXIT_CODE
fi

# Just log the update sql, don't put in log for slack message
echo 'SEV=WARN'
echo '
**************************************************************
Liquibase update SQL
**************************************************************'
update_sql | warnify

echo 'SEV=WARN'
echo '
**************************************************************
Liquibase run output:
**************************************************************' | tee -a LOGFILE
tee -a LOGFILE < my_pipe | warnify &

# Run the liquibase command through the pipe
run_liquibase > my_pipe
# Capture exit code of liquibase command
MY_EXIT_CODE=$?

wait

post_to_slack $MY_EXIT_CODE

if [ -x "/app/shutdown.sh" ]; then 	
	/app/shutdown.sh dev1 dbmigrators $SHUTDOWN_SERVICE
	MY_EXIT_CODE=$?
fi 

# Exit with the liquibase exit code
exit $MY_EXIT_CODE
