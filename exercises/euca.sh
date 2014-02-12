#!/usr/bin/env bash

# **euca.sh**

# we will use the ``euca2ools`` cli tool that wraps the python boto
# library to test ec2 compatibility

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
VOLUME_SIZE=1
ATTACH_DEVICE=/dev/vdc

# Import common functions
source $TOP_DIR/functions

# Import EC2 configuration
source $TOP_DIR/eucarc

# Import exercise configuration
source $TOP_DIR/exerciserc

# If nova api is not enabled we exit with exitcode 55 so that
# the exercise is skipped
is_service_enabled n-api || exit 55

# Skip if the hypervisor is Docker
[[ "$VIRT_DRIVER" == "docker" ]] && exit 55

# Instance type to create
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}

# Boot this image, use first AMI image if unset
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-ami}

# Security group name
SECGROUP=${SECGROUP:-euca_secgroup}


# Launching a server
# ==================

# Find a machine image to boot
IMAGE=`euca-describe-images | grep machine | grep ${DEFAULT_IMAGE_NAME} | cut -f2 | head -n1`
die_if_not_set $LINENO IMAGE "Failure getting image $DEFAULT_IMAGE_NAME"

if is_service_enabled n-cell; then
    # Cells does not support security groups, so force the use of "default"
    SECGROUP="default"
    echo "Using the default security group because of Cells."
else
    # Add a secgroup
    if ! euca-describe-groups | grep -q $SECGROUP; then
        euca-add-group -d "$SECGROUP description" $SECGROUP
        if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! euca-describe-groups | grep -q $SECGROUP; do sleep 1; done"; then
            die $LINENO "Security group not created"
        fi
    fi
fi

# Launch it
INSTANCE=`euca-run-instances -g $SECGROUP -t $DEFAULT_INSTANCE_TYPE $IMAGE | grep INSTANCE | cut -f2`
die_if_not_set $LINENO INSTANCE "Failure launching instance"

# Assure it has booted within a reasonable time
if ! timeout $RUNNING_TIMEOUT sh -c "while ! euca-describe-instances $INSTANCE | grep -q running; do sleep 1; done"; then
    die $LINENO "server didn't become active within $RUNNING_TIMEOUT seconds"
fi

# Volumes
# -------
if is_service_enabled c-vol && ! is_service_enabled n-cell; then
    VOLUME_ZONE=`euca-describe-availability-zones | head -n1 | cut -f2`
    die_if_not_set $LINENO VOLUME_ZONE "Failure to find zone for volume"

    VOLUME=`euca-create-volume -s 1 -z $VOLUME_ZONE | cut -f2`
    die_if_not_set $LINENO VOLUME "Failure to create volume"

    # Test that volume has been created
    VOLUME=`euca-describe-volumes $VOLUME | cut -f2`
    die_if_not_set $LINENO VOLUME "Failure to get volume"

    # Test volume has become available
    if ! timeout $RUNNING_TIMEOUT sh -c "while ! euca-describe-volumes $VOLUME | grep -q available; do sleep 1; done"; then
        die $LINENO "volume didn't become available within $RUNNING_TIMEOUT seconds"
    fi

    # Attach volume to an instance
    euca-attach-volume -i $INSTANCE -d $ATTACH_DEVICE $VOLUME || \
        die $LINENO "Failure attaching volume $VOLUME to $INSTANCE"
    if ! timeout $ACTIVE_TIMEOUT sh -c "while ! euca-describe-volumes $VOLUME | grep -A 1 in-use | grep -q attach; do sleep 1; done"; then
        die $LINENO "Could not attach $VOLUME to $INSTANCE"
    fi

    # Detach volume from an instance
    euca-detach-volume $VOLUME || \
        die $LINENO "Failure detaching volume $VOLUME to $INSTANCE"
    if ! timeout $ACTIVE_TIMEOUT sh -c "while ! euca-describe-volumes $VOLUME | grep -q available; do sleep 1; done"; then
        die $LINENO "Could not detach $VOLUME to $INSTANCE"
    fi

    # Remove volume
    euca-delete-volume $VOLUME || \
        die $LINENO "Failure to delete volume"
    if ! timeout $ACTIVE_TIMEOUT sh -c "while euca-describe-volumes | grep $VOLUME; do sleep 1; done"; then
        die $LINENO "Could not delete $VOLUME"
    fi
else
    echo "Volume Tests Skipped"
fi

if is_service_enabled n-cell; then
    echo "Floating IP Tests Skipped because of Cells."
else
    # Allocate floating address
    FLOATING_IP=`euca-allocate-address | cut -f2`
    die_if_not_set $LINENO FLOATING_IP "Failure allocating floating IP"
    # describe all instances at this moment
    euca-describe-instances
    # Associate floating address
    euca-associate-address -i $INSTANCE $FLOATING_IP || \
        die $LINENO "Failure associating address $FLOATING_IP to $INSTANCE"

    # Authorize pinging
    euca-authorize -P icmp -s 0.0.0.0/0 -t -1:-1 $SECGROUP || \
        die $LINENO "Failure authorizing rule in $SECGROUP"

    # Test we can ping our floating ip within ASSOCIATE_TIMEOUT seconds
    ping_check "$PUBLIC_NETWORK_NAME" $FLOATING_IP $ASSOCIATE_TIMEOUT

    # Revoke pinging
    euca-revoke -P icmp -s 0.0.0.0/0 -t -1:-1 $SECGROUP || \
        die $LINENO "Failure revoking rule in $SECGROUP"

    # Release floating address
    euca-disassociate-address $FLOATING_IP || \
        die $LINENO "Failure disassociating address $FLOATING_IP"

    # Wait just a tick for everything above to complete so release doesn't fail
    if ! timeout $ASSOCIATE_TIMEOUT sh -c "while euca-describe-addresses | grep $INSTANCE | grep -q $FLOATING_IP; do sleep 1; done"; then
        die $LINENO "Floating ip $FLOATING_IP not disassociated within $ASSOCIATE_TIMEOUT seconds"
    fi

    # Release floating address
    euca-release-address $FLOATING_IP || \
        die $LINENO "Failure releasing address $FLOATING_IP"

    # Wait just a tick for everything above to complete so terminate doesn't fail
    if ! timeout $ASSOCIATE_TIMEOUT sh -c "while euca-describe-addresses | grep -q $FLOATING_IP; do sleep 1; done"; then
        die $LINENO "Floating ip $FLOATING_IP not released within $ASSOCIATE_TIMEOUT seconds"
    fi
fi

# Terminate instance
euca-terminate-instances $INSTANCE || \
    die $LINENO "Failure terminating instance $INSTANCE"

# Assure it has terminated within a reasonable time. The behaviour of this
# case changed with bug/836978. Requesting the status of an invalid instance
# will now return an error message including the instance id, so we need to
# filter that out.
if ! timeout $TERMINATE_TIMEOUT sh -c "while euca-describe-instances $INSTANCE | grep -ve '\(InstanceNotFound\|InvalidInstanceID\.NotFound\)' | grep -q $INSTANCE; do sleep 1; done"; then
    die $LINENO "server didn't terminate within $TERMINATE_TIMEOUT seconds"
fi

if [[ "$SECGROUP" = "default" ]] ; then
    echo "Skipping deleting default security group"
else
    # Delete secgroup
    euca-delete-group $SECGROUP || die $LINENO "Failure deleting security group $SECGROUP"
fi

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"
