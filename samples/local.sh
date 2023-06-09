#!/usr/bin/env bash

# Sample ``local.sh`` for user-configurable tasks to run automatically
# at the successful conclusion of ``stack.sh``.

# NOTE: Copy this file to the root DevStack directory for it to work properly.

# This is a collection of some of the things we have found to be useful to run
# after ``stack.sh`` to tweak the OpenStack configuration that DevStack produces.
# These should be considered as samples and are unsupported DevStack code.


# Keep track of the DevStack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $TOP_DIR/functions

# Use openrc + stackrc + localrc for settings
source $TOP_DIR/stackrc

# Destination path for installation ``DEST``
DEST=${DEST:-/opt/stack}

if is_service_enabled nova; then

    # Import ssh keys
    # ---------------

    # Import keys from the current user into the default OpenStack user (usually
    # ``demo``)

    # Get OpenStack user auth
    export OS_CLOUD=devstack

    # Add first keypair found in localhost:$HOME/.ssh
    for i in $HOME/.ssh/id_rsa.pub $HOME/.ssh/id_dsa.pub; do
        if [[ -r $i ]]; then
            openstack keypair create --public-key $i `hostname`
            break
        fi
    done

    # Update security default group
    # -----------------------------

    # Add tcp/22 and icmp to default security group
    default=$(openstack security group list -f value -c ID)
    openstack security group rule create $default --protocol tcp --dst-port 22
    openstack security group rule create $default --protocol icmp

    # Create A Flavor
    # ---------------

    # Get OpenStack admin auth
    source $TOP_DIR/openrc admin admin

    # Name of new flavor
    # set in ``local.conf`` with ``DEFAULT_INSTANCE_TYPE=m1.micro``
    MI_NAME=m1.micro

    # Create micro flavor if not present
    if [[ -z $(openstack flavor list | grep $MI_NAME) ]]; then
        openstack flavor create $MI_NAME --id 6 --ram 128 --disk 0 --vcpus 1
    fi

fi
