#!/bin/bash

# Abort if localrc is not set
if [ ! -e ../../localrc ]; then
    echo "You must have a localrc with ALL necessary passwords defined before proceeding."
    echo "See the xen README for required passwords."
    exit 1
fi

# This directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Source params - override xenrc params in your localrc to suite your taste
source xenrc

# Echo commands
set -o xtrace

# Check for xva file
if [ ! -e $XVA ]; then
    echo "Missing xva file.  Please run build_xva.sh (ideally on a non dom0 host since the build can require lots of space)."
    echo "Place the resulting xva file in $XVA"
    exit 1
fi

# Make sure we have git
if ! which git; then
    GITDIR=/tmp/git-1.7.7
    cd /tmp
    rm -rf $GITDIR*
    wget http://git-core.googlecode.com/files/git-1.7.7.tar.gz
    tar xfv git-1.7.7.tar.gz
    cd $GITDIR
    ./configure
    make install
    cd $TOP_DIR
fi

# Helper to create networks
function create_network() {
    if ! xe network-list | grep bridge | grep -q $1; then
        echo "Creating bridge $1"
        xe network-create name-label=$1
    fi
}

# Create host, vm, mgmt, pub networks
create_network xapi0
create_network $VM_BR
create_network $MGT_BR
create_network $PUB_BR

# Get the uuid for our physical (public) interface
PIF=`xe pif-list --minimal device=eth0`

# Create networks/bridges for vm and management
VM_NET=`xe network-list --minimal bridge=$VM_BR`
MGT_NET=`xe network-list --minimal bridge=$MGT_BR`

# Helper to create vlans
function create_vlan() {
    pif=$1
    vlan=$2
    net=$3
    if ! xe vlan-list | grep tag | grep -q $vlan; then
        xe vlan-create pif-uuid=$pif vlan=$vlan network-uuid=$net
    fi
}

# Create vlans for vm and management
create_vlan $PIF $VM_VLAN $VM_NET
create_vlan $PIF $MGT_VLAN $MGT_NET

# dom0 ip
HOST_IP=${HOST_IP:-`ifconfig xenbr0 | grep "inet addr" | cut -d ":" -f2 | sed "s/ .*//"`}

# Setup host-only nat rules
HOST_NET=169.254.0.0/16
if ! iptables -L -v -t nat | grep -q $HOST_NET; then
    iptables -t nat -A POSTROUTING -s $HOST_NET -j SNAT --to-source $HOST_IP
    iptables -I FORWARD 1 -s $HOST_NET -j ACCEPT
    /etc/init.d/iptables save
fi

# Set up ip forwarding
if ! grep -q "FORWARD_IPV4=YES" /etc/sysconfig/network; then
    # FIXME: This doesn't work on reboot!
    echo "FORWARD_IPV4=YES" >> /etc/sysconfig/network
fi

# Also, enable ip forwarding in rc.local, since the above trick isn't working
if ! grep -q  "echo 1 >/proc/sys/net/ipv4/ip_forward" /etc/rc.local; then
    echo "echo 1 >/proc/sys/net/ipv4/ip_forward" >> /etc/rc.local
fi

# Enable ip forwarding at runtime as well
echo 1 > /proc/sys/net/ipv4/ip_forward

# Set local storage il8n
SR_UUID=`xe sr-list --minimal name-label="Local storage"`
xe sr-param-set uuid=$SR_UUID other-config:i18n-key=local-storage

# Clean nova if desired
if [ "$CLEAN" = "1" ]; then
    rm -rf $TOP_DIR/nova
fi

# Checkout nova
if [ ! -d $TOP_DIR/nova ]; then
    git clone $NOVA_REPO
    cd $TOP_DIR/nova
    git checkout $NOVA_BRANCH
fi 

# Install plugins
cp -pr $TOP_DIR/nova/plugins/xenserver/xenapi/etc/xapi.d /etc/
chmod a+x /etc/xapi.d/plugins/*
yum --enablerepo=base install -y parted
mkdir -p /boot/guest

# Shutdown previous runs
DO_SHUTDOWN=${DO_SHUTDOWN:-1}
if [ "$DO_SHUTDOWN" = "1" ]; then
    # Shutdown all domU's that created previously
    xe vm-list --minimal name-label="$LABEL" | xargs ./scripts/uninstall-os-vpx.sh

    # Destroy any instances that were launched
    for uuid in `xe vm-list | grep -1 instance | grep uuid | sed "s/.*\: //g"`; do
        echo "Shutting down nova instance $uuid"
        xe vm-unpause uuid=$uuid || true
        xe vm-shutdown uuid=$uuid
        xe vm-destroy uuid=$uuid
    done

    # Destroy orphaned vdis
    for uuid in `xe vdi-list | grep -1 Glance | grep uuid | sed "s/.*\: //g"`; do
        xe vdi-destroy uuid=$uuid
    done
fi

# Start guest
$TOP_DIR/scripts/install-os-vpx.sh -f $XVA -v $VM_BR -m $MGT_BR -p $PUB_BR

# If we have copied our ssh credentials, use ssh to monitor while the installation runs
WAIT_TILL_LAUNCH=${WAIT_TILL_LAUNCH:-1}
if [ "$WAIT_TILL_LAUNCH" = "1" ]  && [ -e ~/.ssh/id_rsa.pub  ] && [ "$COPYENV" = "1" ]; then
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

    set +o xtrace

    while ! ssh -q stack@$PUB_IP "[ -e run.sh.log ]"; do
      sleep 1
    done

    ssh stack@$PUB_IP 'tail -f run.sh.log' &

    TAIL_PID=$!

    function kill_tail() {
        kill $TAIL_PID
        exit 1
    }

    # Let Ctrl-c kill tail and exit
    trap kill_tail SIGINT

    echo "Waiting stack.sh to finish..."
    while ! ssh -q stack@$PUB_IP "grep -q 'stack.sh completed in' run.sh.log"; do
        sleep 1
    done

    kill $TAIL_PID

    if ssh -q stack@$PUB_IP "grep -q 'stack.sh failed' run.sh.log"; then
        exit 1
    fi
    echo ""
    echo "Finished - Zip-a-dee Doo-dah!"
    echo "You can then visit the OpenStack Dashboard"
    echo "at http://$PUB_IP, and contact other services at the usual ports."
else
    echo "################################################################################"
    echo ""
    echo "All Finished!"
    echo "Now, you can monitor the progress of the stack.sh installation by "
    echo "tailing /opt/stack/run.sh.log from within your domU."
    echo ""
    echo "ssh into your domU now: 'ssh stack@$PUB_IP' using your password"
    echo "and then do: 'tail -f /opt/stack/run.sh.log'"
    echo ""
    echo "When the script completes, you can then visit the OpenStack Dashboard"
    echo "at http://$PUB_IP, and contact other services at the usual ports."

fi
