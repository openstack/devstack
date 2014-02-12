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

if [[ $EUID -eq 0 ]]; then
    echo "You are running this script as root."
    echo "It might work but you will have a better day running it as $STACK_USER"
    exit 1
fi


# Configure Projects
# ==================

# Import apache functions
source $TOP_DIR/lib/apache

# Import TLS functions
source $TOP_DIR/lib/tls

# Source project function libraries
source $TOP_DIR/lib/infra
source $TOP_DIR/lib/oslo
source $TOP_DIR/lib/stackforge
source $TOP_DIR/lib/horizon
source $TOP_DIR/lib/keystone
source $TOP_DIR/lib/glance
source $TOP_DIR/lib/nova
source $TOP_DIR/lib/cinder
source $TOP_DIR/lib/swift
source $TOP_DIR/lib/ceilometer
source $TOP_DIR/lib/heat
source $TOP_DIR/lib/neutron
source $TOP_DIR/lib/baremetal
source $TOP_DIR/lib/ldap

# Extras Source
# --------------

# Phase: source
if [[ -d $TOP_DIR/extras.d ]]; then
    for i in $TOP_DIR/extras.d/*.sh; do
        [[ -r $i ]] && source $i source
    done
fi

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
GetOSVersion

if [[ "$1" == "--all" ]]; then
    UNSTACK_ALL=${UNSTACK_ALL:-1}
fi

# Run extras
# ==========

# Phase: unstack
if [[ -d $TOP_DIR/extras.d ]]; then
    for i in $TOP_DIR/extras.d/*.sh; do
        [[ -r $i ]] && source $i unstack
    done
fi

if [[ "$Q_USE_DEBUG_COMMAND" == "True" ]]; then
    source $TOP_DIR/openrc
    teardown_neutron_debug
fi

# Call service stop

if is_service_enabled heat; then
    stop_heat
fi

if is_service_enabled ceilometer; then
    stop_ceilometer
fi

if is_service_enabled nova; then
    stop_nova
fi

if is_service_enabled glance; then
    stop_glance
fi

if is_service_enabled key; then
    stop_keystone
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
    stop_cinder
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

if is_service_enabled neutron; then
    stop_neutron
    stop_neutron_third_party
    cleanup_neutron
fi

if is_service_enabled trove; then
    cleanup_trove
fi

# Clean up the remainder of the screen processes
SCREEN=$(which screen)
if [[ -n "$SCREEN" ]]; then
    SESSION=$(screen -ls | awk '/[0-9].stack/ { print $1 }')
    if [[ -n "$SESSION" ]]; then
        screen -X -S $SESSION quit
    fi
fi

cleanup_tmp
