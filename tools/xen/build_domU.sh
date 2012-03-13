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
    ./configure --with-curl --with-expat
    make install
    cd $TOP_DIR
fi

# Helper to create networks
# Uses echo trickery to return network uuid
function create_network() {
    br=$1
    dev=$2
    vlan=$3
    netname=$4
    if [ -z $br ]
    then
        pif=$(xe pif-list --minimal device=$dev VLAN=$vlan)
        if [ -z $pif ]
        then
            net=$(xe network-create name-label=$netname)
        else
            net=$(xe network-list --minimal PIF-uuids=$pif)
        fi
        echo $net
        return 0
    fi
    if [ ! $(xe network-list --minimal params=bridge | grep -w --only-matching $br) ]
    then
        echo "Specified bridge $br does not exist"
        echo "If you wish to use defaults, please keep the bridge name empty"
        exit 1
    else
        net=$(xe network-list --minimal bridge=$br)
        echo $net
    fi
}

function errorcheck() {
    rc=$?
    if [ $rc -ne 0 ]
    then
        exit $rc
    fi
}

# Create host, vm, mgmt, pub networks
VM_NET=$(create_network "$VM_BR" "$VM_DEV" "$VM_VLAN" "vmbr")
errorcheck
MGT_NET=$(create_network "$MGT_BR" "$MGT_DEV" "$MGT_VLAN" "mgtbr")
errorcheck
PUB_NET=$(create_network "$PUB_BR" "$PUB_DEV" "$PUB_VLAN" "pubbr")
errorcheck

# Helper to create vlans
function create_vlan() {
    dev=$1
    vlan=$2
    net=$3
    # VLAN -1 refers to no VLAN (physical network)
    if [ $vlan -eq -1 ]
    then
        return
    fi
    if [ -z $(xe vlan-list --minimal tag=$vlan) ]
    then
        pif=$(xe pif-list --minimal network-uuid=$net)
        # We created a brand new network this time
        if [ -z $pif ]
        then
            pif=$(xe pif-list --minimal device=$dev VLAN=-1)
            xe vlan-create pif-uuid=$pif vlan=$vlan network-uuid=$net
        else
            echo "VLAN does not exist but PIF attached to this network"
            echo "How did we reach here?"
            exit 1
        fi
    fi
}

# Create vlans for vm and management
create_vlan $PUB_DEV $PUB_VLAN $PUB_NET
create_vlan $VM_DEV $VM_VLAN $VM_NET
create_vlan $MGT_DEV $MGT_VLAN $MGT_NET

# dom0 ip
HOST_IP=${HOST_IP:-`ifconfig xenbr0 | grep "inet addr" | cut -d ":" -f2 | sed "s/ .*//"`}

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
    env GIT_SSL_NO_VERIFY=true git clone $NOVA_REPO
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
if [ -z $VM_BR ]; then
    VM_BR=$(xe network-list --minimal uuid=$VM_NET params=bridge)
fi
if [ -z $MGT_BR ]; then
    MGT_BR=$(xe network-list --minimal uuid=$MGT_NET params=bridge)
fi
if [ -z $PUB_BR ]; then
    PUB_BR=$(xe network-list --minimal uuid=$PUB_NET params=bridge)
fi
$TOP_DIR/scripts/install-os-vpx.sh -f $XVA -v $VM_BR -m $MGT_BR -p $PUB_BR -l $GUEST_NAME -w -k "flat_network_bridge=${VM_BR}"

if [ $PUB_IP == "dhcp" ]; then
    PUB_IP=$(xe vm-list --minimal name-label=$GUEST_NAME params=networks |  sed -ne 's,^.*3/ip: \([0-9.]*\).*$,\1,p')
fi

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
