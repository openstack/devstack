#!/usr/bin/env bash

# **build_uec.sh**

# Make sure that we have the proper version of ubuntu (only works on oneiric)
if ! egrep -q "oneiric" /etc/lsb-release; then
    echo "This script only works with ubuntu oneiric."
    exit 1
fi

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Import common functions
. $TOP_DIR/functions

cd $TOP_DIR

# Source params
source ./stackrc

# Ubuntu distro to install
DIST_NAME=${DIST_NAME:-oneiric}

# Configure how large the VM should be
GUEST_SIZE=${GUEST_SIZE:-10G}

# exit on error to stop unexpected errors
set -o errexit
set -o xtrace

# Abort if localrc is not set
if [ ! -e $TOP_DIR/localrc ]; then
    echo "You must have a localrc with ALL necessary passwords defined before proceeding."
    echo "See stack.sh for required passwords."
    exit 1
fi

# Install deps if needed
DEPS="kvm libvirt-bin kpartx cloud-utils curl"
apt_get install -y --force-yes $DEPS || true # allow this to fail gracefully for concurrent builds

# Where to store files and instances
WORK_DIR=${WORK_DIR:-/opt/uecstack}

# Where to store images
image_dir=$WORK_DIR/images/$DIST_NAME
mkdir -p $image_dir

# Start over with a clean base image, if desired
if [ $CLEAN_BASE ]; then
    rm -f $image_dir/disk
fi

# Get the base image if it does not yet exist
if [ ! -e $image_dir/disk ]; then
    $TOOLS_DIR/get_uec_image.sh -r $GUEST_SIZE $DIST_NAME $image_dir/disk $image_dir/kernel
fi

# Copy over dev environment if COPY_ENV is set.
# This will also copy over your current devstack.
if [ $COPY_ENV ]; then
    cd $TOOLS_DIR
    ./copy_dev_environment_to_uec.sh $image_dir/disk
fi

# Option to warm the base image with software requirements.
if [ $WARM_CACHE ]; then
    cd $TOOLS_DIR
    ./warm_apts_for_uec.sh $image_dir/disk
fi

# Name of our instance, used by libvirt
GUEST_NAME=${GUEST_NAME:-devstack}

# Mop up after previous runs
virsh destroy $GUEST_NAME || true

# Where this vm is stored
vm_dir=$WORK_DIR/instances/$GUEST_NAME

# Create vm dir and remove old disk
mkdir -p $vm_dir
rm -f $vm_dir/disk

# Create a copy of the base image
qemu-img create -f qcow2 -b $image_dir/disk $vm_dir/disk

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
NET_XML=$vm_dir/net.xml
NET_NAME=${NET_NAME:-devstack-$GUEST_NETWORK}
cat > $NET_XML <<EOF
<network>
  <name>$NET_NAME</name>
  <bridge name="stackbr%d" />
  <forward/>
  <ip address="$GUEST_GATEWAY" netmask="$GUEST_NETMASK">
    <dhcp>
      <range start='192.168.$GUEST_NETWORK.2' end='192.168.$GUEST_NETWORK.127' />
    </dhcp>
  </ip>
</network>
EOF

if [[ "$GUEST_RECREATE_NET" == "yes" ]]; then
    virsh net-destroy $NET_NAME || true
    # destroying the network isn't enough to delete the leases
    rm -f /var/lib/libvirt/dnsmasq/$NET_NAME.leases
    virsh net-create $vm_dir/net.xml
fi

# libvirt.xml configuration
LIBVIRT_XML=$vm_dir/libvirt.xml
cat > $LIBVIRT_XML <<EOF
<domain type='kvm'>
  <name>$GUEST_NAME</name>
  <memory>$GUEST_RAM</memory>
  <os>
    <type>hvm</type>
    <kernel>$image_dir/kernel</kernel>
    <cmdline>root=/dev/vda ro console=ttyS0 init=/usr/lib/cloud-init/uncloud-init ds=nocloud-net;s=http://192.168.$GUEST_NETWORK.1:4567/ ubuntu-pass=ubuntu</cmdline>
  </os>
  <features>
    <acpi/>
  </features>
  <clock offset='utc'/>
  <vcpu>$GUEST_CORES</vcpu>
  <devices>
    <disk type='file'>
      <driver type='qcow2'/>
      <source file='$vm_dir/disk'/>
      <target dev='vda' bus='virtio'/>
    </disk>

    <interface type='network'>
      <source network='$NET_NAME'/>
    </interface>

    <!-- The order is significant here.  File must be defined first -->
    <serial type="file">
      <source path='$vm_dir/console.log'/>
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


