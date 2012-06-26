#!/bin/bash

# This script is run by install_os_domU.sh
#
# It modifies the ubuntu image created by install_os_domU.sh
# and previously moodified by prepare_guest_template.sh
#
# This script is responsible for:
# - pushing in the DevStack code
# - creating run.sh, to run the code on boot
# It does this by mounting the disk image of the VM.
#
# The resultant image is then templated and started
# by install_os_domU.sh

# Exit on errors
set -o errexit
# Echo commands
set -o xtrace

# This directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Include onexit commands
. $TOP_DIR/scripts/on_exit.sh

# Source params - override xenrc params in your localrc to suite your taste
source xenrc

#
# Parameters
#
GUEST_NAME="$1"

#
# Mount the VDI
#
STAGING_DIR=$($TOP_DIR/scripts/manage-vdi open $GUEST_NAME 0 1 | grep -o "/tmp/tmp.[[:alnum:]]*")
add_on_exit "$TOP_DIR/scripts/manage-vdi close $GUEST_NAME 0 1"

# Make sure we have a stage
if [ ! -d $STAGING_DIR/etc ]; then
    echo "Stage is not properly set up!"
    exit 1
fi

# Configure dns (use same dns as dom0)
# but only when not precise
if [ "$UBUNTU_INST_RELEASE" != "precise" ]; then
    cp /etc/resolv.conf $STAGING_DIR/etc/resolv.conf
elif [ "$MGT_IP" != "dhcp" ] && [ "$PUB_IP" != "dhcp" ]; then
    echo "Configuration without DHCP not supported on Precise"
    exit 1
fi

# Copy over devstack
rm -f /tmp/devstack.tar
cd $TOP_DIR/../../
tar --exclude='stage' --exclude='xen/xvas' --exclude='xen/nova' -cvf /tmp/devstack.tar .
mkdir -p $STAGING_DIR/opt/stack/devstack
tar xf /tmp/devstack.tar -C $STAGING_DIR/opt/stack/devstack
cd $TOP_DIR

# Run devstack on launch
cat <<EOF >$STAGING_DIR/etc/rc.local
# network restart required for getting the right gateway
/etc/init.d/networking restart
chown -R stack /opt/stack
su -c "/opt/stack/run.sh > /opt/stack/run.sh.log 2>&1" stack
exit 0
EOF

# Configure the hostname
echo $GUEST_NAME > $STAGING_DIR/etc/hostname

# Hostname must resolve for rabbit
HOSTS_FILE_IP=$PUB_IP
if [ $MGT_IP != "dhcp" ]; then
    HOSTS_FILE_IP=$MGT_IP
fi
cat <<EOF >$STAGING_DIR/etc/hosts
$HOSTS_FILE_IP $GUEST_NAME
127.0.0.1 localhost localhost.localdomain
EOF

# Configure the network
INTERFACES=$STAGING_DIR/etc/network/interfaces
TEMPLATES_DIR=$TOP_DIR/templates
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

if [ "$ENABLE_GI" == "true" ]; then
    cat <<EOF >>$INTERFACES
auto eth0
iface eth0 inet dhcp
EOF
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
VIRT_DRIVER=xenserver FORCE=yes MULTI_HOST=$MULTI_HOST HOST_IP_IFACE=$HOST_IP_IFACE $STACKSH_PARAMS ./stack.sh
EOF
chmod 755 $STAGING_DIR/opt/stack/run.sh
