#!/bin/bash
# fake-service.sh - a fake service for start/stop testing
# $1 - sleep time

SLEEP_TIME=${1:-3}

LOG=/tmp/fake-service.log
TIMESTAMP_FORMAT=${TIMESTAMP_FORMAT:-"%F-%H%M%S"}

# duplicate output
exec 1> >(tee -a ${LOG})

echo ""
echo "Starting fake-service for ${SLEEP_TIME}"
while true; do
    echo "$(date +${TIMESTAMP_FORMAT}) [$$]"
    sleep ${SLEEP_TIME}
done

