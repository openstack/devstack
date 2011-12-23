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

# Find a machine image to boot
IMAGE=`euca-describe-images | grep machine | cut -f2 | head -n1`

# Define secgroup
SECGROUP=euca_secgroup

# Add a secgroup
euca-add-group -d description $SECGROUP

# Launch it
INSTANCE=`euca-run-instances -g $SECGROUP -t m1.tiny $IMAGE | grep INSTANCE | cut -f2`

# Assure it has booted within a reasonable time
if ! timeout $RUNNING_TIMEOUT sh -c "while euca-describe-instances $INSTANCE | grep -q running; do sleep 1; done"; then
    echo "server didn't become active within $RUNNING_TIMEOUT seconds"
    exit 1
fi

# Allocate floating address
FLOATING_IP=`euca-allocate-address | cut -f2`

# Release floating address
euca-associate-address -i $INSTANCE $FLOATING_IP


# Authorize pinging
euca-authorize -P icmp -s 0.0.0.0/0 -t -1:-1 $SECGROUP

# Max time till the vm is bootable
BOOT_TIMEOUT=${BOOT_TIMEOUT:-15}
if ! timeout $BOOT_TIMEOUT sh -c "while ! ping -c1 -w1 $FLOATING_IP; do sleep 1; done"; then
    echo "Couldn't ping server"
    exit 1
fi

# Revoke pinging
euca-revoke -P icmp -s 0.0.0.0/0 -t -1:-1 $SECGROUP

# Delete group
euca-delete-group $SECGROUP

# Release floating address
euca-disassociate-address $FLOATING_IP

# Release floating address
euca-release-address $FLOATING_IP

# Terminate instance
euca-terminate-instances $INSTANCE
