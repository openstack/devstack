#!/usr/bin/env bash

# **create-stack-user.sh**

# Create a user account suitable for running DevStack
# - create a group named $STACK_USER if it does not exist
# - create a user named $STACK_USER if it does not exist
#
#   - home is $DEST
#
# - configure sudo for $STACK_USER

# ``stack.sh`` was never intended to run as root.  It had a hack to do what is
# now in this script and re-launch itself, but that hack was less than perfect
# and it was time for this nonsense to stop.  Run this script as root to create
# the user and configure sudo.

set -o errexit

# Keep track of the DevStack directory
TOP_DIR=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP_DIR/functions

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro

# Needed to get ``ENABLED_SERVICES`` and ``STACK_USER``
source $TOP_DIR/stackrc

# Give the non-root user the ability to run as **root** via ``sudo``
is_package_installed sudo || is_package_installed sudo-ldap || install_package sudo

[[ -z "$STACK_USER" ]] && die "STACK_USER is not set. Exiting."

if ! getent group $STACK_USER >/dev/null; then
    echo "Creating a group called $STACK_USER"
    groupadd $STACK_USER
fi

if ! getent passwd $STACK_USER >/dev/null; then
    echo "Creating a user called $STACK_USER"
    useradd -g $STACK_USER -s /bin/bash -d $DEST -m $STACK_USER
    # RHEL based distros create home dir with 700 permissions,
    # And Ubuntu 21.04+ with 750, i.e missing executable
    # permission for either group or others
    # Devstack deploy will have issues with this, fix it by
    # adding executable permission
    if [[ $(stat -c '%A' $DEST|grep -o x|wc -l) -lt 3 ]]; then
        echo "Executable permission missing for $DEST, adding it"
        chmod +x $DEST
    fi
fi

echo "Giving stack user passwordless sudo privileges"
# UEC images ``/etc/sudoers`` does not have a ``#includedir``, add one
grep -q "^#includedir.*/etc/sudoers.d" /etc/sudoers ||
    echo "#includedir /etc/sudoers.d" >> /etc/sudoers
( umask 226 && echo "$STACK_USER ALL=(ALL) NOPASSWD:ALL" \
    > /etc/sudoers.d/50_stack_sh )
