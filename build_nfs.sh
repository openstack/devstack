#!/bin/bash

# Source params
source ./stackrc

# TODO: make dest not hardcoded

NAME=$1
DEST="/nfs/$NAME"

# remove old nfs filesystem if one exists
rm -rf $DEST

# build a proto image - natty + packages that will install (optimization)
if [ ! -d proto ]; then
    debootstrap natty proto
    cp files/sources.list proto/etc/apt/sources.list
    chroot proto apt-get update
    chroot proto apt-get install -y `cat files/apts/* | cut -d\# -f1 | egrep -v "(rabbitmq|libvirt-bin|mysql-server)"`
    chroot proto pip install `cat files/pips/*`
    git_clone $NOVA_REPO proto/opt/nova $NOVA_BRANCH
    git_clone $GLANCE_REPO proto/opt/glance $GLANCE_BRANCH
    git_clone $KEYSTONE_REPO proto/opt/keystone $KEYSTONE_BRANCH
    git_clone $NOVNC_REPO proto/opt/novnc $NOVNC_BRANCH
    git_clone $DASH_REPO proto/opt/dash $DASH_BRANCH $DASH_TAG
    git_clone $NOVACLIENT_REPO proto/opt/python-novaclient $NOVACLIENT_BRANCH
    git_clone $OPENSTACKX_REPO proto/opt/openstackx $OPENSTACKX_BRANCH
    chroot proto mkdir -p /opt/files
    wget -c http://images.ansolabs.com/tty.tgz -O proto/opt/files/tty.tgz
fi

cp -pr proto $DEST

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

# set root password to password
echo root:pass | chroot $DEST chpasswd

# Create a stack user that is a member of the libvirtd group so that stack 
# is able to interact with libvirt.
chroot $DEST groupadd libvirtd
chroot $DEST useradd stack -s /bin/bash -d /opt -G libvirtd
# a simple password - pass
echo stack:pass | chroot $DEST chpasswd
# give stack ownership over /opt so it may do the work needed
chroot $DEST chown -R stack /opt

# and has sudo ability (in the future this should be limited to only what 
# stack requires)
echo "stack ALL=(ALL) NOPASSWD: ALL" >> $DEST/etc/sudoers
