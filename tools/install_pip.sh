#!/usr/bin/env bash

# **install_pip.sh**

# Update pip and friends to a known common version

# Assumptions:
# - PYTHON3_VERSION refers to a version already installed

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
# [1] https://opendev.org/openstack/project-config/src/branch/master/nodepool/elements/cache-devstack/source-repository-pip

PIP_GET_PIP_URL=${PIP_GET_PIP_URL:-"https://bootstrap.pypa.io/get-pip.py"}
PIP_GET_PIP36_URL=${PIP_GET_PIP36_URL:-"https://bootstrap.pypa.io/pip/3.6/get-pip.py"}

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
    # Show python3 module version
    python${PYTHON3_VERSION} -m pip --version
}


function install_get_pip {
    if [[ "$PYTHON3_VERSION" = "3.6" ]]; then
        _pip_url=$PIP_GET_PIP36_URL
        _local_pip="$FILES/$(basename $_pip_url)-py36"
    else
        _pip_url=$PIP_GET_PIP_URL
        _local_pip="$FILES/$(basename $_pip_url)"
    fi


    # If get-pip.py isn't python, delete it. This was probably an
    # outage on the server.
    if [[ -r $_local_pip ]]; then
        if ! head -1 $_local_pip | grep -q '#!/usr/bin/env python'; then
            echo "WARNING: Corrupt $_local_pip found removing"
            rm $_local_pip
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
    if [[ ! -r $_local_pip || -r $_local_pip.downloaded ]]; then
        # only test freshness if LOCAL_PIP is actually there,
        # otherwise we generate a scary warning.
        local timecond=""
        if [[ -r $_local_pip ]]; then
            timecond="-z $_local_pip"
        fi

        curl -f --retry 6 --retry-delay 5 \
            $timecond -o $_local_pip $_pip_url || \
            die $LINENO "Download of get-pip.py failed"
        touch $_local_pip.downloaded
    fi
    sudo -H -E python${PYTHON3_VERSION} $_local_pip
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

if [[ -n $PYPI_ALTERNATIVE_URL ]]; then
    configure_pypi_alternative_url
fi

if is_fedora && [[ ${DISTRO} == f* || ${DISTRO} == rhel9 ]]; then
    # get-pip.py will not install over the python3-pip package in
    # Fedora 34 any more.
    #  https://bugzilla.redhat.com/show_bug.cgi?id=1988935
    #  https://github.com/pypa/pip/issues/9904
    # You can still install using get-pip.py if python3-pip is *not*
    # installed; this *should* remain separate under /usr/local and not break
    # if python3-pip is later installed.
    # For general sanity, we just use the packaged pip.  It should be
    # recent enough anyway.  This is included via rpms/general
    : # Simply fall through
else
    if ! is_fedora && ! is_suse; then
        if is_package_installed python3-pip ; then
            uninstall_package python3-pip
        fi
    fi
    install_get_pip
    # Note setuptools is part of requirements.txt and we want to make sure
    # we obey any versioning as described there.
    pip_install_gr setuptools
fi

set -x

get_versions
