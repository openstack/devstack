#!/bin/bash

# Abort if localrc is not set
if [ ! -e ../../localrc ]; then
    echo "You must have a localrc with ALL necessary passwords defined before proceeding."
    echo "See the xen README for required passwords."
    exit 1
fi

# Echo commands
set -o xtrace

# Name of this guest
GUEST_NAME=${GUEST_NAME:-ALLINONE}

# dom0 ip
HOST_IP=${HOST_IP:-`ifconfig xenbr0 | grep "inet addr" | cut -d ":" -f2 | sed "s/ .*//"`}

# Our nova host's network info 
VM_IP=${VM_IP:-10.255.255.255} # A host-only ip that let's the interface come up, otherwise unused
MGT_IP=${MGT_IP:-172.16.100.55}
PUB_IP=${PUB_IP:-192.168.1.55}

# Public network
PUB_BR=${PUB_BR:-xenbr0}
PUB_NETMASK=${PUB_NETMASK:-255.255.255.0}

# VM network params
VM_NETMASK=${VM_NETMASK:-255.255.255.0}
VM_BR=${VM_BR:-xenbr1}
VM_VLAN=${VM_VLAN:-100}

# MGMT network params
MGT_NETMASK=${MGT_NETMASK:-255.255.255.0}
MGT_BR=${MGT_BR:-xenbr2}
MGT_VLAN=${MGT_VLAN:-101}

# VM Password
GUEST_PASSWORD=${GUEST_PASSWORD:-secrete}

# Size of image
VDI_MB=${VDI_MB:-2500}

# This directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

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

# Directory where we stage the build
STAGING_DIR=$TOP_DIR/stage

# Option to clean out old stuff
CLEAN=${CLEAN:-0}
if [ "$CLEAN" = "1" ]; then
    rm -rf $STAGING_DIR
fi

