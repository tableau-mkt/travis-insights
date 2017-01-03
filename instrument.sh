#!/bin/bash

# Exit quickly if we're missing expected environment variables.
if [[ -z $NR_ACCOUNT || -z $NR_INSERT_KEY ]]; then
  echo 'This build will not be logged to New Relic because of missing configuration.'
  echo 'Please export $NR_ACCOUNT and $NR_INSERT_KEY as secret/encrypted environment variables.'
  exit 0
fi

# Override the travis_assert bash function.
eval "$(echo "original_travis_assert()"; declare -f travis_assert | tail -n +2)"
travis_assert() {
  local result=${1:-$?}

  # Log the command to New Relic Insights.
  log_to_insights $result "Pre-Script"

  # Fire off the original travis assert method.
  original_travis_assert $result;
}

# Override the travis_result bash function.
eval "$(echo "original_travis_result()"; declare -f travis_result | tail -n +2)"
travis_result() {
  local result=$1
  export TRAVIS_TEST_RESULT=$(( ${TRAVIS_TEST_RESULT:-0} | $(($result != 0)) ))

  # Log the command to New Relic Insights.
  log_to_insights $result "Script"

  # Fire off the original travis result method.
  original_travis_result $result;
}

log_to_insights() {
  # Ping NR with all of the goodies.
  cat << JSON | curl -d @- -X POST -H "Content-Type: application/json" -H "X-Insert-Key: $NR_INSERT_KEY" https://insights-collector.newrelic.com/v1/accounts/$NR_ACCOUNT/events > /dev/null 2>&1 &
[{
  "eventType": "BuildCommand",
  "ExitCode": $1,
  "Command": "${TRAVIS_CMD//\"/}",
  "Time": $SECONDS,
  "Duration": $[$SECONDS-${LAST_TIME:-$SECONDS}],
  "Branch": "$TRAVIS_BRANCH",
  "BuildID": "$TRAVIS_BUILD_ID",
  "BuildNumber": "$TRAVIS_BUILD_NUMBER",
  "Commit": "$TRAVIS_COMMIT",
  "CommitRange": "$TRAVIS_COMMIT_RANGE",
  "BuildEvent": "$TRAVIS_EVENT_TYPE",
  "JobID": "$TRAVIS_JOB_ID",
  "JobNumber": "$TRAVIS_JOB_NUMBER",
  "BuildOS": "$TRAVIS_OS_NAME",
  "BuildSlug": "$TRAVIS_REPO_SLUG",
  "Tag": "$TRAVIS_TAG",
  "Phase": "$2"
}]
JSON

  export LAST_TIME=$SECONDS

  # If the result is non-zero, wait a moment before returning to give
  # NR a chance to pick up this last fail.
  if [ $result -ne 0 ]; then
    wait
  fi

}
