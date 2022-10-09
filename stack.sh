#!/usr/bin/env bash

# ``stack.sh`` is an opinionated OpenStack developer installation.  It
# installs and configures various combinations of **Cinder**, **Glance**,
# **Horizon**, **Keystone**, **Nova**, **Neutron**, and **Swift**

# This script's options can be changed by setting appropriate environment
# variables.  You can configure things like which git repositories to use,
# services to enable, OS images to use, etc.  Default values are located in the
# ``stackrc`` file. If you are crafty you can run the script on multiple nodes
# using shared settings for common resources (eg., mysql or rabbitmq) and build
# a multi-node developer install.

# To keep this script simple we assume you are running on a recent **Ubuntu**
# (Bionic or newer), **Fedora** (F36 or newer), or **CentOS/RHEL**
# (7 or newer) machine. (It may work on other platforms but support for those
# platforms is left to those who added them to DevStack.) It should work in
# a VM or physical server. Additionally, we maintain a list of ``deb`` and
# ``rpm`` dependencies and other configuration files in this repo.

# Learn more and get the most recent version at http://devstack.org

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following along as the install occurs.
set -o xtrace

# Make sure custom grep options don't get in the way
unset GREP_OPTIONS

# NOTE(sdague): why do we explicitly set locale when running stack.sh?
#
# Devstack is written in bash, and many functions used throughout
# devstack process text coming off a command (like the ip command)
# and do transforms using grep, sed, cut, awk on the strings that are
# returned. Many of these programs are internationalized, which is
# great for end users, but means that the strings that devstack
# functions depend upon might not be there in other locales. We thus
# need to pin the world to an english basis during the runs.
#
# Previously we used the C locale for this, every system has it, and
# it gives us a stable sort order. It does however mean that we
# effectively drop unicode support.... boo!  :(
#
# With python3 being more unicode aware by default, that's not the
# right option. While there is a C.utf8 locale, some distros are
# shipping it as C.UTF8 for extra confusingness. And it's support
# isn't super clear across distros. This is made more challenging when
# trying to support both out of the box distros, and the gate which
# uses diskimage builder to build disk images in a different way than
# the distros do.
#
# So... en_US.utf8 it is. That's existed for a very long time. It is a
# compromise position, but it is the least worse idea at the time of
# this comment.
#
# We also have to unset other variables that might impact LC_ALL
# taking effect.
unset LANG
unset LANGUAGE
LC_ALL=en_US.utf8
export LC_ALL

# Clear all OpenStack related envvars
unset `env | grep -E '^OS_' | cut -d = -f 1`

# Make sure umask is sane
umask 022

# Not all distros have sbin in PATH for regular users.
# osc will normally be installed at /usr/local/bin/openstack so ensure
# /usr/local/bin is also in the path
PATH=$PATH:/usr/local/bin:/usr/local/sbin:/usr/sbin:/sbin

# Keep track of the DevStack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Check for uninitialized variables, a big cause of bugs
NOUNSET=${NOUNSET:-}
if [[ -n "$NOUNSET" ]]; then
    set -o nounset
fi

# Set start of devstack timestamp
DEVSTACK_START_TIME=$(date +%s)

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
    set +o xtrace
    echo "missing devstack/files"
    exit 1
fi

# ``stack.sh`` keeps function libraries here
# Make sure ``$TOP_DIR/inc`` directory is present
if [ ! -d $TOP_DIR/inc ]; then
    set +o xtrace
    echo "missing devstack/inc"
    exit 1
fi

# ``stack.sh`` keeps project libraries here
# Make sure ``$TOP_DIR/lib`` directory is present
if [ ! -d $TOP_DIR/lib ]; then
    set +o xtrace
    echo "missing devstack/lib"
    exit 1
fi

# Check if run in POSIX shell
if [[ "${POSIXLY_CORRECT}" == "y" ]]; then
    set +o xtrace
    echo "You are running POSIX compatibility mode, DevStack requires bash 4.2 or newer."
    exit 1
fi

# OpenStack is designed to be run as a non-root user; Horizon will fail to run
# as **root** since Apache will not serve content from **root** user).
# ``stack.sh`` must not be run as **root**.  It aborts and suggests one course of
# action to create a suitable user account.

if [[ $EUID -eq 0 ]]; then
    set +o xtrace
    echo "DevStack should be run as a user with sudo permissions, "
    echo "not root."
    echo "A \"stack\" user configured correctly can be created with:"
    echo " $TOP_DIR/tools/create-stack-user.sh"
    exit 1
