#!/usr/bin/env bash

# **install_pip.sh**

# Update pip and friends to a known common version

# Assumptions:
# - if USE_PYTHON3=True, PYTHON3_VERSION refers to a version already installed

set -o errexit

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

# Change dir to top of DevStack
cd $TOP_DIR

# Import common functions
source $TOP_DIR/stackrc

# don't start tracing until after we've sourced the world
set -o xtrace

FILES=$TOP_DIR/files

# The URL from where the get-pip.py file gets downloaded. If a local
# get-pip.py mirror is available, PIP_GET_PIP_URL can be set to that
# mirror in local.conf to avoid download timeouts.
# Example:
#  PIP_GET_PIP_URL="http://local-server/get-pip.py"
#
# Note that if get-pip.py already exists in $FILES this script will
# not re-download or check for a new version.  For example, this is
# done by openstack-infra diskimage-builder elements as part of image
# preparation [1].  This prevents any network access, which can be
# unreliable in CI situations.
# [1] http://git.openstack.org/cgit/openstack-infra/project-config/tree/nodepool/elements/cache-devstack/source-repository-pip

PIP_GET_PIP_URL=${PIP_GET_PIP_URL:-"https://bootstrap.pypa.io/get-pip.py"}
LOCAL_PIP="$FILES/$(basename $PIP_GET_PIP_URL)"

GetDistro
echo "Distro: $DISTRO"

function get_versions {
    # FIXME(dhellmann): Deal with multiple python versions here? This
    # is just used for reporting, so maybe not?
    PIP=$(which pip 2>/dev/null || which pip-python 2>/dev/null || true)
    if [[ -n $PIP ]]; then
        PIP_VERSION=$($PIP --version | awk '{ print $2}')
        echo "pip: $PIP_VERSION"
    else
        echo "pip: Not Installed"
    fi
}


function install_get_pip {
    # If get-pip.py isn't python, delete it. This was probably an
    # outage on the server.
    if [[ -r $LOCAL_PIP ]]; then
        if ! head -1 $LOCAL_PIP | grep -q '#!/usr/bin/env python'; then
            echo "WARNING: Corrupt $LOCAL_PIP found removing"
            rm $LOCAL_PIP
        fi
    fi

    # The OpenStack gate and others put a cached version of get-pip.py
    # for this to find, explicitly to avoid download issues.
    #
    # However, if DevStack *did* download the file, we want to check
    # for updates; people can leave their stacks around for a long
    # time and in the mean-time pip might get upgraded.
    #
    # Thus we use curl's "-z" feature to always check the modified
    # since and only download if a new version is out -- but only if
    # it seems we downloaded the file originally.
    if [[ ! -r $LOCAL_PIP || -r $LOCAL_PIP.downloaded ]]; then
        # only test freshness if LOCAL_PIP is actually there,
        # otherwise we generate a scary warning.
        local timecond=""
        if [[ -r $LOCAL_PIP ]]; then
            timecond="-z $LOCAL_PIP"
        fi

        curl -f --retry 6 --retry-delay 5 \
            $timecond -o $LOCAL_PIP $PIP_GET_PIP_URL || \
            die $LINENO "Download of get-pip.py failed"
        touch $LOCAL_PIP.downloaded
    fi
    sudo -H -E python $LOCAL_PIP -c $TOOLS_DIR/cap-pip.txt
    if python3_enabled; then
        sudo -H -E python${PYTHON3_VERSION} $LOCAL_PIP -c $TOOLS_DIR/cap-pip.txt
    fi
}


function configure_pypi_alternative_url {
    PIP_ROOT_FOLDER="$HOME/.pip"
    PIP_CONFIG_FILE="$PIP_ROOT_FOLDER/pip.conf"
    if [[ ! -d $PIP_ROOT_FOLDER ]]; then
        echo "Creating $PIP_ROOT_FOLDER"
        mkdir $PIP_ROOT_FOLDER
    fi
    if [[ ! -f $PIP_CONFIG_FILE ]]; then
        echo "Creating $PIP_CONFIG_FILE"
        touch $PIP_CONFIG_FILE
    fi
    if ! ini_has_option "$PIP_CONFIG_FILE" "global" "index-url"; then
        # It means that the index-url does not exist
        iniset "$PIP_CONFIG_FILE" "global" "index-url" "$PYPI_OVERRIDE"
    fi

}

# Setuptools 8 implements PEP 440, and 8.0.4 adds a warning triggered any time
# pkg_resources inspects the list of installed Python packages if there are
# non-compliant version numbers in the egg-info (for example, from distro
# system packaged Python libraries). This is off by default after 8.2 but can
# be enabled by uncommenting the lines below.
#PYTHONWARNINGS=$PYTHONWARNINGS,always::RuntimeWarning:pkg_resources
#export PYTHONWARNINGS

# Show starting versions
get_versions

# Do pip

# Eradicate any and all system packages

# Python in fedora/suse depends on the python-pip package so removing it
# results in a nonfunctional system. pip on fedora installs to /usr so pip
# can safely override the system pip for all versions of fedora
if ! is_fedora  && ! is_suse; then
    uninstall_package python-pip
    uninstall_package python3-pip
fi

install_get_pip

if [[ -n $PYPI_ALTERNATIVE_URL ]]; then
    configure_pypi_alternative_url
fi

set -x

# Note setuptools is part of requirements.txt and we want to make sure
# we obey any versioning as described there.
pip_install_gr setuptools

get_versions
