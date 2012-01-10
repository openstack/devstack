#!/usr/bin/env bash

# we will use the ``euca2ools`` cli tool that wraps the python boto
# library to test ec2 compatibility
#

# This script exits on an error so that errors don't compound and you see
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# Settings
# ========

# Use openrc + stackrc + localrc for settings
pushd $(cd $(dirname "$0")/.. && pwd)
source ./openrc
popd

# Max time to wait while vm goes from build to active state
ACTIVE_TIMEOUT=${ACTIVE_TIMEOUT:-30}

# Max time till the vm is bootable
BOOT_TIMEOUT=${BOOT_TIMEOUT:-30}

# Max time to wait for proper association and dis-association.
ASSOCIATE_TIMEOUT=${ASSOCIATE_TIMEOUT:-15}

# Instance type to create
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}

# Find a machine image to boot
IMAGE=`euca-describe-images | grep machine | cut -f2 | head -n1`

# Define secgroup
SECGROUP=euca_secgroup

# Add a secgroup
if ! euca-describe-group | grep -q $SECGROUP; then
    euca-add-group -d "$SECGROUP description" $SECGROUP
    if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! euca-describe-group | grep -q $SECGROUP; do sleep 1; done"; then
        echo "Security group not created"
        exit 1
    fi
fi

# Launch it
INSTANCE=`euca-run-instances -g $SECGROUP -t $DEFAULT_INSTANCE_TYPE $IMAGE | grep INSTANCE | cut -f2`

# Assure it has booted within a reasonable time
if ! timeout $RUNNING_TIMEOUT sh -c "while ! euca-describe-instances $INSTANCE | grep -q running; do sleep 1; done"; then
    echo "server didn't become active within $RUNNING_TIMEOUT seconds"
    exit 1
fi

# Allocate floating address
FLOATING_IP=`euca-allocate-address | cut -f2`

# Associate floating address
euca-associate-address -i $INSTANCE $FLOATING_IP

# Authorize pinging
euca-authorize -P icmp -s 0.0.0.0/0 -t -1:-1 $SECGROUP

# Test we can ping our floating ip within ASSOCIATE_TIMEOUT seconds
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! ping -c1 -w1 $FLOATING_IP; do sleep 1; done"; then
    echo "Couldn't ping server with floating ip"
    exit 1
fi

# Revoke pinging
euca-revoke -P icmp -s 0.0.0.0/0 -t -1:-1 $SECGROUP

# Delete group
euca-delete-group $SECGROUP

# Release floating address
euca-disassociate-address $FLOATING_IP

# Wait just a tick for everything above to complete so release doesn't fail
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while euca-describe-addresses | grep $INSTANCE | grep -q $FLOATING_IP; do sleep 1; done"; then
    echo "Floating ip $FLOATING_IP not disassociated within $ASSOCIATE_TIMEOUT seconds"
    exit 1
fi

# Release floating address
euca-release-address $FLOATING_IP

# Wait just a tick for everything above to complete so terminate doesn't fail
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while euca-describe-addresses | grep -q $FLOATING_IP; do sleep 1; done"; then
    echo "Floating ip $FLOATING_IP not released within $ASSOCIATE_TIMEOUT seconds"
    exit 1
fi

# Terminate instance
euca-terminate-instances $INSTANCE