fi

# OpenStack is designed to run at a system level, with system level
# installation of python packages. It does not support running under a
# virtual env, and will fail in really odd ways if you do this. Make
# this explicit as it has come up on the mailing list.
if [[ -n "$VIRTUAL_ENV" ]]; then
    set +o xtrace
    echo "You appear to be running under a python virtualenv."
    echo "DevStack does not support this, as we may break the"
    echo "virtualenv you are currently in by modifying "
    echo "external system-level components the virtualenv relies on."
    echo "We recommend you use a separate virtual-machine if "
    echo "you are worried about DevStack taking over your system."
    exit 1
fi

# Provide a safety switch for devstack. If you do a lot of devstack,
# on a lot of different environments, you sometimes run it on the
# wrong box. This makes there be a way to prevent that.
if [[ -e $HOME/.no-devstack ]]; then
    set +o xtrace
    echo "You've marked this host as a no-devstack host, to save yourself from"
    echo "running devstack accidentally. If this is in error, please remove the"
    echo "~/.no-devstack file"
    exit 1
fi

# Prepare the environment
# -----------------------

# Initialize variables:
LAST_SPINNER_PID=""

# Import common functions
source $TOP_DIR/functions

# Import 'public' stack.sh functions
source $TOP_DIR/lib/stack

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro


# Global Settings
# ---------------

# Check for a ``localrc`` section embedded in ``local.conf`` and extract if
# ``localrc`` does not already exist

# Phase: local
rm -f $TOP_DIR/.localrc.auto
extract_localrc_section $TOP_DIR/local.conf $TOP_DIR/localrc $TOP_DIR/.localrc.auto

# ``stack.sh`` is customizable by setting environment variables.  Override a
# default setting via export:
#
#     export DATABASE_PASSWORD=anothersecret
#     ./stack.sh
#
# or by setting the variable on the command line:
#
#     DATABASE_PASSWORD=simple ./stack.sh
#
# Persistent variables can be placed in a ``local.conf`` file:
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

# write /etc/devstack-version
write_devstack_version

# Warn users who aren't on an explicitly supported distro, but allow them to
# override check and attempt installation with ``FORCE=yes ./stack``
SUPPORTED_DISTROS="bullseye|focal|jammy|f36|opensuse-15.2|opensuse-tumbleweed|rhel8|rhel9"

if [[ ! ${DISTRO} =~ $SUPPORTED_DISTROS ]]; then
    echo "WARNING: this script has not been tested on $DISTRO"
    if [[ "$FORCE" != "yes" ]]; then
        die $LINENO "If you wish to run this script anyway run with FORCE=yes"
    fi
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
is_package_installed sudo || is_package_installed sudo-ldap || install_package sudo

# UEC images ``/etc/sudoers`` does not have a ``#includedir``, add one
sudo grep -q "^#includedir.*/etc/sudoers.d" /etc/sudoers ||
    echo "#includedir /etc/sudoers.d" | sudo tee -a /etc/sudoers

# Conditionally setup detailed logging for sudo
if [[ -n "$LOG_SUDO" ]]; then
    TEMPFILE=`mktemp`
    echo "Defaults log_output" > $TEMPFILE
    chmod 0440 $TEMPFILE
    sudo chown root:root $TEMPFILE
    sudo mv $TEMPFILE /etc/sudoers.d/00_logging
fi

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

function _install_epel {
    # epel-release is in extras repo which is enabled by default
    install_package epel-release

    # RDO repos are not tested with epel and may have incompatibilities so
    # let's limit the packages fetched from epel to the ones not in RDO repos.
    sudo dnf config-manager --save --setopt=includepkgs=debootstrap,dpkg epel
}

function _install_rdo {
    if [[ $DISTRO == "rhel8" ]]; then
        if [[ "$TARGET_BRANCH" == "master" ]]; then
            # rdo-release.el8.rpm points to latest RDO release, use that for master
            sudo dnf -y install https://rdoproject.org/repos/rdo-release.el8.rpm
        else
            # For stable branches use corresponding release rpm
            rdo_release=$(echo $TARGET_BRANCH | sed "s|stable/||g")
            sudo dnf -y install https://rdoproject.org/repos/openstack-${rdo_release}/rdo-release-${rdo_release}.el8.rpm
        fi
    elif [[ $DISTRO == "rhel9" ]]; then
        sudo curl -L -o /etc/yum.repos.d/delorean-deps.repo http://trunk.rdoproject.org/centos9-master/delorean-deps.repo
    fi
    sudo dnf -y update
}


