#!/usr/bin/env bash

# Echo commands
set -o xtrace

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)

ROOT_PASSWORD=${ROOT_PASSWORD:password}
PERSIST_DIR=${PERSIST_DIR:-/opt/kvmstack}
IMAGES_DIR=$PERSIST_DIR/images
mkdir -p $UEC_DIR

# Move to top devstack dir
cd ..

# Abort if localrc is not set
if [ ! -e ./localrc ]; then
    echo "You must have a localrc with ALL necessary passwords defined before proceeding."
    echo "See stack.sh for required passwords."
    exit 1
fi

# Source params
source ./stackrc

# Base image (oneiric by default)
IMAGE_FNAME=natty.raw
IMAGE_NAME=natty

BASE_IMAGE=$PERSIST_DIR/images/natty.raw
BASE_IMAGE_COPY=$IMAGES_DIR/$IMAGE_NAME.raw.copy

VM_NAME=${VM_NAME:-kvmstack}
virsh shutdown $VM_NAME
virsh destroy $VM_NAME

VM_DIR=$PERSIST_DIR/instances/$VM_NAME

mkdir -p $VM_DIR

# Where to mount
COPY_DIR=$VM_DIR/copy
mkdir -p $COPY_DIR


if [ ! -e $IMAGES_DIR/$IMAGE_FNAME ]; then
    cd $TOOLS_DIR
    ./make_image.sh -m -r 5000  natty raw
    mv natty.raw $BASE_IMAGE
    cd $TOP_DIR
fi

function unmount_images() {
    # unmount the filesystem
    while df | grep -q $COPY_DIR; do
        umount $COPY_DIR || echo 'ok'
        sleep 1
    done
}

# unmount from failed runs
unmount_images

function kill_tail() {
    unmount_images
    exit 1
}

if [ ! -e $BASE_IMAGE_COPY ]; then
    cp -p $BASE_IMAGE $BASE_IMAGE_COPY
fi

# Install deps
apt-get install -y kvm libvirt-bin kpartx

# Let Ctrl-c kill tail and exit
trap kill_tail SIGINT

# Where code will live in image
DEST=${DEST:-/opt/stack}

# Mount the file system
mount -o loop,offset=32256 $BASE_IMAGE_COPY  $COPY_DIR

# git clone only if directory doesn't exist already.  Since ``DEST`` might not
# be owned by the installation user, we create the directory and change the
# ownership to the proper user.
function git_clone {
    if [ ! -d $2 ]; then
        sudo mkdir $2
        sudo chown `whoami` $2
        git clone $1 $2
        cd $2
        # This checkout syntax works for both branches and tags
        git checkout $3
    fi
}

# Make sure that base requirements are installed
cp /etc/resolv.conf $COPY_DIR/etc/resolv.conf
chroot $COPY_DIR apt-get update
chroot $COPY_DIR apt-get install -y --force-yes `cat files/apts/* | cut -d\# -f1 | egrep -v "(rabbitmq|libvirt-bin|mysql-server)"`
chroot $COPY_DIR apt-get install -y --download-only rabbitmq-server libvirt-bin mysql-server
chroot $COPY_DIR pip install `cat files/pips/*`

# Clean out code repos if directed to do so
if [ "$CLEAN" = "1" ]; then
    rm -rf $COPY_DIR/$DEST
fi

# Cache openstack code
mkdir -p $COPY_DIR/$DEST
git_clone $NOVA_REPO $COPY_DIR/$DEST/nova $NOVA_BRANCH
git_clone $GLANCE_REPO $COPY_DIR/$DEST/glance $GLANCE_BRANCH
git_clone $KEYSTONE_REPO $COPY_DIR/$DESTkeystone $KEYSTONE_BRANCH
git_clone $NOVNC_REPO $COPY_DIR/$DEST/noVNC $NOVNC_BRANCH
git_clone $DASH_REPO $COPY_DIR/$DEST/dash $DASH_BRANCH $DASH_TAG
git_clone $NOVACLIENT_REPO $COPY_DIR/$DEST/python-novaclient $NOVACLIENT_BRANCH
git_clone $OPENSTACKX_REPO $COPY_DIR/$DEST/openstackx $OPENSTACKX_BRANCH
git_clone $KEYSTONE_REPO $COPY_DIR/$DEST/keystone $KEYSTONE_BRANCH
git_clone $NOVNC_REPO $COPY_DIR/$DEST/noVNC $NOVNC_BRANCH

# unmount the filesystems
unmount_images

rm -f $VM_DIR/kernel
rm -f $VM_DIR/disk

cd $VM_DIR
qemu-img create -f qcow2 -b $BASE_IMAGE_COPY disk

BRIDGE=${BRIDGE:-br0}
CONTAINER=${CONTAINER:-STACK}
CONTAINER_IP=${CONTAINER_IP:-192.168.1.50}
CONTAINER_CIDR=${CONTAINER_CIDR:-$CONTAINER_IP/24}
CONTAINER_NETMASK=${CONTAINER_NETMASK:-255.255.255.0}
CONTAINER_GATEWAY=${CONTAINER_GATEWAY:-192.168.1.1}
CONTAINER_MAC=${CONTAINER_MAC:-02:16:3e:07:70:d7}

