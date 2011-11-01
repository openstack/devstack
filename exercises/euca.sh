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
source ./openrc

# Max time till the vm is bootable
BOOT_TIMEOUT=${BOOT_TIMEOUT:-15}

# find a machine image to boot
IMAGE=`euca-describe-images | grep machine | cut -f2`

# launch it
INSTANCE=`euca-run-instance $IMAGE | grep INSTANCE | cut -f2`

# assure it has booted within a reasonable time
if ! timeout $BOOT_TIMEOUT sh -c "while euca-describe-instances $INSTANCE | grep -q running; do sleep 1; done"; then
    echo "server didn't become active within $BOOT_TIMEOUT seconds"
    exit 1
fi

euca-terminate-instances $INSTANCE
