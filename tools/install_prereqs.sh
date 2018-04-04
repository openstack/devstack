#!/usr/bin/env bash

# **install_prereqs.sh**

# Install system package prerequisites
#
# install_prereqs.sh [-f]
#
# -f        Force an install run now

FORCE_PREREQ=0

while getopts ":f" opt; do
    case $opt in
        f)
            FORCE_PREREQ=1
            ;;
    esac
done

# If ``TOP_DIR`` is set we're being sourced rather than running stand-alone
# or in a sub-shell
if [[ -z "$TOP_DIR" ]]; then
    # Keep track of the DevStack directory
    TOP_DIR=$(cd $(dirname "$0")/.. && pwd)

    # Import common functions
    source $TOP_DIR/functions

    # Determine what system we are running on.  This provides ``os_VENDOR``,
    # ``os_RELEASE``, ``os_PACKAGE``, ``os_CODENAME``
    # and ``DISTRO``
    GetDistro

    # Needed to get ``ENABLED_SERVICES``
    source $TOP_DIR/stackrc

    # Prereq dirs are here
    FILES=$TOP_DIR/files
fi

# Minimum wait time
PREREQ_RERUN_MARKER=${PREREQ_RERUN_MARKER:-$TOP_DIR/.prereqs}
PREREQ_RERUN_HOURS=${PREREQ_RERUN_HOURS:-2}
PREREQ_RERUN_SECONDS=$((60*60*$PREREQ_RERUN_HOURS))

NOW=$(date "+%s")
LAST_RUN=$(head -1 $PREREQ_RERUN_MARKER 2>/dev/null || echo "0")
DELTA=$(($NOW - $LAST_RUN))
if [[ $DELTA -lt $PREREQ_RERUN_SECONDS && -z "$FORCE_PREREQ" ]]; then
    echo "Re-run time has not expired ($(($PREREQ_RERUN_SECONDS - $DELTA)) seconds remaining) "
    echo "and FORCE_PREREQ not set; exiting..."
    return 0
fi

# Make sure the proxy config is visible to sub-processes
export_proxy_variables


# Install Packages
# ================

# Install package requirements
PACKAGES=$(get_packages general,$ENABLED_SERVICES)
PACKAGES="$PACKAGES $(get_plugin_packages)"

if is_ubuntu && echo $PACKAGES | grep -q dkms ; then
    # Ensure headers for the running kernel are installed for any DKMS builds
    PACKAGES="$PACKAGES linux-headers-$(uname -r)"
fi

install_package $PACKAGES

if [[ -n "$SYSLOG" && "$SYSLOG" != "False" ]]; then
    if is_ubuntu || is_fedora; then
        install_package rsyslog-relp
    else
        exit_distro_not_supported "rsyslog-relp installation"
    fi
fi

# TODO(clarkb) remove these once we are switched to global venv by default
export PYTHON=$(which python${PYTHON3_VERSION} 2>/dev/null || which python3 2>/dev/null)

# Mark end of run
# ---------------

date "+%s" >$PREREQ_RERUN_MARKER
date >>$PREREQ_RERUN_MARKER
