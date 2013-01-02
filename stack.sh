#!/usr/bin/env bash

# ``stack.sh`` is an opinionated OpenStack developer installation.  It
# installs and configures various combinations of **Ceilometer**, **Cinder**,
# **Glance**, **Heat**, **Horizon**, **Keystone**, **Nova**, **Quantum**
# and **Swift**

# This script allows you to specify configuration options of what git
# repositories to use, enabled services, network configuration and various
# passwords.  If you are crafty you can run the script on multiple nodes using
# shared settings for common resources (mysql, rabbitmq) and build a multi-node
# developer install.

# To keep this script simple we assume you are running on a recent **Ubuntu**
# (11.10 Oneiric or newer) or **Fedora** (F16 or newer) machine.  It
# should work in a VM or physical server.  Additionally we put the list of
# ``apt`` and ``rpm`` dependencies and other configuration files in this repo.

# Learn more and get the most recent version at http://devstack.org

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $TOP_DIR/functions

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro



# Settings
# ========

# ``stack.sh`` is customizable through setting environment variables.  If you
# want to override a setting you can set and export it::
#
#     export DATABASE_PASSWORD=anothersecret
#     ./stack.sh
#
# You can also pass options on a single line ``DATABASE_PASSWORD=simple ./stack.sh``
#
# Additionally, you can put any local variables into a ``localrc`` file::
#
#     DATABASE_PASSWORD=anothersecret
#     DATABASE_USER=hellaroot
#
# We try to have sensible defaults, so you should be able to run ``./stack.sh``
# in most cases.  ``localrc`` is not distributed with DevStack and will never
# be overwritten by a DevStack update.
#
# DevStack distributes ``stackrc`` which contains locations for the OpenStack
# repositories and branches to configure.  ``stackrc`` sources ``localrc`` to
# allow you to safely override those settings.

if [[ ! -r $TOP_DIR/stackrc ]]; then
    echo "ERROR: missing $TOP_DIR/stackrc - did you grab more than just stack.sh?"
    exit 1
fi
source $TOP_DIR/stackrc


# Proxy Settings
# --------------

# HTTP and HTTPS proxy servers are supported via the usual environment variables [1]
# ``http_proxy``, ``https_proxy`` and ``no_proxy``. They can be set in
# ``localrc`` if necessary or on the command line::
#
# [1] http://www.w3.org/Daemon/User/Proxies/ProxyClients.html
#
#     http_proxy=http://proxy.example.com:3128/ no_proxy=repo.example.net ./stack.sh

if [[ -n "$http_proxy" ]]; then
    export http_proxy=$http_proxy
fi
if [[ -n "$https_proxy" ]]; then
    export https_proxy=$https_proxy
fi
if [[ -n "$no_proxy" ]]; then
    export no_proxy=$no_proxy
fi

# Destination path for installation ``DEST``
DEST=${DEST:-/opt/stack}


# Sanity Check
# ============

# Clean up last environment var cache
if [[ -r $TOP_DIR/.stackenv ]]; then
    rm $TOP_DIR/.stackenv
fi

# Import database configuration
source $TOP_DIR/lib/database

# Validate database selection
# Since DATABASE_BACKENDS is now set, this also gets ENABLED_SERVICES
# properly configured for the database selection.
use_database $DATABASE_TYPE || echo "Invalid database '$DATABASE_TYPE'"

# Remove services which were negated in ENABLED_SERVICES
# using the "-" prefix (e.g., "-rabbit") instead of
# calling disable_service().
disable_negated_services

# Warn users who aren't on an explicitly supported distro, but allow them to
# override check and attempt installation with ``FORCE=yes ./stack``
if [[ ! ${DISTRO} =~ (oneiric|precise|quantal|raring|f16|f17|f18|opensuse-12.2) ]]; then
    echo "WARNING: this script has not been tested on $DISTRO"
    if [[ "$FORCE" != "yes" ]]; then
        echo "If you wish to run this script anyway run with FORCE=yes"
        exit 1
    fi
fi

if is_service_enabled qpid && ! qpid_is_supported; then
    echo "Qpid support is not available for this version of your distribution."
    exit 1
fi

# ``stack.sh`` keeps function libraries here
# Make sure ``$TOP_DIR/lib`` directory is present
if [ ! -d $TOP_DIR/lib ]; then
    echo "ERROR: missing devstack/lib"
    exit 1
fi

# ``stack.sh`` keeps the list of ``apt`` and ``rpm`` dependencies and config
# templates and other useful files in the ``files`` subdirectory
FILES=$TOP_DIR/files
if [ ! -d $FILES ]; then
    echo "ERROR: missing devstack/files"
    exit 1
fi

SCREEN_NAME=${SCREEN_NAME:-stack}
# Check to see if we are already running DevStack
if type -p screen >/dev/null && screen -ls | egrep -q "[0-9].$SCREEN_NAME"; then
    echo "You are already running a stack.sh session."
    echo "To rejoin this session type 'screen -x stack'."
    echo "To destroy this session, type './unstack.sh'."
    exit 1
fi

# Make sure we only have one rpc backend enabled.
rpc_backend_cnt=0
for svc in qpid zeromq rabbit; do
    is_service_enabled $svc &&
        ((rpc_backend_cnt++))
done
if [ "$rpc_backend_cnt" -gt 1 ]; then
    echo "ERROR: only one rpc backend may be enabled,"
    echo "       set only one of 'rabbit', 'qpid', 'zeromq'"
    echo "       via ENABLED_SERVICES."
elif [ "$rpc_backend_cnt" == 0 ]; then
    echo "ERROR: at least one rpc backend must be enabled,"
    echo "       set one of 'rabbit', 'qpid', 'zeromq'"
    echo "       via ENABLED_SERVICES."
fi
unset rpc_backend_cnt

# Set up logging level
VERBOSE=$(trueorfalse True $VERBOSE)


# root Access
# -----------

# OpenStack is designed to be run as a non-root user; Horizon will fail to run
# as **root** since Apache will not serve content from **root** user).  If
# ``stack.sh`` is run as **root**, it automatically creates a **stack** user with
# sudo privileges and runs as that user.

