#!/usr/bin/env bash

# exit on error to stop unexpected errors
set -o errexit

# Make sure that we have the proper version of ubuntu
UBUNTU_VERSION=`cat /etc/lsb-release | grep CODENAME | sed 's/.*=//g'`
if [ ! "oneiric" = "$UBUNTU_VERSION" ]; then
    if [ ! "natty" = "$UBUNTU_VERSION" ]; then
        echo "This script only works with oneiric and natty"
        exit 1
    fi
fi

# Echo commands
set -o xtrace

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

# Where to store files and instances
WORK_DIR=${WORK_DIR:-/opt/kvmstack}

# Where to store images
IMAGES_DIR=$WORK_DIR/images

# Create images dir
mkdir -p $IMAGES_DIR

# Abort if localrc is not set
if [ ! -e $TOP_DIR/localrc ]; then
    echo "You must have a localrc with ALL necessary passwords defined before proceeding."
    echo "See stack.sh for required passwords."
    exit 1
fi

cd $TOP_DIR

# Source params
source ./stackrc

# Configure the root password of the vm to be the same as ``ADMIN_PASSWORD``
ROOT_PASSWORD=${ADMIN_PASSWORD:-password}

# Base image (natty by default)
DIST_NAME=${DIST_NAME:-natty}
IMAGE_FNAME=$DIST_NAME.raw

# Name of our instance, used by libvirt
GUEST_NAME=${GUEST_NAME:-devstack}

# Original version of built image
BASE_IMAGE=$IMAGES_DIR/$DIST_NAME.raw

# Copy of base image, which we pre-install with tasty treats
VM_IMAGE=$IMAGES_DIR/$DIST_NAME.$GUEST_NAME.raw

# Mop up after previous runs
virsh destroy $GUEST_NAME || true

# Where this vm is stored
VM_DIR=$WORK_DIR/instances/$GUEST_NAME

# Create vm dir
mkdir -p $VM_DIR

# Mount point into copied base image
COPY_DIR=$VM_DIR/copy
mkdir -p $COPY_DIR

# Get the base image if it does not yet exist
if [ ! -e $BASE_IMAGE ]; then
    $TOOLS_DIR/get_uec_image.sh -f raw -r 5000 $DIST_NAME $BASE_IMAGE
fi

# Create a copy of the base image
if [ ! -e $VM_IMAGE ]; then
    cp -p $BASE_IMAGE $VM_IMAGE
fi

# Unmount the copied base image
function unmount_images() {
    # unmount the filesystem
    while df | grep -q $COPY_DIR; do
        umount $COPY_DIR || echo 'ok'
        sleep 1
    done
}

# Unmount from failed runs
unmount_images

# Ctrl-c catcher
function kill_unmount() {
    unmount_images
    exit 1
}

# Install deps if needed
dpkg -l kvm libvirt-bin kpartx || apt-get install -y --force-yes kvm libvirt-bin kpartx

# Let Ctrl-c kill tail and exit
trap kill_unmount SIGINT

# Where Openstack code will live in image
DEST=${DEST:-/opt/stack}

# Mount the file system
# For some reason, UEC-based images want 255 heads * 63 sectors * 512 byte sectors = 8225280
mount -t ext4 -o loop,offset=8225280 $VM_IMAGE $COPY_DIR

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
git_clone $HORIZON_REPO $COPY_DIR/$DEST/horizon $HORIZON_BRANCH $HORIZON_TAG
git_clone $NOVACLIENT_REPO $COPY_DIR/$DEST/python-novaclient $NOVACLIENT_BRANCH
git_clone $OPENSTACKX_REPO $COPY_DIR/$DEST/openstackx $OPENSTACKX_BRANCH
git_clone $KEYSTONE_REPO $COPY_DIR/$DEST/keystone $KEYSTONE_BRANCH
git_clone $NOVNC_REPO $COPY_DIR/$DEST/noVNC $NOVNC_BRANCH

# Back to devstack
cd $TOP_DIR

