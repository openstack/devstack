#!/usr/bin/env bash

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

# cd to top of devstack
cd $TOP_DIR

# Echo usage
usage() {
    echo "Cache OpenStack dependencies on a uec image to speed up performance."
    echo ""
    echo "Usage: $0 [full path to raw uec base image]"
}

# Make sure this is a raw image
if ! qemu-img info $1 | grep -q "file format: raw"; then
    usage
    exit 1
fi

# Mount the image
STAGING_DIR=`mktemp -d uec.XXXXXXXXXX`
mkdir -p $STAGING_DIR
mount -t ext4 -o loop $1 $STAGING_DIR

# Make sure that base requirements are installed
cp /etc/resolv.conf $STAGING_DIR/etc/resolv.conf

# Perform caching on the base image to speed up subsequent runs
chroot $STAGING_DIR apt-get update
chroot $STAGING_DIR apt-get install -y --download-only `cat files/apts/* | grep NOPRIME | cut -d\# -f1`
chroot $STAGING_DIR apt-get install -y --force-yes `cat files/apts/* | grep -v NOPRIME | cut -d\# -f1`
chroot $STAGING_DIR pip install `cat files/pips/*`
umount $STAGING_DIR && rm -rf $STAGING_DIR
