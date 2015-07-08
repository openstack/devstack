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
# (14.04 Trusty or newer), **Fedora** (F20 or newer), or **CentOS/RHEL**
# (7 or newer) machine. (It may work on other platforms but support for those
# platforms is left to those who added them to DevStack.) It should work in
# a VM or physical server. Additionally, we maintain a list of ``deb`` and
# ``rpm`` dependencies and other configuration files in this repo.

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

# Not all distros have sbin in PATH for regular users.
PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin

# Keep track of the DevStack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Check for uninitialized variables, a big cause of bugs
NOUNSET=${NOUNSET:-}
if [[ -n "$NOUNSET" ]]; then
    set -o nounset
fi


# Configuration
# =============

# Sanity Checks
# -------------

# Clean up last environment var cache
if [[ -r $TOP_DIR/.stackenv ]]; then
    rm $TOP_DIR/.stackenv
fi

# ``stack.sh`` keeps the list of ``deb`` and ``rpm`` dependencies, config
# templates and other useful files in the ``files`` subdirectory
FILES=$TOP_DIR/files
if [ ! -d $FILES ]; then
    die $LINENO "missing devstack/files"
fi

# ``stack.sh`` keeps function libraries here
# Make sure ``$TOP_DIR/inc`` directory is present
if [ ! -d $TOP_DIR/inc ]; then
    die $LINENO "missing devstack/inc"
fi

# ``stack.sh`` keeps project libraries here
# Make sure ``$TOP_DIR/lib`` directory is present
if [ ! -d $TOP_DIR/lib ]; then
    die $LINENO "missing devstack/lib"
fi

# Check if run in POSIX shell
if [[ "${POSIXLY_CORRECT}" == "y" ]]; then
    echo "You are running POSIX compatibility mode, DevStack requires bash 4.2 or newer."
    exit 1
fi

# OpenStack is designed to be run as a non-root user; Horizon will fail to run
# as **root** since Apache will not serve content from **root** user).
# ``stack.sh`` must not be run as **root**.  It aborts and suggests one course of
# action to create a suitable user account.

if [[ $EUID -eq 0 ]]; then
    echo "You are running this script as root."
    echo "Cut it out."
    echo "Really."
    echo "If you need an account to run DevStack, do this (as root, heh) to create a non-root account:"
    echo "$TOP_DIR/tools/create-stack-user.sh"
    exit 1
fi


# Prepare the environment
# -----------------------

# Initialize variables:
LAST_SPINNER_PID=""

# Import common functions
source $TOP_DIR/functions

# Import config functions
source $TOP_DIR/inc/meta-config

# Import 'public' stack.sh functions
source $TOP_DIR/lib/stack

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro


# Global Settings
# ---------------

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
# Persistent variables can be placed in a ``local.conf`` file::
#
#     [[local|localrc]]
#     DATABASE_PASSWORD=anothersecret
#     DATABASE_USER=hellaroot
#
# We try to have sensible defaults, so you should be able to run ``./stack.sh``
# in most cases.  ``local.conf`` is not distributed with DevStack and will never
# be overwritten by a DevStack update.
#
# DevStack distributes ``stackrc`` which contains locations for the OpenStack
# repositories, branches to configure, and other configuration defaults.
# ``stackrc`` sources the ``localrc`` section of ``local.conf`` to allow you to
# safely override those settings.

if [[ ! -r $TOP_DIR/stackrc ]]; then
    die $LINENO "missing $TOP_DIR/stackrc - did you grab more than just stack.sh?"
fi
source $TOP_DIR/stackrc

# Warn users who aren't on an explicitly supported distro, but allow them to
# override check and attempt installation with ``FORCE=yes ./stack``
if [[ ! ${DISTRO} =~ (precise|trusty|utopic|vivid|7.0|wheezy|sid|testing|jessie|f21|f22|rhel7) ]]; then
    echo "WARNING: this script has not been tested on $DISTRO"
    if [[ "$FORCE" != "yes" ]]; then
        die $LINENO "If you wish to run this script anyway run with FORCE=yes"
    fi
fi

