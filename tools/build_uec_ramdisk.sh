#!/usr/bin/env bash

# **build_uec_ramdisk.sh**

# Build RAM disk images based on UEC image

# Exit on error to stop unexpected errors
set -o errexit

if [ ! "$#" -eq "1" ]; then
    echo "$0 builds a gziped Ubuntu OpenStack install"
    echo "usage: $0 dest"
    exit 1
fi

# Make sure that we have the proper version of ubuntu (only works on oneiric)
if ! egrep -q "oneiric" /etc/lsb-release; then
    echo "This script only works with ubuntu oneiric."
    exit 1
fi

# Clean up resources that may be in use
function cleanup {
    set +o errexit

    if [ -n "$MNT_DIR" ]; then
        umount $MNT_DIR/dev
        umount $MNT_DIR
    fi

    if [ -n "$DEST_FILE_TMP" ]; then
        rm $DEST_FILE_TMP
    fi

    # Kill ourselves to signal parents
    trap 2; kill -2 $$
}

trap cleanup SIGHUP SIGINT SIGTERM SIGQUIT EXIT

# Output dest image
DEST_FILE=$1

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Import common functions
. $TOP_DIR/functions

cd $TOP_DIR

# Source params
source ./stackrc

DEST=${DEST:-/opt/stack}

# Ubuntu distro to install
DIST_NAME=${DIST_NAME:-oneiric}

# Configure how large the VM should be
GUEST_SIZE=${GUEST_SIZE:-2G}

# Exit on error to stop unexpected errors
set -o errexit
set -o xtrace

# Abort if localrc is not set
if [ ! -e $TOP_DIR/localrc ]; then
    echo "You must have a localrc with ALL necessary passwords defined before proceeding."
    echo "See stack.sh for required passwords."
    exit 1
fi

# Install deps if needed
DEPS="kvm libvirt-bin kpartx cloud-utils curl"
apt_get install -y --force-yes $DEPS

# Where to store files and instances
CACHEDIR=${CACHEDIR:-/opt/stack/cache}
WORK_DIR=${WORK_DIR:-/opt/ramstack}

# Where to store images
image_dir=$WORK_DIR/images/$DIST_NAME
mkdir -p $image_dir

# Get the base image if it does not yet exist
if [ ! -e $image_dir/disk ]; then
    $TOOLS_DIR/get_uec_image.sh -r 2000M $DIST_NAME $image_dir/disk
fi

# Configure the root password of the vm to be the same as ``ADMIN_PASSWORD``
ROOT_PASSWORD=${ADMIN_PASSWORD:-password}

# Name of our instance, used by libvirt
GUEST_NAME=${GUEST_NAME:-devstack}

# Pre-load the image with basic environment
if [ ! -e $image_dir/disk-primed ]; then
    cp $image_dir/disk $image_dir/disk-primed
    $TOOLS_DIR/warm_apts_for_uec.sh $image_dir/disk-primed
    $TOOLS_DIR/copy_dev_environment_to_uec.sh $image_dir/disk-primed
fi

# Back to devstack
cd $TOP_DIR

DEST_FILE_TMP=`mktemp $DEST_FILE.XXXXXX`
MNT_DIR=`mktemp -d --tmpdir mntXXXXXXXX`
cp $image_dir/disk-primed $DEST_FILE_TMP
mount -t ext4 -o loop $DEST_FILE_TMP $MNT_DIR
mount -o bind /dev /$MNT_DIR/dev
cp -p /etc/resolv.conf $MNT_DIR/etc/resolv.conf
echo root:$ROOT_PASSWORD | chroot $MNT_DIR chpasswd
touch $MNT_DIR/$DEST/.ramdisk

# We need to install a non-virtual kernel and modules to boot from
if [ ! -r "`ls $MNT_DIR/boot/vmlinuz-*-generic | head -1`" ]; then
    chroot $MNT_DIR apt-get install -y linux-generic
fi

git_clone $NOVA_REPO $DEST/nova $NOVA_BRANCH
git_clone $GLANCE_REPO $DEST/glance $GLANCE_BRANCH
git_clone $KEYSTONE_REPO $DEST/keystone $KEYSTONE_BRANCH
git_clone $NOVNC_REPO $DEST/novnc $NOVNC_BRANCH
git_clone $HORIZON_REPO $DEST/horizon $HORIZON_BRANCH
git_clone $NOVACLIENT_REPO $DEST/python-novaclient $NOVACLIENT_BRANCH
git_clone $OPENSTACKX_REPO $DEST/openstackx $OPENSTACKX_BRANCH
git_clone $TEMPEST_REPO $DEST/tempest $TEMPEST_BRANCH

# Use this version of devstack
rm -rf $MNT_DIR/$DEST/devstack
cp -pr $TOP_DIR $MNT_DIR/$DEST/devstack
chroot $MNT_DIR chown -R stack $DEST/devstack

# Configure host network for DHCP
mkdir -p $MNT_DIR/etc/network
cat > $MNT_DIR/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Set hostname
echo "ramstack" >$MNT_DIR/etc/hostname
echo "127.0.0.1		localhost	ramstack" >$MNT_DIR/etc/hosts

# Configure the runner
RUN_SH=$MNT_DIR/$DEST/run.sh
cat > $RUN_SH <<EOF
#!/usr/bin/env bash

# Get IP range
set \`ip addr show dev eth0 | grep inet\`
PREFIX=\`echo \$2 | cut -d. -f1,2,3\`
export FLOATING_RANGE="\$PREFIX.224/27"

# Kill any existing screens
killall screen

# Run stack.sh
cd $DEST/devstack && \$STACKSH_PARAMS ./stack.sh > $DEST/run.sh.log
echo >> $DEST/run.sh.log
echo >> $DEST/run.sh.log
echo "All done! Time to start clicking." >> $DEST/run.sh.log
EOF

# Make the run.sh executable
chmod 755 $RUN_SH
chroot $MNT_DIR chown stack $DEST/run.sh

umount $MNT_DIR/dev
umount $MNT_DIR
rmdir $MNT_DIR
mv $DEST_FILE_TMP $DEST_FILE
rm -f $DEST_FILE_TMP

trap - SIGHUP SIGINT SIGTERM SIGQUIT EXIT
