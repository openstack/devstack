#!/bin/bash

PROGDIR=`dirname $0`
CHROOTCACHE=${CHROOTCACHE:-/root/cache}

# Source params
source ./stackrc

# TODO: make dest not hardcoded

NAME=$1
DEST="/nfs/$NAME"

# remove old nfs filesystem if one exists
rm -rf $DEST

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
    chroot $CHROOTCACHE/natty-dev useradd stack -s /bin/bash -d /opt -G libvirtd

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

git_clone $NOVA_REPO /opt/stack/nova $NOVA_BRANCH
git_clone $GLANCE_REPO /opt/stack/glance $GLANCE_BRANCH
git_clone $KEYSTONE_REPO /opt/stack/keystone $KEYSTONE_BRANCH
git_clone $NOVNC_REPO /opt/stack/novnc $NOVNC_BRANCH
git_clone $DASH_REPO /opt/stack/dash $DASH_BRANCH $DASH_TAG
git_clone $NOVACLIENT_REPO /opt/stack/python-novaclient $NOVACLIENT_BRANCH
git_clone $OPENSTACKX_REPO /opt/stack/openstackx $OPENSTACKX_BRANCH

chroot $CHROOTCACHE/natty-stack mkdir -p /opt/stack/files
wget -c http://images.ansolabs.com/tty.tgz -O $CHROOTCACHE/natty-stack/opt/stack/files/tty.tgz

cp -pr $CHROOTCACHE/natty-stack $DEST

# set hostname
echo $NAME > $DEST/etc/hostname
echo "127.0.0.1 localhost $NAME" > $DEST/etc/hosts

# copy kernel modules
cp -pr /lib/modules/`uname -r` $DEST/lib/modules


# copy openstack installer and requirement lists to a new directory.
mkdir -p $DEST/opt

# inject stack.sh and dependant files
cp -r files $DEST/opt/files
cp stack.sh $DEST/opt/stack.sh

# injecting root's public ssh key if it exists
if [ -f /root/.ssh/id_rsa.pub ]; then
    mkdir $DEST/root/.ssh
    chmod 700 $DEST/root/.ssh
    cp /root/.ssh/id_rsa.pub $DEST/root/.ssh/authorized_keys
fi
