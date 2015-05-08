#!/usr/bin/env bash
#
# **tools/build_wheels.sh** - Build a cache of Python wheels
#
# build_wheels.sh [package [...]]
#
# System package prerequisites listed in ``files/*/devlibs`` will be installed
#
# Builds wheels for all virtual env requirements listed in
# ``venv-requirements.txt`` plus any supplied on the command line.
#
# Assumes:
# - ``tools/install_pip.sh`` has been run and a suitable ``pip/setuptools`` is available.

# If ``TOP_DIR`` is set we're being sourced rather than running stand-alone
# or in a sub-shell
if [[ -z "$TOP_DIR" ]]; then

    set -o errexit
    set -o nounset

    # Keep track of the DevStack directory
    TOP_DIR=$(cd $(dirname "$0")/.. && pwd)
    FILES=$TOP_DIR/files

    # Import common functions
    source $TOP_DIR/functions

    GetDistro

    source $TOP_DIR/stackrc

    trap err_trap ERR

fi

# Get additional packages to build
MORE_PACKAGES="$@"

# Exit on any errors so that errors don't compound
function err_trap {
    local r=$?
    set +o xtrace

    rm -rf $TMP_VENV_PATH

    exit $r
}

# Get system prereqs
install_package $(get_packages devlibs)

# Get a modern ``virtualenv``
pip_install virtualenv

# Prepare the workspace
TMP_VENV_PATH=$(mktemp -d tmp-venv-XXXX)
virtualenv $TMP_VENV_PATH

# Install modern pip and wheel
PIP_VIRTUAL_ENV=$TMP_VENV_PATH pip_install -U pip wheel

# BUG: cffi has a lot of issues. It has no stable ABI, if installed
# code is built with a different ABI than the one that's detected at
# load time, it tries to compile on the fly for the new ABI in the
# install location (which will probably be /usr and not
# writable). Also cffi is often included via setup_requires by
# packages, which have different install rules (allowing betas) than
# pip has.
#
# Because of this we must pip install cffi into the venv to build
# wheels.
PIP_VIRTUAL_ENV=$TMP_VENV_PATH pip_install_gr cffi

# ``VENV_PACKAGES`` is a list of packages we want to pre-install
VENV_PACKAGE_FILE=$FILES/venv-requirements.txt
if [[ -r $VENV_PACKAGE_FILE ]]; then
    VENV_PACKAGES=$(grep -v '^#' $VENV_PACKAGE_FILE)
fi

for pkg in ${VENV_PACKAGES,/ } ${MORE_PACKAGES}; do
    $TMP_VENV_PATH/bin/pip wheel $pkg
done

# Clean up wheel workspace
rm -rf $TMP_VENV_PATH
