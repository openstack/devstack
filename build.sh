#!/bin/bash

# TODO: make dest not hardcoded

NAME=$1
DEST="/boxes/$NAME/nfs"

mkdir -p /boxes/$NAME

# remove old nfs filesystem if one exists
rm -rf $DEST

# build a proto image - natty + packages that will install (optimization)
if [ ! -d nfs ]; then
    debootstrap natty nfs
    cp sources.list nfs/etc/apt/sources.list
    chroot nfs apt-get update
    chroot nfs apt-get install -y `cat apts/* | cut -d\# -f1 | egrep -v "(rabbitmq|libvirt)"`
    chroot nfs pip install `cat pips/* | cut -d\# -f1`
    git clone https://github.com/cloudbuilders/nova.git nfs/opt/nova
    git clone https://github.com/cloudbuilders/openstackx.git nfs/opt/openstackx
    git clone https://github.com/cloudbuilders/noVNC.git nfs/opt/noVNC
    git clone https://github.com/cloudbuilders/openstack-dashboard.git nfs/opt/dash
    git clone https://github.com/cloudbuilders/python-novaclient.git nfs/opt/python-novaclient
    git clone https://github.com/cloudbuilders/keystone.git nfs/opt/keystone
    git clone https://github.com/cloudbuilders/glance.git nfs/opt/glance
fi

cp -pr nfs $DEST

# set hostname
echo $NAME > $DEST/etc/hostname
echo "127.0.0.1 localhost $NAME" > $DEST/etc/hosts

# copy kernel modules
cp -pr /lib/modules/`uname -r` $DEST/lib/modules

# copy openstack installer and requirement lists to a new directory.
mkdir -p $DEST/opt
cp stack.sh $DEST/opt/stack.sh
cp -r pips $DEST/opt
cp -r apts $DEST/opt

# injecting root's ssh key
# FIXME: only do this if id_rsa.pub exists
mkdir $DEST/root/.ssh
chmod 700 $DEST/root/.ssh
cp /root/.ssh/id_rsa.pub $DEST/root/.ssh/authorized_keys

# set root password to password
echo root:password | chroot $DEST chpasswd

