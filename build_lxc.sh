#!/usr/bin/env bash

# Use stackrc.example if stackrc is missing
if [ ! -e ./stackrc ]; then
    read -n1 -p "No stackrc present.  Copy stackrc.example to stackrc? (y/n) "
    echo
    [[ $REPLY = [yY] ]] && cp stackrc.example stackrc|| { echo "Aborting:  Missing stackrc"; exit 1; }
fi

# Source params
source ./stackrc

# Configurable params
BRIDGE=${BRIDGE:-br0}
CONTAINER=${CONTAINER:-STACK}
CONTAINER_IP=${CONTAINER_IP:-192.168.1.50}
CONTAINER_CIDR=${CONTAINER_CIDR:-$CONTAINER_IP/24}
CONTAINER_NETMASK=${CONTAINER_NETMASK:-255.255.255.0}
CONTAINER_GATEWAY=${CONTAINER_GATEWAY:-192.168.1.1}
NAMESERVER=${NAMESERVER:-$CONTAINER_GATEWAY}
COPYENV=${COPYENV:-1}

# Param string to pass to stack.sh.  Like "EC2_DMZ_HOST=192.168.1.1 MYSQL_USER=nova"
STACKSH_PARAMS=${STACKSH_PARAMS:-}

# Option to use the version of devstack on which we are currently working
USE_CURRENT_DEVSTACK=${USE_CURRENT_DEVSTACK:-1}

# Warn users who aren't on natty
if ! grep -q natty /etc/lsb-release; then
    echo "WARNING: this script has only been tested on natty"
fi

# Install deps
apt-get install -y lxc debootstrap

# Install cgroup-bin from source, since the packaging is buggy and possibly incompatible with our setup
if ! which cgdelete | grep -q cgdelete; then
    apt-get install -y g++ bison flex libpam0g-dev
    wget http://sourceforge.net/projects/libcg/files/libcgroup/v0.37.1/libcgroup-0.37.1.tar.bz2/download -O /tmp/libcgroup-0.37.1.tar.bz2 
    cd /tmp && bunzip2 libcgroup-0.37.1.tar.bz2  && tar xfv libcgroup-0.37.1.tar
    cd libcgroup-0.37.1
    ./configure
    make install
    ldconfig
fi

# Create lxc configuration
LXC_CONF=/tmp/$CONTAINER.conf
cat > $LXC_CONF <<EOF
lxc.network.type = veth
lxc.network.link = $BRIDGE
lxc.network.flags = up
lxc.network.ipv4 = $CONTAINER_CIDR
# allow tap/tun devices
lxc.cgroup.devices.allow = c 10:200 rwm
EOF

# Shutdown any existing container
lxc-stop -n $CONTAINER

# This kills zombie containers
if [ -d /cgroup/$CONTAINER ]; then
    cgdelete -r cpu,net_cls:$CONTAINER
fi

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

# Warm the base image on first install
CACHEDIR=/var/cache/lxc/natty/rootfs-amd64
if [ ! -d $CACHEDIR ]; then
    # by deleting the container, we force lxc-create to re-bootstrap (lxc is
    # lazy and doesn't do anything if a container already exists)
    lxc-destroy -n $CONTAINER
    # trigger the initial debootstrap
    lxc-create -n $CONTAINER -t natty -f $LXC_CONF
    chroot $CACHEDIR apt-get update
    chroot $CACHEDIR apt-get install -y --force-yes `cat files/apts/* | cut -d\# -f1 | egrep -v "(rabbitmq|libvirt-bin|mysql-server)"`
    chroot $CACHEDIR pip install `cat files/pips/*`
fi

