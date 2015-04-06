#!/bin/bash

# **unstack.sh**

# Stops that which is started by ``stack.sh`` (mostly)
# mysql and rabbit are left running as OpenStack code refreshes
# do not require them to be restarted.
#
# Stop all processes by setting ``UNSTACK_ALL`` or specifying ``-a``
# on the command line

UNSTACK_ALL=""

while getopts ":a" opt; do
    case $opt in
        a)
            UNSTACK_ALL=""
            ;;
    esac
done

# Keep track of the current DevStack directory.
TOP_DIR=$(cd $(dirname "$0") && pwd)
FILES=$TOP_DIR/files

# Import common functions
source $TOP_DIR/functions

# Import database library
source $TOP_DIR/lib/database

# Load local configuration
source $TOP_DIR/openrc

# Destination path for service data
DATA_DIR=${DATA_DIR:-${DEST}/data}

if [[ $EUID -eq 0 ]]; then
    echo "You are running this script as root."
    echo "It might work but you will have a better day running it as $STACK_USER"
    exit 1
fi


# Configure Projects
# ==================

# Plugin Phase 0: override_defaults - allow pluggins to override
# defaults before other services are run
run_phase override_defaults

# Import apache functions
source $TOP_DIR/lib/apache

# Import TLS functions
source $TOP_DIR/lib/tls

# Source project function libraries
source $TOP_DIR/lib/infra
source $TOP_DIR/lib/oslo
source $TOP_DIR/lib/lvm
source $TOP_DIR/lib/horizon
source $TOP_DIR/lib/keystone
source $TOP_DIR/lib/glance
source $TOP_DIR/lib/nova
source $TOP_DIR/lib/cinder
source $TOP_DIR/lib/swift
source $TOP_DIR/lib/ceilometer
source $TOP_DIR/lib/heat
source $TOP_DIR/lib/neutron-legacy
source $TOP_DIR/lib/ldap
source $TOP_DIR/lib/dstat

# Extras Source
# --------------

# Phase: source
if [[ -d $TOP_DIR/extras.d ]]; then
    for i in $TOP_DIR/extras.d/*.sh; do
        [[ -r $i ]] && source $i source
    done
fi

load_plugin_settings

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
GetOSVersion

# Run extras
# ==========

# Phase: unstack
run_phase unstack

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

if is_service_enabled keystone; then
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

# Kill TLS proxies and cleanup certificates
if is_service_enabled tls-proxy; then
    stop_tls_proxy
    cleanup_CA
fi
if [ "$USE_SSL" == "True" ]; then
    cleanup_CA
fi

SCSI_PERSIST_DIR=$CINDER_STATE_PATH/volumes/*

# BUG: tgt likes to exit 1 on service stop if everything isn't
# perfect, we should clean up cinder stop paths.

# Get the iSCSI volumes
if is_service_enabled cinder; then
    stop_cinder || /bin/true
    cleanup_cinder || /bin/true
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

if is_service_enabled dstat; then
    stop_dstat
fi

# Clean up the remainder of the screen processes
SCREEN=$(which screen)
if [[ -n "$SCREEN" ]]; then
    SESSION=$(screen -ls | awk '/[0-9].stack/ { print $1 }')
    if [[ -n "$SESSION" ]]; then
        screen -X -S $SESSION quit
    fi
fi

# BUG: maybe it doesn't exist? We should isolate this further down.
clean_lvm_volume_group $DEFAULT_VOLUME_GROUP_NAME || /bin/true
