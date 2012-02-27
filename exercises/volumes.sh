#!/usr/bin/env bash

# Test nova volumes with the nova command from python-novaclient

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

# Boot this image, use first AMi image if unset
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-ami}

# Launching a server
# ==================

# List servers for tenant:
nova list

# Images
# ------

# Nova has a **deprecated** way of listing images.
nova image-list

# But we recommend using glance directly
glance -f index

# Grab the id of the image to launch
IMAGE=`glance -f index | egrep $DEFAULT_IMAGE_NAME | head -1 | cut -d" " -f1`

# determinine instance type
# -------------------------

# Helper function to grab a numbered field from python novaclient cli result
# Fields are numbered starting with 1
# Reverse syntax is supported: -1 is the last field, -2 is second to last, etc.
function get_field () {
    while read data
    do
        if [ "$1" -lt 0 ]; then
            field="(\$(NF$1))"
        else
            field="\$$(($1 + 1))"
        fi
        echo "$data" | awk -F'[ \t]*\\|[ \t]*' "{print $field}"
    done
}

# List of instance types:
nova flavor-list

INSTANCE_TYPE=`nova flavor-list | grep $DEFAULT_INSTANCE_TYPE | get_field 1`
if [[ -z "$INSTANCE_TYPE" ]]; then
    # grab the first flavor in the list to launch if default doesn't exist
   INSTANCE_TYPE=`nova flavor-list | head -n 4 | tail -n 1 | get_field 1`
fi

NAME="myserver"

VM_UUID=`nova boot --flavor $INSTANCE_TYPE --image $IMAGE $NAME --security_groups=$SECGROUP | grep ' id ' | get_field 2`

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
IP=`nova show $VM_UUID | grep "private network" | get_field 2`

# for single node deployments, we can ping private ips
MULTI_HOST=${MULTI_HOST:-0}
if [ "$MULTI_HOST" = "0" ]; then
    # sometimes the first ping fails (10 seconds isn't enough time for the VM's
    # network to respond?), so let's ping for a default of 15 seconds with a
    # timeout of a second for each ping.
    if ! timeout $BOOT_TIMEOUT sh -c "while ! ping -c1 -w1 $IP; do sleep 1; done"; then
        echo "Couldn't ping server"
        exit 1
    fi
else
    # On a multi-host system, without vm net access, do a sleep to wait for the boot
    sleep $BOOT_TIMEOUT
fi

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
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME | grep available; do sleep 1; done"; then
    echo "Volume $VOL_NAME not created"
    exit 1
fi

# Get volume ID
VOL_ID=`nova volume-list | grep $VOL_NAME | head -1 | get_field 1`

# Attach to server
DEVICE=/dev/vdb
nova volume-attach $VM_UUID $VOL_ID $DEVICE
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME | grep in-use; do sleep 1; done"; then
    echo "Volume $VOL_NAME not attached to $NAME"
    exit 1
fi

VOL_ATTACH=`nova volume-list | grep $VOL_NAME | head -1 | get_field -1`
if [[ "$VOL_ATTACH" != $VM_UUID ]]; then
    echo "Volume not attached to correct instance"
    exit 1
fi

# Detach volume
nova volume-detach $VM_UUID $VOL_ID
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME | grep available; do sleep 1; done"; then
    echo "Volume $VOL_NAME not detached from $NAME"
    exit 1
fi

# Delete volume
nova volume-delete $VOL_ID
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME; do sleep 1; done"; then
    echo "Volume $VOL_NAME not deleted"
    exit 1
fi

# shutdown the server
nova delete $NAME
