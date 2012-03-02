#!/usr/bin/env bash

# Test swift via the command line tools that ship with it.

echo "**************************************************"
echo "Begin DevStack Exercise: $0"
echo "**************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# Settings
# ========

# Use openrc + stackrc + localrc for settings
pushd $(cd $(dirname "$0")/.. && pwd) >/dev/null

# Import common functions
source ./functions

# Import configuration
source ./openrc
popd >/dev/null

# Container name
CONTAINER=ex-swift


# Testing Swift
# =============

# Check if we have to swift via keystone
swift stat
die_if_error "Failure geting status"

# We start by creating a test container
swift post $CONTAINER
die_if_error "Failure creating container $CONTAINER"

# add some files into it.
swift upload $CONTAINER /etc/issue
die_if_error "Failure uploading file to container $CONTAINER"

# list them
swift list $CONTAINER
die_if_error "Failure listing contents of container $CONTAINER"

# And we may want to delete them now that we have tested that
# everything works.
swift delete $CONTAINER
die_if_error "Failure deleting container $CONTAINER"

set +o xtrace
echo "**************************************************"
echo "End DevStack Exercise: $0"
echo "**************************************************"
