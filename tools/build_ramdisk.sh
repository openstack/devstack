#!/bin/bash

# **build_ramdisk.sh**

# Build RAM disk images

# Exit on error to stop unexpected errors
set -o errexit

if [ ! "$#" -eq "1" ]; then
    echo "$0 builds a gziped Ubuntu OpenStack install"
    echo "usage: $0 dest"
    exit 1
fi

# Clean up any resources that may be in use
cleanup() {
    set +o errexit

    # Mop up temporary files
    if [ -n "$MNTDIR" -a -d "$MNTDIR" ]; then
        umount $MNTDIR
        rmdir $MNTDIR
    fi
    if [ -n "$DEV_FILE_TMP" -a -e "$DEV_FILE_TMP "]; then
        rm -f $DEV_FILE_TMP
    fi
    if [ -n "$IMG_FILE_TMP" -a -e "$IMG_FILE_TMP" ]; then
        rm -f $IMG_FILE_TMP
    fi

    # Release NBD devices
    if [ -n "$NBD" ]; then
        qemu-nbd -d $NBD
    fi

    # Kill ourselves to signal any calling process
    trap 2; kill -2 $$
}

trap cleanup SIGHUP SIGINT SIGTERM

# Set up nbd
modprobe nbd max_part=63

# Echo commands
set -o xtrace

IMG_FILE=$1

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Import common functions
. $TOP_DIR/functions

# Store cwd
CWD=`pwd`

cd $TOP_DIR

# Source params
source ./stackrc

CACHEDIR=${CACHEDIR:-/opt/stack/cache}

DEST=${DEST:-/opt/stack}

# Configure the root password of the vm to be the same as ``ADMIN_PASSWORD``
ROOT_PASSWORD=${ADMIN_PASSWORD:-password}

# Base image (natty by default)
DIST_NAME=${DIST_NAME:-natty}

# Param string to pass to stack.sh.  Like "EC2_DMZ_HOST=192.168.1.1 MYSQL_USER=nova"
STACKSH_PARAMS=${STACKSH_PARAMS:-}

# Option to use the version of devstack on which we are currently working
USE_CURRENT_DEVSTACK=${USE_CURRENT_DEVSTACK:-1}

# clean install
if [ ! -r $CACHEDIR/$DIST_NAME-base.img ]; then
    $TOOLS_DIR/get_uec_image.sh $DIST_NAME $CACHEDIR/$DIST_NAME-base.img
fi

# Finds and returns full device path for the next available NBD device.
# Exits script if error connecting or none free.
# map_nbd image
function map_nbd() {
    for i in `seq 0 15`; do
        if [ ! -e /sys/block/nbd$i/pid ]; then
            NBD=/dev/nbd$i
            # Connect to nbd and wait till it is ready
            qemu-nbd -c $NBD $1
            if ! timeout 60 sh -c "while ! [ -e ${NBD}p1 ]; do sleep 1; done"; then
                echo "Couldn't connect $NBD"
                exit 1
            fi
            break
        fi
    done
    if [ -z "$NBD" ]; then
        echo "No free NBD slots"
        exit 1
    fi
    echo $NBD
}

# Prime image with as many apt as we can
DEV_FILE=$CACHEDIR/$DIST_NAME-dev.img
DEV_FILE_TMP=`mktemp $DEV_FILE.XXXXXX`
if [ ! -r $DEV_FILE ]; then
    cp -p $CACHEDIR/$DIST_NAME-base.img $DEV_FILE_TMP

    NBD=`map_nbd $DEV_FILE_TMP`
    MNTDIR=`mktemp -d --tmpdir mntXXXXXXXX`
    mount -t ext4 ${NBD}p1 $MNTDIR
    cp -p /etc/resolv.conf $MNTDIR/etc/resolv.conf

    chroot $MNTDIR apt-get install -y --download-only `cat files/apts/* | grep NOPRIME | cut -d\# -f1`
    chroot $MNTDIR apt-get install -y --force-yes `cat files/apts/* | grep -v NOPRIME | cut -d\# -f1`

    # Create a stack user that is a member of the libvirtd group so that stack
    # is able to interact with libvirt.
    chroot $MNTDIR groupadd libvirtd
    chroot $MNTDIR useradd $STACK_USER -s /bin/bash -d $DEST -G libvirtd
    mkdir -p $MNTDIR/$DEST
    chroot $MNTDIR chown $STACK_USER $DEST

    # A simple password - pass
    echo $STACK_USER:pass | chroot $MNTDIR chpasswd
    echo root:$ROOT_PASSWORD | chroot $MNTDIR chpasswd

    # And has sudo ability (in the future this should be limited to only what
    # stack requires)
    echo "$STACK_USER ALL=(ALL) NOPASSWD: ALL" >> $MNTDIR/etc/sudoers

    umount $MNTDIR
    rmdir $MNTDIR
    qemu-nbd -d $NBD
    NBD=""
    mv $DEV_FILE_TMP $DEV_FILE
fi
rm -f $DEV_FILE_TMP


# Clone git repositories onto the system
# ======================================

IMG_FILE_TMP=`mktemp $IMG_FILE.XXXXXX`

if [ ! -r $IMG_FILE ]; then
    NBD=`map_nbd $DEV_FILE`

    # Pre-create the image file
    # FIXME(dt): This should really get the partition size to
    # pre-create the image file
    dd if=/dev/zero of=$IMG_FILE_TMP bs=1 count=1 seek=$((2*1024*1024*1024))
    # Create filesystem image for RAM disk
    dd if=${NBD}p1 of=$IMG_FILE_TMP bs=1M

    qemu-nbd -d $NBD
    NBD=""
    mv $IMG_FILE_TMP $IMG_FILE
fi
rm -f $IMG_FILE_TMP

MNTDIR=`mktemp -d --tmpdir mntXXXXXXXX`
mount -t ext4 -o loop $IMG_FILE $MNTDIR
cp -p /etc/resolv.conf $MNTDIR/etc/resolv.conf

# We need to install a non-virtual kernel and modules to boot from
if [ ! -r "`ls $MNTDIR/boot/vmlinuz-*-generic | head -1`" ]; then
    chroot $MNTDIR apt-get install -y linux-generic
fi

git_clone $NOVA_REPO $DEST/nova $NOVA_BRANCH
git_clone $GLANCE_REPO $DEST/glance $GLANCE_BRANCH
git_clone $KEYSTONE_REPO $DEST/keystone $KEYSTONE_BRANCH
git_clone $NOVNC_REPO $DEST/novnc $NOVNC_BRANCH
git_clone $HORIZON_REPO $DEST/horizon $HORIZON_BRANCH
git_clone $NOVACLIENT_REPO $DEST/python-novaclient $NOVACLIENT_BRANCH
git_clone $OPENSTACKX_REPO $DEST/openstackx $OPENSTACKX_BRANCH

# Use this version of devstack
rm -rf $MNTDIR/$DEST/devstack
cp -pr $CWD $MNTDIR/$DEST/devstack
chroot $MNTDIR chown -R $STACK_USER $DEST/devstack

# Configure host network for DHCP
mkdir -p $MNTDIR/etc/network
cat > $MNTDIR/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Set hostname
echo "ramstack" >$MNTDIR/etc/hostname
echo "127.0.0.1		localhost	ramstack" >$MNTDIR/etc/hosts

# Configure the runner
RUN_SH=$MNTDIR/$DEST/run.sh
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
chroot $MNTDIR chown $STACK_USER $DEST/run.sh

umount $MNTDIR
rmdir $MNTDIR