if [[ $EUID -eq 0 ]]; then
    ROOTSLEEP=${ROOTSLEEP:-10}
    echo "You are running this script as root."
    echo "In $ROOTSLEEP seconds, we will create a user 'stack' and run as that user"
    sleep $ROOTSLEEP

    # Give the non-root user the ability to run as **root** via ``sudo``
    is_package_installed sudo || install_package sudo
    if ! getent group stack >/dev/null; then
        echo "Creating a group called stack"
        groupadd stack
    fi
    if ! getent passwd stack >/dev/null; then
        echo "Creating a user called stack"
        useradd -g stack -s /bin/bash -d $DEST -m stack
    fi

    echo "Giving stack user passwordless sudo privileges"
    # UEC images ``/etc/sudoers`` does not have a ``#includedir``, add one
    grep -q "^#includedir.*/etc/sudoers.d" /etc/sudoers ||
        echo "#includedir /etc/sudoers.d" >> /etc/sudoers
    ( umask 226 && echo "stack ALL=(ALL) NOPASSWD:ALL" \
        > /etc/sudoers.d/50_stack_sh )

    echo "Copying files to stack user"
    STACK_DIR="$DEST/${TOP_DIR##*/}"
    cp -r -f -T "$TOP_DIR" "$STACK_DIR"
    chown -R stack "$STACK_DIR"
    if [[ "$SHELL_AFTER_RUN" != "no" ]]; then
        exec su -c "set -e; cd $STACK_DIR; bash stack.sh; bash" stack
    else
        exec su -c "set -e; cd $STACK_DIR; bash stack.sh" stack
    fi
    exit 1
else
    # We're not **root**, make sure ``sudo`` is available
    is_package_installed sudo || die "Sudo is required.  Re-run stack.sh as root ONE TIME ONLY to set up sudo."

    # UEC images ``/etc/sudoers`` does not have a ``#includedir``, add one
    sudo grep -q "^#includedir.*/etc/sudoers.d" /etc/sudoers ||
        echo "#includedir /etc/sudoers.d" | sudo tee -a /etc/sudoers

    # Set up devstack sudoers
    TEMPFILE=`mktemp`
    echo "`whoami` ALL=(root) NOPASSWD:ALL" >$TEMPFILE
    # Some binaries might be under /sbin or /usr/sbin, so make sure sudo will
    # see them by forcing PATH
    echo "Defaults:`whoami` secure_path=/sbin:/usr/sbin:/usr/bin:/bin:/usr/local/sbin:/usr/local/bin" >> $TEMPFILE
    chmod 0440 $TEMPFILE
    sudo chown root:root $TEMPFILE
    sudo mv $TEMPFILE /etc/sudoers.d/50_stack_sh

    # Remove old file
    sudo rm -f /etc/sudoers.d/stack_sh_nova
fi

# Create the destination directory and ensure it is writable by the user
sudo mkdir -p $DEST
if [ ! -w $DEST ]; then
    sudo chown `whoami` $DEST
fi

# Set ``OFFLINE`` to ``True`` to configure ``stack.sh`` to run cleanly without
# Internet access. ``stack.sh`` must have been previously run with Internet
# access to install prerequisites and fetch repositories.
OFFLINE=`trueorfalse False $OFFLINE`

# Set ``ERROR_ON_CLONE`` to ``True`` to configure ``stack.sh`` to exit if
# the destination git repository does not exist during the ``git_clone``
# operation.
ERROR_ON_CLONE=`trueorfalse False $ERROR_ON_CLONE`

# Destination path for service data
DATA_DIR=${DATA_DIR:-${DEST}/data}
sudo mkdir -p $DATA_DIR
sudo chown `whoami` $DATA_DIR


# Common Configuration
# ====================

# Set fixed and floating range here so we can make sure not to use addresses
# from either range when attempting to guess the IP to use for the host.
# Note that setting FIXED_RANGE may be necessary when running DevStack
# in an OpenStack cloud that uses either of these address ranges internally.
FLOATING_RANGE=${FLOATING_RANGE:-172.24.4.224/28}
FIXED_RANGE=${FIXED_RANGE:-10.0.0.0/24}
FIXED_NETWORK_SIZE=${FIXED_NETWORK_SIZE:-256}
NETWORK_GATEWAY=${NETWORK_GATEWAY:-10.0.0.1}

# Find the interface used for the default route
HOST_IP_IFACE=${HOST_IP_IFACE:-$(ip route | sed -n '/^default/{ s/.*dev \(\w\+\)\s\+.*/\1/; p; }')}
# Search for an IP unless an explicit is set by ``HOST_IP`` environment variable
if [ -z "$HOST_IP" -o "$HOST_IP" == "dhcp" ]; then
    HOST_IP=""
    HOST_IPS=`LC_ALL=C ip -f inet addr show ${HOST_IP_IFACE} | awk '/inet/ {split($2,parts,"/");  print parts[1]}'`
    for IP in $HOST_IPS; do
        # Attempt to filter out IP addresses that are part of the fixed and
        # floating range. Note that this method only works if the ``netaddr``
        # python library is installed. If it is not installed, an error
        # will be printed and the first IP from the interface will be used.
        # If that is not correct set ``HOST_IP`` in ``localrc`` to the correct
        # address.
        if ! (address_in_net $IP $FIXED_RANGE || address_in_net $IP $FLOATING_RANGE); then
            HOST_IP=$IP
            break;
        fi
    done
    if [ "$HOST_IP" == "" ]; then
        echo "Could not determine host ip address."
        echo "Either localrc specified dhcp on ${HOST_IP_IFACE} or defaulted"
        exit 1
    fi
fi

# Allow the use of an alternate hostname (such as localhost/127.0.0.1) for service endpoints.
SERVICE_HOST=${SERVICE_HOST:-$HOST_IP}
SERVICE_PROTOCOL=${SERVICE_PROTOCOL:-http}

# Configure services to use syslog instead of writing to individual log files
SYSLOG=`trueorfalse False $SYSLOG`
SYSLOG_HOST=${SYSLOG_HOST:-$HOST_IP}
SYSLOG_PORT=${SYSLOG_PORT:-516}

# Use color for logging output (only available if syslog is not used)
LOG_COLOR=`trueorfalse True $LOG_COLOR`

# Service startup timeout
SERVICE_TIMEOUT=${SERVICE_TIMEOUT:-60}


# Configure Projects
# ==================

# Get project function libraries
source $TOP_DIR/lib/tls
source $TOP_DIR/lib/horizon
source $TOP_DIR/lib/keystone
source $TOP_DIR/lib/glance
source $TOP_DIR/lib/nova
source $TOP_DIR/lib/cinder
source $TOP_DIR/lib/swift
source $TOP_DIR/lib/ceilometer
source $TOP_DIR/lib/heat
source $TOP_DIR/lib/quantum
source $TOP_DIR/lib/tempest
source $TOP_DIR/lib/baremetal

# Set the destination directories for OpenStack projects
HORIZON_DIR=$DEST/horizon
OPENSTACKCLIENT_DIR=$DEST/python-openstackclient
NOVNC_DIR=$DEST/noVNC
SWIFT3_DIR=$DEST/swift3