# Configure Target Directories
# ----------------------------

# Destination path for installation ``DEST``
DEST=${DEST:-/opt/stack}

# Create the destination directory and ensure it is writable by the user
# and read/executable by everybody for daemons (e.g. apache run for horizon)
# If directory exists do not modify the permissions.
if [[ ! -d $DEST ]]; then
    sudo mkdir -p $DEST
    safe_chown -R $STACK_USER $DEST
    safe_chmod 0755 $DEST
fi

# Destination path for devstack logs
if [[ -n ${LOGDIR:-} ]]; then
    mkdir -p $LOGDIR
fi

# Destination path for service data
DATA_DIR=${DATA_DIR:-${DEST}/data}
if [[ ! -d $DATA_DIR ]]; then
    sudo mkdir -p $DATA_DIR
    safe_chown -R $STACK_USER $DATA_DIR
    safe_chmod 0755 $DATA_DIR
fi

# Create and/or clean the async state directory
async_init

# Configure proper hostname
# Certain services such as rabbitmq require that the local hostname resolves
# correctly.  Make sure it exists in /etc/hosts so that is always true.
LOCAL_HOSTNAME=`hostname -s`
if ! fgrep -qwe "$LOCAL_HOSTNAME" /etc/hosts; then
    sudo sed -i "s/\(^127.0.0.1.*\)/\1 $LOCAL_HOSTNAME/" /etc/hosts
fi

# If you have all the repos installed above already setup (e.g. a CI
# situation where they are on your image) you may choose to skip this
# to speed things up
SKIP_EPEL_INSTALL=$(trueorfalse False SKIP_EPEL_INSTALL)

if [[ $DISTRO == "rhel8" ]]; then
    # If we have /etc/ci/mirror_info.sh assume we're on a OpenStack CI
    # node, where EPEL is installed (but disabled) and already
    # pointing at our internal mirror
    if [[ -f /etc/ci/mirror_info.sh ]]; then
        SKIP_EPEL_INSTALL=True
        sudo dnf config-manager --set-enabled epel
    fi

    # PowerTools repo provides libyaml-devel required by devstack itself and
    # EPEL packages assume that the PowerTools repository is enable.
    sudo dnf config-manager --set-enabled PowerTools

    # CentOS 8.3 changed the repository name to lower case.
    sudo dnf config-manager --set-enabled powertools

    if [[ ${SKIP_EPEL_INSTALL} != True ]]; then
        _install_epel
    fi
    # Along with EPEL, CentOS (and a-likes) require some packages only
    # available in RDO repositories (e.g. OVS, or later versions of
    # kvm) to run.
    _install_rdo

    # NOTE(cgoncalves): workaround RHBZ#1154272
    # dnf fails for non-privileged users when expired_repos.json doesn't exist.
    # RHBZ: https://bugzilla.redhat.com/show_bug.cgi?id=1154272
    # Patch: https://github.com/rpm-software-management/dnf/pull/1448
    echo "[]" | sudo tee /var/cache/dnf/expired_repos.json
elif [[ $DISTRO == "rhel9" ]]; then
    sudo dnf config-manager --set-enabled crb
    # rabbitmq and other packages are provided by RDO repositories.
    _install_rdo
fi

# Ensure python is installed
# --------------------------
install_python


# Configure Logging
# -----------------

# Set up logging level
VERBOSE=$(trueorfalse True VERBOSE)
VERBOSE_NO_TIMESTAMP=$(trueorfalse False VERBOSE)

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
        _of_args="-v"
        if [[ "$VERBOSE_NO_TIMESTAMP" == "True" ]]; then
            _of_args="$_of_args --no-timestamp"
        fi
        # Set fd 1 and 2 to write the log file
        exec 1> >( $PYTHON $TOP_DIR/tools/outfilter.py $_of_args -o "${LOGFILE}" ) 2>&1
        # Set fd 6 to summary log file
        exec 6> >( $PYTHON $TOP_DIR/tools/outfilter.py -o "${SUMFILE}" )
    else
        # Set fd 1 and 2 to primary logfile
        exec 1> >( $PYTHON $TOP_DIR/tools/outfilter.py -o "${LOGFILE}" ) 2>&1
        # Set fd 6 to summary logfile and stdout
        exec 6> >( $PYTHON $TOP_DIR/tools/outfilter.py -v -o "${SUMFILE}" >&3 )
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
    exec 6> >( $PYTHON $TOP_DIR/tools/outfilter.py -v >&3 )