# Cache openstack code
git_clone $NOVA_REPO $CACHEDIR/opt/nova $NOVA_BRANCH
git_clone $GLANCE_REPO $CACHEDIR/opt/glance $GLANCE_BRANCH
git_clone $KEYSTONE_REPO $CACHEDIR/opt/keystone $KEYSTONE_BRANCH
git_clone $NOVNC_REPO $CACHEDIR/opt/novnc $NOVNC_BRANCH
git_clone $DASH_REPO $CACHEDIR/opt/dash $DASH_BRANCH $DASH_TAG
git_clone $NIXON_REPO $CACHEDIR/opt/nixon $NIXON_BRANCH
git_clone $NOVACLIENT_REPO $CACHEDIR/opt/python-novaclient $NOVACLIENT_BRANCH
git_clone $OPENSTACKX_REPO $CACHEDIR/opt/openstackx $OPENSTACKX_BRANCH
git_clone $MUNIN_REPO $CACHEDIR/opt/openstack-munin $MUNIN_BRANCH

# Use this version of devstack?
if [ "$USE_CURRENT_DEVSTACK" = "1" ]; then
    rm -rf $CACHEDIR/opt/devstack
    cp -pr . $CACHEDIR/opt/devstack
fi

# Destroy the old container
lxc-destroy -n $CONTAINER

# If this call is to TERMINATE the container then exit
if [ "$TERMINATE" = "1" ]; then
    exit
fi

# Create the container
lxc-create -n $CONTAINER -t natty -f $LXC_CONF

# Specify where our container rootfs lives
ROOTFS=/var/lib/lxc/$CONTAINER/rootfs/

# Create a stack user that is a member of the libvirtd group so that stack 
# is able to interact with libvirt.
chroot $ROOTFS groupadd libvirtd
chroot $ROOTFS useradd stack -s /bin/bash -d /opt -G libvirtd

# a simple password - pass
echo stack:pass | chroot $ROOTFS chpasswd

# and has sudo ability (in the future this should be limited to only what 
# stack requires)
echo "stack ALL=(ALL) NOPASSWD: ALL" >> $ROOTFS/etc/sudoers

# Copy kernel modules
mkdir -p $ROOTFS/lib/modules/`uname -r`/kernel
cp -p /lib/modules/`uname -r`/modules.dep $ROOTFS/lib/modules/`uname -r`/
cp -pR /lib/modules/`uname -r`/kernel/net $ROOTFS/lib/modules/`uname -r`/kernel/

# Gracefully cp only if source file/dir exists
function cp_it {
    if [ -e $1 ] || [ -d $1 ]; then
        cp -pr $1 $2
    fi
}

# Copy over your ssh keys and env if desired
if [ "$COPYENV" = "1" ]; then
    cp_it ~/.ssh $ROOTFS/opt/.ssh
    cp_it ~/.ssh/id_rsa.pub $ROOTFS/opt/.ssh/authorized_keys
    cp_it ~/.gitconfig $ROOTFS/opt/.gitconfig
    cp_it ~/.vimrc $ROOTFS/opt/.vimrc
    cp_it ~/.bashrc $ROOTFS/opt/.bashrc
fi

# Make our ip address hostnames look nice at the command prompt
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> $ROOTFS/opt/.bashrc
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> $ROOTFS/etc/profile

# Give stack ownership over /opt so it may do the work needed
chroot $ROOTFS chown -R stack /opt

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

# Configure the runner
RUN_SH=$ROOTFS/opt/run.sh
cat > $RUN_SH <<EOF
#!/usr/bin/env bash
# Make sure dns is set up
echo "nameserver $NAMESERVER" | sudo resolvconf -a eth0
sleep 1

# Kill any existing screens
killall screen

# Install and run stack.sh
sudo apt-get update
sudo apt-get -y --force-yes install git-core vim-nox sudo
if [ ! -d "/opt/devstack" ]; then
    git clone git://github.com/cloudbuilders/devstack.git /opt/devstack
fi
cd /opt/devstack && $STACKSH_PARAMS ./stack.sh > /opt/run.sh.log
EOF

# Make the run.sh executable
chmod 755 $RUN_SH

# Make runner launch on boot
RC_LOCAL=$ROOTFS/etc/rc.local
cat > $RC_LOCAL <<EOF
#!/bin/sh -e
su -c "/opt/run.sh" stack
EOF

# Configure cgroup directory
if ! mount | grep -q cgroup; then
    mkdir -p /cgroup
    mount none -t cgroup /cgroup
fi

# Start our container
lxc-start -d -n $CONTAINER
