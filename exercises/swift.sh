#!/usr/bin/env bash

# **swift.sh**

# Test swift via the ``swift`` command line from ``python-swiftclient``

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

# If swift is not enabled we exit with exitcode 55 which mean
# exercise is skipped.
is_service_enabled s-proxy || exit 55

# Container name
CONTAINER=ex-swift


# Testing Swift
# =============

# Check if we have to swift via keystone
swift stat || die $LINENO "Failure geting status"

# We start by creating a test container
swift post $CONTAINER || die $LINENO "Failure creating container $CONTAINER"

# add some files into it.
swift upload $CONTAINER /etc/issue || die $LINENO "Failure uploading file to container $CONTAINER"

# list them
swift list $CONTAINER || die $LINENO "Failure listing contents of container $CONTAINER"

# And we may want to delete them now that we have tested that
# everything works.
swift delete $CONTAINER || die $LINENO "Failure deleting container $CONTAINER"

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"