# Check to see if we are already running DevStack
# Note that this may fail if USE_SCREEN=False
if type -p screen > /dev/null && screen -ls | egrep -q "[0-9]\.$SCREEN_NAME"; then
    echo "You are already running a stack.sh session."
    echo "To rejoin this session type 'screen -x stack'."
    echo "To destroy this session, type './unstack.sh'."
    exit 1
fi


# Local Settings
# --------------

# Make sure the proxy config is visible to sub-processes
export_proxy_variables

# Remove services which were negated in ``ENABLED_SERVICES``
# using the "-" prefix (e.g., "-rabbit") instead of
# calling disable_service().
disable_negated_services


# Configure sudo
# --------------

# We're not as **root** so make sure ``sudo`` is available
is_package_installed sudo || install_package sudo

# UEC images ``/etc/sudoers`` does not have a ``#includedir``, add one
sudo grep -q "^#includedir.*/etc/sudoers.d" /etc/sudoers ||
    echo "#includedir /etc/sudoers.d" | sudo tee -a /etc/sudoers

# Set up DevStack sudoers
TEMPFILE=`mktemp`
echo "$STACK_USER ALL=(root) NOPASSWD:ALL" >$TEMPFILE
# Some binaries might be under ``/sbin`` or ``/usr/sbin``, so make sure sudo will
# see them by forcing ``PATH``
echo "Defaults:$STACK_USER secure_path=/sbin:/usr/sbin:/usr/bin:/bin:/usr/local/sbin:/usr/local/bin" >> $TEMPFILE
echo "Defaults:$STACK_USER !requiretty" >> $TEMPFILE
chmod 0440 $TEMPFILE
sudo chown root:root $TEMPFILE
sudo mv $TEMPFILE /etc/sudoers.d/50_stack_sh


# Configure Distro Repositories
# -----------------------------

# For Debian/Ubuntu make apt attempt to retry network ops on it's own
if is_ubuntu; then
    echo 'APT::Acquire::Retries "20";' | sudo tee /etc/apt/apt.conf.d/80retry  >/dev/null
fi

# Some distros need to add repos beyond the defaults provided by the vendor
# to pick up required packages.

if is_fedora && [[ $DISTRO == "rhel7" ]]; then
    # RHEL requires EPEL for many Open Stack dependencies

    # NOTE: We always remove and install latest -- some environments
    # use snapshot images, and if EPEL version updates they break
    # unless we update them to latest version.
    if sudo yum repolist enabled epel | grep -q 'epel'; then
        uninstall_package epel-release || true
    fi

    # This trick installs the latest epel-release from a bootstrap
    # repo, then removes itself (as epel-release installed the
    # "real" repo).
    #
    # You would think that rather than this, you could use
    # $releasever directly in .repo file we create below.  However
    # RHEL gives a $releasever of "6Server" which breaks the path;
    # see https://bugzilla.redhat.com/show_bug.cgi?id=1150759
    cat <<EOF | sudo tee /etc/yum.repos.d/epel-bootstrap.repo
[epel-bootstrap]
name=Bootstrap EPEL
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=epel-7&arch=\$basearch
failovermethod=priority
enabled=0
gpgcheck=0
EOF
    # Enable a bootstrap repo.  It is removed after finishing
    # the epel-release installation.
    is_package_installed yum-utils || install_package yum-utils
    sudo yum-config-manager --enable epel-bootstrap
    yum_install epel-release || \
        die $LINENO "Error installing EPEL repo, cannot continue"
    # EPEL rpm has installed it's version
    sudo rm -f /etc/yum.repos.d/epel-bootstrap.repo

    # ... and also optional to be enabled
    sudo yum-config-manager --enable rhel-7-server-optional-rpms

    RHEL_RDO_REPO_RPM=${RHEL7_RDO_REPO_RPM:-"https://repos.fedorapeople.org/repos/openstack/openstack-juno/rdo-release-juno-1.noarch.rpm"}
    RHEL_RDO_REPO_ID=${RHEL7_RDO_REPO_ID:-"openstack-juno"}

    if ! sudo yum repolist enabled $RHEL_RDO_REPO_ID | grep -q $RHEL_RDO_REPO_ID; then
        echo "RDO repo not detected; installing"
        yum_install $RHEL_RDO_REPO_RPM || \
            die $LINENO "Error installing RDO repo, cannot continue"
    fi

    if is_oraclelinux; then
        sudo yum-config-manager --enable ol7_optional_latest ol7_addons ol7_MySQL56
    fi

