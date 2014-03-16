#!/usr/bin/env bash

# ``stack.sh`` is an opinionated OpenStack developer installation.  It
# installs and configures various combinations of **Ceilometer**, **Cinder**,
# **Glance**, **Heat**, **Horizon**, **Keystone**, **Nova**, **Neutron**,
# and **Swift**

# This script's options can be changed by setting appropriate environment
# variables.  You can configure things like which git repositories to use,
# services to enable, OS images to use, etc.  Default values are located in the
# ``stackrc`` file. If you are crafty you can run the script on multiple nodes
# using shared settings for common resources (eg., mysql or rabbitmq) and build
# a multi-node developer install.

# To keep this script simple we assume you are running on a recent **Ubuntu**
# (12.04 Precise or newer) or **Fedora** (F18 or newer) machine.  (It may work
# on other platforms but support for those platforms is left to those who added
# them to DevStack.)  It should work in a VM or physical server.  Additionally
# we maintain a list of ``apt`` and ``rpm`` dependencies and other configuration
# files in this repo.

# Learn more and get the most recent version at http://devstack.org

# Make sure custom grep options don't get in the way
unset GREP_OPTIONS

# Sanitize language settings to avoid commands bailing out
# with "unsupported locale setting" errors.
unset LANG
unset LANGUAGE
LC_ALL=C
export LC_ALL

# Make sure umask is sane
umask 022

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $TOP_DIR/functions

# Import config functions
source $TOP_DIR/lib/config

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro


# Global Settings
# ===============

# Check for a ``localrc`` section embedded in ``local.conf`` and extract if
# ``localrc`` does not already exist

# Phase: local
rm -f $TOP_DIR/.localrc.auto
if [[ -r $TOP_DIR/local.conf ]]; then
    LRC=$(get_meta_section_files $TOP_DIR/local.conf local)
    for lfile in $LRC; do
        if [[ "$lfile" == "localrc" ]]; then
            if [[ -r $TOP_DIR/localrc ]]; then
                warn $LINENO "localrc and local.conf:[[local]] both exist, using localrc"
            else
                echo "# Generated file, do not edit" >$TOP_DIR/.localrc.auto
                get_meta_section $TOP_DIR/local.conf local $lfile >>$TOP_DIR/.localrc.auto
            fi
        fi
    done
fi

# ``stack.sh`` is customizable by setting environment variables.  Override a
# default setting via export::
#
#     export DATABASE_PASSWORD=anothersecret
#     ./stack.sh
#
# or by setting the variable on the command line::
#
#     DATABASE_PASSWORD=simple ./stack.sh
#
# Persistent variables can be placed in a ``localrc`` file::
#
#     DATABASE_PASSWORD=anothersecret
#     DATABASE_USER=hellaroot
#
# We try to have sensible defaults, so you should be able to run ``./stack.sh``
# in most cases.  ``localrc`` is not distributed with DevStack and will never
# be overwritten by a DevStack update.
#
# DevStack distributes ``stackrc`` which contains locations for the OpenStack
# repositories, branches to configure, and other configuration defaults.
# ``stackrc`` sources ``localrc`` to allow you to safely override those settings.

if [[ ! -r $TOP_DIR/stackrc ]]; then
    log_error $LINENO "missing $TOP_DIR/stackrc - did you grab more than just stack.sh?"
fi
source $TOP_DIR/stackrc


# Local Settings
# --------------

# Make sure the proxy config is visible to sub-processes
export_proxy_variables

# Destination path for installation ``DEST``
DEST=${DEST:-/opt/stack}


# Sanity Check
# ------------

# Clean up last environment var cache
if [[ -r $TOP_DIR/.stackenv ]]; then
    rm $TOP_DIR/.stackenv
fi

# ``stack.sh`` keeps the list of ``apt`` and ``rpm`` dependencies and config
# templates and other useful files in the ``files`` subdirectory
FILES=$TOP_DIR/files
if [ ! -d $FILES ]; then
    log_error $LINENO "missing devstack/files"
fi

# ``stack.sh`` keeps function libraries here
# Make sure ``$TOP_DIR/lib`` directory is present
if [ ! -d $TOP_DIR/lib ]; then
    log_error $LINENO "missing devstack/lib"
fi

# Import common services (database, message queue) configuration
source $TOP_DIR/lib/database
source $TOP_DIR/lib/rpc_backend

# Remove services which were negated in ENABLED_SERVICES
# using the "-" prefix (e.g., "-rabbit") instead of
# calling disable_service().
disable_negated_services

# Warn users who aren't on an explicitly supported distro, but allow them to
# override check and attempt installation with ``FORCE=yes ./stack``
if [[ ! ${DISTRO} =~ (precise|saucy|trusty|7.0|wheezy|sid|testing|jessie|f19|f20|rhel6) ]]; then
    echo "WARNING: this script has not been tested on $DISTRO"
    if [[ "$FORCE" != "yes" ]]; then
        die $LINENO "If you wish to run this script anyway run with FORCE=yes"
    fi
fi

# Make sure we only have one rpc backend enabled,
# and the specified rpc backend is available on your platform.
check_rpc_backend

# Check to see if we are already running DevStack
# Note that this may fail if USE_SCREEN=False
if type -p screen >/dev/null && screen -ls | egrep -q "[0-9].$SCREEN_NAME"; then
    echo "You are already running a stack.sh session."
    echo "To rejoin this session type 'screen -x stack'."
    echo "To destroy this session, type './unstack.sh'."
    exit 1
