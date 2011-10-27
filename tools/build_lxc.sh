#!/usr/bin/env bash

# Sanity check
if [ "$EUID" -ne "0" ]; then
  echo "This script must be run with root privileges."
  exit 1
fi

# Keep track of ubuntu version
UBUNTU_VERSION=`cat /etc/lsb-release | grep CODENAME | sed 's/.*=//g'`

# Move to top devstack dir
cd ..

# Abort if localrc is not set
if [ ! -e ./localrc ]; then
    echo "You must have a localrc with ALL necessary passwords defined before proceeding."
    echo "See stack.sh for required passwords."
    exit 1
fi

# Source params
source ./stackrc

# Store cwd
CWD=`pwd`

# Configurable params
BRIDGE=${BRIDGE:-br0}
GUEST_NAME=${GUEST_NAME:-STACK}
GUEST_IP=${GUEST_IP:-192.168.1.50}
GUEST_CIDR=${GUEST_CIDR:-$GUEST_IP/24}
GUEST_NETMASK=${GUEST_NETMASK:-255.255.255.0}
GUEST_GATEWAY=${GUEST_GATEWAY:-192.168.1.1}
NAMESERVER=${NAMESERVER:-`cat /etc/resolv.conf | grep nameserver | head -1 | cut -d " " -f2`}
COPYENV=${COPYENV:-1}
DEST=${DEST:-/opt/stack}
WAIT_TILL_LAUNCH=${WAIT_TILL_LAUNCH:-1}

# Param string to pass to stack.sh.  Like "EC2_DMZ_HOST=192.168.1.1 MYSQL_USER=nova"
# By default, n-vol is disabled for lxc, as iscsitarget doesn't work properly in lxc
STACKSH_PARAMS=${STACKSH_PARAMS:-"ENABLED_SERVICES=g-api,g-reg,key,n-api,n-cpu,n-net,n-sch,n-vnc,dash,mysql,rabbit"}

# Option to use the version of devstack on which we are currently working
USE_CURRENT_DEVSTACK=${USE_CURRENT_DEVSTACK:-1}


# Install deps
apt-get install -y lxc debootstrap

# Install cgroup-bin from source, since the packaging is buggy and possibly incompatible with our setup
if ! which cgdelete | grep -q cgdelete; then
    apt-get install -y g++ bison flex libpam0g-dev make
    wget http://sourceforge.net/projects/libcg/files/libcgroup/v0.37.1/libcgroup-0.37.1.tar.bz2/download -O /tmp/libcgroup-0.37.1.tar.bz2
    cd /tmp && bunzip2 libcgroup-0.37.1.tar.bz2  && tar xfv libcgroup-0.37.1.tar
    cd libcgroup-0.37.1
    ./configure
    make install
    ldconfig
fi

# Create lxc configuration
LXC_CONF=/tmp/$GUEST_NAME.conf
cat > $LXC_CONF <<EOF
lxc.network.type = veth
lxc.network.link = $BRIDGE
lxc.network.flags = up
lxc.network.ipv4 = $GUEST_CIDR
# allow tap/tun devices
lxc.cgroup.devices.allow = c 10:200 rwm
EOF

# Shutdown any existing container
lxc-stop -n $GUEST_NAME

# This kills zombie containers
if [ -d /cgroup/$GUEST_NAME ]; then
    cgdelete -r cpu,net_cls:$GUEST_NAME
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

# Helper to create the container
function create_lxc {
    if [ "natty" = "$UBUNTU_VERSION" ]; then
        lxc-create -n $GUEST_NAME -t natty -f $LXC_CONF
    else
        lxc-create -n $GUEST_NAME -t ubuntu -f $LXC_CONF
    fi
}

# Location of the base image directory
if [ "natty" = "$UBUNTU_VERSION" ]; then
    CACHEDIR=/var/cache/lxc/natty/rootfs-amd64
else
    CACHEDIR=/var/cache/lxc/oneiric/rootfs-amd64
fi

# Provide option to do totally clean install
if [ "$CLEAR_LXC_CACHE" = "1" ]; then
    rm -rf $CACHEDIR
fi

# Warm the base image on first install
if [ ! -f $CACHEDIR/bootstrapped ]; then
    # by deleting the container, we force lxc-create to re-bootstrap (lxc is
    # lazy and doesn't do anything if a container already exists)
    lxc-destroy -n $GUEST_NAME
    # trigger the initial debootstrap
    create_lxc
    touch $CACHEDIR/bootstrapped
fi

# Make sure that base requirements are installed
chroot $CACHEDIR apt-get update
chroot $CACHEDIR apt-get install -y --force-yes `cat files/apts/* | cut -d\# -f1 | egrep -v "(rabbitmq|libvirt-bin|mysql-server)"`
chroot $CACHEDIR apt-get install -y --download-only rabbitmq-server libvirt-bin mysql-server
chroot $CACHEDIR pip install `cat files/pips/*`

# Clean out code repos if directed to do so
if [ "$CLEAN" = "1" ]; then
    rm -rf $CACHEDIR/$DEST
fi