fi


# Configure Target Directories
# ----------------------------

# Destination path for installation ``DEST``
DEST=${DEST:-/opt/stack}

# Create the destination directory and ensure it is writable by the user
# and read/executable by everybody for daemons (e.g. apache run for horizon)
sudo mkdir -p $DEST
safe_chown -R $STACK_USER $DEST
safe_chmod 0755 $DEST

# Basic test for ``$DEST`` path permissions (fatal on error unless skipped)
check_path_perm_sanity ${DEST}

# Destination path for service data
DATA_DIR=${DATA_DIR:-${DEST}/data}
sudo mkdir -p $DATA_DIR
safe_chown -R $STACK_USER $DATA_DIR

# Configure proper hostname
# Certain services such as rabbitmq require that the local hostname resolves
# correctly.  Make sure it exists in /etc/hosts so that is always true.
LOCAL_HOSTNAME=`hostname -s`
if [ -z "`grep ^127.0.0.1 /etc/hosts | grep $LOCAL_HOSTNAME`" ]; then
    sudo sed -i "s/\(^127.0.0.1.*\)/\1 $LOCAL_HOSTNAME/" /etc/hosts
fi


# Configure Logging
# -----------------

# Set up logging level
VERBOSE=$(trueorfalse True VERBOSE)

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

function kill_spinner {
    if [ ! -z "$LAST_SPINNER_PID" ]; then
        kill >/dev/null 2>&1 $LAST_SPINNER_PID
        printf "\b\b\bdone\n" >&3
    fi
}