# Download our base image.  This image is made using prepare_guest.sh
BASE_IMAGE_URL=${BASE_IMAGE_URL:-http://images.ansolabs.com/xen/stage.tgz}
if [ ! -e $STAGING_DIR ]; then
    if [ ! -e /tmp/stage.tgz ]; then
        wget $BASE_IMAGE_URL -O /tmp/stage.tgz
    fi
    tar xfz /tmp/stage.tgz
    cd $TOP_DIR
fi

# Free up precious disk space
rm -f /tmp/stage.tgz

# Make sure we have a stage
if [ ! -d $STAGING_DIR/etc ]; then
    echo "Stage is not properly set up!"
    exit 1
fi

# Directory where our conf files are stored
FILES_DIR=$TOP_DIR/files
TEMPLATES_DIR=$TOP_DIR/templates

# Directory for supporting script files
SCRIPT_DIR=$TOP_DIR/scripts

# Version of ubuntu with which we are working
UBUNTU_VERSION=`cat $STAGING_DIR/etc/lsb-release | grep "DISTRIB_CODENAME=" | sed "s/DISTRIB_CODENAME=//"`
KERNEL_VERSION=`ls $STAGING_DIR/boot/vmlinuz* | head -1 | sed "s/.*vmlinuz-//"`

# Setup fake grub
rm -rf $STAGING_DIR/boot/grub/
mkdir -p $STAGING_DIR/boot/grub/
cp $TEMPLATES_DIR/menu.lst.in $STAGING_DIR/boot/grub/menu.lst
sed -e "s,@KERNEL_VERSION@,$KERNEL_VERSION,g" -i $STAGING_DIR/boot/grub/menu.lst

# Setup fstab, tty, and other system stuff
cp $FILES_DIR/fstab $STAGING_DIR/etc/fstab
cp $FILES_DIR/hvc0.conf $STAGING_DIR/etc/init/

# Put the VPX into UTC.
rm -f $STAGING_DIR/etc/localtime

# Configure dns (use same dns as dom0)
cp /etc/resolv.conf $STAGING_DIR/etc/resolv.conf

# Copy over devstack
rm -f /tmp/devstack.tar
tar --exclude='stage' --exclude='xen/xvas' --exclude='xen/nova' -cvf /tmp/devstack.tar $TOP_DIR/../../../devstack
cd $STAGING_DIR/opt/stack/
tar xf /tmp/devstack.tar
cd $TOP_DIR

# Configure OVA
VDI_SIZE=$(($VDI_MB*1024*1024))
PRODUCT_BRAND=${PRODUCT_BRAND:-openstack}
PRODUCT_VERSION=${PRODUCT_VERSION:-001}
BUILD_NUMBER=${BUILD_NUMBER:-001}
LABEL="$PRODUCT_BRAND $PRODUCT_VERSION-$BUILD_NUMBER"
OVA=$STAGING_DIR/tmp/ova.xml
cp $TEMPLATES_DIR/ova.xml.in  $OVA
sed -e "s,@VDI_SIZE@,$VDI_SIZE,g" -i $OVA
sed -e "s,@PRODUCT_BRAND@,$PRODUCT_BRAND,g" -i $OVA
sed -e "s,@PRODUCT_VERSION@,$PRODUCT_VERSION,g" -i $OVA
sed -e "s,@BUILD_NUMBER@,$BUILD_NUMBER,g" -i $OVA

# Directory for xvas
XVA_DIR=$TOP_DIR/xvas

# Create xva dir
mkdir -p $XVA_DIR

# Clean nova if desired
if [ "$CLEAN" = "1" ]; then
    rm -rf $TOP_DIR/nova
fi

# Checkout nova
if [ ! -d $TOP_DIR/nova ]; then
    git clone git://github.com/cloudbuilders/nova.git
    git checkout diablo
fi 

# Run devstack on launch
cat <<EOF >$STAGING_DIR/etc/rc.local
GUEST_PASSWORD=$GUEST_PASSWORD STAGING_DIR=/ DO_TGZ=0 bash /opt/stack/devstack/tools/xen/prepare_guest.sh
su -c "/opt/stack/run.sh > /opt/stack/run.sh.log" stack
exit 0
EOF

# Install plugins
cp -pr $TOP_DIR/nova/plugins/xenserver/xenapi/etc/xapi.d /etc/
chmod a+x /etc/xapi.d/plugins/*
yum --enablerepo=base install -y parted
mkdir -p /boot/guest

# Set local storage il8n
SR_UUID=`xe sr-list --minimal name-label="Local storage"`
xe sr-param-set uuid=$SR_UUID other-config:i18n-key=local-storage

# Uninstall previous runs
xe vm-list --minimal name-label="$LABEL" | xargs ./scripts/uninstall-os-vpx.sh

# Destroy any instances that were launched
for uuid in `xe vm-list | grep -1 instance | grep uuid | sed "s/.*\: //g"`; do
    echo "Shutting down nova instance $uuid"
    xe vm-shutdown uuid=$uuid
    xe vm-destroy uuid=$uuid
done

# Path to head xva.  By default keep overwriting the same one to save space
USE_SEPARATE_XVAS=${USE_SEPARATE_XVAS:-0}
if [ "$USE_SEPARATE_XVAS" = "0" ]; then
    XVA=$XVA_DIR/$UBUNTU_VERSION.xva 
else
    XVA=$XVA_DIR/$UBUNTU_VERSION.$GUEST_NAME.xva 
fi

# Clean old xva. In the future may not do this every time.
rm -f $XVA

# Configure the hostname
echo $GUEST_NAME > $STAGING_DIR/etc/hostname

# Hostname must resolve for rabbit
cat <<EOF >$STAGING_DIR/etc/hosts
$MGT_IP $GUEST_NAME
127.0.0.1 localhost localhost.localdomain
EOF

# Configure the network
INTERFACES=$STAGING_DIR/etc/network/interfaces
cp $TEMPLATES_DIR/interfaces.in  $INTERFACES
sed -e "s,@ETH1_IP@,$VM_IP,g" -i $INTERFACES
sed -e "s,@ETH1_NETMASK@,$VM_NETMASK,g" -i $INTERFACES
sed -e "s,@ETH2_IP@,$MGT_IP,g" -i $INTERFACES
sed -e "s,@ETH2_NETMASK@,$MGT_NETMASK,g" -i $INTERFACES
sed -e "s,@ETH3_IP@,$PUB_IP,g" -i $INTERFACES
sed -e "s,@ETH3_NETMASK@,$PUB_NETMASK,g" -i $INTERFACES

# Configure run.sh
cat <<EOF >$STAGING_DIR/opt/stack/run.sh
#!/bin/bash
cd /opt/stack/devstack
killall screen
UPLOAD_LEGACY_TTY=yes HOST_IP=$PUB_IP VIRT_DRIVER=xenserver FORCE=yes MULTI_HOST=1 $STACKSH_PARAMS ./stack.sh
EOF
chmod 755 $STAGING_DIR/opt/stack/run.sh

# Create xva
if [ ! -e $XVA ]; then
    rm -rf /tmp/mkxva*
    UID=0 $SCRIPT_DIR/mkxva -o $XVA -t xva -x $OVA $STAGING_DIR $VDI_MB /tmp/
fi

# Start guest
$TOP_DIR/scripts/install-os-vpx.sh -f $XVA -v $VM_BR -m $MGT_BR -p $PUB_BR

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