rm -rf $vm_dir/uec
cp -r $TOOLS_DIR/uec $vm_dir/uec

# set metadata
cat > $vm_dir/uec/meta-data<<EOF
hostname: $GUEST_NAME
instance-id: i-hop
instance-type: m1.ignore
local-hostname: $GUEST_NAME.local
EOF

# set user-data
cat > $vm_dir/uec/user-data<<EOF
#!/bin/bash
# hostname needs to resolve for rabbit
sed -i "s/127.0.0.1/127.0.0.1 \`hostname\`/" /etc/hosts
apt-get update
apt-get install git sudo -y
# Disable byobu
sudo apt-get remove -y byobu
EOF

# Setup stack user with our key
if [[ -e ~/.ssh/id_rsa.pub ]]; then
    PUB_KEY=`cat  ~/.ssh/id_rsa.pub`
    cat >> $vm_dir/uec/user-data<<EOF
mkdir -p /opt/stack
if [ ! -d /opt/stack/devstack ]; then
    git clone https://github.com/cloudbuilders/devstack.git /opt/stack/devstack
    cd /opt/stack/devstack
    cat > localrc <<LOCAL_EOF
ROOTSLEEP=0
`cat $TOP_DIR/localrc`
LOCAL_EOF
fi
useradd -U -G sudo -s /bin/bash -d /opt/stack -m $STACK_USER
echo $STACK_USER:pass | chpasswd
mkdir -p /opt/stack/.ssh
echo "$PUB_KEY" > /opt/stack/.ssh/authorized_keys
chown -R $STACK_USER /opt/stack
chmod 700 /opt/stack/.ssh
chmod 600 /opt/stack/.ssh/authorized_keys

grep -q "^#includedir.*/etc/sudoers.d" /etc/sudoers ||
    echo "#includedir /etc/sudoers.d" >> /etc/sudoers
( umask 226 && echo "stack ALL=(ALL) NOPASSWD:ALL" \
    > /etc/sudoers.d/50_stack_sh )
EOF
fi

# Run stack.sh
cat >> $vm_dir/uec/user-data<<EOF
sudo -u $STACK_USER bash -l -c "cd /opt/stack/devstack && ./stack.sh"
EOF

# (re)start a metadata service
(
    pid=`lsof -iTCP@192.168.$GUEST_NETWORK.1:4567 -n | awk '{print $2}' | tail -1`
    [ -z "$pid" ] || kill -9 $pid
)
cd $vm_dir/uec
python meta.py 192.168.$GUEST_NETWORK.1:4567 &

# Create the instance
virsh create $vm_dir/libvirt.xml

# Tail the console log till we are done
WAIT_TILL_LAUNCH=${WAIT_TILL_LAUNCH:-1}
if [ "$WAIT_TILL_LAUNCH" = "1" ]; then
    set +o xtrace
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
    echo

    if ! timeout 60 sh -c "while [ ! -s /var/lib/libvirt/dnsmasq/$NET_NAME.leases ]; do sleep 1; done"; then
        echo "Your instance failed to acquire an IP address"
        exit 1
    fi

    ip=`cat /var/lib/libvirt/dnsmasq/$NET_NAME.leases | cut -d " " -f3`
    echo "#############################################################"
    echo "              -- This is your instance's IP: --"
    echo "                           $ip"
    echo "#############################################################"

    sleep 2

    while [ ! -e "$vm_dir/console.log" ]; do
        sleep 1
    done

    tail -F $vm_dir/console.log &

    TAIL_PID=$!

    function kill_tail() {
        kill $TAIL_PID
        exit 1
    }

    # Let Ctrl-c kill tail and exit
    trap kill_tail SIGINT

    echo "Waiting stack.sh to finish..."
    while ! egrep -q '^stack.sh (completed|failed)' $vm_dir/console.log ; do
        sleep 1
    done

    set -o xtrace

    kill $TAIL_PID

    if ! grep -q "^stack.sh completed in" $vm_dir/console.log; then
        exit 1
    fi

    set +o xtrace
    echo ""
    echo "Finished - Zip-a-dee Doo-dah!"
fi
