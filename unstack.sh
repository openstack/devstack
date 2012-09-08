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

# Get the iSCSI volumes
if is_service_enabled cinder n-vol; then
    TARGETS=$(sudo tgtadm --op show --mode target)
    if [[ -n "$TARGETS" ]]; then
        # FIXME(dtroyer): this could very well require more here to
        #                 clean up left-over volumes
        echo "iSCSI target cleanup needed:"
        echo "$TARGETS"
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
    sudo kill -9 $(ps aux | awk '/[d]nsmasq.+interface=tap/ { print $2 }')
fi