# Unmount the filesystems
unmount_images

# Network configuration variables
GUEST_NETWORK=${GUEST_NETWORK:-1}

GUEST_IP=${GUEST_IP:-192.168.$GUEST_NETWORK.50}
GUEST_CIDR=${GUEST_CIDR:-$GUEST_IP/24}
GUEST_NETMASK=${GUEST_NETMASK:-255.255.255.0}
GUEST_GATEWAY=${GUEST_GATEWAY:-192.168.$GUEST_NETWORK.1}
GUEST_MAC=${GUEST_MAC:-"02:16:3e:07:69:`printf '%02X' $GUEST_NETWORK`"}
GUEST_RAM=${GUEST_RAM:-1524288}
GUEST_CORES=${GUEST_CORES:-1}

# libvirt.xml configuration
NET_XML=$VM_DIR/net.xml
cat > $NET_XML <<EOF
<network>
  <name>devstack-$GUEST_NETWORK</name>
  <bridge name="stackbr%d" />
  <forward/>
  <ip address="$GUEST_GATEWAY" netmask="$GUEST_NETMASK" />
</network>
EOF

virsh net-destroy devstack-$GUEST_NETWORK || true
virsh net-create $VM_DIR/net.xml

# libvirt.xml configuration
LIBVIRT_XML=$VM_DIR/libvirt.xml
cat > $LIBVIRT_XML <<EOF
<domain type='kvm'>
    <name>$GUEST_NAME</name>
    <memory>$GUEST_RAM</memory>
    <os>
        <type>hvm</type>
        <bootmenu enable='yes'/>
    </os>
    <features>
        <acpi/>
    </features>
    <vcpu>$GUEST_CORES</vcpu>
    <devices>
        <disk type='file'>
            <driver type='qcow2'/>
            <source file='$VM_DIR/disk'/>
            <target dev='vda' bus='virtio'/>
        </disk>

        <interface type='network'>
           <source network='devstack-$GUEST_NETWORK'/>
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

# Mount point for instance fs
ROOTFS=$VM_DIR/root
mkdir -p $ROOTFS

# Clean up from previous runs
umount $ROOTFS || echo 'ok'

# Clean up old runs
cd $VM_DIR
rm -f $VM_DIR/disk

# Create our instance fs
qemu-img create -f qcow2 -b $VM_IMAGE disk

# Make sure we have nbd-ness
modprobe nbd max_part=63

# Set up nbd
for i in `seq 0 15`; do
    if [ ! -e /sys/block/nbd$i/pid ]; then
        NBD=/dev/nbd$i
        # Connect to nbd and wait till it is ready
        qemu-nbd -c $NBD disk
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
NBD_DEV=`basename $NBD`

# Mount the instance
mount ${NBD}p1 $ROOTFS

# Configure instance network
INTERFACES=$ROOTFS/etc/network/interfaces
cat > $INTERFACES <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
        address $GUEST_IP
        netmask $GUEST_NETMASK
        gateway $GUEST_GATEWAY
EOF

# User configuration for the instance
chroot $ROOTFS groupadd libvirtd || true
chroot $ROOTFS useradd stack -s /bin/bash -d $DEST -G libvirtd
cp -pr $TOP_DIR $ROOTFS/$DEST/devstack
echo "root:$ROOT_PASSWORD" | chroot $ROOTFS chpasswd
echo "stack:pass" | chroot $ROOTFS chpasswd
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

