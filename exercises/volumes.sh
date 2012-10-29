#!/usr/bin/env bash

# **volumes.sh**

# Test nova volumes with the nova command from python-novaclient

echo "*********************************************************************"
echo "Begin DevStack Exercise: $0"
echo "*********************************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occured.
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

# Import quantum functions if needed
if is_service_enabled quantum; then
    source $TOP_DIR/lib/quantum
    setup_quantum
fi

# Import exercise configuration
source $TOP_DIR/exerciserc

# If cinder or n-vol are not enabled we exit with exitcode 55 which mean
# exercise is skipped.
is_service_enabled cinder n-vol || exit 55

# Instance type to create
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}

# Boot this image, use first AMi image if unset
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-ami}

# Security group name
SECGROUP=${SECGROUP:-vol_secgroup}


# Launching a server
# ==================

# List servers for tenant:
nova list

# Images
# ------

# Nova has a **deprecated** way of listing images.
nova image-list

# But we recommend using glance directly
glance image-list

# Grab the id of the image to launch
IMAGE=$(glance image-list | egrep " $DEFAULT_IMAGE_NAME " | get_field 1)

# Security Groups
# ---------------

# List of secgroups:
nova secgroup-list

# Create a secgroup
if ! nova secgroup-list | grep -q $SECGROUP; then
    nova secgroup-create $SECGROUP "$SECGROUP description"
    if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! nova secgroup-list | grep -q $SECGROUP; do sleep 1; done"; then
        echo "Security group not created"
        exit 1
    fi
fi

# Configure Security Group Rules
nova secgroup-add-rule $SECGROUP icmp -1 -1 0.0.0.0/0
nova secgroup-add-rule $SECGROUP tcp 22 22 0.0.0.0/0

# determinine instance type
# -------------------------

# List of instance types:
nova flavor-list

INSTANCE_TYPE=`nova flavor-list | grep $DEFAULT_INSTANCE_TYPE | get_field 1`
if [[ -z "$INSTANCE_TYPE" ]]; then
    # grab the first flavor in the list to launch if default doesn't exist
   INSTANCE_TYPE=`nova flavor-list | head -n 4 | tail -n 1 | get_field 1`
fi

NAME="ex-vol"

VM_UUID=`nova boot --flavor $INSTANCE_TYPE --image $IMAGE $NAME --security_groups=$SECGROUP | grep ' id ' | get_field 2`
die_if_not_set VM_UUID "Failure launching $NAME"


# Testing
# =======

# First check if it spins up (becomes active and responds to ping on
# internal ip).  If you run this script from a nova node, you should
# bypass security groups and have direct access to the server.

# Waiting for boot
# ----------------

# check that the status is active within ACTIVE_TIMEOUT seconds
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova show $VM_UUID | grep status | grep -q ACTIVE; do sleep 1; done"; then
    echo "server didn't become active!"
    exit 1
fi

# get the IP of the server
IP=`nova show $VM_UUID | grep "$PRIVATE_NETWORK_NAME" | get_field 2`
die_if_not_set IP "Failure retrieving IP address"

# for single node deployments, we can ping private ips
ping_check "$PRIVATE_NETWORK_NAME" $IP $BOOT_TIMEOUT

# Volumes
# -------

VOL_NAME="myvol-$(openssl rand -hex 4)"

# Verify it doesn't exist
if [[ -n "`nova volume-list | grep $VOL_NAME | head -1 | get_field 2`" ]]; then
    echo "Volume $VOL_NAME already exists"
    exit 1
fi

# Create a new volume
nova volume-create --display_name $VOL_NAME --display_description "test volume: $VOL_NAME" 1
if [[ $? != 0 ]]; then
    echo "Failure creating volume $VOL_NAME"
    exit 1
fi

start_time=`date +%s`
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME | grep available; do sleep 1; done"; then
    echo "Volume $VOL_NAME not created"
    exit 1
fi
end_time=`date +%s`
echo "Completed volume-create in $((end_time - start_time)) seconds"

# Get volume ID
VOL_ID=`nova volume-list | grep $VOL_NAME | head -1 | get_field 1`
die_if_not_set VOL_ID "Failure retrieving volume ID for $VOL_NAME"

# Attach to server
DEVICE=/dev/vdb
start_time=`date +%s`
nova volume-attach $VM_UUID $VOL_ID $DEVICE || \
    die "Failure attaching volume $VOL_NAME to $NAME"
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME | grep in-use; do sleep 1; done"; then
    echo "Volume $VOL_NAME not attached to $NAME"
    exit 1
fi
end_time=`date +%s`
echo "Completed volume-attach in $((end_time - start_time)) seconds"

VOL_ATTACH=`nova volume-list | grep $VOL_NAME | head -1 | get_field -1`
die_if_not_set VOL_ATTACH "Failure retrieving $VOL_NAME status"
if [[ "$VOL_ATTACH" != $VM_UUID ]]; then
    echo "Volume not attached to correct instance"
    exit 1
fi

# Detach volume
start_time=`date +%s`
nova volume-detach $VM_UUID $VOL_ID || die "Failure detaching volume $VOL_NAME from $NAME"
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME | grep available; do sleep 1; done"; then
    echo "Volume $VOL_NAME not detached from $NAME"
    exit 1
fi
end_time=`date +%s`
echo "Completed volume-detach in $((end_time - start_time)) seconds"

# Delete volume
start_time=`date +%s`
nova volume-delete $VOL_ID || die "Failure deleting volume $VOL_NAME"
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME; do sleep 1; done"; then
    echo "Volume $VOL_NAME not deleted"
    exit 1
fi
end_time=`date +%s`
echo "Completed volume-delete in $((end_time - start_time)) seconds"

# Shutdown the server
nova delete $VM_UUID || die "Failure deleting instance $NAME"

# Wait for termination
if ! timeout $TERMINATE_TIMEOUT sh -c "while nova list | grep -q $VM_UUID; do sleep 1; done"; then
    echo "Server $NAME not deleted"
    exit 1
fi

# Delete a secgroup
nova secgroup-delete $SECGROUP || die "Failure deleting security group $SECGROUP"

if is_service_enabled quantum; then
    teardown_quantum
fi

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"
