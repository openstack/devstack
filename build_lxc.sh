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

# Destroy any existing container
lxc-stop -n $CONTAINER
lxc-destroy -n $CONTAINER

FSTAB=/tmp/fstab
cat > $FSTAB <<EOF
none /var/lib/lxc/$CONTAINER/dev/pts devpts defaults 0 0
none /var/lib/lxc/$CONTAINER/proc proc defaults 0 0
none /var/lib/lxc/$CONTAINER/sys sysfs defaults 0 0
none /var/lib/lxc/$CONTAINER/var/lock tmpfs defaults 0 0
none /var/lib/lxc/$CONTAINER/var/run tmpfs defaults 0 0
/var/cache/apt/ $APTCACHEDIR none bind 0 0
EOF

# Create network configuration
NET_CONF=/tmp/net.conf
cat > $NET_CONF <<EOF
lxc.network.type = veth
lxc.network.link = $BRIDGE
lxc.network.flags = up
lxc.network.ipv4 = $CONTAINER_CIDR
lxc.mount = $FSTAB
EOF

# Configure the network
lxc-create -n $CONTAINER -t natty -f $NET_CONF

# Where our container lives
ROOTFS=/var/lib/lxc/$CONTAINER/rootfs/

# Copy over your ssh keys if desired
if [ $COPYENV ]; then
    cp -pr ~/.ssh $ROOTFS/root/.ssh
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

# Setup apt cache
# FIXME - use proper fstab mount
CWD=`pwd`
APTCACHEDIR=$CWD/cache/apt
mkdir -p $APTCACHEDIR
cp -pr $APTCACHEDIR/* $ROOTFS/var/cache/apt/

# Configure cgroup directory
mkdir -p /cgroup
mount none -t cgroup /cgroup

# Start our container
lxc-start -d -n $CONTAINER
