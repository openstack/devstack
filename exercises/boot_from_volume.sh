#!/usr/bin/env bash

# **boot_from_volume.sh**

# This script demonstrates how to boot from a volume.  It does the following:
#  *  Create a 'builder' instance
#  *  Attach a volume to the instance
#  *  Format and install an os onto the volume
#  *  Detach volume from builder, and then boot volume-backed instance

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

# Boot this image, use first AMI image if unset
DEFAULT_IMAGE_NAME=${DEFAULT_IMAGE_NAME:-ami}

# Instance type
DEFAULT_INSTANCE_TYPE=${DEFAULT_INSTANCE_TYPE:-m1.tiny}

# Default floating IP pool name
DEFAULT_FLOATING_POOL=${DEFAULT_FLOATING_POOL:-nova}

# Default user
DEFAULT_INSTANCE_USER=${DEFAULT_INSTANCE_USER:-cirros}

# Security group name
SECGROUP=${SECGROUP:-boot_secgroup}


# Launching servers
# =================

# Grab the id of the image to launch
IMAGE=`glance image-list | egrep " $DEFAULT_IMAGE_NAME " | get_field 1`
die_if_not_set IMAGE "Failure getting image"

# Instance and volume names
INSTANCE_NAME=${INSTANCE_NAME:-test_instance}
VOL_INSTANCE_NAME=${VOL_INSTANCE_NAME:-test_vol_instance}
VOL_NAME=${VOL_NAME:-test_volume}

# Clean-up from previous runs
nova delete $VOL_INSTANCE_NAME || true
nova delete $INSTANCE_NAME || true

# Wait till server is gone
if ! timeout $ACTIVE_TIMEOUT sh -c "while nova show $INSTANCE_NAME; do sleep 1; done"; then
    echo "server didn't terminate!"
    exit 1
fi

# Configure Security Groups
nova secgroup-delete $SECGROUP || true
nova secgroup-create $SECGROUP "$SECGROUP description"
nova secgroup-add-rule $SECGROUP icmp -1 -1 0.0.0.0/0
nova secgroup-add-rule $SECGROUP tcp 22 22 0.0.0.0/0

# Determinine instance type
INSTANCE_TYPE=`nova flavor-list | grep $DEFAULT_INSTANCE_TYPE | cut -d"|" -f2`
if [[ -z "$INSTANCE_TYPE" ]]; then
    # grab the first flavor in the list to launch if default doesn't exist
   INSTANCE_TYPE=`nova flavor-list | head -n 4 | tail -n 1 | cut -d"|" -f2`
fi

# Setup Keypair
KEY_NAME=test_key
KEY_FILE=key.pem
nova keypair-delete $KEY_NAME || true
nova keypair-add $KEY_NAME > $KEY_FILE
chmod 600 $KEY_FILE

# Boot our instance
VM_UUID=`nova boot --flavor $INSTANCE_TYPE --image $IMAGE --security_groups=$SECGROUP --key_name $KEY_NAME $INSTANCE_NAME | grep ' id ' | get_field 2`
die_if_not_set VM_UUID "Failure launching $INSTANCE_NAME"

# check that the status is active within ACTIVE_TIMEOUT seconds
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova show $VM_UUID | grep status | grep -q ACTIVE; do sleep 1; done"; then
    echo "server didn't become active!"
    exit 1
fi

# Delete the old volume
nova volume-delete $VOL_NAME || true

# Free every floating ips - setting FREE_ALL_FLOATING_IPS=True in localrc will make life easier for testers
if [ "$FREE_ALL_FLOATING_IPS" = "True" ]; then
    nova floating-ip-list | grep nova | cut -d "|" -f2 | tr -d " " | xargs -n1 nova floating-ip-delete || true
fi

# Allocate floating ip
FLOATING_IP=`nova floating-ip-create | grep $DEFAULT_FLOATING_POOL | get_field 1`

# Make sure the ip gets allocated
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! nova floating-ip-list | grep -q $FLOATING_IP; do sleep 1; done"; then
    echo "Floating IP not allocated"
    exit 1
fi

# Add floating ip to our server
nova add-floating-ip $VM_UUID $FLOATING_IP

# Test we can ping our floating ip within ASSOCIATE_TIMEOUT seconds
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! ping -c1 -w1 $FLOATING_IP; do sleep 1; done"; then
    echo "Couldn't ping server with floating ip"
    exit 1
fi

# Create our volume
nova volume-create --display_name=$VOL_NAME 1

# Wait for volume to activate
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME | grep available; do sleep 1; done"; then
    echo "Volume $VOL_NAME not created"
    exit 1
fi

# FIXME (anthony) - python-novaclient should accept a volume_name for the attachment param?
DEVICE=/dev/vdb
VOLUME_ID=`nova volume-list | grep $VOL_NAME  | get_field 1`
nova volume-attach $INSTANCE_NAME $VOLUME_ID $DEVICE

# Wait till volume is attached
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME | grep in-use; do sleep 1; done"; then
    echo "Volume $VOL_NAME not created"
    exit 1