# Cache openstack code
mkdir -p $CACHEDIR/$DEST
git_clone $NOVA_REPO $CACHEDIR/$DEST/nova $NOVA_BRANCH
git_clone $GLANCE_REPO $CACHEDIR/$DEST/glance $GLANCE_BRANCH
git_clone $KEYSTONE_REPO $CACHEDIR/$DESTkeystone $KEYSTONE_BRANCH
git_clone $NOVNC_REPO $CACHEDIR/$DEST/noVNC $NOVNC_BRANCH
git_clone $DASH_REPO $CACHEDIR/$DEST/dash $DASH_BRANCH $DASH_TAG
git_clone $NOVACLIENT_REPO $CACHEDIR/$DEST/python-novaclient $NOVACLIENT_BRANCH
git_clone $OPENSTACKX_REPO $CACHEDIR/$DEST/openstackx $OPENSTACKX_BRANCH
git_clone $KEYSTONE_REPO $CACHEDIR/$DEST/keystone $KEYSTONE_BRANCH
git_clone $NOVNC_REPO $CACHEDIR/$DEST/novnc $NOVNC_BRANCH

# Use this version of devstack?
if [ "$USE_CURRENT_DEVSTACK" = "1" ]; then
    rm -rf $CACHEDIR/$DEST/devstack
    cp -pr $CWD $CACHEDIR/$DEST/devstack
fi

# pre-cache uec images
for image_url in ${IMAGE_URLS//,/ }; do
    IMAGE_FNAME=`basename "$image_url"`
    if [ ! -f $CACHEDIR/$IMAGE_FNAME ]; then
        wget -c $image_url -O $CACHEDIR/$IMAGE_FNAME
    fi
    cp $CACHEDIR/$IMAGE_FNAME $CACHEDIR/$DEST/devstack/files
done

# Destroy the old container
lxc-destroy -n $GUEST_NAME

# If this call is to TERMINATE the container then exit
if [ "$TERMINATE" = "1" ]; then
    exit
fi

# Create the container
create_lxc

# Specify where our container rootfs lives
ROOTFS=/var/lib/lxc/$GUEST_NAME/rootfs/

# Create a stack user that is a member of the libvirtd group so that stack
# is able to interact with libvirt.
chroot $ROOTFS groupadd libvirtd
chroot $ROOTFS useradd stack -s /bin/bash -d $DEST -G libvirtd

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
        cp -pRL $1 $2
    fi
}

# Copy over your ssh keys and env if desired
if [ "$COPYENV" = "1" ]; then
    cp_it ~/.ssh $ROOTFS/$DEST/.ssh
    cp_it ~/.ssh/id_rsa.pub $ROOTFS/$DEST/.ssh/authorized_keys
    cp_it ~/.gitconfig $ROOTFS/$DEST/.gitconfig
    cp_it ~/.vimrc $ROOTFS/$DEST/.vimrc
    cp_it ~/.bashrc $ROOTFS/$DEST/.bashrc
fi

# Make our ip address hostnames look nice at the command prompt
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> $ROOTFS/$DEST/.bashrc
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> $ROOTFS/etc/profile

# Give stack ownership over $DEST so it may do the work needed
chroot $ROOTFS chown -R stack $DEST

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

# Configure the runner
RUN_SH=$ROOTFS/$DEST/run.sh
cat > $RUN_SH <<EOF
#!/usr/bin/env bash
# Make sure dns is set up
echo "nameserver $NAMESERVER" | sudo resolvconf -a eth0
# Make there is a default route - needed for natty
if ! route | grep -q default; then
    sudo ip route add default via $GUEST_GATEWAY
fi
sleep 1

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
EOF

# Make the run.sh executable
chmod 755 $RUN_SH

# Make runner launch on boot
RC_LOCAL=$ROOTFS/etc/init.d/local
cat > $RC_LOCAL <<EOF
#!/bin/sh -e
su -c "$DEST/run.sh" stack
EOF
chmod +x $RC_LOCAL
chroot $ROOTFS sudo update-rc.d local defaults 80

# Configure cgroup directory
if ! mount | grep -q cgroup; then
    mkdir -p /cgroup
    mount none -t cgroup /cgroup
fi

# Start our container
lxc-start -d -n $GUEST_NAME

if [ "$WAIT_TILL_LAUNCH" = "1" ]; then
    # Done creating the container, let's tail the log
    echo
    echo "============================================================="
    echo "                          -- YAY! --"
    echo "============================================================="
    echo
    echo "We're done creating the container, about to start tailing the"
    echo "stack.sh log. It will take a second or two to start."
    echo
    echo "Just CTRL-C at any time to stop tailing."

    while [ ! -e "$ROOTFS/$DEST/run.sh.log" ]; do
      sleep 1
    done

    tail -F $ROOTFS/$DEST/run.sh.log &

    TAIL_PID=$!

    function kill_tail() {
        kill $TAIL_PID
        exit 1
    }

    # Let Ctrl-c kill tail and exit
    trap kill_tail SIGINT

    echo "Waiting stack.sh to finish..."
    while ! cat $ROOTFS/$DEST/run.sh.log | grep -q 'All done' ; do
        sleep 5
    done

    kill $TAIL_PID

    if grep -q "stack.sh failed" $ROOTFS/$DEST/run.sh.log; then
        exit 1
    fi

    echo ""
    echo "Finished - Zip-a-dee Doo-dah!"
fi
