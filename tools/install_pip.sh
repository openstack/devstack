#!/usr/bin/env bash

# **install_pip.sh**

# install_pip.sh [--pip-version <version>] [--use-get-pip] [--setuptools] [--force]
#
# Update pip and friends to a known common version

# Assumptions:
# - currently we try to leave the system setuptools alone, install
#   the system package if it is not already present
# - update pip to $INSTALL_PIP_VERSION

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

# Change dir to top of devstack
cd $TOP_DIR

# Import common functions
source $TOP_DIR/functions

FILES=$TOP_DIR/files

# Handle arguments

INSTALL_PIP_VERSION=${INSTALL_PIP_VERSION:-"1.4"}
while [[ -n "$1" ]]; do
    case $1 in
        --force)
            FORCE=1
            ;;
        --pip-version)
            INSTALL_PIP_VERSION="$2"
            shift
            ;;
        --setuptools)
            SETUPTOOLS=1
            ;;
        --use-get-pip)
            USE_GET_PIP=1;
            ;;
    esac
    shift
done

SETUPTOOLS_EZ_SETUP_URL=https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py
PIP_GET_PIP_URL=https://raw.github.com/pypa/pip/master/contrib/get-pip.py
PIP_TAR_URL=https://pypi.python.org/packages/source/p/pip/pip-$INSTALL_PIP_VERSION.tar.gz

GetDistro
echo "Distro: $DISTRO"

function get_versions() {
    PIP=$(which pip 2>/dev/null || which pip-python 2>/dev/null)
    if [[ -n $PIP ]]; then
        DISTRIBUTE_VERSION=$($PIP freeze | grep 'distribute==')
        SETUPTOOLS_VERSION=$($PIP freeze | grep 'setuptools==')
        PIP_VERSION=$($PIP --version | awk '{ print $2}')
        echo "pip: $PIP_VERSION  setuptools: $SETUPTOOLS_VERSION  distribute: $DISTRIBUTE_VERSION"
    fi
}

function setuptools_ez_setup() {
    if [[ ! -r $FILES/ez_setup.py ]]; then
        (cd $FILES; \
         curl -OR $SETUPTOOLS_EZ_SETUP_URL; \
        )
    fi
    sudo python $FILES/ez_setup.py
}

function install_get_pip() {
    if [[ ! -r $FILES/get-pip.py ]]; then
        (cd $FILES; \
            curl $PIP_GET_PIP_URL; \
        )
    fi
    sudo python $FILES/get-pip.py
}

function install_pip_tarball() {
    curl -O $PIP_TAR_URL
    tar xvfz pip-$INSTALL_PIP_VERSION.tar.gz
    cd pip-$INSTALL_PIP_VERSION
    sudo python setup.py install
}

# Show starting versions
get_versions

# Do setuptools
if [[ -n "$SETUPTOOLS" ]]; then
    # We want it from source
    uninstall_package python-setuptools
    setuptools_ez_setup
else
    # See about installing the distro setuptools
    if ! python -c "import setuptools"; then
        install_package python-setuptools
    fi
fi

# Do pip
if [[ -z $PIP || "$PIP_VERSION" != "$INSTALL_PIP_VERSION" || -n $FORCE ]]; then

    # Eradicate any and all system packages
    uninstall_package python-pip

    if [[ -n "$USE_GET_PIP" ]]; then
        install_get_pip
    else
        install_pip_tarball
    fi

    get_versions
fi
