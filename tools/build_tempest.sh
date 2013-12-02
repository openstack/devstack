#!/usr/bin/env bash
#
# **build_tempest.sh**

# Checkout and prepare a Tempest repo: git://git.openstack.org/openstack/tempest.git

function usage {
    echo "$0 - Check out and prepare a Tempest repo"
    echo ""
    echo "Usage: $0"
    exit 1
}

if [ "$1" = "-h" ]; then
    usage
fi

# Clean up any resources that may be in use
cleanup() {
    set +o errexit

    # Kill ourselves to signal any calling process
    trap 2; kill -2 $$
}

trap cleanup SIGHUP SIGINT SIGTERM SIGQUIT EXIT

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Import common functions
. $TOP_DIR/functions

# Abort if localrc is not set
if [ ! -e $TOP_DIR/localrc ]; then
    echo "You must have a localrc with ALL necessary passwords and configuration defined before proceeding."
    echo "See stack.sh for required passwords."
    exit 1
fi

# Source params
source ./stackrc

# Where Openstack code lives
DEST=${DEST:-/opt/stack}

TEMPEST_DIR=$DEST/tempest

# Install tests and prerequisites
git_clone $TEMPEST_REPO $TEMPEST_DIR $TEMPEST_BRANCH

trap - SIGHUP SIGINT SIGTERM SIGQUIT EXIT
