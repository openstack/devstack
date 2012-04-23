#!/bin/bash

set -e

declare -a on_exit_hooks

on_exit()
{
    for i in $(seq $((${#on_exit_hooks[*]} - 1)) -1 0)
    do
        eval "${on_exit_hooks[$i]}"
    done
}

add_on_exit()
{
    local n=${#on_exit_hooks[*]}
    on_exit_hooks[$n]="$*"
    if [[ $n -eq 0 ]]
    then
        trap on_exit EXIT
    fi
}

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

GUEST_NAME="$1"

# Directory where we stage the build
STAGING_DIR=$($TOP_DIR/scripts/manage-vdi open $GUEST_NAME 0 1 | grep -o "/tmp/tmp.[[:alnum:]]*")
add_on_exit "$TOP_DIR/scripts/manage-vdi close $GUEST_NAME 0 1"

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

# Configure dns (use same dns as dom0)
cp /etc/resolv.conf $STAGING_DIR/etc/resolv.conf

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
GUEST_PASSWORD=$GUEST_PASSWORD STAGING_DIR=/ DO_TGZ=0 bash /opt/stack/devstack/tools/xen/prepare_guest.sh > /opt/stack/prepare_guest.log 2>&1
su -c "/opt/stack/run.sh > /opt/stack/run.sh.log 2>&1" stack
exit 0
EOF

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
UPLOAD_LEGACY_TTY=yes HOST_IP=$PUB_IP VIRT_DRIVER=xenserver FORCE=yes MULTI_HOST=$MULTI_HOST HOST_IP_IFACE=$HOST_IP_IFACE $STACKSH_PARAMS ./stack.sh
EOF
chmod 755 $STAGING_DIR/opt/stack/run.sh

echo "Done"