fi

# Set up logging level
VERBOSE=$(trueorfalse True $VERBOSE)

# root Access
# -----------

# OpenStack is designed to be run as a non-root user; Horizon will fail to run
# as **root** since Apache will not serve content from **root** user).
# ``stack.sh`` must not be run as **root**.  It aborts and suggests one course of
# action to create a suitable user account.

if [[ $EUID -eq 0 ]]; then
    echo "You are running this script as root."
    echo "Cut it out."
    echo "Really."
    echo "If you need an account to run DevStack, do this (as root, heh) to create $STACK_USER:"
    echo "$TOP_DIR/tools/create-stack-user.sh"
    exit 1
fi

# We're not **root**, make sure ``sudo`` is available
is_package_installed sudo || install_package sudo

# UEC images ``/etc/sudoers`` does not have a ``#includedir``, add one
sudo grep -q "^#includedir.*/etc/sudoers.d" /etc/sudoers ||
    echo "#includedir /etc/sudoers.d" | sudo tee -a /etc/sudoers

# Set up devstack sudoers
TEMPFILE=`mktemp`
echo "$STACK_USER ALL=(root) NOPASSWD:ALL" >$TEMPFILE
# Some binaries might be under /sbin or /usr/sbin, so make sure sudo will
# see them by forcing PATH
echo "Defaults:$STACK_USER secure_path=/sbin:/usr/sbin:/usr/bin:/bin:/usr/local/sbin:/usr/local/bin" >> $TEMPFILE
chmod 0440 $TEMPFILE
sudo chown root:root $TEMPFILE
sudo mv $TEMPFILE /etc/sudoers.d/50_stack_sh

# Additional repos
# ----------------

# Some distros need to add repos beyond the defaults provided by the vendor
# to pick up required packages.

# The Debian Wheezy official repositories do not contain all required packages,
# add gplhost repository.
if [[ "$os_VENDOR" =~ (Debian) ]]; then
    echo 'deb http://archive.gplhost.com/debian grizzly main' | sudo tee /etc/apt/sources.list.d/gplhost_wheezy-backports.list
    echo 'deb http://archive.gplhost.com/debian grizzly-backports main' | sudo tee -a /etc/apt/sources.list.d/gplhost_wheezy-backports.list
    apt_get update
    apt_get install --force-yes gplhost-archive-keyring
fi

if [[ is_fedora && $DISTRO =~ (rhel6) ]]; then
    # Installing Open vSwitch on RHEL6 requires enabling the RDO repo.
    RHEL6_RDO_REPO_RPM=${RHEL6_RDO_REPO_RPM:-"http://rdo.fedorapeople.org/openstack-havana/rdo-release-havana.rpm"}
    RHEL6_RDO_REPO_ID=${RHEL6_RDO_REPO_ID:-"openstack-havana"}
    if ! sudo yum repolist enabled $RHEL6_RDO_REPO_ID | grep -q $RHEL6_RDO_REPO_ID; then
        echo "RDO repo not detected; installing"
        yum_install $RHEL6_RDO_REPO_RPM || \
            die $LINENO "Error installing RDO repo, cannot continue"
    fi

    # RHEL6 requires EPEL for many Open Stack dependencies
    RHEL6_EPEL_RPM=${RHEL6_EPEL_RPM:-"http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm"}
    if ! sudo yum repolist enabled epel | grep -q 'epel'; then
        echo "EPEL not detected; installing"
        yum_install ${RHEL6_EPEL_RPM} || \
            die $LINENO "Error installing EPEL repo, cannot continue"
    fi

    # ... and also optional to be enabled
    is_package_installed yum-utils || install_package yum-utils
    sudo yum-config-manager --enable rhel-6-server-optional-rpms

fi

# Filesystem setup
# ----------------

# Create the destination directory and ensure it is writable by the user
# and read/executable by everybody for daemons (e.g. apache run for horizon)
sudo mkdir -p $DEST
safe_chown -R $STACK_USER $DEST
safe_chmod 0755 $DEST

# a basic test for $DEST path permissions (fatal on error unless skipped)
check_path_perm_sanity ${DEST}

# Certain services such as rabbitmq require that the local hostname resolves
# correctly.  Make sure it exists in /etc/hosts so that is always true.
LOCAL_HOSTNAME=`hostname -s`
if [ -z "`grep ^127.0.0.1 /etc/hosts | grep $LOCAL_HOSTNAME`" ]; then
    sudo sed -i "s/\(^127.0.0.1.*\)/\1 $LOCAL_HOSTNAME/" /etc/hosts
fi

# Destination path for service data
DATA_DIR=${DATA_DIR:-${DEST}/data}
sudo mkdir -p $DATA_DIR
safe_chown -R $STACK_USER $DATA_DIR


# Common Configuration
# --------------------

# Set ``OFFLINE`` to ``True`` to configure ``stack.sh`` to run cleanly without
# Internet access. ``stack.sh`` must have been previously run with Internet
# access to install prerequisites and fetch repositories.
OFFLINE=`trueorfalse False $OFFLINE`

# Set ``ERROR_ON_CLONE`` to ``True`` to configure ``stack.sh`` to exit if
# the destination git repository does not exist during the ``git_clone``
# operation.
ERROR_ON_CLONE=`trueorfalse False $ERROR_ON_CLONE`

# Whether to enable the debug log level in OpenStack services
ENABLE_DEBUG_LOG_LEVEL=`trueorfalse True $ENABLE_DEBUG_LOG_LEVEL`