# Create configuration
LIBVIRT_XML=libvirt.xml
cat > $LIBVIRT_XML <<EOF
<domain type='kvm'>
    <name>$VM_NAME</name>
    <memory>1524288</memory>
    <os>
            <type>hvm</type>
            <bootmenu enable='yes'/>
<!--
            <kernel>$VM_DIR/kernel</kernel>
                <cmdline>root=/dev/vda console=ttyS0</cmdline>
-->
    </os>
    <features>
        <acpi/>
    </features>
    <vcpu>1</vcpu>
    <devices>
        <disk type='file'>
            <driver type='qcow2'/>
            <source file='$VM_DIR/disk'/>
            <target dev='vda' bus='virtio'/>
        </disk>

        <interface type='bridge'>
            <source bridge='$BRIDGE'/>
            <mac address='$CONTAINER_MAC'/>
        </interface>

        <!-- The order is significant here.  File must be defined first -->
        <serial type="file">
            <source path='$VM_DIR/console.log'/>
            <target port='1'/>
        </serial>

        <console type='pty' tty='/dev/pts/2'>
            <source path='/dev/pts/2'/>
            <target port='0'/>
        </console>

        <serial type='pty'>
            <source path='/dev/pts/2'/>
            <target port='0'/>
        </serial>

        <graphics type='vnc' port='-1' autoport='yes' keymap='en-us' listen='0.0.0.0'/>
    </devices>
</domain>
EOF

ROOTFS=$VM_DIR/root
mkdir -p $ROOTFS

modprobe nbd max_part=63

umount $ROOTFS || echo 'ok'
qemu-nbd -d /dev/nbd5 || echo 'ok'

qemu-nbd -c /dev/nbd5 disk
mount /dev/nbd5 $ROOTFS -o offset=32256 -t ext4

# Configure instance network
INTERFACES=$ROOTFS/etc/network/interfaces
cat > $INTERFACES <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
        address $CONTAINER_IP
        netmask $CONTAINER_NETMASK
        gateway $CONTAINER_GATEWAY
EOF

chroot $ROOTFS groupadd libvirtd
chroot $ROOTFS useradd stack -s /bin/bash -d $DEST -G libvirtd
cp -pr $TOOLS_DIR/.. $ROOTFS/$DEST/devstack
echo "root:$ROOT_PASSWORD" | chroot $ROOTFS chpasswd

# a simple password - pass
echo "stack:pass" | chroot $ROOTFS chpasswd

# stack requires)
echo "stack ALL=(ALL) NOPASSWD: ALL" >> $ROOTFS/etc/sudoers

# Gracefully cp only if source file/dir exists
function cp_it {
    if [ -e $1 ] || [ -d $1 ]; then
        cp -pRL $1 $2
    fi
}

# Copy over your ssh keys and env if desired
COPYENV=${COPYENV:-1}
if [ "$COPYENV" = "1" ]; then
    cp_it ~/.ssh $ROOTFS/$DEST/.ssh
    cp_it ~/.ssh/id_rsa.pub $ROOTFS/$DEST/.ssh/authorized_keys
    cp_it ~/.gitconfig $ROOTFS/$DEST/.gitconfig
    cp_it ~/.vimrc $ROOTFS/$DEST/.vimrc
    cp_it ~/.bashrc $ROOTFS/$DEST/.bashrc
fi

# Configure the runner
RUN_SH=$ROOTFS/$DEST/run.sh
cat > $RUN_SH <<EOF
#!/usr/bin/env bash
sleep 1

# Kill any existing screens
killall screen

# Install and run stack.sh
sudo apt-get update
sudo apt-get -y --force-yes install git-core vim-nox sudo
if [ ! -d "$DEST/devstack" ]; then
    git clone git://github.com/cloudbuilders/devstack.git $DEST/devstack
fi
cd $DEST/devstack && $STACKSH_PARAMS FORCE=yes ./stack.sh > /$DEST/run.sh.log
echo >> /$DEST/run.sh.log
echo >> /$DEST/run.sh.log
echo "All done! Time to start clicking." >> /$DEST/run.sh.log
EOF

# Make the run.sh executable
chmod 755 $RUN_SH

# Make runner launch on boot
RC_LOCAL=$ROOTFS/etc/init.d/local
cat > $RC_LOCAL <<EOF
#!/bin/sh -e
su -c "$DEST/run.sh" stack
EOF

# Make our ip address hostnames look nice at the command prompt
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> $ROOTFS/$DEST/.bashrc
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> $ROOTFS/etc/profile

# Give stack ownership over $DEST so it may do the work needed
chroot $ROOTFS chown -R stack $DEST

chmod +x $RC_LOCAL
chroot $ROOTFS sudo update-rc.d local defaults 80

sudo sed -e "s/quiet splash/splash console=ttyS0 console=ttyS1,19200n8/g" -i $ROOTFS/boot/grub/menu.lst

umount $ROOTFS
qemu-nbd -d /dev/nbd5

cd $VM_DIR
virsh create libvirt.xml
