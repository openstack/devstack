#!/usr/bin/env bash

# **exercise.sh** - using the cloud can be fun

# we will use the ``nova`` cli tool provided by the ``python-novaclient``
# package
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

# Boot this image, use first AMi image if unset
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-ami}

# Security group name
SECGROUP=${SECGROUP:-test_secgroup}

# Default floating IP pool name
DEFAULT_FLOATING_POOL=${DEFAULT_FLOATING_POOL:-nova}

# Additional floating IP pool and range
TEST_FLOATING_POOL=${TEST_FLOATING_POOL:-test}

# Get a token for clients that don't support service catalog
# ==========================================================

# manually create a token by querying keystone (sending JSON data).  Keystone
# returns a token and catalog of endpoints.  We use python to parse the token
# and save it.

TOKEN=`curl -s -d  "{\"auth\":{\"passwordCredentials\": {\"username\": \"$NOVA_USERNAME\", \"password\": \"$NOVA_PASSWORD\"}}}" -H "Content-type: application/json" http://$HOST_IP:5000/v2.0/tokens | python -c "import sys; import json; tok = json.loads(sys.stdin.read()); print tok['access']['token']['id'];"`

# Launching a server
# ==================

# List servers for tenant:
nova list

# Images
# ------

# Nova has a **deprecated** way of listing images.
nova image-list

# But we recommend using glance directly
glance -f -A $TOKEN -H $GLANCE_HOST index

# Grab the id of the image to launch
IMAGE=`glance -f -A $TOKEN -H $GLANCE_HOST index | egrep $DEFAULT_IMAGE_NAME | head -1 | cut -d" " -f1`

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

# determinine instance type
# -------------------------

# List of instance types:
nova flavor-list

INSTANCE_TYPE=`nova flavor-list | grep $DEFAULT_INSTANCE_TYPE | cut -d"|" -f2`
if [[ -z "$INSTANCE_TYPE" ]]; then
    # grab the first flavor in the list to launch if default doesn't exist
   INSTANCE_TYPE=`nova flavor-list | head -n 4 | tail -n 1 | cut -d"|" -f2`
fi

NAME="myserver"

VM_UUID=`nova boot --flavor $INSTANCE_TYPE --image $IMAGE $NAME --security_groups=$SECGROUP | grep ' id ' | cut -d"|" -f3 | sed 's/ //g'`

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
IP=`nova show $VM_UUID | grep "private network" | cut -d"|" -f3`

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

# Security Groups & Floating IPs
# ------------------------------

if ! nova secgroup-list-rules $SECGROUP | grep -q icmp; then
    # allow icmp traffic (ping)
    nova secgroup-add-rule $SECGROUP icmp -1 -1 0.0.0.0/0
    if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! nova secgroup-list-rules $SECGROUP | grep -q icmp; do sleep 1; done"; then
        echo "Security group rule not created"
        exit 1
    fi
fi

# List rules for a secgroup
nova secgroup-list-rules $SECGROUP

# allocate a floating ip from default pool
FLOATING_IP=`nova floating-ip-create | grep $DEFAULT_FLOATING_POOL | cut -d '|' -f2`

# list floating addresses
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! nova floating-ip-list | grep -q $FLOATING_IP; do sleep 1; done"; then
    echo "Floating IP not allocated"
    exit 1
fi

# add floating ip to our server
nova add-floating-ip $VM_UUID $FLOATING_IP

# test we can ping our floating ip within ASSOCIATE_TIMEOUT seconds
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! ping -c1 -w1 $FLOATING_IP; do sleep 1; done"; then
    echo "Couldn't ping server with floating ip"
    exit 1
fi

# Allocate an IP from second floating pool
TEST_FLOATING_IP=`nova floating-ip-create $TEST_FLOATING_POOL | grep $TEST_FLOATING_POOL | cut -d '|' -f2`

# list floating addresses
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! nova floating-ip-list | grep $TEST_FLOATING_POOL | grep -q $TEST_FLOATING_IP; do sleep 1; done"; then
    echo "Floating IP not allocated"
    exit 1
fi

# dis-allow icmp traffic (ping)
nova secgroup-delete-rule $SECGROUP icmp -1 -1 0.0.0.0/0

# FIXME (anthony): make xs support security groups
if [ "$VIRT_DRIVER" != "xenserver" ]; then
    # test we can aren't able to ping our floating ip within ASSOCIATE_TIMEOUT seconds
    if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ping -c1 -w1 $FLOATING_IP; do sleep 1; done"; then
        print "Security group failure - ping should not be allowed!"
        echo "Couldn't ping server with floating ip"
        exit 1
    fi
fi

# de-allocate the floating ip
nova floating-ip-delete $FLOATING_IP

# Delete second floating IP
nova floating-ip-delete $TEST_FLOATING_IP

# shutdown the server
nova delete $VM_UUID

# Delete a secgroup
nova secgroup-delete $SECGROUP

# FIXME: validate shutdown within 5 seconds
# (nova show $NAME returns 1 or status != ACTIVE)?
