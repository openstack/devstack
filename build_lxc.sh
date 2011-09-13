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

# Shutdown any existing container
lxc-stop -n $CONTAINER
sleep 1
# This prevents zombie containers
cgdelete -r cpu,net_cls:$CONTAINER
sleep 1
# Destroy the old container
lxc-destroy -n $CONTAINER
sleep 1

# Warm the base image on first run or when WARMCACHE=1
CACHEDIR=/var/cache/lxc/natty/rootfs-amd64
if [ "$WARMCACHE" = "1" ] || [ ! -d $CACHEDIR ]; then
    if [ -d $CACHEDIR ]; then
        # Pre-cache files
        chroot $CACHEDIR apt-get update
        chroot $CACHEDIR apt-get install -y `cat apts/* | cut -d\# -f1 | egrep -v "(rabbitmq|libvirt-bin|mysql-server)"`
        chroot $CACHEDIR pip install `cat pips/*`
    fi
fi

# Create network configuration
LXC_CONF=/tmp/net.conf
cat > $LXC_CONF <<EOF
lxc.network.type = veth
lxc.network.link = $BRIDGE
lxc.network.flags = up
lxc.network.ipv4 = $CONTAINER_CIDR
# allow tap/tun devices
lxc.cgroup.devices.allow = c 10:200 rwm
EOF

# Configure the network
lxc-create -n $CONTAINER -t natty -f $LXC_CONF
sleep 2

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
echo \#\!/bin/sh -e > /etc/rc.local
echo "nameserver $NAMESERVER" | resolvconf -a eth0
sleep 1
# Create a stack user that is a member of the libvirtd group so that stack 
# is able to interact with libvirt.
groupadd libvirtd
useradd stack -s /bin/bash -d /opt -G libvirtd

# a simple password - pass
echo stack:pass | chpasswd

# give stack ownership over /opt so it may do the work needed
chown -R stack /opt

# and has sudo ability (in the future this should be limited to only what 
# stack requires)

echo "stack ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Install and run stack.sh
apt-get update
apt-get -y --force-yes install git-core vim-nox sudo
su -c "git clone git://github.com/cloudbuilders/nfs-stack.git ~/nfs-stack" stack
su -c "cd ~/nfs-stack && ./stack.sh" stack
EOF

chmod 700 $INSTALL_SH

# Make installer run on boot
RC_LOCAL=$ROOTFS/etc/rc.local
cat > $RC_LOCAL <<EOF
#!/bin/sh -e
/root/install.sh
EOF

# Configure cgroup directory
mkdir -p /cgroup
mount none -t cgroup /cgroup

# Start our container
lxc-start -d -n $CONTAINER

cat << EOF > /bin/remove_dead_cgroup.shecho
"Removing dead cgroup .$CONTAINER." >> /var/log/cgroup
rmdir /cgroup/$CONTAINER >> /var/log/cgroup 2>&1
echo "return value was $?" >> /var/log/cgroup
EOF
chmod 755 /bin/remove_dead_cgroup.sh
echo /bin/remove_dead_cgroup.sh > /cgroup/release_agent
echo 1 > /cgroup/notify_on_release
