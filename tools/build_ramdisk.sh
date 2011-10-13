#!/bin/bash
# build_ramdisk.sh - Build RAM disk images

if [ ! "$#" -eq "1" ]; then
    echo "$0 builds a gziped natty openstack install"
    echo "usage: $0 dest"
    exit 1
fi

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

# clean install of natty
if [ ! -d $CHROOTCACHE/natty-base ]; then
    $PROGDIR/make_image.sh -C natty $CHROOTCACHE/natty-base
    # copy kernel modules...  
    # NOTE(ja): is there a better way to do this?
    cp -pr /lib/modules/`uname -r` $CHROOTCACHE/natty-base/lib/modules
    # a simple password - pass
    echo root:pass | chroot $CHROOTCACHE/natty-base chpasswd
fi

# prime natty with as many apt/pips as we can
if [ ! -d $CHROOTCACHE/natty-dev ]; then
    rsync -azH $CHROOTCACHE/natty-base/ $CHROOTCACHE/natty-dev/
    chroot $CHROOTCACHE/natty-dev apt-get install -y `cat files/apts/* | cut -d\# -f1 | egrep -v "(rabbitmq|libvirt-bin|mysql-server)"`
    chroot $CHROOTCACHE/natty-dev pip install `cat files/pips/*`

    # Create a stack user that is a member of the libvirtd group so that stack 
    # is able to interact with libvirt.
    chroot $CHROOTCACHE/natty-dev groupadd libvirtd
    chroot $CHROOTCACHE/natty-dev useradd stack -s /bin/bash -d $DEST -G libvirtd
    mkdir -p $CHROOTCACHE/natty-dev/$DEST
    chown stack $CHROOTCACHE/natty-dev/$DEST

    # a simple password - pass
    echo stack:pass | chroot $CHROOTCACHE/natty-dev chpasswd

    # and has sudo ability (in the future this should be limited to only what 
    # stack requires)
    echo "stack ALL=(ALL) NOPASSWD: ALL" >> $CHROOTCACHE/natty-dev/etc/sudoers
fi

# clone git repositories onto the system
# ======================================

if [ ! -d $CHROOTCACHE/natty-stack ]; then
    rsync -azH $CHROOTCACHE/natty-dev/ $CHROOTCACHE/natty-stack/
fi

# git clone only if directory doesn't exist already.  Since ``DEST`` might not
# be owned by the installation user, we create the directory and change the
# ownership to the proper user.
function git_clone {

    # clone new copy or fetch latest changes
    CHECKOUT=$CHROOTCACHE/natty-stack$2
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
    chroot $CHROOTCACHE/natty-stack/ chown -R stack $2
}

git_clone $NOVA_REPO $DEST/nova $NOVA_BRANCH
git_clone $GLANCE_REPO $DEST/glance $GLANCE_BRANCH
git_clone $KEYSTONE_REPO $DEST/keystone $KEYSTONE_BRANCH
git_clone $NOVNC_REPO $DEST/novnc $NOVNC_BRANCH
git_clone $DASH_REPO $DEST/dash $DASH_BRANCH
git_clone $NOVACLIENT_REPO $DEST/python-novaclient $NOVACLIENT_BRANCH
git_clone $OPENSTACKX_REPO $DEST/openstackx $OPENSTACKX_BRANCH

# Use this version of devstack?
if [ "$USE_CURRENT_DEVSTACK" = "1" ]; then
    rm -rf $CHROOTCACHE/natty-stack/$DEST/devstack
    cp -pr $CWD $CHROOTCACHE/natty-stack/$DEST/devstack
fi

# Configure host network for DHCP
mkdir -p $CHROOTCACHE/natty-stack/etc/network
cat > $CHROOTCACHE/natty-stack/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Configure the runner
RUN_SH=$CHROOTCACHE/natty-stack/$DEST/run.sh
cat > $RUN_SH <<EOF
#!/usr/bin/env bash

# Get IP range
set \`ip addr show dev eth0 | grep inet\`
PREFIX=\`echo \$2 | cut -d. -f1,2,3\`
export FLOATING_RANGE="\$PREFIX.224/27"

# Pre-empt download of natty image
tar czf $DEST/devstack/files/natty.tgz /etc/hosts
mkdir -p $DEST/devstack/files/images
touch $DEST/devstack/files/images/natty-server-cloudimg-amd64-vmlinuz-virtual
touch $DEST/devstack/files/images/natty-server-cloudimg-amd64.img

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
chroot $CHROOTCACHE/natty-stack chown stack $DEST/run.sh

# build a new image
BASE=$CHROOTCACHE/build.$$
IMG=$BASE.img
MNT=$BASE/

# (quickly) create a 2GB blank filesystem
dd bs=1 count=1 seek=$((2*1024*1024*1024)) if=/dev/zero of=$IMG
# force it to be initialized as ext2
mkfs.ext2 -F $IMG

# mount blank image loopback and load it
mkdir -p $MNT
mount -o loop $IMG $MNT
rsync -azH $CHROOTCACHE/natty-stack/ $MNT

# umount and cleanup
umount $MNT
rmdir $MNT

# gzip into final location
gzip -1 $IMG -c > $1

