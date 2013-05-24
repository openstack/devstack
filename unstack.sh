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

# Import database library
source $TOP_DIR/lib/database

# Load local configuration
source $TOP_DIR/stackrc

# Destination path for service data
DATA_DIR=${DATA_DIR:-${DEST}/data}

# Get project function libraries
source $TOP_DIR/lib/baremetal
source $TOP_DIR/lib/cinder
source $TOP_DIR/lib/horizon
source $TOP_DIR/lib/swift
source $TOP_DIR/lib/quantum

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
GetOSVersion

if [[ "$1" == "--all" ]]; then
    UNSTACK_ALL=${UNSTACK_ALL:-1}
fi

# Run extras
# ==========

if [[ -d $TOP_DIR/extras.d ]]; then
    for i in $TOP_DIR/extras.d/*.sh; do
        [[ -r $i ]] && source $i unstack
    done
fi

if [[ "$Q_USE_DEBUG_COMMAND" == "True" ]]; then
    source $TOP_DIR/openrc
    teardown_quantum_debug
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
if is_service_enabled s-proxy; then
    stop_swift
    cleanup_swift
fi

# Apache has the WSGI processes
if is_service_enabled horizon; then
    stop_horizon
fi

# Kill TLS proxies
if is_service_enabled tls-proxy; then
    killall stud
fi

# baremetal might have created a fake environment
if is_service_enabled baremetal && [[ "$BM_USE_FAKE_ENV" = "True" ]]; then
    cleanup_fake_baremetal_env
fi

SCSI_PERSIST_DIR=$CINDER_STATE_PATH/volumes/*

# Get the iSCSI volumes
if is_service_enabled cinder; then
    cleanup_cinder
fi

if [[ -n "$UNSTACK_ALL" ]]; then
    # Stop MySQL server
    if is_service_enabled mysql; then
        stop_service mysql
    fi

    if is_service_enabled postgresql; then
        stop_service postgresql
    fi

    # Stop rabbitmq-server
    if is_service_enabled rabbit; then
        stop_service rabbitmq-server
    fi
fi

if is_service_enabled quantum; then
    stop_quantum
    stop_quantum_third_party
    cleanup_quantum
fi
