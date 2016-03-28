#!/usr/bin/env bash
#
# **tools/build_venv.sh** - Build a Python Virtual Envirnment
#
# build_venv.sh venv-path [package [...]]
#
# Installs basic common prereq packages that require compilation
# to allow quick copying of resulting venv as a baseline
#
# Assumes:
# - a useful pip is installed
# - virtualenv will be installed by pip


VENV_DEST=${1:-.venv}
shift

MORE_PACKAGES="$@"

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

fi

# Build new venv
virtualenv $VENV_DEST

# Install modern pip
PIP_VIRTUAL_ENV=$VENV_DEST pip_install -U pip

# Install additional packages
PIP_VIRTUAL_ENV=$VENV_DEST pip_install ${MORE_PACKAGES}
