#!/usr/bin/env bash

# **copy_dev_environment_to_uec.sh**

# Echo commands
set -o xtrace

# Exit on error to stop unexpected errors
set -o errexit

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Import common functions
. $TOP_DIR/functions

# Change dir to top of devstack
cd $TOP_DIR

# Source params
source ./stackrc

# Echo usage
function usage {
    echo "Add stack user and keys"
    echo ""
    echo "Usage: $0 [full path to raw uec base image]"
}

# Make sure this is a raw image
if ! qemu-img info $1 | grep -q "file format: raw"; then
    usage
    exit 1
fi

# Mount the image
DEST=/opt/stack
STAGING_DIR=/tmp/`echo $1 | sed  "s/\//_/g"`.stage.user
mkdir -p $STAGING_DIR
umount $STAGING_DIR || true
sleep 1
mount -t ext4 -o loop $1 $STAGING_DIR
mkdir -p $STAGING_DIR/$DEST

# Create a stack user that is a member of the libvirtd group so that stack
# is able to interact with libvirt.
chroot $STAGING_DIR groupadd libvirtd || true
chroot $STAGING_DIR useradd $STACK_USER -s /bin/bash -d $DEST -G libvirtd || true

# Add a simple password - pass
echo $STACK_USER:pass | chroot $STAGING_DIR chpasswd

# Configure sudo
( umask 226 && echo "$STACK_USER ALL=(ALL) NOPASSWD:ALL" \
    > $STAGING_DIR/etc/sudoers.d/50_stack_sh )

# Copy over your ssh keys and env if desired
cp_it ~/.ssh $STAGING_DIR/$DEST/.ssh
cp_it ~/.ssh/id_rsa.pub $STAGING_DIR/$DEST/.ssh/authorized_keys
cp_it ~/.gitconfig $STAGING_DIR/$DEST/.gitconfig
cp_it ~/.vimrc $STAGING_DIR/$DEST/.vimrc
cp_it ~/.bashrc $STAGING_DIR/$DEST/.bashrc

# Copy devstack
rm -rf $STAGING_DIR/$DEST/devstack
cp_it . $STAGING_DIR/$DEST/devstack

# Give stack ownership over $DEST so it may do the work needed
chroot $STAGING_DIR chown -R $STACK_USER $DEST

# Unmount
umount $STAGING_DIR
