#!/usr/bin/env bash

# Make sure that we have the proper version of ubuntu
UBUNTU_VERSION=`cat /etc/lsb-release | grep CODENAME | sed 's/.*=//g'`
if [ ! "oneiric" = "$UBUNTU_VERSION" ]; then
    if [ ! "natty" = "$UBUNTU_VERSION" ]; then
        echo "This script only works with oneiric and natty"
        exit 1
    fi
fi

# exit on error to stop unexpected errors
set -o errexit

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

# Abort if localrc is not set
if [ ! -e $TOP_DIR/localrc ]; then
    echo "You must have a localrc with ALL necessary passwords defined before proceeding."
    echo "See stack.sh for required passwords."
    exit 1
fi

# Install deps if needed
dpkg -l kvm libvirt-bin kpartx || apt-get install -y --force-yes kvm libvirt-bin kpartx

# Where to store files and instances
WORK_DIR=${WORK_DIR:-/opt/kvmstack}

# Where to store images
IMAGES_DIR=$WORK_DIR/images

# Original version of built image
DIST_NAME=${DIST_NAME:oneiric}
UEC_NAME=$DIST_NAME-server-cloudimg-amd64
UEC_URL=http://uec-images.ubuntu.com/$DIST_NAME/current/$UEC_NAME-disk1.img
BASE_IMAGE=$IMAGES_DIR/$DIST_NAME.raw

# download the base uec image if we haven't already
if [ ! -e $BASE_IMAGE ]; then
    mkdir -p $IMAGES_DIR
    curl $UEC_URL -O $BASE_IMAGE
fi

cd $TOP_DIR

# Source params
source ./stackrc

# Configure the root password of the vm to be the same as ``ADMIN_PASSWORD``
ROOT_PASSWORD=${ADMIN_PASSWORD:-password}

# Name of our instance, used by libvirt
GUEST_NAME=${GUEST_NAME:-devstack}

# Mop up after previous runs
virsh destroy $GUEST_NAME || true

# Where this vm is stored
VM_DIR=$WORK_DIR/instances/$GUEST_NAME

# Create vm dir and remove old disk
mkdir -p $VM_DIR
rm -f $VM_DIR/disk.img

# Create a copy of the base image
qemu-img create -f qcow2 -b ${BASE_IMAGE} $VM_DIR/disk.img

# Back to devstack
cd $TOP_DIR

GUEST_NETWORK=${GUEST_NETWORK:-1}
GUEST_RECREATE_NET=${GUEST_RECREATE_NET:-yes}
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

if [[ "$GUEST_RECREATE_NET" == "yes" ]]; then
    virsh net-destroy devstack-$GUEST_NETWORK || true
    virsh net-create $VM_DIR/net.xml
fi

# libvirt.xml configuration
LIBVIRT_XML=$VM_DIR/libvirt.xml
cat > $LIBVIRT_XML <<EOF
<domain type='kvm'>
  <name>$GUEST_NAME</name>
  <memory>$GUEST_RAM</memory>
  <os>
    <type arch='i686' machine='pc'>hvm</type>
    <boot dev='hd'/>
    <kernel>$VM_DIR/kernel</kernel>
    <cmdline>root=/dev/vda ro init=/usr/lib/cloud-init/uncloud-init ds=nocloud ubuntu-pass=ubuntu</cmdline>
  </os>
  <features>
    <acpi/>
  </features>
  <clock offset='utc'/>
  <vcpu>$GUEST_CORES</vcpu>
  <devices>
    <disk type='file'>
      <driver type='qcow2'/>
      <source file='$VM_DIR/disk.img'/>
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
