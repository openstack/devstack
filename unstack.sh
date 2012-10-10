#!/usr/bin/env bash

# **unstack.sh**

# Stops that which is started by ``stack.sh`` (mostly)
# mysql and rabbit are left running as OpenStack code refreshes
# do not require them to be restarted.
#
# Stop all processes by setting ``UNSTACK_ALL`` or specifying ``--all``
# on the command line

# Keep track of the current devstack directory.
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $TOP_DIR/functions

# Load local configuration
source $TOP_DIR/stackrc

# Destination path for service data
DATA_DIR=${DATA_DIR:-${DEST}/data}

# Get project function libraries
source $TOP_DIR/lib/cinder
source $TOP_DIR/lib/n-vol

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
GetOSVersion

if [[ "$1" == "--all" ]]; then
    UNSTACK_ALL=${UNSTACK_ALL:-1}
fi

# Shut down devstack's screen to get the bulk of OpenStack services in one shot
SCREEN=$(which screen)
if [[ -n "$SCREEN" ]]; then
    SESSION=$(screen -ls | awk '/[0-9].stack/ { print $1 }')
    if [[ -n "$SESSION" ]]; then
        screen -X -S $SESSION quit
    fi
fi

# Swift runs daemons
if is_service_enabled swift; then
    swift-init all stop 2>/dev/null || true
fi

# Apache has the WSGI processes
if is_service_enabled horizon; then
    stop_service apache2
fi

SCSI_PERSIST_DIR=$CINDER_STATE_PATH/volumes/*

# Get the iSCSI volumes
if is_service_enabled cinder n-vol; then
    if is_service_enabled n-vol; then
        SCSI_PERSIST_DIR=$NOVA_STATE_PATH/volumes/*
    fi

    TARGETS=$(sudo tgtadm --op show --mode target)
    if [ $? -ne 0 ]; then
        # If tgt driver isn't running this won't work obviously
        # So check the response and restart if need be
        echo "tgtd seems to be in a bad state, restarting..."
        if [[ "$os_PACKAGE" = "deb" ]]; then
            restart_service tgt
        else
            restart_service tgtd
        fi
        TARGETS=$(sudo tgtadm --op show --mode target)
    fi

    if [[ -n "$TARGETS" ]]; then
        iqn_list=( $(grep --no-filename -r iqn $SCSI_PERSIST_DIR | sed 's/<target //' | sed 's/>//') )
        for i in "${iqn_list[@]}"; do
            echo removing iSCSI target: $i
            sudo tgt-admin --delete $i
        done
    fi

    if is_service_enabled cinder; then
        sudo rm -rf $CINDER_STATE_PATH/volumes/*
    fi

    if is_service_enabled n-vol; then
        sudo rm -rf $NOVA_STATE_PATH/volumes/*
    fi

    if [[ "$os_PACKAGE" = "deb" ]]; then
        stop_service tgt
    else
        stop_service tgtd
    fi
fi

if [[ -n "$UNSTACK_ALL" ]]; then
    # Stop MySQL server
    if is_service_enabled mysql; then
        stop_service mysql
    fi

    # Stop rabbitmq-server
    if is_service_enabled rabbit; then
        stop_service rabbitmq-server
    fi
fi

# Quantum dhcp agent runs dnsmasq
if is_service_enabled q-dhcp; then
    pid=$(ps aux | awk '/[d]nsmasq.+interface=tap/ { print $2 }')
    [ ! -z $pid ] && sudo kill -9 $pid
fi
