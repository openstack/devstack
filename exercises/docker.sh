#!/usr/bin/env bash

# **docker**

# Test Docker hypervisor

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

# Skip if the hypervisor is not Docker
[[ "$VIRT_DRIVER" == "docker" ]] || exit 55

# Import docker functions and declarations
source $TOP_DIR/lib/nova_plugins/hypervisor-docker

# Image and flavor are ignored but the CLI requires them...

# Instance type to create
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}

# Boot this image, use first AMI image if unset
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-ami}

# Instance name
VM_NAME=ex-docker


# Launching a server
# ==================

# Grab the id of the image to launch
IMAGE=$(glance image-list | egrep " $DOCKER_IMAGE_NAME:latest " | get_field 1)
die_if_not_set $LINENO IMAGE "Failure getting image $DOCKER_IMAGE_NAME"

# Select a flavor
INSTANCE_TYPE=$(nova flavor-list | grep $DEFAULT_INSTANCE_TYPE | get_field 1)
if [[ -z "$INSTANCE_TYPE" ]]; then
    # grab the first flavor in the list to launch if default doesn't exist
    INSTANCE_TYPE=$(nova flavor-list | head -n 4 | tail -n 1 | get_field 1)
fi

# Clean-up from previous runs
nova delete $VM_NAME || true
if ! timeout $ACTIVE_TIMEOUT sh -c "while nova show $VM_NAME; do sleep 1; done"; then
    die $LINENO "server didn't terminate!"
fi

# Boot instance
# -------------

VM_UUID=$(nova boot --flavor $INSTANCE_TYPE --image $IMAGE $VM_NAME | grep ' id ' | get_field 2)
die_if_not_set $LINENO VM_UUID "Failure launching $VM_NAME"

# Check that the status is active within ACTIVE_TIMEOUT seconds
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova show $VM_UUID | grep status | grep -q ACTIVE; do sleep 1; done"; then
    die $LINENO "server didn't become active!"
fi

# Get the instance IP
IP=$(nova show $VM_UUID | grep "$PRIVATE_NETWORK_NAME" | get_field 2)
die_if_not_set $LINENO IP "Failure retrieving IP address"

# Private IPs can be pinged in single node deployments
ping_check "$PRIVATE_NETWORK_NAME" $IP $BOOT_TIMEOUT

# Clean up
# --------

# Delete instance
nova delete $VM_UUID || die $LINENO "Failure deleting instance $VM_NAME"
if ! timeout $TERMINATE_TIMEOUT sh -c "while nova list | grep -q $VM_UUID; do sleep 1; done"; then
    die $LINENO "Server $VM_NAME not deleted"
fi

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"
