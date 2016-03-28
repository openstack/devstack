#!/bin/bash
set -eux

# Need to set barrier=0 to avoid a Xen bug
# https://bugs.launchpad.net/ubuntu/+source/linux/+bug/824089
sed -i -e 's/errors=/barrier=0,errors=/' /etc/fstab

# Allow root to login with a password
sed -i -e 's/.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config

# Install the XenServer tools so IP addresses are reported
wget --no-proxy @XS_TOOLS_URL@ -O /root/tools.deb
dpkg -i /root/tools.deb
rm /root/tools.deb
