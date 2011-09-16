#!/bin/bash

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
    git clone https://github.com/cloudbuilders/nova.git proto/opt/nova
    git clone https://github.com/cloudbuilders/openstackx.git proto/opt/openstackx
    git clone https://github.com/cloudbuilders/noVNC.git proto/opt/noVNC
    git clone https://github.com/cloudbuilders/openstack-dashboard.git proto/opt/dash
    git clone https://github.com/cloudbuilders/python-novaclient.git proto/opt/python-novaclient
    git clone https://github.com/cloudbuilders/keystone.git proto/opt/keystone
    git clone https://github.com/cloudbuilders/glance.git proto/opt/glance
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
