#!/usr/bin/env bash

# **warm_apts_for_uec.sh**

# Echo commands
set -o xtrace

# Exit on error to stop unexpected errors
set -o errexit

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

# Change dir to top of devstack
cd $TOP_DIR

# Echo usage
function usage {
    echo "Cache OpenStack dependencies on a uec image to speed up performance."
    echo ""
    echo "Usage: $0 [full path to raw uec base image]"
}

# Make sure this is a raw image
if ! qemu-img info $1 | grep -q "file format: raw"; then
    usage
    exit 1
fi

# Make sure we are in the correct dir
if [ ! -d files/apts ]; then
    echo "Please run this script from devstack/tools/"
    exit 1
fi

# Mount the image
STAGING_DIR=/tmp/`echo $1 | sed  "s/\//_/g"`.stage
mkdir -p $STAGING_DIR
umount $STAGING_DIR || true
sleep 1
mount -t ext4 -o loop $1 $STAGING_DIR

# Make sure that base requirements are installed
cp /etc/resolv.conf $STAGING_DIR/etc/resolv.conf

# Perform caching on the base image to speed up subsequent runs
chroot $STAGING_DIR apt-get update
chroot $STAGING_DIR apt-get install -y --download-only `cat files/apts/* | grep NOPRIME | cut -d\# -f1`
chroot $STAGING_DIR apt-get install -y --force-yes `cat files/apts/* | grep -v NOPRIME | cut -d\# -f1` || true

# Unmount
umount $STAGING_DIR
