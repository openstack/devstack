#!/usr/bin/env bash

# **install_pip.sh**

# install_pip.sh [--pip-version <version>] [--use-get-pip] [--force]
#
# Update pip and friends to a known common version

# Assumptions:
# - update pip to $INSTALL_PIP_VERSION

set -o errexit
set -o xtrace

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

# Change dir to top of devstack
cd $TOP_DIR

# Import common functions
source $TOP_DIR/functions

FILES=$TOP_DIR/files

PIP_GET_PIP_URL=https://bootstrap.pypa.io/get-pip.py

GetDistro
echo "Distro: $DISTRO"

function get_versions {
    PIP=$(which pip 2>/dev/null || which pip-python 2>/dev/null || true)
    if [[ -n $PIP ]]; then
        PIP_VERSION=$($PIP --version | awk '{ print $2}')
        echo "pip: $PIP_VERSION"
    else
        echo "pip: Not Installed"
    fi
}


function install_get_pip {
    if [[ ! -r $FILES/get-pip.py ]]; then
        (cd $FILES; \
            curl -O $PIP_GET_PIP_URL; \
        )
    fi
    sudo -E python $FILES/get-pip.py
}


# Show starting versions
get_versions

# Do pip

# Eradicate any and all system packages
uninstall_package python-pip

install_get_pip

pip_install -U setuptools

get_versions
