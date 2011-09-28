#!/bin/bash

if [ ! "$#" -eq "1" ]; then
    echo "$0 builds a gziped natty openstack install"
    echo "usage: $0 dest"
    exit 1
fi

# Source params
source ./stackrc

# clean install of natty
if [ ! -d natty-base ]; then
    debootstrap natty natty-base
    # copy kernel modules...  
    # NOTE(ja): is there a better way to do this?
    cp -pr /lib/modules/`uname -r` proto/lib/modules
    cp files/sources.list natty-base/etc/apt/sources.list
    chroot natty-base apt-get update
fi

# prime natty with as many apt/pips as we can
if [ ! -d primed ]; then
    rsync -azH natty-base/ primed/
    chroot primed apt-get install -y `cat files/apts/* | cut -d\# -f1 | egrep -v "(rabbitmq|libvirt-bin|mysql-server)"`
    chroot primed pip install `cat files/pips/*`

    # Create a stack user that is a member of the libvirtd group so that stack 
    # is able to interact with libvirt.
    chroot primed groupadd libvirtd
    chroot primed useradd stack -s /bin/bash -d /opt -G libvirtd

    # a simple password - pass
    echo stack:pass | chroot primed chpasswd

    # and has sudo ability (in the future this should be limited to only what 
    # stack requires)
    echo "stack ALL=(ALL) NOPASSWD: ALL" >> primed/etc/sudoers
fi

# clone git repositories onto the system
# ======================================

if [ ! -d cloned ]; then
    rsync -azH primed/ cloned/
fi

# git clone only if directory doesn't exist already.  Since ``DEST`` might not
# be owned by the installation user, we create the directory and change the
# ownership to the proper user.
function git_clone {

    # clone new copy or fetch latest changes
    CHECKOUT=cloned$2
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
    chroot cloned/ chown -R stack $2
}

git_clone $NOVA_REPO /opt/stack/nova $NOVA_BRANCH
git_clone $GLANCE_REPO /opt/stack/glance $GLANCE_BRANCH
git_clone $KEYSTONE_REPO /opt/stack/keystone $KEYSTONE_BRANCH
git_clone $NOVNC_REPO /opt/stack/novnc $NOVNC_BRANCH
git_clone $DASH_REPO /opt/stack/dash $DASH_BRANCH
git_clone $NIXON_REPO /opt/stack/nixon $NIXON_BRANCH
git_clone $NOVACLIENT_REPO /opt/stack/python-novaclient $NOVACLIENT_BRANCH
git_clone $OPENSTACKX_REPO /opt/stack/openstackx $OPENSTACKX_BRANCH
git_clone $MUNIN_REPO /opt/stack/openstack-munin $MUNIN_BRANCH

# build a new image
BASE=build.$$
IMG=$BASE.img
MNT=$BASE/

# create a 2GB blank filesystem
dd if=/dev/zero of=$IMG bs=1024k count=2048
# force it to be initialized as ext2
mkfs.ext2 -F $IMG

# mount blank image loopback and load it
mkdir -p $MNT
mount -o loop $IMG $MNT
rsync -azH cloned/ $MNT

# umount and cleanup
umount $MNT
rmdir $MNT

# gzip into final location
gzip -1 $IMG -c > $1