# Echo text to the log file, summary log file and stdout
# echo_summary "something to say"
function echo_summary {
    if [[ -t 3 && "$VERBOSE" != "True" ]]; then
        kill_spinner
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
LOGDAYS=${LOGDAYS:-7}
CURRENT_LOG_TIME=$(date "+$TIMESTAMP_FORMAT")

if [[ -n ${LOGDIR:-} ]]; then
    mkdir -p $LOGDIR
fi

if [[ -n "$LOGFILE" ]]; then
    # Clean up old log files.  Append '.*' to the user-specified
    # ``LOGFILE`` to match the date in the search template.
    LOGFILE_DIR="${LOGFILE%/*}"           # dirname
    LOGFILE_NAME="${LOGFILE##*/}"         # basename
    mkdir -p $LOGFILE_DIR
    find $LOGFILE_DIR -maxdepth 1 -name $LOGFILE_NAME.\* -mtime +$LOGDAYS -exec rm {} \;
    LOGFILE=$LOGFILE.${CURRENT_LOG_TIME}
    SUMFILE=$LOGFILE.summary.${CURRENT_LOG_TIME}

    # Redirect output according to config

    # Set fd 3 to a copy of stdout. So we can set fd 1 without losing
    # stdout later.
    exec 3>&1
    if [[ "$VERBOSE" == "True" ]]; then
        # Set fd 1 and 2 to write the log file
        exec 1> >( $TOP_DIR/tools/outfilter.py -v -o "${LOGFILE}" ) 2>&1
        # Set fd 6 to summary log file
        exec 6> >( $TOP_DIR/tools/outfilter.py -o "${SUMFILE}" )
    else
        # Set fd 1 and 2 to primary logfile
        exec 1> >( $TOP_DIR/tools/outfilter.py -o "${LOGFILE}" ) 2>&1
        # Set fd 6 to summary logfile and stdout
        exec 6> >( $TOP_DIR/tools/outfilter.py -v -o "${SUMFILE}" >&3 )
    fi

    echo_summary "stack.sh log $LOGFILE"
    # Specified logfile name always links to the most recent log
    ln -sf $LOGFILE $LOGFILE_DIR/$LOGFILE_NAME
    ln -sf $SUMFILE $LOGFILE_DIR/$LOGFILE_NAME.summary
else
    # Set up output redirection without log files
    # Set fd 3 to a copy of stdout. So we can set fd 1 without losing
    # stdout later.
    exec 3>&1
    if [[ "$VERBOSE" != "True" ]]; then
        # Throw away stdout and stderr
        exec 1>/dev/null 2>&1
    fi
    # Always send summary fd to original stdout
    exec 6> >( $TOP_DIR/tools/outfilter.py -v >&3 )
fi

# Set up logging of screen windows
# Set ``SCREEN_LOGDIR`` to turn on logging of screen windows to the
# directory specified in ``SCREEN_LOGDIR``, we will log to the the file
# ``screen-$SERVICE_NAME-$TIMESTAMP.log`` in that dir and have a link
# ``screen-$SERVICE_NAME.log`` to the latest log file.
# Logs are kept for as long specified in ``LOGDAYS``.
# This is deprecated....logs go in ``LOGDIR``, only symlinks will be here now.
if [[ -n "$SCREEN_LOGDIR" ]]; then

    # We make sure the directory is created.
    if [[ -d "$SCREEN_LOGDIR" ]]; then
        # We cleanup the old logs
        find $SCREEN_LOGDIR -maxdepth 1 -name screen-\*.log -mtime +$LOGDAYS -exec rm {} \;
    else
        mkdir -p $SCREEN_LOGDIR
    fi
fi


# Configure Error Traps
# ---------------------

# Kill background processes on exit
trap exit_trap EXIT
function exit_trap {
    local r=$?
    jobs=$(jobs -p)
    # Only do the kill when we're logging through a process substitution,
    # which currently is only to verbose logfile
    if [[ -n $jobs && -n "$LOGFILE" && "$VERBOSE" == "True" ]]; then
        echo "exit_trap: cleaning up child processes"
        kill 2>&1 $jobs
    fi

    # Kill the last spinner process
    kill_spinner

    if [[ $r -ne 0 ]]; then
        echo "Error on exit"
        if [[ -z $LOGDIR ]]; then
            $TOP_DIR/tools/worlddump.py
        else
            $TOP_DIR/tools/worlddump.py -d $LOGDIR
        fi
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

# Begin trapping error exit codes
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following along as the install occurs.
set -o xtrace

# Print the kernel version
uname -a

# Reset the bundle of CA certificates
SSL_BUNDLE_FILE="$DATA_DIR/ca-bundle.pem"
rm -f $SSL_BUNDLE_FILE

# Import common services (database, message queue) configuration
source $TOP_DIR/lib/database
source $TOP_DIR/lib/rpc_backend

# Service to enable with SSL if ``USE_SSL`` is True
SSL_ENABLED_SERVICES="key,nova,cinder,glance,s-proxy,neutron"

if is_service_enabled tls-proxy && [ "$USE_SSL" == "True" ]; then
    die $LINENO "tls-proxy and SSL are mutually exclusive"
fi

# Configure Projects
# ==================

# Clone all external plugins
fetch_plugins

# Plugin Phase 0: override_defaults - allow pluggins to override
# defaults before other services are run
run_phase override_defaults

# Import Apache functions
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
run_phase source

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
            pw=$(generate_hex_string 10)
        fi
        eval "$var=$pw"
        echo "$var=$pw" >> $localrc
    fi
    $XTRACE
}


# Database Configuration
# ----------------------

# To select between database backends, add the following to ``local.conf``:
#
#    disable_service mysql
#    enable_service postgresql
#
# The available database backends are listed in ``DATABASE_BACKENDS`` after
# ``lib/database`` is sourced. ``mysql`` is the default.

initialize_database_backends && echo "Using $DATABASE_TYPE database backend" || echo "No database enabled"


# Queue Configuration
# -------------------

# Rabbit connection info
# In multi node DevStack, second node needs ``RABBIT_USERID``, but rabbit
# isn't enabled.
RABBIT_USERID=${RABBIT_USERID:-stackrabbit}
if is_service_enabled rabbit; then
    RABBIT_HOST=${RABBIT_HOST:-$SERVICE_HOST}
    read_password RABBIT_PASSWORD "ENTER A PASSWORD TO USE FOR RABBIT."
fi


# Keystone
# --------

if is_service_enabled keystone; then
    # The ``SERVICE_TOKEN`` is used to bootstrap the Keystone database.  It is
    # just a string and is not a 'real' Keystone token.
    read_password SERVICE_TOKEN "ENTER A SERVICE_TOKEN TO USE FOR THE SERVICE ADMIN TOKEN."
    # Services authenticate to Identity with servicename/``SERVICE_PASSWORD``
    read_password SERVICE_PASSWORD "ENTER A SERVICE_PASSWORD TO USE FOR THE SERVICE AUTHENTICATION."
    # Horizon currently truncates usernames and passwords at 20 characters
    read_password ADMIN_PASSWORD "ENTER A PASSWORD TO USE FOR HORIZON AND KEYSTONE (20 CHARS OR LESS)."

    # Keystone can now optionally install OpenLDAP by enabling the ``ldap``
    # service in ``local.conf`` (e.g. ``enable_service ldap``).
    # To clean out the Keystone contents in OpenLDAP set ``KEYSTONE_CLEAR_LDAP``
    # to ``yes`` (e.g. ``KEYSTONE_CLEAR_LDAP=yes``) in ``local.conf``.  To enable the
    # Keystone Identity Driver (``keystone.identity.backends.ldap.Identity``)
    # set ``KEYSTONE_IDENTITY_BACKEND`` to ``ldap`` (e.g.
    # ``KEYSTONE_IDENTITY_BACKEND=ldap``) in ``local.conf``.

    # Only request LDAP password if the service is enabled
    if is_service_enabled ldap; then
        read_password LDAP_PASSWORD "ENTER A PASSWORD TO USE FOR LDAP"
    fi
fi


# Swift
# -----

if is_service_enabled s-proxy; then
    # We only ask for Swift Hash if we have enabled swift service.
    # ``SWIFT_HASH`` is a random unique string for a swift cluster that
    # can never change.
    read_password SWIFT_HASH "ENTER A RANDOM SWIFT HASH."

    if [[ -z "$SWIFT_TEMPURL_KEY" ]] && [[ "$SWIFT_ENABLE_TEMPURLS" == "True" ]]; then
        read_password SWIFT_TEMPURL_KEY "ENTER A KEY FOR SWIFT TEMPURLS."
    fi
fi

# Save configuration values
save_stackenv $LINENO


# Install Packages
# ================

# OpenStack uses a fair number of other projects.

# Install package requirements
# Source it so the entire environment is available
echo_summary "Installing package prerequisites"
source $TOP_DIR/tools/install_prereqs.sh

# Normalise USE_CONSTRAINTS
USE_CONSTRAINTS=$(trueorfalse False USE_CONSTRAINTS)

# Configure an appropriate Python environment
if [[ "$OFFLINE" != "True" ]]; then
    PYPI_ALTERNATIVE_URL=${PYPI_ALTERNATIVE_URL:-""} $TOP_DIR/tools/install_pip.sh
fi

TRACK_DEPENDS=${TRACK_DEPENDS:-False}

# Install Python packages into a virtualenv so that we can track them
if [[ $TRACK_DEPENDS = True ]]; then
    echo_summary "Installing Python packages into a virtualenv $DEST/.venv"
    pip_install -U virtualenv

    rm -rf $DEST/.venv
    virtualenv --system-site-packages $DEST/.venv
    source $DEST/.venv/bin/activate
    $DEST/.venv/bin/pip freeze > $DEST/requires-pre-pip
fi

# Do the ugly hacks for broken packages and distros
source $TOP_DIR/tools/fixup_stuff.sh


# Virtual Environment
# -------------------

# Install required infra support libraries
install_infra

# Pre-build some problematic wheels
if [[ -n ${WHEELHOUSE:-} && ! -d ${WHEELHOUSE:-} ]]; then
    source $TOP_DIR/tools/build_wheels.sh
fi


# Extras Pre-install
# ------------------
# Phase: pre-install
run_phase stack pre-install

install_rpc_backend

if is_service_enabled $DATABASE_BACKENDS; then
    install_database
    install_database_python
fi

if is_service_enabled neutron; then
    install_neutron_agent_packages
fi

# Check Out and Install Source
# ----------------------------

echo_summary "Installing OpenStack project source"

# Install Oslo libraries
install_oslo

# Install client libraries
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

# Install middleware
install_keystonemiddleware

if is_service_enabled keystone; then
    if [ "$KEYSTONE_AUTH_HOST" == "$SERVICE_HOST" ]; then
        stack_install_service keystone
        configure_keystone
    fi
fi

if is_service_enabled s-proxy; then
    if is_service_enabled ceilometer; then
        install_ceilometermiddleware
    fi
    stack_install_service swift
    configure_swift

    # swift3 middleware to provide S3 emulation to Swift
    if is_service_enabled swift3; then
        # Replace the nova-objectstore port by the swift port
        S3_SERVICE_PORT=8080
        git_clone $SWIFT3_REPO $SWIFT3_DIR $SWIFT3_BRANCH
        setup_develop $SWIFT3_DIR
    fi
fi

if is_service_enabled g-api n-api; then
    # Image catalog service
    stack_install_service glance
    configure_glance
fi

if is_service_enabled cinder; then
    # Block volume service
    stack_install_service cinder
    configure_cinder
fi

if is_service_enabled neutron; then
    # Network service
    stack_install_service neutron
    install_neutron_third_party
fi

if is_service_enabled nova; then
    # Compute service
    stack_install_service nova
    cleanup_nova
    configure_nova
fi

if is_service_enabled horizon; then
    # django openstack_auth
    install_django_openstack_auth
    # dashboard
    stack_install_service horizon
    configure_horizon
fi

if is_service_enabled ceilometer; then
    install_ceilometerclient
    stack_install_service ceilometer
    echo_summary "Configuring Ceilometer"
    configure_ceilometer
fi

if is_service_enabled heat; then
    stack_install_service heat
    install_heat_other
    cleanup_heat
    configure_heat
fi

if is_service_enabled tls-proxy || [ "$USE_SSL" == "True" ]; then
    configure_CA
    init_CA
    init_cert
    # Add name to ``/etc/hosts``.
    # Don't be naive and add to existing line!
fi


# Extras Install
# --------------

# Phase: install
run_phase stack install

# Install the OpenStack client, needed for most setup commands
if use_library_from_git "python-openstackclient"; then
    git_clone_by_name "python-openstackclient"
    setup_dev_lib "python-openstackclient"
else
    pip_install_gr python-openstackclient
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

USE_SCREEN=$(trueorfalse True USE_SCREEN)
if [[ "$USE_SCREEN" == "True" ]]; then
    # Create a new named screen to run processes in
    screen -d -m -S $SCREEN_NAME -t shell -s /bin/bash
    sleep 1

    # Set a reasonable status bar
    SCREEN_HARDSTATUS=${SCREEN_HARDSTATUS:-}
    if [ -z "$SCREEN_HARDSTATUS" ]; then
        SCREEN_HARDSTATUS='%{= .} %-Lw%{= .}%> %n%f %t*%{= .}%+Lw%< %-=%{g}(%{d}%H/%l%{g})'
    fi
    screen -r $SCREEN_NAME -X hardstatus alwayslastline "$SCREEN_HARDSTATUS"
    screen -r $SCREEN_NAME -X setenv PROMPT_COMMAND /bin/true
fi

# Clear ``screenrc`` file
SCREENRC=$TOP_DIR/$SCREEN_NAME-screenrc
if [[ -e $SCREENRC ]]; then
    rm -f $SCREENRC
fi

# Initialize the directory for service status check
init_service_check

# Save configuration values
save_stackenv $LINENO


# Start Services
# ==============

# Dstat
# -----

# A better kind of sysstat, with the top process per time slice
start_dstat


# Keystone
# --------

if is_service_enabled keystone; then
    echo_summary "Starting Keystone"

    if [ "$KEYSTONE_AUTH_HOST" == "$SERVICE_HOST" ]; then
        init_keystone
        start_keystone
    fi

    # Set up a temporary admin URI for Keystone
    SERVICE_ENDPOINT=$KEYSTONE_AUTH_URI/v2.0

    if is_service_enabled tls-proxy; then
        export OS_CACERT=$INT_CA_DIR/ca-chain.pem
        # Until the client support is fixed, just use the internal endpoint
        SERVICE_ENDPOINT=http://$KEYSTONE_AUTH_HOST:$KEYSTONE_AUTH_PORT_INT/v2.0
    fi

    # Setup OpenStackClient token-endpoint auth
    export OS_TOKEN=$SERVICE_TOKEN
    export OS_URL=$SERVICE_ENDPOINT

    create_keystone_accounts
    create_nova_accounts
    create_glance_accounts
    create_cinder_accounts
    create_neutron_accounts

    if is_service_enabled ceilometer; then
        create_ceilometer_accounts
    fi

    if is_service_enabled swift; then
        create_swift_accounts
    fi

    if is_service_enabled heat; then
        create_heat_accounts
    fi

    # Begone token auth
    unset OS_TOKEN OS_URL

    # force set to use v2 identity authentication even with v3 commands
    export OS_AUTH_TYPE=v2password

    # Set up password auth credentials now that Keystone is bootstrapped
    export OS_AUTH_URL=$SERVICE_ENDPOINT
    export OS_TENANT_NAME=admin
    export OS_USERNAME=admin
    export OS_PASSWORD=$ADMIN_PASSWORD
    export OS_REGION_NAME=$REGION_NAME
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
    # Run init_neutron only on the node hosting the Neutron API server
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

    if is_service_enabled n-net; then
        rm -rf ${NOVA_STATE_PATH}/networks
        sudo mkdir -p ${NOVA_STATE_PATH}/networks
        safe_chown -R ${STACK_USER} ${NOVA_STATE_PATH}/networks
    fi

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


# Extras Configuration
# ====================

# Phase: post-config
run_phase stack post-config


# Local Configuration
# ===================

# Apply configuration from ``local.conf`` if it exists for layer 2 services
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

# Upload an image to Glance.
#
# The default image is CirrOS, a small testing image which lets you login as **root**
# CirrOS has a ``cloud-init`` analog supporting login via keypair and sending
# scripts as userdata.
# See https://help.ubuntu.com/community/CloudInit for more on ``cloud-init``

if is_service_enabled g-reg; then
    TOKEN=$(openstack token issue -c id -f value)
    die_if_not_set $LINENO TOKEN "Keystone fail to get token"

    echo_summary "Uploading images"

    # Option to upload legacy ami-tty, which works with xenserver
    if [[ -n "$UPLOAD_LEGACY_TTY" ]]; then
        IMAGE_URLS="${IMAGE_URLS:+${IMAGE_URLS},}https://github.com/downloads/citrix-openstack/warehouse/tty.tgz"
    fi

    for image_url in ${IMAGE_URLS//,/ }; do
        upload_image $image_url $TOKEN
    done
fi

# Create an access key and secret key for Nova EC2 register image
if is_service_enabled keystone && is_service_enabled swift3 && is_service_enabled nova; then
    eval $(openstack ec2 credentials create --user nova --project $SERVICE_TENANT_NAME -f shell -c access -c secret)
    iniset $NOVA_CONF DEFAULT s3_access_key "$access"
    iniset $NOVA_CONF DEFAULT s3_secret_key "$secret"
    iniset $NOVA_CONF DEFAULT s3_affix_tenant "True"
fi

# Create a randomized default value for the keymgr's fixed_key
if is_service_enabled nova; then
    iniset $NOVA_CONF keymgr fixed_key $(generate_hex_string 32)
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
if is_service_enabled q-svc && [[ "$NEUTRON_CREATE_INITIAL_NETWORKS" == "True" ]]; then
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
    create_volume_types
fi
if is_service_enabled ceilometer; then
    echo_summary "Starting Ceilometer"
    init_ceilometer
    start_ceilometer
fi

# Configure and launch Heat engine, api and metadata
if is_service_enabled heat; then
    # Initialize heat
    echo_summary "Configuring Heat"
    init_heat
    echo_summary "Starting Heat"
    start_heat
    if [ "$HEAT_BUILD_PIP_MIRROR" = "True" ]; then
        echo_summary "Building Heat pip mirror"
        build_heat_pip_mirror
    fi
fi


# Create account rc files
# =======================

# Creates source able script files for easier user switching.
# This step also creates certificates for tenants and users,
# which is helpful in image bundle steps.

if is_service_enabled nova && is_service_enabled keystone; then
    USERRC_PARAMS="-PA --target-dir $TOP_DIR/accrc"

    if [ -f $SSL_BUNDLE_FILE ]; then
        USERRC_PARAMS="$USERRC_PARAMS --os-cacert $SSL_BUNDLE_FILE"
    fi

    if [[ "$HEAT_STANDALONE" = "True" ]]; then
        USERRC_PARAMS="$USERRC_PARAMS --heat-url http://$HEAT_API_HOST:$HEAT_API_PORT/v1"
    fi

    $TOP_DIR/tools/create_userrc.sh $USERRC_PARAMS
fi


# Save some values we generated for later use
save_stackenv

# Update/create user clouds.yaml file.
# clouds.yaml will have
# - A `devstack` entry for the `demo` user for the `demo` project.
# - A `devstack-admin` entry for the `admin` user for the `admin` project.

# The location is a variable to allow for easier refactoring later to make it
# overridable. There is currently no usecase where doing so makes sense, so
# it's not currently configurable.
CLOUDS_YAML=~/.config/openstack/clouds.yaml

mkdir -p $(dirname $CLOUDS_YAML)

CA_CERT_ARG=''
if [ -f "$SSL_BUNDLE_FILE" ]; then
    CA_CERT_ARG="--os-cacert $SSL_BUNDLE_FILE"
fi
$TOP_DIR/tools/update_clouds_yaml.py \
    --file $CLOUDS_YAML \
    --os-cloud devstack \
    --os-region-name $REGION_NAME \
    --os-identity-api-version $IDENTITY_API_VERSION \
    $CA_CERT_ARG \
    --os-auth-url $KEYSTONE_AUTH_URI/v$IDENTITY_API_VERSION \
    --os-username demo \
    --os-password $ADMIN_PASSWORD \
    --os-project-name demo
$TOP_DIR/tools/update_clouds_yaml.py \
    --file $CLOUDS_YAML \
    --os-cloud devstack-admin \
    --os-region-name $REGION_NAME \
    --os-identity-api-version $IDENTITY_API_VERSION \
    $CA_CERT_ARG \
    --os-auth-url $KEYSTONE_AUTH_URI/v$IDENTITY_API_VERSION \
    --os-username admin \
    --os-password $ADMIN_PASSWORD \
    --os-project-name admin


# Wrapup configuration
# ====================

# local.conf extra
# ----------------

# Apply configuration from ``local.conf`` if it exists for layer 2 services
# Phase: extra
merge_config_group $TOP_DIR/local.conf extra


# Run extras
# ----------

# Phase: extra
run_phase stack extra


# local.conf post-extra
# ---------------------

# Apply late configuration from ``local.conf`` if it exists for layer 2 services
# Phase: post-extra
merge_config_group $TOP_DIR/local.conf post-extra


# Run local script
# ----------------

# Run ``local.sh`` if it exists to perform user-managed tasks
if [[ -x $TOP_DIR/local.sh ]]; then
    echo "Running user script $TOP_DIR/local.sh"
    $TOP_DIR/local.sh
fi

# Check the status of running services
service_check


# Bash completion
# ===============

# Prepare bash completion for OSC
openstack complete | sudo tee /etc/bash_completion.d/osc.bash_completion > /dev/null

# If cinder is configured, set global_filter for PV devices
if is_service_enabled cinder; then
    if is_ubuntu; then
        echo_summary "Configuring lvm.conf global device filter"
        set_lvm_filter
    else
        echo_summary "Skip setting lvm filters for non Ubuntu systems"
    fi
fi


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
# ===============

echo ""
echo ""
echo ""
echo "This is your host IP address: $HOST_IP"
if [ "$HOST_IPV6" != "" ]; then
    echo "This is your host IPv6 address: $HOST_IPV6"
fi

# If you installed Horizon on this server you should be able
# to access the site using your browser.
if is_service_enabled horizon; then
    echo "Horizon is now available at http://$SERVICE_HOST/"
fi

# If Keystone is present you can point ``nova`` cli to this server
if is_service_enabled keystone; then
    echo "Keystone is serving at $KEYSTONE_SERVICE_URI/"
    echo "The default users are: admin and demo"
    echo "The password: $ADMIN_PASSWORD"
fi

# Warn that a deprecated feature was used
if [[ -n "$DEPRECATED_TEXT" ]]; then
    echo_summary "WARNING: $DEPRECATED_TEXT"
fi

# Indicate how long this took to run (bash maintained variable ``SECONDS``)
echo_summary "stack.sh completed in $SECONDS seconds."

# Restore/close logging file descriptors
exec 1>&3
exec 2>&3
exec 3>&-
exec 6>&-