# Should cinder perform secure deletion of volumes?
# Defaults to true, can be set to False to avoid this bug when testing:
# https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1023755
CINDER_SECURE_DELETE=`trueorfalse True $CINDER_SECURE_DELETE`

# Name of the LVM volume group to use/create for iscsi volumes
VOLUME_GROUP=${VOLUME_GROUP:-stack-volumes}
VOLUME_NAME_PREFIX=${VOLUME_NAME_PREFIX:-volume-}
INSTANCE_NAME_PREFIX=${INSTANCE_NAME_PREFIX:-instance-}

# Generic helper to configure passwords
function read_password {
    XTRACE=$(set +o | grep xtrace)
    set +o xtrace
    var=$1; msg=$2
    pw=${!var}

    localrc=$TOP_DIR/localrc

    # If the password is not defined yet, proceed to prompt user for a password.
    if [ ! $pw ]; then
        # If there is no localrc file, create one
        if [ ! -e $localrc ]; then
            touch $localrc
        fi

        # Presumably if we got this far it can only be that our localrc is missing
        # the required password.  Prompt user for a password and write to localrc.
        echo ''
        echo '################################################################################'
        echo $msg
        echo '################################################################################'
        echo "This value will be written to your localrc file so you don't have to enter it "
        echo "again.  Use only alphanumeric characters."
        echo "If you leave this blank, a random default value will be used."
        pw=" "
        while true; do
            echo "Enter a password now:"
            read -e $var
            pw=${!var}
            [[ "$pw" = "`echo $pw | tr -cd [:alnum:]`" ]] && break
            echo "Invalid chars in password.  Try again:"
        done
        if [ ! $pw ]; then
            pw=`openssl rand -hex 10`
        fi
        eval "$var=$pw"
        echo "$var=$pw" >> $localrc
    fi
    $XTRACE
}


# Nova Network Configuration
# --------------------------

# FIXME: more documentation about why these are important options.  Also
# we should make sure we use the same variable names as the option names.

if [ "$VIRT_DRIVER" = 'xenserver' ]; then
    PUBLIC_INTERFACE_DEFAULT=eth3
    # Allow ``build_domU.sh`` to specify the flat network bridge via kernel args
    FLAT_NETWORK_BRIDGE_DEFAULT=$(grep -o 'flat_network_bridge=[[:alnum:]]*' /proc/cmdline | cut -d= -f 2 | sort -u)
    GUEST_INTERFACE_DEFAULT=eth1
elif [ "$VIRT_DRIVER" = 'baremetal' ]; then
    PUBLIC_INTERFACE_DEFAULT=eth0
    FLAT_NETWORK_BRIDGE_DEFAULT=br100
    FLAT_INTERFACE=${FLAT_INTERFACE:-eth0}
    FORCE_DHCP_RELEASE=${FORCE_DHCP_RELEASE:-False}
    NET_MAN=${NET_MAN:-FlatManager}
    STUB_NETWORK=${STUB_NETWORK:-False}
else
    PUBLIC_INTERFACE_DEFAULT=br100
    FLAT_NETWORK_BRIDGE_DEFAULT=br100
    GUEST_INTERFACE_DEFAULT=eth0
fi

PUBLIC_INTERFACE=${PUBLIC_INTERFACE:-$PUBLIC_INTERFACE_DEFAULT}
NET_MAN=${NET_MAN:-FlatDHCPManager}
EC2_DMZ_HOST=${EC2_DMZ_HOST:-$SERVICE_HOST}
FLAT_NETWORK_BRIDGE=${FLAT_NETWORK_BRIDGE:-$FLAT_NETWORK_BRIDGE_DEFAULT}
VLAN_INTERFACE=${VLAN_INTERFACE:-$GUEST_INTERFACE_DEFAULT}
FORCE_DHCP_RELEASE=${FORCE_DHCP_RELEASE:-True}

# Test floating pool and range are used for testing.  They are defined
# here until the admin APIs can replace nova-manage
TEST_FLOATING_POOL=${TEST_FLOATING_POOL:-test}
TEST_FLOATING_RANGE=${TEST_FLOATING_RANGE:-192.168.253.0/29}

# ``MULTI_HOST`` is a mode where each compute node runs its own network node.  This
# allows network operations and routing for a VM to occur on the server that is
# running the VM - removing a SPOF and bandwidth bottleneck.
MULTI_HOST=`trueorfalse False $MULTI_HOST`

# If you are using the FlatDHCP network mode on multiple hosts, set the
# ``FLAT_INTERFACE`` variable but make sure that the interface doesn't already
# have an IP or you risk breaking things.
#
# **DHCP Warning**:  If your flat interface device uses DHCP, there will be a
# hiccup while the network is moved from the flat interface to the flat network
# bridge.  This will happen when you launch your first instance.  Upon launch
# you will lose all connectivity to the node, and the VM launch will probably
# fail.
#
# If you are running on a single node and don't need to access the VMs from
# devices other than that node, you can set ``FLAT_INTERFACE=``
# This will stop nova from bridging any interfaces into ``FLAT_NETWORK_BRIDGE``.
FLAT_INTERFACE=${FLAT_INTERFACE-$GUEST_INTERFACE_DEFAULT}

## FIXME(ja): should/can we check that FLAT_INTERFACE is sane?


# Database Configuration
# ----------------------

# To select between database backends, add a line to localrc like:
#
#  use_database postgresql
#
# The available database backends are defined in the ``DATABASE_BACKENDS``
# variable defined in stackrc. By default, MySQL is enabled as the database
# backend.

initialize_database_backends && echo "Using $DATABASE_TYPE database backend" || echo "No database enabled"


# RabbitMQ or Qpid
# --------------------------

# Rabbit connection info
if is_service_enabled rabbit; then
    RABBIT_HOST=${RABBIT_HOST:-localhost}
    read_password RABBIT_PASSWORD "ENTER A PASSWORD TO USE FOR RABBIT."
fi

if is_service_enabled swift; then
    # If we are using swift3, we can default the s3 port to swift instead
    # of nova-objectstore
    if is_service_enabled swift3;then
        S3_SERVICE_PORT=${S3_SERVICE_PORT:-8080}
    fi
    # We only ask for Swift Hash if we have enabled swift service.
    # ``SWIFT_HASH`` is a random unique string for a swift cluster that
    # can never change.
    read_password SWIFT_HASH "ENTER A RANDOM SWIFT HASH."
fi

# Set default port for nova-objectstore
S3_SERVICE_PORT=${S3_SERVICE_PORT:-3333}


# Keystone
# --------

