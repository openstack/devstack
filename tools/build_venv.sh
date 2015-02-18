#!/usr/bin/env bash
#
# **tools/build_venv.sh** - Build a Python Virtual Envirnment
#
# build_venv.sh venv-path [package [...]]
#
# Assumes:
# - a useful pip is installed
# - virtualenv will be installed by pip
# - installs basic common prereq packages that require compilation
#   to allow quick copying of resulting venv as a baseline


VENV_DEST=${1:-.venv}
shift

MORE_PACKAGES="$@"

# If TOP_DIR is set we're being sourced rather than running stand-alone
# or in a sub-shell
if [[ -z "$TOP_DIR" ]]; then

    set -o errexit
    set -o nounset

    # Keep track of the devstack directory
    TOP_DIR=$(cd $(dirname "$0")/.. && pwd)
    FILES=$TOP_DIR/files

    # Import common functions
    source $TOP_DIR/functions

    GetDistro

    source $TOP_DIR/stackrc

    trap err_trap ERR

fi

# Exit on any errors so that errors don't compound
function err_trap {
    local r=$?
    set +o xtrace

    rm -rf $TMP_VENV_PATH

    exit $r
}

# Build new venv
virtualenv $VENV_DEST

# Install modern pip
$VENV_DEST/bin/pip install -U pip

for pkg in ${MORE_PACKAGES}; do
    pip_install_venv $VENV_DEST $pkg
done
