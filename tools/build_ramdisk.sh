#!/bin/bash
# build_ramdisk.sh - Build RAM disk images

if [ ! "$#" -eq "1" ]; then
    echo "$0 builds a gziped natty openstack install"
    echo "usage: $0 dest"
    exit 1
fi

IMG_FILE=$1

PROGDIR=`dirname $0`
CHROOTCACHE=${CHROOTCACHE:-/var/cache/devstack}

# Source params
source ./stackrc

# Store cwd
CWD=`pwd`

DEST=${DEST:-/opt/stack}

# Param string to pass to stack.sh.  Like "EC2_DMZ_HOST=192.168.1.1 MYSQL_USER=nova"
STACKSH_PARAMS=${STACKSH_PARAMS:-}

# Option to use the version of devstack on which we are currently working
USE_CURRENT_DEVSTACK=${USE_CURRENT_DEVSTACK:-1}

# Set up nbd
modprobe nbd max_part=63
NBD=${NBD:-/dev/nbd9}
NBD_DEV=`basename $NBD`

# clean install of natty
if [ ! -r $CHROOTCACHE/natty-base.img ]; then
    $PROGDIR/get_uec_image.sh natty $CHROOTCACHE/natty-base.img
#    # copy kernel modules...
#    # NOTE(ja): is there a better way to do this?
#    cp -pr /lib/modules/`uname -r` $CHROOTCACHE/natty-base/lib/modules
#    # a simple password - pass
#    echo root:pass | chroot $CHROOTCACHE/natty-base chpasswd
fi

# prime natty with as many apt/pips as we can
if [ ! -r $CHROOTCACHE/natty-dev.img ]; then
    cp -p $CHROOTCACHE/natty-base.img $CHROOTCACHE/natty-dev.img

    qemu-nbd -c $NBD $CHROOTCACHE/natty-dev.img
    if ! timeout 60 sh -c "while ! [ -e /sys/block/$NBD_DEV/pid ]; do sleep 1; done"; then
        echo "Couldn't connect $NBD"
        exit 1
    fi
    MNTDIR=`mktemp -d --tmpdir mntXXXXXXXX`
    mount -t ext4 ${NBD}p1 $MNTDIR
    cp -p /etc/resolv.conf $MNTDIR/etc/resolv.conf

    chroot $MNTDIR apt-get install -y `cat files/apts/* | cut -d\# -f1 | egrep -v "(rabbitmq|libvirt-bin|mysql-server)"`
    chroot $MNTDIR pip install `cat files/pips/*`

    # Create a stack user that is a member of the libvirtd group so that stack
    # is able to interact with libvirt.
    chroot $MNTDIR groupadd libvirtd
    chroot $MNTDIR useradd stack -s /bin/bash -d $DEST -G libvirtd
    mkdir -p $MNTDIR/$DEST
    chroot $MNTDIR chown stack $DEST

    # a simple password - pass
    echo stack:pass | chroot $MNTDIR chpasswd

    # and has sudo ability (in the future this should be limited to only what
    # stack requires)
    echo "stack ALL=(ALL) NOPASSWD: ALL" >> $MNTDIR/etc/sudoers

    umount $MNTDIR
    rmdir $MNTDIR
    qemu-nbd -d $NBD
fi

# clone git repositories onto the system
# ======================================

if [ ! -r $IMG_FILE ]; then
    qemu-img convert -O raw $CHROOTCACHE/natty-dev.img $IMG_FILE
fi

qemu-nbd -c $NBD $IMG_FILE
if ! timeout 60 sh -c "while ! [ -e /sys/block/$NBD_DEV/pid ]; do sleep 1; done"; then
    echo "Couldn't connect $NBD"
    exit 1
fi
MNTDIR=`mktemp -d --tmpdir mntXXXXXXXX`
mount -t ext4 ${NBD}p1 $MNTDIR
cp -p /etc/resolv.conf $MNTDIR/etc/resolv.conf

# git clone only if directory doesn't exist already.  Since ``DEST`` might not
# be owned by the installation user, we create the directory and change the
# ownership to the proper user.
function git_clone {

    # clone new copy or fetch latest changes
    CHECKOUT=${MNTDIR}$2
    if [ ! -d $CHECKOUT ]; then
        mkdir -p $CHECKOUT
        git clone $1 $CHECKOUT
    else
        pushd $CHECKOUT
        git fetch
        popd
    fi

    # FIXME(ja): checkout specified version (should works for branches and tags)

    pushd $CHECKOUT
    # checkout the proper branch/tag
    git checkout $3
    # force our local version to be the same as the remote version
    git reset --hard origin/$3
    popd

    # give ownership to the stack user
    chroot $MNTDIR chown -R stack $2
}

git_clone $NOVA_REPO $DEST/nova $NOVA_BRANCH
git_clone $GLANCE_REPO $DEST/glance $GLANCE_BRANCH
git_clone $KEYSTONE_REPO $DEST/keystone $KEYSTONE_BRANCH
git_clone $NOVNC_REPO $DEST/novnc $NOVNC_BRANCH
git_clone $DASH_REPO $DEST/dash $DASH_BRANCH
git_clone $NOVACLIENT_REPO $DEST/python-novaclient $NOVACLIENT_BRANCH
git_clone $OPENSTACKX_REPO $DEST/openstackx $OPENSTACKX_BRANCH

# Use this version of devstack
rm -rf $MNTDIR/$DEST/devstack
cp -pr $CWD $MNTDIR/$DEST/devstack
chroot $MNTDIR chown -R stack $DEST/devstack

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
chroot $MNTDIR chown stack $DEST/run.sh

umount $MNTDIR
rmdir $MNTDIR
qemu-nbd -d $NBD

gzip -1 $IMG_FILE