fi

# Basic test for ``$DEST`` path permissions (fatal on error unless skipped)
check_path_perm_sanity ${DEST}

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

    #Remove timing data file
    if [ -f "$OSCWRAP_TIMER_FILE" ] ; then
        rm "$OSCWRAP_TIMER_FILE"
    fi

    # Kill the last spinner process
    kill_spinner

    if [[ $r -ne 0 ]]; then
        echo "Error on exit"
        # If we error before we've installed os-testr, this will fail.
        if type -p generate-subunit > /dev/null; then
            generate-subunit $DEVSTACK_START_TIME $SECONDS 'fail' >> ${SUBUNIT_OUTPUT}
        fi
        if [[ -z $LOGDIR ]]; then
            ${PYTHON} $TOP_DIR/tools/worlddump.py
        else
            ${PYTHON} $TOP_DIR/tools/worlddump.py -d $LOGDIR
        fi
    else
        # If we error before we've installed os-testr, this will fail.
        if type -p generate-subunit > /dev/null; then
            generate-subunit $DEVSTACK_START_TIME $SECONDS >> ${SUBUNIT_OUTPUT}
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

# Print the kernel version
uname -a

# Reset the bundle of CA certificates
SSL_BUNDLE_FILE="$DATA_DIR/ca-bundle.pem"
rm -f $SSL_BUNDLE_FILE

# Import common services (database, message queue) configuration
source $TOP_DIR/lib/database
source $TOP_DIR/lib/rpc_backend

# Configure Projects
# ==================

# Clone all external plugins
fetch_plugins

# Plugin Phase 0: override_defaults - allow plugins to override
# defaults before other services are run
run_phase override_defaults

# Import Apache functions
source $TOP_DIR/lib/apache

# Import TLS functions
source $TOP_DIR/lib/tls

# Source project function libraries
source $TOP_DIR/lib/infra
source $TOP_DIR/lib/libraries
source $TOP_DIR/lib/lvm
source $TOP_DIR/lib/horizon
source $TOP_DIR/lib/keystone
source $TOP_DIR/lib/glance
source $TOP_DIR/lib/nova
source $TOP_DIR/lib/placement
source $TOP_DIR/lib/cinder
source $TOP_DIR/lib/swift
source $TOP_DIR/lib/neutron
source $TOP_DIR/lib/ldap
source $TOP_DIR/lib/dstat
source $TOP_DIR/lib/tcpdump
source $TOP_DIR/lib/etcd3
source $TOP_DIR/lib/os-vif

# Extras Source
# --------------

# Phase: source
run_phase source


# Interactive Configuration
# -------------------------

# Do all interactive config up front before the logging spew begins