# Set fixed and floating range here so we can make sure not to use addresses
# from either range when attempting to guess the IP to use for the host.
# Note that setting FIXED_RANGE may be necessary when running DevStack
# in an OpenStack cloud that uses either of these address ranges internally.
FLOATING_RANGE=${FLOATING_RANGE:-172.24.4.0/24}
FIXED_RANGE=${FIXED_RANGE:-10.0.0.0/24}
FIXED_NETWORK_SIZE=${FIXED_NETWORK_SIZE:-256}

HOST_IP=$(get_default_host_ip $FIXED_RANGE $FLOATING_RANGE "$HOST_IP_IFACE" "$HOST_IP")
if [ "$HOST_IP" == "" ]; then
    die $LINENO "Could not determine host ip address. Either localrc specified dhcp on ${HOST_IP_IFACE} or defaulted"
fi

# Allow the use of an alternate hostname (such as localhost/127.0.0.1) for service endpoints.
SERVICE_HOST=${SERVICE_HOST:-$HOST_IP}

# Allow the use of an alternate protocol (such as https) for service endpoints
SERVICE_PROTOCOL=${SERVICE_PROTOCOL:-http}

# Configure services to use syslog instead of writing to individual log files
SYSLOG=`trueorfalse False $SYSLOG`
SYSLOG_HOST=${SYSLOG_HOST:-$HOST_IP}
SYSLOG_PORT=${SYSLOG_PORT:-516}

# for DSTAT logging
DSTAT_FILE=${DSTAT_FILE:-"dstat.txt"}

# Use color for logging output (only available if syslog is not used)
LOG_COLOR=`trueorfalse True $LOG_COLOR`

# Service startup timeout
SERVICE_TIMEOUT=${SERVICE_TIMEOUT:-60}

# Reset the bundle of CA certificates
SSL_BUNDLE_FILE="$DATA_DIR/ca-bundle.pem"
rm -f $SSL_BUNDLE_FILE


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

# Set the destination directories for other OpenStack projects
OPENSTACKCLIENT_DIR=$DEST/python-openstackclient

# Interactive Configuration
# -------------------------

# Do all interactive config up front before the logging spew begins

