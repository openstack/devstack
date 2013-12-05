#!/usr/bin/env bash

# **marconi.sh**

# Sanity check that Marconi started if enabled

echo "*********************************************************************"
echo "Begin DevStack Exercise: $0"
echo "*********************************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# Settings
# ========

# Keep track of the current directory
EXERCISE_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $EXERCISE_DIR/..; pwd)

# Import common functions
source $TOP_DIR/functions

# Import configuration
source $TOP_DIR/openrc

# Import exercise configuration
source $TOP_DIR/exerciserc

is_service_enabled marconi-server || exit 55

curl http://$SERVICE_HOST:8888/v1/ 2>/dev/null | grep -q 'Auth' || die $LINENO "Marconi API not functioning!"

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"
