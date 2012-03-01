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

# Directory for xvas
XVA_DIR=$TOP_DIR/xvas

# Create xva dir
mkdir -p $XVA_DIR

# Path to xva
XVA=$XVA_DIR/$GUEST_NAME.xva

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

# Run devstack on launch
cat <<EOF >$STAGING_DIR/etc/rc.local
# network restart required for getting the right gateway
/etc/init.d/networking restart
GUEST_PASSWORD=$GUEST_PASSWORD STAGING_DIR=/ DO_TGZ=0 bash /opt/stack/devstack/tools/xen/prepare_guest.sh > /opt/stack/prepare_guest.log 2>&1
su -c "/opt/stack/run.sh > /opt/stack/run.sh.log" stack
exit 0
EOF

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
if [ $VM_IP == "dhcp" ]; then
    echo 'eth1 on dhcp'
    sed -e "s,iface eth1 inet static,iface eth1 inet dhcp,g" -i $INTERFACES
    sed -e '/@ETH1_/d' -i $INTERFACES
else
    sed -e "s,@ETH1_IP@,$VM_IP,g" -i $INTERFACES
    sed -e "s,@ETH1_NETMASK@,$VM_NETMASK,g" -i $INTERFACES
fi

if [ $MGT_IP == "dhcp" ]; then
    echo 'eth2 on dhcp'
    sed -e "s,iface eth2 inet static,iface eth2 inet dhcp,g" -i $INTERFACES
    sed -e '/@ETH2_/d' -i $INTERFACES
else
    sed -e "s,@ETH2_IP@,$MGT_IP,g" -i $INTERFACES
    sed -e "s,@ETH2_NETMASK@,$MGT_NETMASK,g" -i $INTERFACES
fi

if [ $PUB_IP == "dhcp" ]; then
    echo 'eth3 on dhcp'
    sed -e "s,iface eth3 inet static,iface eth3 inet dhcp,g" -i $INTERFACES
    sed -e '/@ETH3_/d' -i $INTERFACES
else
    sed -e "s,@ETH3_IP@,$PUB_IP,g" -i $INTERFACES
    sed -e "s,@ETH3_NETMASK@,$PUB_NETMASK,g" -i $INTERFACES
fi

if [ -h $STAGING_DIR/sbin/dhclient3 ]; then
    rm -f $STAGING_DIR/sbin/dhclient3
fi

# Gracefully cp only if source file/dir exists
function cp_it {
    if [ -e $1 ] || [ -d $1 ]; then
        cp -pRL $1 $2
    fi
}

# Copy over your ssh keys and env if desired
COPYENV=${COPYENV:-1}
if [ "$COPYENV" = "1" ]; then
    cp_it ~/.ssh $STAGING_DIR/opt/stack/.ssh
    cp_it ~/.ssh/id_rsa.pub $STAGING_DIR/opt/stack/.ssh/authorized_keys
    cp_it ~/.gitconfig $STAGING_DIR/opt/stack/.gitconfig
    cp_it ~/.vimrc $STAGING_DIR/opt/stack/.vimrc
    cp_it ~/.bashrc $STAGING_DIR/opt/stack/.bashrc
fi

# Configure run.sh
cat <<EOF >$STAGING_DIR/opt/stack/run.sh
#!/bin/bash
cd /opt/stack/devstack
killall screen
UPLOAD_LEGACY_TTY=yes HOST_IP=$PUB_IP VIRT_DRIVER=xenserver FORCE=yes MULTI_HOST=1 HOST_IP_IFACE=$HOST_IP_IFACE $STACKSH_PARAMS ./stack.sh
EOF
chmod 755 $STAGING_DIR/opt/stack/run.sh

# Create xva
if [ ! -e $XVA ]; then
    rm -rf /tmp/mkxva*
    UID=0 $SCRIPT_DIR/mkxva -o $XVA -t xva -x $OVA $STAGING_DIR $VDI_MB /tmp/
fi

echo "Built $(basename $XVA).  If your dom0 is on a different machine, copy this to [devstackdir]/tools/xen/$(basename $XVA)"
echo "Also copy your localrc to [devstackdir]"