# Generic helper to configure passwords
function read_password {
    local xtrace
    xtrace=$(set +o | grep xtrace)
    set +o xtrace
    var=$1; msg=$2
    pw=${!var}

    if [[ -f $RC_DIR/localrc ]]; then
        localrc=$TOP_DIR/localrc
    else
        localrc=$TOP_DIR/.localrc.password
    fi

    # If the password is not defined yet, proceed to prompt user for a password.
    if [ ! $pw ]; then
        # If there is no localrc file, create one
        if [ ! -e $localrc ]; then
            touch $localrc
        fi

        # Presumably if we got this far it can only be that our
        # localrc is missing the required password.  Prompt user for a
        # password and write to localrc.

        echo ''
        echo '################################################################################'
        echo $msg
        echo '################################################################################'
        echo "This value will be written to ${localrc} file so you don't have to enter it "
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

    # restore previous xtrace value
    $xtrace
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

if initialize_database_backends; then
    echo "Using $DATABASE_TYPE database backend"
    # Last chance for the database password. This must be handled here
    # because read_password is not a library function.
    read_password DATABASE_PASSWORD "ENTER A PASSWORD TO USE FOR THE DATABASE."

    define_database_baseurl
else
    echo "No database enabled"
fi


# Queue Configuration
# -------------------

# Rabbit connection info
# In multi node DevStack, second node needs ``RABBIT_USERID``, but rabbit
# isn't enabled.
if is_service_enabled rabbit; then
    read_password RABBIT_PASSWORD "ENTER A PASSWORD TO USE FOR RABBIT."
fi


# Keystone
# --------

if is_service_enabled keystone; then
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

# Bring down global requirements before any use of pip_install. This is
# necessary to ensure that the constraints file is in place before we
# attempt to apply any constraints to pip installs.
# We always need the master branch in addition to any stable branch, so
# override GIT_DEPTH here.
GIT_DEPTH=0 git_clone $REQUIREMENTS_REPO $REQUIREMENTS_DIR $REQUIREMENTS_BRANCH

# Install package requirements
# Source it so the entire environment is available
echo_summary "Installing package prerequisites"
source $TOP_DIR/tools/install_prereqs.sh

# Configure an appropriate Python environment.
#
# NOTE(ianw) 2021-08-11 : We install the latest pip here because pip
# is very active and changes are not generally reflected in the LTS
# distros.  This often involves important things like dependency or
# conflict resolution, and has often been required because the
# complicated constraints etc. used by openstack have tickled bugs in
# distro versions of pip.  We want to find these problems as they
# happen, rather than years later when we try to update our LTS
# distro.  Whilst it is clear that global installations of upstream
# pip are less and less common, with virtualenv's being the general
# approach now; there are a lot of devstack plugins that assume a
# global install environment.
if [[ "$OFFLINE" != "True" ]]; then
    PYPI_ALTERNATIVE_URL=${PYPI_ALTERNATIVE_URL:-""} $TOP_DIR/tools/install_pip.sh
fi

# Do the ugly hacks for broken packages and distros
source $TOP_DIR/tools/fixup_stuff.sh
fixup_all

# Install subunit for the subunit output stream
pip_install -U os-testr

# the default rate limit of 1000 messages / 30 seconds is not
# sufficient given how verbose our logging is.
iniset -sudo /etc/systemd/journald.conf "Journal" "RateLimitBurst" "0"
sudo systemctl restart systemd-journald

# Virtual Environment
# -------------------

# Install required infra support libraries
install_infra

# Install bindep
$VIRTUALENV_CMD $DEST/bindep-venv
# TODO(ianw) : optionally install from zuul checkout?
$DEST/bindep-venv/bin/pip install bindep
export BINDEP_CMD=${DEST}/bindep-venv/bin/bindep

# Install packages as defined in plugin bindep.txt files
pkgs="$( _get_plugin_bindep_packages )"
if [[ -n "${pkgs}" ]]; then
    install_package ${pkgs}
fi

# Extras Pre-install
# ------------------
# Phase: pre-install
run_phase stack pre-install

# NOTE(danms): Set global limits before installing anything
set_systemd_override DefaultLimitNOFILE ${ULIMIT_NOFILE}

install_rpc_backend
restart_rpc_backend

if is_service_enabled $DATABASE_BACKENDS; then
    install_database
fi
if [ -n "$DATABASE_TYPE" ]; then
    install_database_python
fi

if is_service_enabled neutron; then
    install_neutron_agent_packages
fi

if is_service_enabled etcd3; then
    install_etcd3
fi

# Setup TLS certs
# ---------------

# Do this early, before any webservers are set up to ensure
# we don't run into problems with missing certs when apache
# is restarted.
if is_service_enabled tls-proxy; then
    configure_CA
    init_CA
    init_cert
fi

# Dstat
# -----

# Install dstat services prerequisites
install_dstat


# Check Out and Install Source
# ----------------------------

echo_summary "Installing OpenStack project source"

# Install additional libraries
install_libs

# Install uwsgi
install_apache_uwsgi

# Install client libraries
install_keystoneauth
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

# Install middleware
install_keystonemiddleware

if is_service_enabled keystone; then
    if [ "$KEYSTONE_SERVICE_HOST" == "$SERVICE_HOST" ]; then
        stack_install_service keystone
        configure_keystone
    fi
fi

if is_service_enabled swift; then
    if is_service_enabled ceilometer; then
        install_ceilometermiddleware
    fi
    stack_install_service swift
    configure_swift

    # s3api middleware to provide S3 emulation to Swift
    if is_service_enabled s3api; then
        # Replace the nova-objectstore port by the swift port
        S3_SERVICE_PORT=8080
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
fi

if is_service_enabled nova; then
    # Compute service
    stack_install_service nova
    configure_nova
fi

if is_service_enabled placement; then
    # placement api
    stack_install_service placement
    configure_placement
fi

# create a placement-client fake service to know we need to configure
# placement connectivity. We configure the placement service for nova
# if placement-api or placement-client is active, and n-cpu on the
# same box.
if is_service_enabled placement placement-client; then
    if is_service_enabled n-cpu || is_service_enabled n-sch; then
        configure_placement_nova_compute
    fi
fi

if is_service_enabled horizon; then
    # dashboard
    stack_install_service horizon
fi

if is_service_enabled tls-proxy; then
    fix_system_ca_bundle_path
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

# Installs alias for osc so that we can collect timing for all
# osc commands. Alias dies with stack.sh.
install_oscwrap

# Syslog
# ------

if [[ $SYSLOG != "False" ]]; then
    if [[ "$SYSLOG_HOST" = "$HOST_IP" ]]; then
        # Configure the master host to receive
        cat <<EOF | sudo tee /etc/rsyslog.d/90-stack-m.conf >/dev/null
\$ModLoad imrelp
\$InputRELPServerRun $SYSLOG_PORT
EOF
    else
        # Set rsyslog to send to remote host
        cat <<EOF | sudo tee /etc/rsyslog.d/90-stack-s.conf >/dev/null
*.*		:omrelp:$SYSLOG_HOST:$SYSLOG_PORT
EOF
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


# Export Certificate Authority Bundle
# -----------------------------------

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

# Save configuration values
save_stackenv $LINENO

# Kernel Samepage Merging (KSM)
# -----------------------------

# Processes that mark their memory as mergeable can share identical memory
# pages if KSM is enabled. This is particularly useful for nova + libvirt
# backends but any other setup that marks its memory as mergeable can take
# advantage. The drawback is there is higher cpu load; however, we tend to
# be memory bound not cpu bound so enable KSM by default but allow people
# to opt out if the CPU time is more important to them.

if [[ $ENABLE_KSM == "True" ]] ; then
    if [[ -f /sys/kernel/mm/ksm/run ]] ; then
        sudo sh -c "echo 1 > /sys/kernel/mm/ksm/run"
    fi
fi


# Start Services
# ==============

# Dstat
# -----

# A better kind of sysstat, with the top process per time slice
start_dstat

# Run a background tcpdump for debugging
# Note: must set TCPDUMP_ARGS with the enabled service
if is_service_enabled tcpdump; then
    start_tcpdump
fi

# Etcd
# -----

# etcd is a distributed key value store that provides a reliable way to store data across a cluster of machines
if is_service_enabled etcd3; then
    start_etcd3
fi

# Keystone
# --------

if is_service_enabled tls-proxy; then
    start_tls_proxy http-services '*' 443 $SERVICE_HOST 80
fi

# Write a clouds.yaml file and use the devstack-admin cloud
write_clouds_yaml
export OS_CLOUD=${OS_CLOUD:-devstack-admin}

if is_service_enabled keystone; then
    echo_summary "Starting Keystone"

    if [ "$KEYSTONE_SERVICE_HOST" == "$SERVICE_HOST" ]; then
        init_keystone
        start_keystone
        bootstrap_keystone
    fi

    create_keystone_accounts
    if is_service_enabled nova; then
        async_runfunc create_nova_accounts
    fi
    if is_service_enabled glance; then
        async_runfunc create_glance_accounts
    fi
    if is_service_enabled cinder; then
        async_runfunc create_cinder_accounts
    fi
    if is_service_enabled neutron; then
        async_runfunc create_neutron_accounts
    fi
    if is_service_enabled swift; then
        async_runfunc create_swift_accounts
    fi

fi

# Horizon
# -------

if is_service_enabled horizon; then
    echo_summary "Configuring Horizon"
    async_runfunc configure_horizon
fi

async_wait create_nova_accounts create_glance_accounts create_cinder_accounts
async_wait create_neutron_accounts create_swift_accounts configure_horizon

# Glance
# ------

# NOTE(yoctozepto): limited to node hosting the database which is the controller
if is_service_enabled $DATABASE_BACKENDS && is_service_enabled glance; then
    echo_summary "Configuring Glance"
    async_runfunc init_glance
fi


# Neutron
# -------

if is_service_enabled neutron; then
    echo_summary "Configuring Neutron"

    configure_neutron

    # Run init_neutron only on the node hosting the Neutron API server
    if is_service_enabled $DATABASE_BACKENDS && is_service_enabled neutron; then
        async_runfunc init_neutron
    fi
fi


# Nova
# ----

if is_service_enabled q-dhcp; then
    # TODO(frickler): These are remnants from n-net, check which parts are really
    # still needed for Neutron.
    # Do not kill any dnsmasq instance spawned by NetworkManager
    netman_pid=$(pidof NetworkManager || true)
    if [ -z "$netman_pid" ]; then
        sudo killall dnsmasq || true
    else
        sudo ps h -o pid,ppid -C dnsmasq | grep -v $netman_pid | awk '{print $1}' | sudo xargs kill || true
    fi

    clean_iptables

    # Force IP forwarding on, just in case
    sudo sysctl -w net.ipv4.ip_forward=1
fi

# os-vif
# ------
if is_service_enabled nova neutron; then
    configure_os_vif
fi

# Storage Service
# ---------------

if is_service_enabled swift; then
    echo_summary "Configuring Swift"
    async_runfunc init_swift
fi


# Volume Service
# --------------

if is_service_enabled cinder; then
    echo_summary "Configuring Cinder"
    async_runfunc init_cinder
fi

# Placement Service
# ---------------

if is_service_enabled placement; then
    echo_summary "Configuring placement"
    async_runfunc init_placement
fi

# Wait for neutron and placement before starting nova
async_wait init_neutron
async_wait init_placement
async_wait init_glance
async_wait init_swift
async_wait init_cinder

# Compute Service
# ---------------

if is_service_enabled nova; then
    echo_summary "Configuring Nova"
    init_nova

    async_runfunc configure_neutron_nova
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
if is_service_enabled swift; then
    echo_summary "Starting Swift"
    start_swift
fi

# NOTE(lyarwood): By default use a single hardcoded fixed_key across devstack
# deployments.  This ensures the keys match across nova and cinder across all
# hosts.
FIXED_KEY=${FIXED_KEY:-bae3516cc1c0eb18b05440eba8012a4a880a2ee04d584a9c1579445e675b12defdc716ec}
if is_service_enabled cinder; then
    iniset $CINDER_CONF key_manager fixed_key "$FIXED_KEY"
fi

async_wait configure_neutron_nova

# NOTE(clarkb): This must come after async_wait configure_neutron_nova because
# configure_neutron_nova modifies $NOVA_CONF and $NOVA_CPU_CONF as well. If
# we don't wait then these two ini updates race either other and can result
# in unexpected configs.
if is_service_enabled nova; then
    iniset $NOVA_CONF key_manager fixed_key "$FIXED_KEY"
    iniset $NOVA_CPU_CONF key_manager fixed_key "$FIXED_KEY"
fi

# Launch the nova-api and wait for it to answer before continuing
if is_service_enabled n-api; then
    echo_summary "Starting Nova API"
    start_nova_api
fi

if is_service_enabled ovn-controller ovn-controller-vtep; then
    echo_summary "Starting OVN services"
    start_ovn_services
fi

if is_service_enabled neutron-api; then
    echo_summary "Starting Neutron"
    start_neutron_api
elif is_service_enabled q-svc; then
    echo_summary "Starting Neutron"
    configure_neutron_after_post_config
    start_neutron_service_and_check
fi

# Start placement before any of the service that are likely to want
# to use it to manage resource providers.
if is_service_enabled placement; then
    echo_summary "Starting Placement"
    start_placement
fi

if is_service_enabled neutron; then
    start_neutron
fi
# Once neutron agents are started setup initial network elements
if is_service_enabled q-svc && [[ "$NEUTRON_CREATE_INITIAL_NETWORKS" == "True" ]]; then
    echo_summary "Creating initial neutron network elements"
    # Here's where plugins can wire up their own networks instead
    # of the code in lib/neutron_plugins/services/l3
    if type -p neutron_plugin_create_initial_networks > /dev/null; then
        neutron_plugin_create_initial_networks
    else
        create_neutron_initial_network
    fi

fi

if is_service_enabled nova; then
    echo_summary "Starting Nova"
    start_nova
    async_runfunc create_flavors
fi
if is_service_enabled cinder; then
    echo_summary "Starting Cinder"
    start_cinder
    create_volume_types
fi

# This sleep is required for cinder volume service to become active and
# publish capabilities to cinder scheduler before creating the image-volume
if [[ "$USE_CINDER_FOR_GLANCE" == "True" ]]; then
    sleep 30
fi

# Launch the Glance services
# NOTE (abhishekk): We need to start glance api service only after cinder
# service has started as on glance startup glance-api queries cinder for
# validating volume_type configured for cinder store of glance.
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

# NOTE(yoctozepto): limited to node hosting the database which is the controller
if is_service_enabled $DATABASE_BACKENDS && is_service_enabled glance; then
    echo_summary "Uploading images"

    for image_url in ${IMAGE_URLS//,/ }; do
        upload_image $image_url
    done
fi

async_wait create_flavors

if is_service_enabled horizon; then
    echo_summary "Starting Horizon"
    init_horizon
    start_horizon
fi


# Create account rc files
# =======================

# Creates source able script files for easier user switching.
# This step also creates certificates for tenants and users,
# which is helpful in image bundle steps.

if is_service_enabled nova && is_service_enabled keystone; then
    USERRC_PARAMS="-PA --target-dir $TOP_DIR/accrc --os-password $ADMIN_PASSWORD"

    if [ -f $SSL_BUNDLE_FILE ]; then
        USERRC_PARAMS="$USERRC_PARAMS --os-cacert $SSL_BUNDLE_FILE"
    fi

    $TOP_DIR/tools/create_userrc.sh $USERRC_PARAMS
fi


# Save some values we generated for later use
save_stackenv


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


# Sanity checks
# =============

# Check that computes are all ready
#
# TODO(sdague): there should be some generic phase here.
if is_service_enabled n-cpu; then
    is_nova_ready
fi

# Check the status of running services
service_check

# Configure nova cellsv2
# ----------------------

# Do this late because it requires compute hosts to have started
if is_service_enabled n-api; then
    if is_service_enabled n-cpu; then
        $TOP_DIR/tools/discover_hosts.sh
    else
        # Some CI systems like Hyper-V build the control plane on
        # Linux, and join in non Linux Computes after setup. This
        # allows them to delay the processing until after their whole
        # environment is up.
        echo_summary "SKIPPING Cell setup because n-cpu is not enabled. You will have to do this manually before you have a working environment."
    fi
    # Run the nova-status upgrade check command which can also be used
    # to verify the base install. Note that this is good enough in a
    # single node deployment, but in a multi-node setup it won't verify
    # any subnodes - that would have to be driven from whatever tooling
    # is deploying the subnodes, e.g. the zuul v3 devstack-multinode job.
    $NOVA_BIN_DIR/nova-status --config-file $NOVA_CONF upgrade check
fi

# Run local script
# ----------------

# Run ``local.sh`` if it exists to perform user-managed tasks
if [[ -x $TOP_DIR/local.sh ]]; then
    echo "Running user script $TOP_DIR/local.sh"
    $TOP_DIR/local.sh
fi

# Bash completion
# ===============

# Prepare bash completion for OSC
# Note we use "command" to avoid the timing wrapper
# which isn't relevant here and floods logs
command openstack complete \
    | sudo tee /etc/bash_completion.d/osc.bash_completion > /dev/null

# If cinder is configured, set global_filter for PV devices
if is_service_enabled cinder; then
    if is_ubuntu; then
        echo_summary "Configuring lvm.conf global device filter"
        set_lvm_filter
    else
        echo_summary "Skip setting lvm filters for non Ubuntu systems"
    fi
fi

# Run test-config
# ---------------

# Phase: test-config
run_phase stack test-config

# Apply late configuration from ``local.conf`` if it exists for layer 2 services
# Phase: test-config
merge_config_group $TOP_DIR/local.conf test-config

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

# Make sure we didn't leak any background tasks
async_cleanup

# Dump out the time totals
time_totals
async_print_timing

if is_service_enabled mysql; then
    if [[ "$MYSQL_GATHER_PERFORMANCE" == "True" && "$MYSQL_HOST" ]]; then
        echo ""
        echo ""
        echo "Post-stack database query stats:"
        mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $MYSQL_HOST stats -e \
              'SELECT * FROM queries' -t 2>/dev/null
        mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -h $MYSQL_HOST stats -e \
              'DELETE FROM queries' 2>/dev/null
    fi
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
    echo "Horizon is now available at http://$SERVICE_HOST$HORIZON_APACHE_ROOT"
fi

# If Keystone is present you can point ``nova`` cli to this server
if is_service_enabled keystone; then
    echo "Keystone is serving at $KEYSTONE_SERVICE_URI/"
    echo "The default users are: admin and demo"
    echo "The password: $ADMIN_PASSWORD"
fi

# Warn that a deprecated feature was used
if [[ -n "$DEPRECATED_TEXT" ]]; then
    echo
    echo -e "WARNING: $DEPRECATED_TEXT"
    echo
fi

echo
echo "Services are running under systemd unit files."
echo "For more information see: "
echo "https://docs.openstack.org/devstack/latest/systemd.html"
echo

# Useful info on current state
cat /etc/devstack-version
echo

# Indicate how long this took to run (bash maintained variable ``SECONDS``)
echo_summary "stack.sh completed in $SECONDS seconds."


# Restore/close logging file descriptors
exec 1>&3
exec 2>&3
exec 3>&-
exec 6>&-
