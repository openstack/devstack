#!/usr/bin/env bash

# **swift.sh**

# Test swift via the ``python-openstackclient`` command line

echo "*********************************************************************"
echo "Begin DevStack Exercise: $0"
echo "*********************************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following as the install occurs.
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
OBJECT=/etc/issue


# Testing Swift
# =============

# Check if we have to swift via keystone
openstack object store account show || die $LINENO "Failure getting account status"

# We start by creating a test container
openstack container create $CONTAINER || die $LINENO "Failure creating container $CONTAINER"

# add a file into it.
openstack object create $CONTAINER $OBJECT || die $LINENO "Failure uploading file to container $CONTAINER"

# list the objects
openstack object list $CONTAINER || die $LINENO "Failure listing contents of container $CONTAINER"

# delete the object first
openstack object delete $CONTAINER $OBJECT || die $LINENO "Failure deleting object $OBJECT in container $CONTAINER"

# delete the container
openstack container delete $CONTAINER || die $LINENO "Failure deleting container $CONTAINER"

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"