fi

# The following script builds our bootable volume.
# To do this, ssh to the builder instance, mount volume, and build a volume-backed image.
STAGING_DIR=/tmp/stage
CIRROS_DIR=/tmp/cirros
ssh -o StrictHostKeyChecking=no -i $KEY_FILE ${DEFAULT_INSTANCE_USER}@$FLOATING_IP << EOF
set -o errexit
set -o xtrace
sudo mkdir -p $STAGING_DIR
sudo mkfs.ext3 -b 1024 $DEVICE 1048576
sudo mount $DEVICE $STAGING_DIR
# The following lines create a writable empty file so that we can scp
# the actual file
sudo touch $STAGING_DIR/cirros-0.3.0-x86_64-rootfs.img.gz
sudo chown cirros $STAGING_DIR/cirros-0.3.0-x86_64-rootfs.img.gz
EOF

# Download cirros
if [ ! -e cirros-0.3.0-x86_64-rootfs.img.gz ]; then
    wget http://images.ansolabs.com/cirros-0.3.0-x86_64-rootfs.img.gz
fi

# Copy cirros onto the volume
scp -o StrictHostKeyChecking=no -i $KEY_FILE cirros-0.3.0-x86_64-rootfs.img.gz ${DEFAULT_INSTANCE_USER}@$FLOATING_IP:$STAGING_DIR

# Unpack cirros into volume
ssh -o StrictHostKeyChecking=no -i $KEY_FILE ${DEFAULT_INSTANCE_USER}@$FLOATING_IP << EOF
set -o errexit
set -o xtrace
cd $STAGING_DIR
sudo mkdir -p $CIRROS_DIR
sudo gunzip cirros-0.3.0-x86_64-rootfs.img.gz
sudo mount cirros-0.3.0-x86_64-rootfs.img $CIRROS_DIR

# Copy cirros into our volume
sudo cp -pr $CIRROS_DIR/* $STAGING_DIR/

cd
sync
sudo umount $CIRROS_DIR
# The following typically fails.  Don't know why.
sudo umount $STAGING_DIR || true
EOF

# Detach the volume from the builder instance
nova volume-detach $INSTANCE_NAME $VOLUME_ID

# Boot instance from volume!  This is done with the --block_device_mapping param.
# The format of mapping is:
# <dev_name>=<id>:<type>:<size(GB)>:<delete_on_terminate>
# Leaving the middle two fields blank appears to do-the-right-thing
VOL_VM_UUID=`nova boot --flavor $INSTANCE_TYPE --image $IMAGE --block_device_mapping vda=$VOLUME_ID:::0 --security_groups=$SECGROUP --key_name $KEY_NAME $VOL_INSTANCE_NAME | grep ' id ' | get_field 2`
die_if_not_set VOL_VM_UUID "Failure launching $VOL_INSTANCE_NAME"

# Check that the status is active within ACTIVE_TIMEOUT seconds
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova show $VOL_VM_UUID | grep status | grep -q ACTIVE; do sleep 1; done"; then
    echo "server didn't become active!"
    exit 1
fi

# Add floating ip to our server
nova remove-floating-ip $VM_UUID $FLOATING_IP

# Gratuitous sleep, probably hiding a race condition :/
sleep 1

# Add floating ip to our server
nova add-floating-ip $VOL_VM_UUID $FLOATING_IP

# Test we can ping our floating ip within ASSOCIATE_TIMEOUT seconds
if ! timeout $ASSOCIATE_TIMEOUT sh -c "while ! ping -c1 -w1 $FLOATING_IP; do sleep 1; done"; then
    echo "Couldn't ping volume-backed server with floating ip"
    exit 1
fi

# Make sure our volume-backed instance launched
ssh -o StrictHostKeyChecking=no -i $KEY_FILE ${DEFAULT_INSTANCE_USER}@$FLOATING_IP << EOF
echo "success!"
EOF

# Delete volume backed instance
nova delete $VOL_INSTANCE_NAME || \
    die "Failure deleting instance volume $VOL_INSTANCE_NAME"

# Wait till our volume is no longer in-use
if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova volume-list | grep $VOL_NAME | grep available; do sleep 1; done"; then
    echo "Volume $VOL_NAME not created"
    exit 1
fi

# Delete the volume
nova volume-delete $VOL_NAME || \
    die "Failure deleting volume $VOLUME_NAME"

# Delete instance
nova delete $INSTANCE_NAME || \
    die "Failure deleting instance $INSTANCE_NAME"

# Wait for termination
if ! timeout $TERMINATE_TIMEOUT sh -c "while nova list | grep -q $VM_UUID; do sleep 1; done"; then
    echo "Server $NAME not deleted"
    exit 1
fi

# De-allocate the floating ip
nova floating-ip-delete $FLOATING_IP || \
    die "Failure deleting floating IP $FLOATING_IP"

# Delete a secgroup
nova secgroup-delete $SECGROUP || die "Failure deleting security group $SECGROUP"

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"