# The ``SERVICE_TOKEN`` is used to bootstrap the Keystone database.  It is
# just a string and is not a 'real' Keystone token.
read_password SERVICE_TOKEN "ENTER A SERVICE_TOKEN TO USE FOR THE SERVICE ADMIN TOKEN."
# Services authenticate to Identity with servicename/``SERVICE_PASSWORD``
read_password SERVICE_PASSWORD "ENTER A SERVICE_PASSWORD TO USE FOR THE SERVICE AUTHENTICATION."
# Horizon currently truncates usernames and passwords at 20 characters
read_password ADMIN_PASSWORD "ENTER A PASSWORD TO USE FOR HORIZON AND KEYSTONE (20 CHARS OR LESS)."

# Set the tenant for service accounts in Keystone
SERVICE_TENANT_NAME=${SERVICE_TENANT_NAME:-service}


# Log files
# ---------

# Draw a spinner so the user knows something is happening
function spinner() {
    local delay=0.75
    local spinstr='/-\|'
    printf "..." >&3
    while [ true ]; do
        local temp=${spinstr#?}
        printf "[%c]" "$spinstr" >&3
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b" >&3
    done
}

# Echo text to the log file, summary log file and stdout
# echo_summary "something to say"
function echo_summary() {
    if [[ -t 3 && "$VERBOSE" != "True" ]]; then
        kill >/dev/null 2>&1 $LAST_SPINNER_PID
        if [ ! -z "$LAST_SPINNER_PID" ]; then
            printf "\b\b\bdone\n" >&3
        fi
        echo -n $@ >&6
        spinner &
        LAST_SPINNER_PID=$!
    else
        echo $@ >&6
    fi
}

# Echo text only to stdout, no log files
# echo_nolog "something not for the logs"
function echo_nolog() {
    echo $@ >&3
}

# Set up logging for ``stack.sh``
# Set ``LOGFILE`` to turn on logging
# Append '.xxxxxxxx' to the given name to maintain history
# where 'xxxxxxxx' is a representation of the date the file was created
TIMESTAMP_FORMAT=${TIMESTAMP_FORMAT:-"%F-%H%M%S"}
if [[ -n "$LOGFILE" || -n "$SCREEN_LOGDIR" ]]; then
    LOGDAYS=${LOGDAYS:-7}
    CURRENT_LOG_TIME=$(date "+$TIMESTAMP_FORMAT")
fi

if [[ -n "$LOGFILE" ]]; then
    # First clean up old log files.  Use the user-specified ``LOGFILE``
    # as the template to search for, appending '.*' to match the date
    # we added on earlier runs.
    LOGDIR=$(dirname "$LOGFILE")
    LOGNAME=$(basename "$LOGFILE")
    mkdir -p $LOGDIR
    find $LOGDIR -maxdepth 1 -name $LOGNAME.\* -mtime +$LOGDAYS -exec rm {} \;
    LOGFILE=$LOGFILE.${CURRENT_LOG_TIME}
    SUMFILE=$LOGFILE.${CURRENT_LOG_TIME}.summary

    # Redirect output according to config

    # Copy stdout to fd 3
    exec 3>&1
    if [[ "$VERBOSE" == "True" ]]; then
        # Redirect stdout/stderr to tee to write the log file
        exec 1> >( awk '
                {
                    cmd ="date +\"%Y-%m-%d %H:%M:%S \""
                    cmd | getline now
                    close("date +\"%Y-%m-%d %H:%M:%S \"")
                    sub(/^/, now)
                    print
                    fflush()
                }' | tee "${LOGFILE}" ) 2>&1
        # Set up a second fd for output
        exec 6> >( tee "${SUMFILE}" )
    else
        # Set fd 1 and 2 to primary logfile
        exec 1> "${LOGFILE}" 2>&1
        # Set fd 6 to summary logfile and stdout
        exec 6> >( tee "${SUMFILE}" /dev/fd/3 )
    fi

    echo_summary "stack.sh log $LOGFILE"
    # Specified logfile name always links to the most recent log
    ln -sf $LOGFILE $LOGDIR/$LOGNAME
    ln -sf $SUMFILE $LOGDIR/$LOGNAME.summary
else
    # Set up output redirection without log files
    # Copy stdout to fd 3
    exec 3>&1
    if [[ "$VERBOSE" != "True" ]]; then
        # Throw away stdout and stderr
        exec 1>/dev/null 2>&1
    fi
    # Always send summary fd to original stdout
    exec 6>&3
fi

# Set up logging of screen windows
# Set ``SCREEN_LOGDIR`` to turn on logging of screen windows to the
# directory specified in ``SCREEN_LOGDIR``, we will log to the the file
# ``screen-$SERVICE_NAME-$TIMESTAMP.log`` in that dir and have a link
# ``screen-$SERVICE_NAME.log`` to the latest log file.
# Logs are kept for as long specified in ``LOGDAYS``.
if [[ -n "$SCREEN_LOGDIR" ]]; then

    # We make sure the directory is created.
    if [[ -d "$SCREEN_LOGDIR" ]]; then
        # We cleanup the old logs
        find $SCREEN_LOGDIR -maxdepth 1 -name screen-\*.log -mtime +$LOGDAYS -exec rm {} \;
    else
        mkdir -p $SCREEN_LOGDIR
    fi
fi


# Set Up Script Execution
# -----------------------

# Kill background processes on exit
trap clean EXIT
clean() {
    local r=$?
    kill >/dev/null 2>&1 $(jobs -p)
    exit $r
}


# Exit on any errors so that errors don't compound
trap failed ERR
failed() {
    local r=$?
    kill >/dev/null 2>&1 $(jobs -p)
    set +o xtrace
    [ -n "$LOGFILE" ] && echo "${0##*/} failed: full log in $LOGFILE"
    exit $r
}

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following along as the install occurs.
set -o xtrace


# Install Packages
# ================

# OpenStack uses a fair number of other projects.

# Install package requirements
echo_summary "Installing package prerequisites"
if is_ubuntu; then
    install_package $(get_packages $FILES/apts)
elif is_fedora; then
    install_package $(get_packages $FILES/rpms)
elif is_suse; then
    install_package $(get_packages $FILES/rpms-suse)
else
    exit_distro_not_supported "list of packages"
fi

if [[ $SYSLOG != "False" ]]; then
    if is_ubuntu || is_fedora; then
        install_package rsyslog-relp
    elif is_suse; then
        install_package rsyslog-module-relp
    else
        exit_distro_not_supported "rsyslog-relp installation"
    fi
fi

if is_service_enabled rabbit; then
    # Install rabbitmq-server
    # the temp file is necessary due to LP: #878600
    tfile=$(mktemp)
    install_package rabbitmq-server > "$tfile" 2>&1
    cat "$tfile"
    rm -f "$tfile"
elif is_service_enabled qpid; then
    if is_fedora; then
        install_package qpid-cpp-server-daemon
    elif is_ubuntu; then
        install_package qpidd
    else
        exit_distro_not_supported "qpid installation"
    fi
elif is_service_enabled zeromq; then
    if is_fedora; then
        install_package zeromq python-zmq
    elif is_ubuntu; then
        install_package libzmq1 python-zmq
    elif is_suse; then
        install_package libzmq1 python-pyzmq
    else
        exit_distro_not_supported "zeromq installation"
    fi
fi

if is_service_enabled $DATABASE_BACKENDS; then
    install_database
fi

if is_service_enabled q-agt; then
    install_quantum_agent_packages
fi

TRACK_DEPENDS=${TRACK_DEPENDS:-False}

# Install python packages into a virtualenv so that we can track them
if [[ $TRACK_DEPENDS = True ]] ; then
    echo_summary "Installing Python packages into a virtualenv $DEST/.venv"
    install_package python-virtualenv

    rm -rf $DEST/.venv
    virtualenv --system-site-packages $DEST/.venv
    source $DEST/.venv/bin/activate
    $DEST/.venv/bin/pip freeze > $DEST/requires-pre-pip
fi


# Check Out Source
# ----------------

echo_summary "Installing OpenStack project source"

# Grab clients first
install_keystoneclient
install_glanceclient
install_novaclient
# Check out the client libs that are used most
git_clone $OPENSTACKCLIENT_REPO $OPENSTACKCLIENT_DIR $OPENSTACKCLIENT_BRANCH

# glance, swift middleware and nova api needs keystone middleware
if is_service_enabled key g-api n-api swift; then
    # unified auth system (manages accounts/tokens)
    install_keystone
fi

if is_service_enabled swift; then
    install_swiftclient
    install_swift
    if is_service_enabled swift3; then
        # swift3 middleware to provide S3 emulation to Swift
        git_clone $SWIFT3_REPO $SWIFT3_DIR $SWIFT3_BRANCH
    fi
fi

if is_service_enabled g-api n-api; then
    # image catalog service
    install_glance
fi
if is_service_enabled nova; then
    # compute service
    install_nova
fi
if is_service_enabled n-novnc; then
    # a websockets/html5 or flash powered VNC console for vm instances
    git_clone $NOVNC_REPO $NOVNC_DIR $NOVNC_BRANCH
fi
if is_service_enabled horizon; then
    # dashboard
    install_horizon
fi
if is_service_enabled quantum; then
    install_quantum
    install_quantumclient
    install_quantum_third_party
fi
if is_service_enabled heat; then
    install_heat
    install_heatclient
fi
if is_service_enabled cinder; then
    install_cinder
fi
if is_service_enabled ceilometer; then
    install_ceilometer
fi
if is_service_enabled tempest; then
    install_tempest
fi


# Initialization
# ==============

echo_summary "Configuring OpenStack projects"

# Set up our checkouts so they are installed into python path
# allowing ``import nova`` or ``import glance.client``
configure_keystoneclient
configure_novaclient
setup_develop $OPENSTACKCLIENT_DIR
if is_service_enabled key g-api n-api swift; then
    configure_keystone
fi
if is_service_enabled swift; then
    configure_swift
    configure_swiftclient
    if is_service_enabled swift3; then
        setup_develop $SWIFT3_DIR
    fi
fi
if is_service_enabled g-api n-api; then
    configure_glance
fi

# Do this _after_ glance is installed to override the old binary
# TODO(dtroyer): figure out when this is no longer necessary
configure_glanceclient

if is_service_enabled nova; then
    configure_nova
fi
if is_service_enabled horizon; then
    configure_horizon
fi
if is_service_enabled quantum; then
    setup_quantumclient
    setup_quantum
fi
if is_service_enabled heat; then
    configure_heat
    configure_heatclient
fi
if is_service_enabled cinder; then
    configure_cinder
fi

if [[ $TRACK_DEPENDS = True ]] ; then
    $DEST/.venv/bin/pip freeze > $DEST/requires-post-pip
    if ! diff -Nru $DEST/requires-pre-pip $DEST/requires-post-pip > $DEST/requires.diff ; then
        cat $DEST/requires.diff
    fi
    echo "Ran stack.sh in depend tracking mode, bailing out now"
    exit 0
fi

if is_service_enabled tls-proxy; then
    configure_CA
    init_CA
    # Add name to /etc/hosts
    # don't be naive and add to existing line!
fi

# Syslog
# ------

if [[ $SYSLOG != "False" ]]; then
    if [[ "$SYSLOG_HOST" = "$HOST_IP" ]]; then
        # Configure the master host to receive
        cat <<EOF >/tmp/90-stack-m.conf
\$ModLoad imrelp
\$InputRELPServerRun $SYSLOG_PORT
EOF
        sudo mv /tmp/90-stack-m.conf /etc/rsyslog.d
    else
        # Set rsyslog to send to remote host
        cat <<EOF >/tmp/90-stack-s.conf
*.*		:omrelp:$SYSLOG_HOST:$SYSLOG_PORT
EOF
        sudo mv /tmp/90-stack-s.conf /etc/rsyslog.d
    fi
    echo_summary "Starting rsyslog"
    restart_service rsyslog
fi


# Finalize queue installation
# ----------------------------

if is_service_enabled rabbit; then
    # Start rabbitmq-server
    echo_summary "Starting RabbitMQ"
    if is_fedora || is_suse; then
        # service is not started by default
        restart_service rabbitmq-server
    fi
    # change the rabbit password since the default is "guest"
    sudo rabbitmqctl change_password guest $RABBIT_PASSWORD
elif is_service_enabled qpid; then
    echo_summary "Starting qpid"
    restart_service qpidd
fi


# Configure database
# ------------------

if is_service_enabled $DATABASE_BACKENDS; then
    configure_database
fi


# Configure screen
# ----------------

if [ -z "$SCREEN_HARDSTATUS" ]; then
    SCREEN_HARDSTATUS='%{= .} %-Lw%{= .}%> %n%f %t*%{= .}%+Lw%< %-=%{g}(%{d}%H/%l%{g})'
fi

# Clear screen rc file
SCREENRC=$TOP_DIR/$SCREEN_NAME-screenrc
if [[ -e $SCREENRC ]]; then
    echo -n > $SCREENRC
fi

# Create a new named screen to run processes in
screen -d -m -S $SCREEN_NAME -t shell -s /bin/bash
sleep 1

# Set a reasonable status bar
screen -r $SCREEN_NAME -X hardstatus alwayslastline "$SCREEN_HARDSTATUS"

# Initialize the directory for service status check
init_service_check

# Keystone
# --------

if is_service_enabled key; then
    echo_summary "Starting Keystone"
    init_keystone
    start_keystone

    # Set up a temporary admin URI for Keystone
    SERVICE_ENDPOINT=$KEYSTONE_SERVICE_PROTOCOL://$KEYSTONE_AUTH_HOST:$KEYSTONE_AUTH_PORT/v2.0

    if is_service_enabled tls-proxy; then
        export OS_CACERT=$INT_CA_DIR/ca-chain.pem
        # Until the client support is fixed, just use the internal endpoint
        SERVICE_ENDPOINT=http://$KEYSTONE_AUTH_HOST:$KEYSTONE_AUTH_PORT_INT/v2.0
    fi

    # Do the keystone-specific bits from keystone_data.sh
    export OS_SERVICE_TOKEN=$SERVICE_TOKEN
    export OS_SERVICE_ENDPOINT=$SERVICE_ENDPOINT
    create_keystone_accounts
    create_nova_accounts
    create_cinder_accounts
    create_quantum_accounts

    # ``keystone_data.sh`` creates services, admin and demo users, and roles.
    ADMIN_PASSWORD=$ADMIN_PASSWORD SERVICE_TENANT_NAME=$SERVICE_TENANT_NAME SERVICE_PASSWORD=$SERVICE_PASSWORD \
    SERVICE_TOKEN=$SERVICE_TOKEN SERVICE_ENDPOINT=$SERVICE_ENDPOINT SERVICE_HOST=$SERVICE_HOST \
    S3_SERVICE_PORT=$S3_SERVICE_PORT KEYSTONE_CATALOG_BACKEND=$KEYSTONE_CATALOG_BACKEND \
    DEVSTACK_DIR=$TOP_DIR ENABLED_SERVICES=$ENABLED_SERVICES HEAT_API_CFN_PORT=$HEAT_API_CFN_PORT \
    HEAT_API_PORT=$HEAT_API_PORT \
        bash -x $FILES/keystone_data.sh

    # Set up auth creds now that keystone is bootstrapped
    export OS_AUTH_URL=$SERVICE_ENDPOINT
    export OS_TENANT_NAME=admin
    export OS_USERNAME=admin
    export OS_PASSWORD=$ADMIN_PASSWORD
    unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT
fi


# Horizon
# -------

# Set up the django horizon application to serve via apache/wsgi

if is_service_enabled horizon; then
    echo_summary "Configuring and starting Horizon"
    init_horizon
    start_horizon
fi


# Glance
# ------

if is_service_enabled g-reg; then
    echo_summary "Configuring Glance"

    init_glance

    # Store the images in swift if enabled.
    if is_service_enabled swift; then
        iniset $GLANCE_API_CONF DEFAULT default_store swift
        iniset $GLANCE_API_CONF DEFAULT swift_store_auth_address $KEYSTONE_SERVICE_PROTOCOL://$KEYSTONE_SERVICE_HOST:$KEYSTONE_SERVICE_PORT/v2.0/
        iniset $GLANCE_API_CONF DEFAULT swift_store_user $SERVICE_TENANT_NAME:glance
        iniset $GLANCE_API_CONF DEFAULT swift_store_key $SERVICE_PASSWORD
        iniset $GLANCE_API_CONF DEFAULT swift_store_create_container_on_put True
    fi
fi


# Quantum
# -------

if is_service_enabled quantum; then
    echo_summary "Configuring Quantum"

    configure_quantum
    init_quantum
fi

# Some Quantum plugins require network controllers which are not
# a part of the OpenStack project. Configure and start them.
if is_service_enabled quantum; then
    configure_quantum_third_party
    init_quantum_third_party
    start_quantum_third_party
fi


# Nova
# ----

if is_service_enabled nova; then
    echo_summary "Configuring Nova"
    configure_nova
fi

if is_service_enabled n-net q-dhcp; then
    # Delete traces of nova networks from prior runs
    sudo killall dnsmasq || true
    clean_iptables
    rm -rf ${NOVA_STATE_PATH}/networks
    sudo mkdir -p ${NOVA_STATE_PATH}/networks
    sudo chown -R ${USER} ${NOVA_STATE_PATH}/networks
    # Force IP forwarding on, just on case
    sudo sysctl -w net.ipv4.ip_forward=1
fi


# Storage Service
# ---------------

if is_service_enabled swift; then
    echo_summary "Configuring Swift"
    init_swift
fi


# Volume Service
# --------------

if is_service_enabled cinder; then
    echo_summary "Configuring Cinder"
    init_cinder
fi

if is_service_enabled nova; then
    echo_summary "Configuring Nova"
    # Rebuild the config file from scratch
    create_nova_conf
    init_nova

    # Additional Nova configuration that is dependent on other services
    if is_service_enabled quantum; then
        create_nova_conf_quantum
    elif is_service_enabled n-net; then
        create_nova_conf_nova_network
    fi
    # All nova-compute workers need to know the vnc configuration options
    # These settings don't hurt anything if n-xvnc and n-novnc are disabled
    if is_service_enabled n-cpu; then
        NOVNCPROXY_URL=${NOVNCPROXY_URL:-"http://$SERVICE_HOST:6080/vnc_auto.html"}
        add_nova_opt "novncproxy_base_url=$NOVNCPROXY_URL"
        XVPVNCPROXY_URL=${XVPVNCPROXY_URL:-"http://$SERVICE_HOST:6081/console"}
        add_nova_opt "xvpvncproxy_base_url=$XVPVNCPROXY_URL"
    fi
    if [ "$VIRT_DRIVER" = 'xenserver' ]; then
        VNCSERVER_PROXYCLIENT_ADDRESS=${VNCSERVER_PROXYCLIENT_ADDRESS=169.254.0.1}
    else
        VNCSERVER_PROXYCLIENT_ADDRESS=${VNCSERVER_PROXYCLIENT_ADDRESS=127.0.0.1}
    fi
    # Address on which instance vncservers will listen on compute hosts.
    # For multi-host, this should be the management ip of the compute host.
    VNCSERVER_LISTEN=${VNCSERVER_LISTEN=127.0.0.1}
    add_nova_opt "vncserver_listen=$VNCSERVER_LISTEN"
    add_nova_opt "vncserver_proxyclient_address=$VNCSERVER_PROXYCLIENT_ADDRESS"
    add_nova_opt "ec2_dmz_host=$EC2_DMZ_HOST"
    if is_service_enabled zeromq; then
        add_nova_opt "rpc_backend=nova.openstack.common.rpc.impl_zmq"
    elif is_service_enabled qpid; then
        add_nova_opt "rpc_backend=nova.rpc.impl_qpid"
    elif [ -n "$RABBIT_HOST" ] &&  [ -n "$RABBIT_PASSWORD" ]; then
        add_nova_opt "rabbit_host=$RABBIT_HOST"
        add_nova_opt "rabbit_password=$RABBIT_PASSWORD"
    fi
    add_nova_opt "glance_api_servers=$GLANCE_HOSTPORT"


    # XenServer
    # ---------

    if [ "$VIRT_DRIVER" = 'xenserver' ]; then
        echo_summary "Using XenServer virtualization driver"
        read_password XENAPI_PASSWORD "ENTER A PASSWORD TO USE FOR XEN."
        add_nova_opt "compute_driver=xenapi.XenAPIDriver"
        XENAPI_CONNECTION_URL=${XENAPI_CONNECTION_URL:-"http://169.254.0.1"}
        XENAPI_USER=${XENAPI_USER:-"root"}
        add_nova_opt "xenapi_connection_url=$XENAPI_CONNECTION_URL"
        add_nova_opt "xenapi_connection_username=$XENAPI_USER"
        add_nova_opt "xenapi_connection_password=$XENAPI_PASSWORD"
        add_nova_opt "flat_injected=False"
        # Need to avoid crash due to new firewall support
        XEN_FIREWALL_DRIVER=${XEN_FIREWALL_DRIVER:-"nova.virt.firewall.IptablesFirewallDriver"}
        add_nova_opt "firewall_driver=$XEN_FIREWALL_DRIVER"

    # OpenVZ
    # ------

    elif [ "$VIRT_DRIVER" = 'openvz' ]; then
        echo_summary "Using OpenVZ virtualization driver"
        # TODO(deva): OpenVZ driver does not yet work if compute_driver is set here.
        #             Replace connection_type when this is fixed.
        #             add_nova_opt "compute_driver=openvz.connection.OpenVzConnection"
        add_nova_opt "connection_type=openvz"
        LIBVIRT_FIREWALL_DRIVER=${LIBVIRT_FIREWALL_DRIVER:-"nova.virt.libvirt.firewall.IptablesFirewallDriver"}
        add_nova_opt "firewall_driver=$LIBVIRT_FIREWALL_DRIVER"

    # Bare Metal
    # ----------

    elif [ "$VIRT_DRIVER" = 'baremetal' ]; then
        echo_summary "Using BareMetal driver"
        add_nova_opt "compute_driver=nova.virt.baremetal.driver.BareMetalDriver"
        LIBVIRT_FIREWALL_DRIVER=${LIBVIRT_FIREWALL_DRIVER:-"nova.virt.firewall.NoopFirewallDriver"}
        add_nova_opt "firewall_driver=$LIBVIRT_FIREWALL_DRIVER"
        add_nova_opt "baremetal_driver=$BM_DRIVER"
        add_nova_opt "baremetal_tftp_root=/tftpboot"
        add_nova_opt "baremetal_instance_type_extra_specs=cpu_arch:$BM_CPU_ARCH"
        add_nova_opt "baremetal_power_manager=$BM_POWER_MANAGER"
        add_nova_opt "scheduler_host_manager=nova.scheduler.baremetal_host_manager.BaremetalHostManager"
        add_nova_opt "scheduler_default_filters=AllHostsFilter"

    # Default
    # -------

    else
        echo_summary "Using libvirt virtualization driver"
        add_nova_opt "compute_driver=libvirt.LibvirtDriver"
        LIBVIRT_FIREWALL_DRIVER=${LIBVIRT_FIREWALL_DRIVER:-"nova.virt.libvirt.firewall.IptablesFirewallDriver"}
        add_nova_opt "firewall_driver=$LIBVIRT_FIREWALL_DRIVER"
    fi
fi

# Extra things to prepare nova for baremetal, before nova starts
if is_service_enabled nova && is_baremetal; then
    echo_summary "Preparing for nova baremetal"
    prepare_baremetal_toolchain
    configure_baremetal_nova_dirs
    if [[ "$BM_USE_FAKE_ENV" = "True" ]]; then
       create_fake_baremetal_env
    fi
fi

# Launch Services
# ===============

# Only run the services specified in ``ENABLED_SERVICES``

# Launch Swift Services
if is_service_enabled swift; then
    echo_summary "Starting Swift"
    start_swift
fi

# Launch the Glance services
if is_service_enabled g-api g-reg; then
    echo_summary "Starting Glance"
    start_glance
fi

# Create an access key and secret key for nova ec2 register image
if is_service_enabled key && is_service_enabled swift3 && is_service_enabled nova; then
    NOVA_USER_ID=$(keystone user-list | grep ' nova ' | get_field 1)
    NOVA_TENANT_ID=$(keystone tenant-list | grep " $SERVICE_TENANT_NAME " | get_field 1)
    CREDS=$(keystone ec2-credentials-create --user_id $NOVA_USER_ID --tenant_id $NOVA_TENANT_ID)
    ACCESS_KEY=$(echo "$CREDS" | awk '/ access / { print $4 }')
    SECRET_KEY=$(echo "$CREDS" | awk '/ secret / { print $4 }')
    add_nova_opt "s3_access_key=$ACCESS_KEY"
    add_nova_opt "s3_secret_key=$SECRET_KEY"
    add_nova_opt "s3_affix_tenant=True"
fi

screen_it zeromq "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-rpc-zmq-receiver"

# Launch the nova-api and wait for it to answer before continuing
if is_service_enabled n-api; then
    echo_summary "Starting Nova API"
    start_nova_api
fi

if is_service_enabled q-svc; then
    echo_summary "Starting Quantum"

    start_quantum_service_and_check
    create_quantum_initial_network
    setup_quantum_debug
elif is_service_enabled $DATABASE_BACKENDS && is_service_enabled n-net; then
    # Create a small network
    $NOVA_BIN_DIR/nova-manage network create "$PRIVATE_NETWORK_NAME" $FIXED_RANGE 1 $FIXED_NETWORK_SIZE $NETWORK_CREATE_ARGS

    # Create some floating ips
    $NOVA_BIN_DIR/nova-manage floating create $FLOATING_RANGE --pool=$PUBLIC_NETWORK_NAME

    # Create a second pool
    $NOVA_BIN_DIR/nova-manage floating create --ip_range=$TEST_FLOATING_RANGE --pool=$TEST_FLOATING_POOL
fi

if is_service_enabled quantum; then
    start_quantum_agents
fi
if is_service_enabled nova; then
    echo_summary "Starting Nova"
    start_nova
fi
if is_service_enabled cinder; then
    echo_summary "Starting Cinder"
    start_cinder
fi
if is_service_enabled ceilometer; then
    echo_summary "Configuring Ceilometer"
    configure_ceilometer
    echo_summary "Starting Ceilometer"
    start_ceilometer
fi

# Starting the nova-objectstore only if swift3 service is not enabled.
# Swift will act as s3 objectstore.
is_service_enabled swift3 || \
    screen_it n-obj "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-objectstore"


# Configure and launch heat engine, api and metadata
if is_service_enabled heat; then
    # Initialize heat, including replacing nova flavors
    echo_summary "Configuring Heat"
    init_heat
    echo_summary "Starting Heat"
    start_heat
fi

# Create account rc files
# =======================

# Creates source able script files for easier user switching.
# This step also creates certificates for tenants and users,
# which is helpful in image bundle steps.

if is_service_enabled nova && is_service_enabled key; then
    $TOP_DIR/tools/create_userrc.sh -PA --target-dir $TOP_DIR/accrc
fi


# Install Images
# ==============

# Upload an image to glance.
#
# The default image is cirros, a small testing image which lets you login as **root**
# cirros also uses ``cloud-init``, supporting login via keypair and sending scripts as
# userdata.  See https://help.ubuntu.com/community/CloudInit for more on cloud-init
#
# Override ``IMAGE_URLS`` with a comma-separated list of UEC images.
#  * **oneiric**: http://uec-images.ubuntu.com/oneiric/current/oneiric-server-cloudimg-amd64.tar.gz
#  * **precise**: http://uec-images.ubuntu.com/precise/current/precise-server-cloudimg-amd64.tar.gz

if is_service_enabled g-reg; then
    TOKEN=$(keystone token-get | grep ' id ' | get_field 2)

    if is_baremetal; then
       echo_summary "Creating and uploading baremetal images"

       # build and upload separate deploy kernel & ramdisk
       upload_baremetal_deploy $TOKEN

       # upload images, separating out the kernel & ramdisk for PXE boot
       for image_url in ${IMAGE_URLS//,/ }; do
           upload_baremetal_image $image_url $TOKEN
       done
    else
       echo_summary "Uploading images"

       # Option to upload legacy ami-tty, which works with xenserver
       if [[ -n "$UPLOAD_LEGACY_TTY" ]]; then
           IMAGE_URLS="${IMAGE_URLS:+${IMAGE_URLS},}https://github.com/downloads/citrix-openstack/warehouse/tty.tgz"
       fi

       for image_url in ${IMAGE_URLS//,/ }; do
           upload_image $image_url $TOKEN
       done
    fi
fi

# If we are running nova with baremetal driver, there are a few
# last-mile configuration bits to attend to, which must happen
# after n-api and n-sch have started.
# Also, creating the baremetal flavor must happen after images
# are loaded into glance, though just knowing the IDs is sufficient here
if is_service_enabled nova && is_baremetal; then
    # create special flavor for baremetal if we know what images to associate
    [[ -n "$BM_DEPLOY_KERNEL_ID" ]] && [[ -n "$BM_DEPLOY_RAMDISK_ID" ]] && \
       create_baremetal_flavor $BM_DEPLOY_KERNEL_ID $BM_DEPLOY_RAMDISK_ID

    # otherwise user can manually add it later by calling nova-baremetal-manage
    # otherwise user can manually add it later by calling nova-baremetal-manage
    [[ -n "$BM_FIRST_MAC" ]] && add_baremetal_node

    # NOTE: we do this here to ensure that our copy of dnsmasq is running
    sudo pkill dnsmasq || true
    sudo dnsmasq --conf-file= --port=0 --enable-tftp --tftp-root=/tftpboot \
        --dhcp-boot=pxelinux.0 --bind-interfaces --pid-file=/var/run/dnsmasq.pid \
        --interface=$BM_DNSMASQ_IFACE --dhcp-range=$BM_DNSMASQ_RANGE

    # ensure callback daemon is running
    sudo pkill nova-baremetal-deploy-helper || true
    screen_it baremetal "nova-baremetal-deploy-helper"
fi

# Configure Tempest last to ensure that the runtime configuration of
# the various OpenStack services can be queried.
if is_service_enabled tempest; then
    echo_summary "Configuring Tempest"
    configure_tempest
    echo '**************************************************'
    echo_summary "Finished Configuring Tempest"
    echo '**************************************************'
fi

# Save some values we generated for later use
CURRENT_RUN_TIME=$(date "+$TIMESTAMP_FORMAT")
echo "# $CURRENT_RUN_TIME" >$TOP_DIR/.stackenv
for i in BASE_SQL_CONN ENABLED_SERVICES HOST_IP LOGFILE \
  SERVICE_HOST SERVICE_PROTOCOL TLS_IP; do
    echo $i=${!i} >>$TOP_DIR/.stackenv
done


# Run local script
# ================

# Run ``local.sh`` if it exists to perform user-managed tasks
if [[ -x $TOP_DIR/local.sh ]]; then
    echo "Running user script $TOP_DIR/local.sh"
    $TOP_DIR/local.sh
fi

# Check the status of running services
service_check

# Fin
# ===

set +o xtrace

if [[ -n "$LOGFILE" ]]; then
    exec 1>&3
    # Force all output to stdout and logs now
    exec 1> >( tee -a "${LOGFILE}" ) 2>&1
else
    # Force all output to stdout now
    exec 1>&3
fi


# Using the cloud
# ---------------

echo ""
echo ""
echo ""

# If you installed Horizon on this server you should be able
# to access the site using your browser.
if is_service_enabled horizon; then
    echo "Horizon is now available at http://$SERVICE_HOST/"
fi

# Warn that the default flavors have been changed by Heat
if is_service_enabled heat; then
    echo "Heat has replaced the default flavors. View by running: nova flavor-list"
fi

# If Keystone is present you can point ``nova`` cli to this server
if is_service_enabled key; then
    echo "Keystone is serving at $KEYSTONE_AUTH_PROTOCOL://$SERVICE_HOST:$KEYSTONE_SERVICE_PORT/v2.0/"
    echo "Examples on using novaclient command line is in exercise.sh"
    echo "The default users are: admin and demo"
    echo "The password: $ADMIN_PASSWORD"
fi

# Echo ``HOST_IP`` - useful for ``build_uec.sh``, which uses dhcp to give the instance an address
echo "This is your host ip: $HOST_IP"

# Warn that ``EXTRA_FLAGS`` needs to be converted to ``EXTRA_OPTS``
if [[ -n "$EXTRA_FLAGS" ]]; then
    echo_summary "WARNING: EXTRA_FLAGS is defined and may need to be converted to EXTRA_OPTS"
fi

# Indicate how long this took to run (bash maintained variable ``SECONDS``)
echo_summary "stack.sh completed in $SECONDS seconds."
