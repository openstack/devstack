#!/usr/bin/env bash

# **floating_ips.sh** - using the cloud can be fun

# we will use the ``nova`` cli tool provided by the ``python-novaclient``
# package to work out the instance connectivity

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

# Import exercise configuration
source $TOP_DIR/exerciserc

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

# Determinine instance type
# -------------------------

# List of instance types:
nova flavor-list

INSTANCE_TYPE=`nova flavor-list | grep $DEFAULT_INSTANCE_TYPE | get_field 1`
if [[ -z "$INSTANCE_TYPE" ]]; then
    # grab the first flavor in the list to launch if default doesn't exist
   INSTANCE_TYPE=`nova flavor-list | head -n 4 | tail -n 1 | get_field 1`
fi

NAME="ex-float"

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
IP=`nova show $VM_UUID | grep "private network" | get_field 2`
die_if_not_set IP "Failure retrieving IP address"

# for single node deployments, we can ping private ips
MULTI_HOST=`trueorfalse False $MULTI_HOST`
if [ "$MULTI_HOST" = "False" ]; then
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
FLOATING_IP=`nova floating-ip-create | grep $DEFAULT_FLOATING_POOL | get_field 1`
die_if_not_set FLOATING_IP "Failure creating floating IP"

# list floating addresses
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! nova floating-ip-list | grep -q $FLOATING_IP; do sleep 1; done"; then
    echo "Floating IP not allocated"
    exit 1
fi

# add floating ip to our server
nova add-floating-ip $VM_UUID $FLOATING_IP || \
    die "Failure adding floating IP $FLOATING_IP to $NAME"

# test we can ping our floating ip within ASSOCIATE_TIMEOUT seconds
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! ping -c1 -w1 $FLOATING_IP; do sleep 1; done"; then
    echo "Couldn't ping server with floating ip"
    exit 1
fi

# Allocate an IP from second floating pool
TEST_FLOATING_IP=`nova floating-ip-create $TEST_FLOATING_POOL | grep $TEST_FLOATING_POOL | get_field 1`
die_if_not_set TEST_FLOATING_IP "Failure creating floating IP in $TEST_FLOATING_POOL"

# list floating addresses
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! nova floating-ip-list | grep $TEST_FLOATING_POOL | grep -q $TEST_FLOATING_IP; do sleep 1; done"; then
    echo "Floating IP not allocated"
    exit 1
fi

# dis-allow icmp traffic (ping)
nova secgroup-delete-rule $SECGROUP icmp -1 -1 0.0.0.0/0 || die "Failure deleting security group rule from $SECGROUP"

# FIXME (anthony): make xs support security groups
if [ "$VIRT_DRIVER" != "xenserver" -a "$VIRT_DRIVER" != "openvz" ]; then
    # test we can aren't able to ping our floating ip within ASSOCIATE_TIMEOUT seconds
    if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ping -c1 -w1 $FLOATING_IP; do sleep 1; done"; then
        print "Security group failure - ping should not be allowed!"
        echo "Couldn't ping server with floating ip"
        exit 1
    fi
fi

# de-allocate the floating ip
nova floating-ip-delete $FLOATING_IP || die "Failure deleting floating IP $FLOATING_IP"

# Delete second floating IP
nova floating-ip-delete $TEST_FLOATING_IP || die "Failure deleting floating IP $TEST_FLOATING_IP"

# Shutdown the server
nova delete $VM_UUID || die "Failure deleting instance $NAME"

# Wait for termination
if ! timeout $TERMINATE_TIMEOUT sh -c "while nova list | grep -q $VM_UUID; do sleep 1; done"; then
    echo "Server $NAME not deleted"
    exit 1
fi

# Delete a secgroup
nova secgroup-delete $SECGROUP || die "Failure deleting security group $SECGROUP"

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"
