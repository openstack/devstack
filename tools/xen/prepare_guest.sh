#!/bin/bash

# This script is run on an Ubuntu VM.
# This script is inserted into the VM by prepare_guest_template.sh
# and is run when that VM boots.
# It customizes a fresh Ubuntu install, so it is ready
# to run stack.sh
#
# This includes installing the XenServer tools,
# creating the user called "stack",
# and shuts down the VM to signal the script has completed

set -o errexit
set -o nounset
set -o xtrace

# Configurable nuggets
GUEST_PASSWORD="$1"
XS_TOOLS_PATH="$2"
STACK_USER="$3"

# Install basics
apt-get update
apt-get install -y cracklib-runtime curl wget ssh openssh-server tcpdump ethtool
apt-get install -y curl wget ssh openssh-server python-pip git vim-nox sudo python-netaddr
pip install xenapi

# Install XenServer guest utilities
dpkg -i $XS_TOOLS_PATH
update-rc.d -f xe-linux-distribution remove
update-rc.d xe-linux-distribution defaults

# Make a small cracklib dictionary, so that passwd still works, but we don't
# have the big dictionary.
mkdir -p /usr/share/cracklib
echo a | cracklib-packer

# Make /etc/shadow, and set the root password
pwconv
echo "root:$GUEST_PASSWORD" | chpasswd

# Put the VPX into UTC.
rm -f /etc/localtime

# Add stack user
groupadd libvirtd
useradd $STACK_USER -s /bin/bash -d /opt/stack -G libvirtd
echo $STACK_USER:$GUEST_PASSWORD | chpasswd
echo "$STACK_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Add an udev rule, so that new block devices could be written by stack user
cat > /etc/udev/rules.d/50-openstack-blockdev.rules << EOF
KERNEL=="xvd[b-z]", GROUP="$STACK_USER", MODE="0660"
EOF

# Give ownership of /opt/stack to stack user
chown -R $STACK_USER /opt/stack

# Make our ip address hostnames look nice at the command prompt
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> /opt/stack/.bashrc
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> /root/.bashrc
echo "export PS1='${debian_chroot:+($debian_chroot)}\\u@\\H:\\w\\$ '" >> /etc/profile

function setup_vimrc {
    if [ ! -e $1 ]; then
        # Simple but usable vimrc
        cat > $1 <<EOF
syntax on
se ts=4
se expandtab
se shiftwidth=4
EOF
    fi
}

# Setup simple .vimrcs
setup_vimrc /root/.vimrc
setup_vimrc /opt/stack/.vimrc

# remove self from local.rc
# so this script is not run again
rm -rf /etc/rc.local

# Restore rc.local file
cp /etc/rc.local.preparebackup /etc/rc.local

# shutdown to notify we are done
shutdown -h now
