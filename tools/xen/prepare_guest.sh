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
DOMZERO_USER="$4"


function setup_domzero_user {
    local username

    username="$1"

    local key_updater_script
    local sudoers_file
    key_updater_script="/home/$username/update_authorized_keys.sh"
    sudoers_file="/etc/sudoers.d/allow_$username"

    # Create user
    adduser --disabled-password --quiet "$username" --gecos "$username"

    # Give passwordless sudo
    cat > $sudoers_file << EOF
    $username ALL = NOPASSWD: ALL
EOF
    chmod 0440 $sudoers_file

    # A script to populate this user's authenticated_keys from xenstore
    cat > $key_updater_script << EOF
#!/bin/bash
set -eux

DOMID=\$(sudo xenstore-read domid)
sudo xenstore-exists /local/domain/\$DOMID/authorized_keys/$username
sudo xenstore-read /local/domain/\$DOMID/authorized_keys/$username > /home/$username/xenstore_value
cat /home/$username/xenstore_value > /home/$username/.ssh/authorized_keys
EOF

    # Give the key updater to the user
    chown $username:$username $key_updater_script
    chmod 0700 $key_updater_script

    # Setup the .ssh folder
    mkdir -p /home/$username/.ssh
    chown $username:$username /home/$username/.ssh
    chmod 0700 /home/$username/.ssh
    touch /home/$username/.ssh/authorized_keys
    chown $username:$username /home/$username/.ssh/authorized_keys
    chmod 0600 /home/$username/.ssh/authorized_keys

    # Setup the key updater as a cron job
    crontab -u $username - << EOF
* * * * * $key_updater_script
EOF

}

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

setup_domzero_user "$DOMZERO_USER"

# Add an udev rule, so that new block devices could be written by stack user
cat > /etc/udev/rules.d/50-openstack-blockdev.rules << EOF
KERNEL=="xvd[b-z]", GROUP="$STACK_USER", MODE="0660"
EOF

# Give ownership of /opt/stack to stack user
chown -R $STACK_USER /opt/stack

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
