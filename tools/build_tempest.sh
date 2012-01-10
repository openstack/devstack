#!/usr/bin/env bash
#
# build_tempest.sh - Checkout and prepare a Tempest repo
#                    (https://github.com/openstack/tempest.git)

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
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

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

DIST_NAME=${DIST_NAME:-oneiric}

# git clone only if directory doesn't exist already.  Since ``DEST`` might not
# be owned by the installation user, we create the directory and change the
# ownership to the proper user.
function git_clone {

    GIT_REMOTE=$1
    GIT_DEST=$2
    GIT_BRANCH=$3

    # do a full clone only if the directory doesn't exist
    if [ ! -d $GIT_DEST ]; then
        git clone $GIT_REMOTE $GIT_DEST
        cd $2
        # This checkout syntax works for both branches and tags
        git checkout $GIT_BRANCH
    elif [[ "$RECLONE" == "yes" ]]; then
        # if it does exist then simulate what clone does if asked to RECLONE
        cd $GIT_DEST
        # set the url to pull from and fetch
        git remote set-url origin $GIT_REMOTE
        git fetch origin
        # remove the existing ignored files (like pyc) as they cause breakage
        # (due to the py files having older timestamps than our pyc, so python
        # thinks the pyc files are correct using them)
        find $GIT_DEST -name '*.pyc' -delete
        git checkout -f origin/$GIT_BRANCH
        # a local branch might not exist
        git branch -D $GIT_BRANCH || true
        git checkout -b $GIT_BRANCH
    fi
}

# Install tests and prerequisites
sudo PIP_DOWNLOAD_CACHE=/var/cache/pip pip install --use-mirrors `cat $TOP_DIR/files/pips/tempest`

git_clone $TEMPEST_REPO $TEMPEST_DIR $TEMPEST_BRANCH

trap - SIGHUP SIGINT SIGTERM SIGQUIT EXIT
