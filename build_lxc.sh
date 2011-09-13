#!/bin/bash
# Configurable params
BRIDGE=${BRIDGE:-br0}
CONTAINER=${CONTAINER:-TESTER}
CONTAINER_IP=${CONTAINER_IP:-192.168.1.50}
CONTAINER_CIDR=${CONTAINER_CIDR:-$CONTAINER_IP/24}
CONTAINER_NETMASK=${CONTAINER_NETMASK:-255.255.255.0}
CONTAINER_GATEWAY=${CONTAINER_GATEWAY:-192.168.1.1}
NAMESERVER=${NAMESERVER:-192.168.1.1}
COPYENV=${COPYENV:-1}
WARMCACHE=${WARMCACHE:-0}

# Destroy any existing container
lxc-stop -n $CONTAINER
sleep 1
lxc-destroy -n $CONTAINER
sleep 1

# Create network configuration
NET_CONF=/tmp/net.conf
cat > $NET_CONF <<EOF
lxc.network.type = veth
lxc.network.link = $BRIDGE
lxc.network.flags = up
lxc.network.ipv4 = $CONTAINER_CIDR
EOF

# Configure the network
lxc-create -n $CONTAINER -t natty -f $NET_CONF

if [ "$WARMCACHE" = "1" ]; then
    # Pre-cache files
    BASECACHE=/var/cache/lxc/natty/rootfs-amd64
    chroot $BASECACHE apt-get update
    chroot $BASECACHE apt-get install -y `cat apts/* | cut -d\# -f1 | egrep -v "(rabbitmq|libvirt-bin|mysql-server)"`
    chroot $BASECACHE pip install `cat pips/*`
fi

# Where our container lives
ROOTFS=/var/lib/lxc/$CONTAINER/rootfs/

# Copy over your ssh keys and env if desired
if [ "$COPYENV" = "1" ]; then
    cp -pr ~/.ssh $ROOTFS/root/.ssh
    cp -p ~/.ssh/id_rsa.pub $ROOTFS/root/.ssh/authorized_keys
    cp -pr ~/.gitconfig $ROOTFS/root/.gitconfig
    cp -pr ~/.vimrc $ROOTFS/root/.vimrc
    cp -pr ~/.bashrc $ROOTFS/root/.bashrc
fi

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

# Configure the first run installer
INSTALL_SH=$ROOTFS/root/install.sh
cat > $INSTALL_SH <<EOF
#!/bin/bash
echo "nameserver $NAMESERVER" | resolvconf -a eth0
sleep 1
apt-get update
apt-get -y --force-yes install git-core vim-nox sudo
git clone git://github.com/cloudbuilders/nfs-stack.git /root/nfs-stack
EOF

chmod 700 $INSTALL_SH

# Make installer run on boot
RC_LOCAL=$ROOTFS/etc/rc.local
cat > $RC_LOCAL <<EOF
#!/bin/sh -e
/root/install.sh
EOF

# Setup cache
# FIXME - use proper fstab mount
CWD=`pwd`
CACHEDIR=$CWD/cache/
mkdir -p $CACHEDIR/apt
mkdir -p $CACHEDIR/pip
cp -pr $CACHEDIR/apt/* $ROOTFS/var/cache/apt/
cp -pr $CACHEDIR/pip/* $ROOTFS/var/cache/pip/

# Configure cgroup directory
if [ ! -d /cgroup ] ; then
    mkdir -p /cgroup
    mount none -t cgroup /cgroup
fi

# Start our container
lxc-start -d -n $CONTAINER