# Generic helper to configure passwords
function read_password {
    XTRACE=$(set +o | grep xtrace)
    set +o xtrace
    var=$1; msg=$2
    pw=${!var}

    if [[ -f $RC_DIR/localrc ]]; then
        localrc=$TOP_DIR/localrc
    else
        localrc=$TOP_DIR/.localrc.auto
    fi

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


# Database Configuration

# To select between database backends, add the following to ``localrc``:
#
#    disable_service mysql
#    enable_service postgresql
#
# The available database backends are listed in ``DATABASE_BACKENDS`` after
# ``lib/database`` is sourced. ``mysql`` is the default.

initialize_database_backends && echo "Using $DATABASE_TYPE database backend" || echo "No database enabled"


# Queue Configuration

# Rabbit connection info
if is_service_enabled rabbit; then
    RABBIT_HOST=${RABBIT_HOST:-localhost}
    read_password RABBIT_PASSWORD "ENTER A PASSWORD TO USE FOR RABBIT."
fi


# Keystone

if is_service_enabled key; then
    # The ``SERVICE_TOKEN`` is used to bootstrap the Keystone database.  It is
    # just a string and is not a 'real' Keystone token.
    read_password SERVICE_TOKEN "ENTER A SERVICE_TOKEN TO USE FOR THE SERVICE ADMIN TOKEN."
    # Services authenticate to Identity with servicename/``SERVICE_PASSWORD``
    read_password SERVICE_PASSWORD "ENTER A SERVICE_PASSWORD TO USE FOR THE SERVICE AUTHENTICATION."
    # Horizon currently truncates usernames and passwords at 20 characters
    read_password ADMIN_PASSWORD "ENTER A PASSWORD TO USE FOR HORIZON AND KEYSTONE (20 CHARS OR LESS)."

    # Keystone can now optionally install OpenLDAP by enabling the ``ldap``
    # service in ``localrc`` (e.g. ``enable_service ldap``).
    # To clean out the Keystone contents in OpenLDAP set ``KEYSTONE_CLEAR_LDAP``
    # to ``yes`` (e.g. ``KEYSTONE_CLEAR_LDAP=yes``) in ``localrc``.  To enable the
    # Keystone Identity Driver (``keystone.identity.backends.ldap.Identity``)
    # set ``KEYSTONE_IDENTITY_BACKEND`` to ``ldap`` (e.g.
    # ``KEYSTONE_IDENTITY_BACKEND=ldap``) in ``localrc``.

    # only request ldap password if the service is enabled
    if is_service_enabled ldap; then
        read_password LDAP_PASSWORD "ENTER A PASSWORD TO USE FOR LDAP"
    fi
fi


# Swift

if is_service_enabled s-proxy; then
    # We only ask for Swift Hash if we have enabled swift service.
    # ``SWIFT_HASH`` is a random unique string for a swift cluster that
    # can never change.
    read_password SWIFT_HASH "ENTER A RANDOM SWIFT HASH."
fi


# Configure logging
# -----------------

# Draw a spinner so the user knows something is happening
function spinner {
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
function echo_summary {
    if [[ -t 3 && "$VERBOSE" != "True" ]]; then
        kill >/dev/null 2>&1 $LAST_SPINNER_PID
        if [ ! -z "$LAST_SPINNER_PID" ]; then
            printf "\b\b\bdone\n" >&3
        fi
        echo -n -e $@ >&6
        spinner &
        LAST_SPINNER_PID=$!
    else
        echo -e $@ >&6
    fi
}

# Echo text only to stdout, no log files
# echo_nolog "something not for the logs"
function echo_nolog {
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
    LOGFILENAME=$(basename "$LOGFILE")
    mkdir -p $LOGDIR
    find $LOGDIR -maxdepth 1 -name $LOGFILENAME.\* -mtime +$LOGDAYS -exec rm {} \;
    LOGFILE=$LOGFILE.${CURRENT_LOG_TIME}
    SUMFILE=$LOGFILE.${CURRENT_LOG_TIME}.summary

    # Redirect output according to config

    # Copy stdout to fd 3
    exec 3>&1
    if [[ "$VERBOSE" == "True" ]]; then
        # Redirect stdout/stderr to tee to write the log file
        exec 1> >( awk -v logfile=${LOGFILE} '
                /((set \+o$)|xtrace)/ { next }
                {
                    cmd ="date +\"%Y-%m-%d %H:%M:%S.%3N | \""
                    cmd | getline now
                    close("date +\"%Y-%m-%d %H:%M:%S.%3N | \"")
                    sub(/^/, now)
                    print > logfile
                    fflush(logfile)
                    print
                    fflush("")
                }' ) 2>&1
        # Set up a second fd for output
        exec 6> >( tee "${SUMFILE}" )
    else
        # Set fd 1 and 2 to primary logfile
        exec 1> "${LOGFILE}" 2>&1
        # Set fd 6 to summary logfile and stdout
        exec 6> >( tee "${SUMFILE}" >&3 )
    fi

    echo_summary "stack.sh log $LOGFILE"
    # Specified logfile name always links to the most recent log
    ln -sf $LOGFILE $LOGDIR/$LOGFILENAME
    ln -sf $SUMFILE $LOGDIR/$LOGFILENAME.summary
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
trap exit_trap EXIT
function exit_trap {
    local r=$?
    jobs=$(jobs -p)
    if [[ -n $jobs ]]; then
        echo "exit_trap: cleaning up child processes"
        kill 2>&1 $jobs
    fi
    exit $r
}

# Exit on any errors so that errors don't compound
trap err_trap ERR
function err_trap {
    local r=$?
    set +o xtrace
    if [[ -n "$LOGFILE" ]]; then
        echo "${0##*/} failed: full log in $LOGFILE"
    else
        echo "${0##*/} failed"
    fi
    exit $r
}


set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following along as the install occurs.
set -o xtrace


# Install Packages
# ================

# OpenStack uses a fair number of other projects.

# Install package requirements
# Source it so the entire environment is available
echo_summary "Installing package prerequisites"
source $TOP_DIR/tools/install_prereqs.sh

# Configure an appropriate python environment
if [[ "$OFFLINE" != "True" ]]; then
    $TOP_DIR/tools/install_pip.sh
fi

# Do the ugly hacks for borken packages and distros
$TOP_DIR/tools/fixup_stuff.sh

install_rpc_backend

if is_service_enabled $DATABASE_BACKENDS; then
    install_database
fi

if is_service_enabled neutron; then
    install_neutron_agent_packages
fi

TRACK_DEPENDS=${TRACK_DEPENDS:-False}

# Install python packages into a virtualenv so that we can track them
if [[ $TRACK_DEPENDS = True ]]; then
    echo_summary "Installing Python packages into a virtualenv $DEST/.venv"
    pip_install -U virtualenv

    rm -rf $DEST/.venv
    virtualenv --system-site-packages $DEST/.venv
    source $DEST/.venv/bin/activate
    $DEST/.venv/bin/pip freeze > $DEST/requires-pre-pip
fi

# Check Out and Install Source
# ----------------------------

echo_summary "Installing OpenStack project source"

# Install required infra support libraries
install_infra

# Install oslo libraries that have graduated
install_oslo

# Install stackforge libraries for testing
if is_service_enabled stackforge_libs; then
    install_stackforge
fi

# Install clients libraries
install_keystoneclient
install_glanceclient
install_cinderclient
install_novaclient
if is_service_enabled swift glance horizon; then
    install_swiftclient
fi
if is_service_enabled neutron nova horizon; then
    install_neutronclient
fi
if is_service_enabled heat horizon; then
    install_heatclient
fi

git_clone $OPENSTACKCLIENT_REPO $OPENSTACKCLIENT_DIR $OPENSTACKCLIENT_BRANCH
setup_develop $OPENSTACKCLIENT_DIR

if is_service_enabled key; then
    install_keystone
    configure_keystone
fi

if is_service_enabled s-proxy; then
    install_swift
    configure_swift

    # swift3 middleware to provide S3 emulation to Swift
    if is_service_enabled swift3; then
        # replace the nova-objectstore port by the swift port
        S3_SERVICE_PORT=8080
        git_clone $SWIFT3_REPO $SWIFT3_DIR $SWIFT3_BRANCH
        setup_develop $SWIFT3_DIR
    fi
fi

if is_service_enabled g-api n-api; then
    # image catalog service
    install_glance
    configure_glance
fi

if is_service_enabled cinder; then
    install_cinder
    configure_cinder
fi

if is_service_enabled neutron; then
    install_neutron
    install_neutron_third_party
fi

if is_service_enabled nova; then
    # compute service
    install_nova
    cleanup_nova
    configure_nova
fi

if is_service_enabled horizon; then
    # dashboard
    install_horizon
    configure_horizon
fi

if is_service_enabled ceilometer; then
    install_ceilometerclient
    install_ceilometer
    echo_summary "Configuring Ceilometer"
    configure_ceilometer
    configure_ceilometerclient
fi

if is_service_enabled heat; then
    install_heat
    cleanup_heat
    configure_heat
fi

if is_service_enabled tls-proxy; then
    configure_CA
    init_CA
    init_cert
    # Add name to /etc/hosts
    # don't be naive and add to existing line!
fi


# Extras Install
# --------------

# Phase: install
if [[ -d $TOP_DIR/extras.d ]]; then
    for i in $TOP_DIR/extras.d/*.sh; do
        [[ -r $i ]] && source $i stack install
    done
fi

if [[ $TRACK_DEPENDS = True ]]; then
    $DEST/.venv/bin/pip freeze > $DEST/requires-post-pip
    if ! diff -Nru $DEST/requires-pre-pip $DEST/requires-post-pip > $DEST/requires.diff; then
        echo "Detect some changes for installed packages of pip, in depend tracking mode"
        cat $DEST/requires.diff
    fi
    echo "Ran stack.sh in depend tracking mode, bailing out now"
    exit 0
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

    RSYSLOGCONF="/etc/rsyslog.conf"
    if [ -f $RSYSLOGCONF ]; then
        sudo cp -b $RSYSLOGCONF $RSYSLOGCONF.bak
        if [[ $(grep '$SystemLogRateLimitBurst' $RSYSLOGCONF)  ]]; then
            sudo sed -i 's/$SystemLogRateLimitBurst\ .*/$SystemLogRateLimitBurst\ 0/' $RSYSLOGCONF
        else
            sudo sed -i '$ i $SystemLogRateLimitBurst\ 0' $RSYSLOGCONF
        fi
        if [[ $(grep '$SystemLogRateLimitInterval' $RSYSLOGCONF)  ]]; then
            sudo sed -i 's/$SystemLogRateLimitInterval\ .*/$SystemLogRateLimitInterval\ 0/' $RSYSLOGCONF
        else
            sudo sed -i '$ i $SystemLogRateLimitInterval\ 0' $RSYSLOGCONF
        fi
    fi

    echo_summary "Starting rsyslog"
    restart_service rsyslog
fi


# Finalize queue installation
# ----------------------------
restart_rpc_backend


# Export Certicate Authority Bundle
# ---------------------------------

# If certificates were used and written to the SSL bundle file then these
# should be exported so clients can validate their connections.

if [ -f $SSL_BUNDLE_FILE ]; then
    export OS_CACERT=$SSL_BUNDLE_FILE
fi


# Configure database
# ------------------

if is_service_enabled $DATABASE_BACKENDS; then
    configure_database
fi


# Configure screen
# ----------------

USE_SCREEN=$(trueorfalse True $USE_SCREEN)
if [[ "$USE_SCREEN" == "True" ]]; then
    # Create a new named screen to run processes in
    screen -d -m -S $SCREEN_NAME -t shell -s /bin/bash
    sleep 1

    # Set a reasonable status bar
    if [ -z "$SCREEN_HARDSTATUS" ]; then
        SCREEN_HARDSTATUS='%{= .} %-Lw%{= .}%> %n%f %t*%{= .}%+Lw%< %-=%{g}(%{d}%H/%l%{g})'
    fi
    screen -r $SCREEN_NAME -X hardstatus alwayslastline "$SCREEN_HARDSTATUS"
    screen -r $SCREEN_NAME -X setenv PROMPT_COMMAND /bin/true
fi

# Clear screen rc file
SCREENRC=$TOP_DIR/$SCREEN_NAME-screenrc
if [[ -e $SCREENRC ]]; then
    rm -f $SCREENRC
fi

# Initialize the directory for service status check
init_service_check

# Dstat
# -------

# A better kind of sysstat, with the top process per time slice
DSTAT_OPTS="-tcndylp --top-cpu-adv"
if [[ -n ${SCREEN_LOGDIR} ]]; then
    screen_it dstat "cd $TOP_DIR; dstat $DSTAT_OPTS | tee $SCREEN_LOGDIR/$DSTAT_FILE"
else
    screen_it dstat "dstat $DSTAT_OPTS"
fi

# Start Services
# ==============

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
    # Add temporarily to make openstackclient work
    export OS_TOKEN=$SERVICE_TOKEN
    export OS_URL=$SERVICE_ENDPOINT
    create_keystone_accounts
    create_nova_accounts
    create_cinder_accounts
    create_neutron_accounts

    if is_service_enabled ceilometer; then
        create_ceilometer_accounts
    fi

    if is_service_enabled swift || is_service_enabled s-proxy; then
        create_swift_accounts
    fi

    if is_service_enabled heat; then
        create_heat_accounts
    fi

    # ``keystone_data.sh`` creates services, admin and demo users, and roles.
    ADMIN_PASSWORD=$ADMIN_PASSWORD SERVICE_TENANT_NAME=$SERVICE_TENANT_NAME SERVICE_PASSWORD=$SERVICE_PASSWORD \
    SERVICE_TOKEN=$SERVICE_TOKEN SERVICE_ENDPOINT=$SERVICE_ENDPOINT SERVICE_HOST=$SERVICE_HOST \
    S3_SERVICE_PORT=$S3_SERVICE_PORT KEYSTONE_CATALOG_BACKEND=$KEYSTONE_CATALOG_BACKEND \
    DEVSTACK_DIR=$TOP_DIR ENABLED_SERVICES=$ENABLED_SERVICES \
        bash -x $FILES/keystone_data.sh

    # Set up auth creds now that keystone is bootstrapped
    unset OS_TOKEN OS_URL
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
fi


# Neutron
# -------

if is_service_enabled neutron; then
    echo_summary "Configuring Neutron"

    configure_neutron
    # Run init_neutron only on the node hosting the neutron API server
    if is_service_enabled $DATABASE_BACKENDS && is_service_enabled q-svc; then
        init_neutron
    fi
fi

# Some Neutron plugins require network controllers which are not
# a part of the OpenStack project. Configure and start them.
if is_service_enabled neutron; then
    configure_neutron_third_party
    init_neutron_third_party
    start_neutron_third_party
fi


# Nova
# ----

if is_service_enabled n-net q-dhcp; then
    # Delete traces of nova networks from prior runs
    # Do not kill any dnsmasq instance spawned by NetworkManager
    netman_pid=$(pidof NetworkManager || true)
    if [ -z "$netman_pid" ]; then
        sudo killall dnsmasq || true
    else
        sudo ps h -o pid,ppid -C dnsmasq | grep -v $netman_pid | awk '{print $1}' | sudo xargs kill || true
    fi

    clean_iptables
    rm -rf ${NOVA_STATE_PATH}/networks
    sudo mkdir -p ${NOVA_STATE_PATH}/networks
    safe_chown -R ${USER} ${NOVA_STATE_PATH}/networks
    # Force IP forwarding on, just in case
    sudo sysctl -w net.ipv4.ip_forward=1
fi


# Storage Service
# ---------------

if is_service_enabled s-proxy; then
    echo_summary "Configuring Swift"
    init_swift
fi


# Volume Service
# --------------

if is_service_enabled cinder; then
    echo_summary "Configuring Cinder"
    init_cinder
fi


# Compute Service
# ---------------

if is_service_enabled nova; then
    echo_summary "Configuring Nova"
    init_nova

    # Additional Nova configuration that is dependent on other services
    if is_service_enabled neutron; then
        create_nova_conf_neutron
    elif is_service_enabled n-net; then
        create_nova_conf_nova_network
    fi

    init_nova_cells
fi

# Extra things to prepare nova for baremetal, before nova starts
if is_service_enabled nova && is_baremetal; then
    echo_summary "Preparing for nova baremetal"
    prepare_baremetal_toolchain
    configure_baremetal_nova_dirs
fi


# Extras Configuration
# ====================

# Phase: post-config
if [[ -d $TOP_DIR/extras.d ]]; then
    for i in $TOP_DIR/extras.d/*.sh; do
        [[ -r $i ]] && source $i stack post-config
    done
fi


# Local Configuration
# ===================

# Apply configuration from local.conf if it exists for layer 2 services
# Phase: post-config
merge_config_group $TOP_DIR/local.conf post-config


# Launch Services
# ===============

# Only run the services specified in ``ENABLED_SERVICES``

# Launch Swift Services
if is_service_enabled s-proxy; then
    echo_summary "Starting Swift"
    start_swift
fi

# Launch the Glance services
if is_service_enabled glance; then
    echo_summary "Starting Glance"
    start_glance
fi

# Install Images
# ==============

# Upload an image to glance.
#
# The default image is cirros, a small testing image which lets you login as **root**
# cirros has a ``cloud-init`` analog supporting login via keypair and sending
# scripts as userdata.
# See https://help.ubuntu.com/community/CloudInit for more on cloud-init
#
# Override ``IMAGE_URLS`` with a comma-separated list of UEC images.
#  * **precise**: http://uec-images.ubuntu.com/precise/current/precise-server-cloudimg-amd64.tar.gz

if is_service_enabled g-reg; then
    TOKEN=$(keystone token-get | grep ' id ' | get_field 2)
    die_if_not_set $LINENO TOKEN "Keystone fail to get token"

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

# Create an access key and secret key for nova ec2 register image
if is_service_enabled key && is_service_enabled swift3 && is_service_enabled nova; then
    NOVA_USER_ID=$(keystone user-list | grep ' nova ' | get_field 1)
    die_if_not_set $LINENO NOVA_USER_ID "Failure retrieving NOVA_USER_ID for nova"
    NOVA_TENANT_ID=$(keystone tenant-list | grep " $SERVICE_TENANT_NAME " | get_field 1)
    die_if_not_set $LINENO NOVA_TENANT_ID "Failure retrieving NOVA_TENANT_ID for $SERVICE_TENANT_NAME"
    CREDS=$(keystone ec2-credentials-create --user-id $NOVA_USER_ID --tenant-id $NOVA_TENANT_ID)
    ACCESS_KEY=$(echo "$CREDS" | awk '/ access / { print $4 }')
    SECRET_KEY=$(echo "$CREDS" | awk '/ secret / { print $4 }')
    iniset $NOVA_CONF DEFAULT s3_access_key "$ACCESS_KEY"
    iniset $NOVA_CONF DEFAULT s3_secret_key "$SECRET_KEY"
    iniset $NOVA_CONF DEFAULT s3_affix_tenant "True"
fi

# Create a randomized default value for the keymgr's fixed_key
if is_service_enabled nova; then
    FIXED_KEY=""
    for i in $(seq 1 64); do
        FIXED_KEY+=$(echo "obase=16; $(($RANDOM % 16))" | bc);
    done;
    iniset $NOVA_CONF keymgr fixed_key "$FIXED_KEY"
fi

if is_service_enabled zeromq; then
    echo_summary "Starting zermomq receiver"
    screen_it zeromq "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-rpc-zmq-receiver"
fi

# Launch the nova-api and wait for it to answer before continuing
if is_service_enabled n-api; then
    echo_summary "Starting Nova API"
    start_nova_api
fi

if is_service_enabled q-svc; then
    echo_summary "Starting Neutron"
    start_neutron_service_and_check
    check_neutron_third_party_integration
elif is_service_enabled $DATABASE_BACKENDS && is_service_enabled n-net; then
    NM_CONF=${NOVA_CONF}
    if is_service_enabled n-cell; then
        NM_CONF=${NOVA_CELLS_CONF}
    fi

    # Create a small network
    $NOVA_BIN_DIR/nova-manage --config-file $NM_CONF network create "$PRIVATE_NETWORK_NAME" $FIXED_RANGE 1 $FIXED_NETWORK_SIZE $NETWORK_CREATE_ARGS

    # Create some floating ips
    $NOVA_BIN_DIR/nova-manage --config-file $NM_CONF floating create $FLOATING_RANGE --pool=$PUBLIC_NETWORK_NAME

    # Create a second pool
    $NOVA_BIN_DIR/nova-manage --config-file $NM_CONF floating create --ip_range=$TEST_FLOATING_RANGE --pool=$TEST_FLOATING_POOL
fi

if is_service_enabled neutron; then
    start_neutron_agents
fi
# Once neutron agents are started setup initial network elements
if is_service_enabled q-svc; then
    echo_summary "Creating initial neutron network elements"
    create_neutron_initial_network
    setup_neutron_debug
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
    echo_summary "Starting Ceilometer"
    init_ceilometer
    start_ceilometer
fi

# Configure and launch heat engine, api and metadata
if is_service_enabled heat; then
    # Initialize heat
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
    USERRC_PARAMS="-PA --target-dir $TOP_DIR/accrc"

    if [ -f $SSL_BUNDLE_FILE ]; then
        USERRC_PARAMS="$USERRC_PARAMS --os-cacert $SSL_BUNDLE_FILE"
    fi

    $TOP_DIR/tools/create_userrc.sh $USERRC_PARAMS
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
    [[ -n "$BM_FIRST_MAC" ]] && add_baremetal_node

    if [[ "$BM_DNSMASQ_FROM_NOVA_NETWORK" = "False" ]]; then
        # NOTE: we do this here to ensure that our copy of dnsmasq is running
        sudo pkill dnsmasq || true
        sudo dnsmasq --conf-file= --port=0 --enable-tftp --tftp-root=/tftpboot \
            --dhcp-boot=pxelinux.0 --bind-interfaces --pid-file=/var/run/dnsmasq.pid \
            --interface=$BM_DNSMASQ_IFACE --dhcp-range=$BM_DNSMASQ_RANGE \
            ${BM_DNSMASQ_DNS:+--dhcp-option=option:dns-server,$BM_DNSMASQ_DNS}
    fi
    # ensure callback daemon is running
    sudo pkill nova-baremetal-deploy-helper || true
    screen_it baremetal "cd ; nova-baremetal-deploy-helper"
fi

# Save some values we generated for later use
CURRENT_RUN_TIME=$(date "+$TIMESTAMP_FORMAT")
echo "# $CURRENT_RUN_TIME" >$TOP_DIR/.stackenv
for i in BASE_SQL_CONN ENABLED_SERVICES HOST_IP LOGFILE \
    SERVICE_HOST SERVICE_PROTOCOL STACK_USER TLS_IP KEYSTONE_AUTH_PROTOCOL OS_CACERT; do
    echo $i=${!i} >>$TOP_DIR/.stackenv
done


# Local Configuration
# ===================

# Apply configuration from local.conf if it exists for layer 2 services
# Phase: extra
merge_config_group $TOP_DIR/local.conf extra


# Run extras
# ==========

# Phase: extra
if [[ -d $TOP_DIR/extras.d ]]; then
    for i in $TOP_DIR/extras.d/*.sh; do
        [[ -r $i ]] && source $i stack extra
    done
fi

# Local Configuration
# ===================

# Apply configuration from local.conf if it exists for layer 2 services
# Phase: post-extra
merge_config_group $TOP_DIR/local.conf post-extra


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

# If Keystone is present you can point ``nova`` cli to this server
if is_service_enabled key; then
    echo "Keystone is serving at $KEYSTONE_AUTH_PROTOCOL://$SERVICE_HOST:$KEYSTONE_SERVICE_PORT/v2.0/"
    echo "Examples on using novaclient command line is in exercise.sh"
    echo "The default users are: admin and demo"
    echo "The password: $ADMIN_PASSWORD"
fi

# Echo ``HOST_IP`` - useful for ``build_uec.sh``, which uses dhcp to give the instance an address
echo "This is your host ip: $HOST_IP"

# Warn that a deprecated feature was used
if [[ -n "$DEPRECATED_TEXT" ]]; then
    echo_summary "WARNING: $DEPRECATED_TEXT"
fi

# TODO(dtroyer): Remove EXTRA_OPTS after stable/icehouse branch is cut
# Specific warning for deprecated configs
if [[ -n "$EXTRA_OPTS" ]]; then
    echo ""
    echo_summary "WARNING: EXTRA_OPTS is used"
    echo "You are using EXTRA_OPTS to pass configuration into nova.conf."
    echo "Please convert that configuration in localrc to a nova.conf section in local.conf:"
    echo "EXTRA_OPTS will be removed early in the Juno development cycle"
    echo "
[[post-config|\$NOVA_CONF]]
[DEFAULT]
"
    for I in "${EXTRA_OPTS[@]}"; do
        # Replace the first '=' with ' ' for iniset syntax
        echo ${I}
    done
fi

# TODO(dtroyer): Remove EXTRA_BAREMETAL_OPTS after stable/icehouse branch is cut
if [[ -n "$EXTRA_BAREMETAL_OPTS" ]]; then
    echo ""
    echo_summary "WARNING: EXTRA_BAREMETAL_OPTS is used"
    echo "You are using EXTRA_BAREMETAL_OPTS to pass configuration into nova.conf."
    echo "Please convert that configuration in localrc to a nova.conf section in local.conf:"
    echo "EXTRA_BAREMETAL_OPTS will be removed early in the Juno development cycle"
    echo "
[[post-config|\$NOVA_CONF]]
[baremetal]
"
    for I in "${EXTRA_BAREMETAL_OPTS[@]}"; do
        # Replace the first '=' with ' ' for iniset syntax
        echo ${I}
    done
fi

# TODO(dtroyer): Remove Q_AGENT_EXTRA_AGENT_OPTS after stable/juno branch is cut
if [[ -n "$Q_AGENT_EXTRA_AGENT_OPTS" ]]; then
    echo ""
    echo_summary "WARNING: Q_AGENT_EXTRA_AGENT_OPTS is used"
    echo "You are using Q_AGENT_EXTRA_AGENT_OPTS to pass configuration into $NEUTRON_CONF."
    echo "Please convert that configuration in localrc to a $NEUTRON_CONF section in local.conf:"
    echo "Q_AGENT_EXTRA_AGENT_OPTS will be removed early in the 'K' development cycle"
    echo "
[[post-config|/\$Q_PLUGIN_CONF_FILE]]
[DEFAULT]
"
    for I in "${Q_AGENT_EXTRA_AGENT_OPTS[@]}"; do
        # Replace the first '=' with ' ' for iniset syntax
        echo ${I}
    done
fi

# TODO(dtroyer): Remove Q_AGENT_EXTRA_SRV_OPTS after stable/juno branch is cut
if [[ -n "$Q_AGENT_EXTRA_SRV_OPTS" ]]; then
    echo ""
    echo_summary "WARNING: Q_AGENT_EXTRA_SRV_OPTS is used"
    echo "You are using Q_AGENT_EXTRA_SRV_OPTS to pass configuration into $NEUTRON_CONF."
    echo "Please convert that configuration in localrc to a $NEUTRON_CONF section in local.conf:"
    echo "Q_AGENT_EXTRA_AGENT_OPTS will be removed early in the 'K' development cycle"
    echo "
[[post-config|/\$Q_PLUGIN_CONF_FILE]]
[DEFAULT]
"
    for I in "${Q_AGENT_EXTRA_SRV_OPTS[@]}"; do
        # Replace the first '=' with ' ' for iniset syntax
        echo ${I}
    done
fi

# TODO(dtroyer): Remove Q_DHCP_EXTRA_DEFAULT_OPTS after stable/icehouse branch is cut
if [[ -n "$Q_DHCP_EXTRA_DEFAULT_OPTS" ]]; then
    echo ""
    echo_summary "WARNING: Q_DHCP_EXTRA_DEFAULT_OPTS is used"
    echo "You are using Q_DHCP_EXTRA_DEFAULT_OPTS to pass configuration into $Q_DHCP_CONF_FILE."
    echo "Please convert that configuration in localrc to a $Q_DHCP_CONF_FILE section in local.conf:"
    echo "Q_DHCP_EXTRA_DEFAULT_OPTS will be removed early in the Juno development cycle"
    echo "
[[post-config|/\$Q_DHCP_CONF_FILE]]
[DEFAULT]
"
    for I in "${Q_DHCP_EXTRA_DEFAULT_OPTS[@]}"; do
        # Replace the first '=' with ' ' for iniset syntax
        echo ${I}
    done
fi

# TODO(dtroyer): Remove Q_SRV_EXTRA_DEFAULT_OPTS after stable/icehouse branch is cut
if [[ -n "$Q_SRV_EXTRA_DEFAULT_OPTS" ]]; then
    echo ""
    echo_summary "WARNING: Q_SRV_EXTRA_DEFAULT_OPTS is used"
    echo "You are using Q_SRV_EXTRA_DEFAULT_OPTS to pass configuration into $NEUTRON_CONF."
    echo "Please convert that configuration in localrc to a $NEUTRON_CONF section in local.conf:"
    echo "Q_SRV_EXTRA_DEFAULT_OPTS will be removed early in the Juno development cycle"
    echo "
[[post-config|\$NEUTRON_CONF]]
[DEFAULT]
"
    for I in "${Q_SRV_EXTRA_DEFAULT_OPTS[@]}"; do
        # Replace the first '=' with ' ' for iniset syntax
        echo ${I}
    done
fi

# Indicate how long this took to run (bash maintained variable ``SECONDS``)
echo_summary "stack.sh completed in $SECONDS seconds."

# Restore/close logging file descriptors
exec 1>&3
exec 2>&3
exec 3>&-
exec 6>&-