# pre-cache uec images
for image_url in ${IMAGE_URLS//,/ }; do
    IMAGE_FNAME=`basename "$image_url"`
    if [ ! -f $IMAGES_DIR/$IMAGE_FNAME ]; then
        wget -c $image_url -O $IMAGES_DIR/$IMAGE_FNAME
    fi
    cp $IMAGES_DIR/$IMAGE_FNAME $ROOTFS/$DEST/devstack/files
done

# Configure the runner
RUN_SH=$ROOTFS/$DEST/run.sh
cat > $RUN_SH <<EOF
#!/usr/bin/env bash

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
cat $DEST/run.sh.log
EOF
chmod 755 $RUN_SH

# Make runner launch on boot
RC_LOCAL=$ROOTFS/etc/init.d/zlocal
cat > $RC_LOCAL <<EOF
#!/bin/sh -e
# cloud-init overwrites the hostname with ubuntuhost
echo $GUEST_NAME > /etc/hostname
hostname $GUEST_NAME
su -c "$DEST/run.sh" stack
EOF
chmod +x $RC_LOCAL
chroot $ROOTFS sudo update-rc.d zlocal defaults 99

# Make our ip address hostnames look nice at the command prompt
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> $ROOTFS/$DEST/.bashrc
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> $ROOTFS/etc/profile

# Give stack ownership over $DEST so it may do the work needed
chroot $ROOTFS chown -R stack $DEST

# Set the hostname
echo $GUEST_NAME > $ROOTFS/etc/hostname

# We need the hostname to resolve for rabbit to launch
if ! grep -q $GUEST_NAME $ROOTFS/etc/hosts; then
    echo "$GUEST_IP $GUEST_NAME" >> $ROOTFS/etc/hosts
fi

# GRUB 2 wants to see /dev
mount -o bind /dev $ROOTFS/dev

# Change boot params so that we get a console log
G_DEV_UUID=`blkid -t LABEL=cloudimg-rootfs -s UUID -o value | head -1`
sed -e "s/GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=3/" -i $ROOTFS/etc/default/grub
sed -e "s,GRUB_CMDLINE_LINUX_DEFAULT=.*$,GRUB_CMDLINE_LINUX_DEFAULT=\"console=ttyS0 console=tty0 ds=nocloud ubuntu-pass=pass\",g" -i $ROOTFS/etc/default/grub
sed -e 's/[#]*GRUB_TERMINAL=.*$/GRUB_TERMINAL="serial console"/' -i $ROOTFS/etc/default/grub
echo 'GRUB_SERIAL_COMMAND="serial --unit=0"' >>$ROOTFS/etc/default/grub
echo 'GRUB_DISABLE_OS_PROBER=true' >>$ROOTFS/etc/default/grub
echo "GRUB_DEVICE_UUID=$G_DEV_UUID" >>$ROOTFS/etc/default/grub

chroot $ROOTFS update-grub
umount $ROOTFS/dev

# Pre-generate ssh host keys and allow password login
chroot $ROOTFS dpkg-reconfigure openssh-server
sed -e 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' -i $ROOTFS/etc/ssh/sshd_config

# Unmount
umount $ROOTFS || echo 'ok'
qemu-nbd -d $NBD

# Create the instance
cd $VM_DIR && virsh create libvirt.xml

# Tail the console log till we are done
WAIT_TILL_LAUNCH=${WAIT_TILL_LAUNCH:-1}
if [ "$WAIT_TILL_LAUNCH" = "1" ]; then
    # Done creating the container, let's tail the log
    echo
    echo "============================================================="
    echo "                          -- YAY! --"
    echo "============================================================="
    echo
    echo "We're done launching the vm, about to start tailing the"
    echo "stack.sh log. It will take a second or two to start."
    echo
    echo "Just CTRL-C at any time to stop tailing."

    while [ ! -e "$VM_DIR/console.log" ]; do
      sleep 1
    done

    tail -F $VM_DIR/console.log &

    TAIL_PID=$!

    function kill_tail() {
        kill $TAIL_PID
        exit 1
    }

    # Let Ctrl-c kill tail and exit
    trap kill_tail SIGINT

    set +o xtrace

    echo "Waiting stack.sh to finish..."
    while ! cat $VM_DIR/console.log | grep -q 'All done' ; do
        sleep 1
    done

    set -o xtrace

    kill $TAIL_PID

    if ! grep -q "^stack.sh completed in" $VM_DIR/console.log; then
        exit 1
    fi
    echo ""
    echo "Finished - Zip-a-dee Doo-dah!"
fi
