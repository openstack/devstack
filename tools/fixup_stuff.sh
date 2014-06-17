#!/usr/bin/env bash

# **fixup_stuff.sh**

# fixup_stuff.sh
#
# All distro and package specific hacks go in here
#
# - prettytable 0.7.2 permissions are 600 in the package and
#   pip 1.4 doesn't fix it (1.3 did)
#
# - httplib2 0.8 permissions are 600 in the package and
#   pip 1.4 doesn't fix it (1.3 did)
#
# - RHEL6:
#
#   - set selinux not enforcing
#   - (re)start messagebus daemon
#   - remove distro packages python-crypto and python-lxml
#   - pre-install hgtools to work around a bug in RHEL6 distribute
#   - install nose 1.1 from EPEL

set -o errexit
set -o xtrace

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Change dir to top of devstack
cd $TOP_DIR

# Import common functions
source $TOP_DIR/functions

FILES=$TOP_DIR/files

# Keystone Port Reservation
# -------------------------
# Reserve and prevent $KEYSTONE_AUTH_PORT and $KEYSTONE_AUTH_PORT_INT from
# being used as ephemeral ports by the system. The default(s) are 35357 and
# 35358 which are in the Linux defined ephemeral port range (in disagreement
# with the IANA ephemeral port range). This is a workaround for bug #1253482
# where Keystone will try and bind to the port and the port will already be
# in use as an ephemeral port by another process. This places an explicit
# exception into the Kernel for the Keystone AUTH ports.
keystone_ports=${KEYSTONE_AUTH_PORT:-35357},${KEYSTONE_AUTH_PORT_INT:-35358}

# Get any currently reserved ports, strip off leading whitespace
reserved_ports=$(sysctl net.ipv4.ip_local_reserved_ports | awk -F'=' '{print $2;}' | sed 's/^ //')

if [[ -z "${reserved_ports}" ]]; then
    # If there are no currently reserved ports, reserve the keystone ports
    sudo sysctl -w net.ipv4.ip_local_reserved_ports=${keystone_ports}
else
    # If there are currently reserved ports, keep those and also reserve the
    # keystone specific ports. Duplicate reservations are merged into a single
    # reservation (or range) automatically by the kernel.
    sudo sysctl -w net.ipv4.ip_local_reserved_ports=${keystone_ports},${reserved_ports}
fi


# Python Packages
# ---------------

# get_package_path python-package    # in import notation
function get_package_path {
    local package=$1
    echo $(python -c "import os; import $package; print(os.path.split(os.path.realpath($package.__file__))[0])")
}


# Pre-install affected packages so we can fix the permissions
# These can go away once we are confident that pip 1.4.1+ is available everywhere

# Fix prettytable 0.7.2 permissions
# Don't specify --upgrade so we use the existing package if present
pip_install 'prettytable>0.7'
PACKAGE_DIR=$(get_package_path prettytable)
# Only fix version 0.7.2
dir=$(echo $PACKAGE_DIR/prettytable-0.7.2*)
if [[ -d $dir ]]; then
    sudo chmod +r $dir/*
fi

# Fix httplib2 0.8 permissions
# Don't specify --upgrade so we use the existing package if present
pip_install httplib2
PACKAGE_DIR=$(get_package_path httplib2)
# Only fix version 0.8
dir=$(echo $PACKAGE_DIR-0.8*)
if [[ -d $dir ]]; then
    sudo chmod +r $dir/*
fi

# Ubuntu 12.04
# ------------

# We can regularly get kernel crashes on the 12.04 default kernel, so attempt
# to install a new kernel
if [[ ${DISTRO} =~ (precise) ]]; then
    # Finally, because we suspect the Precise kernel is problematic, install a new kernel
    UPGRADE_KERNEL=$(trueorfalse False $UPGRADE_KERNEL)
    if [[ $UPGRADE_KERNEL == "True" ]]; then
        if [[ ! `uname -r` =~ (^3\.11) ]]; then
            apt_get install linux-generic-lts-saucy
            echo "Installing Saucy LTS kernel, please reboot before proceeding"
            exit 1
        fi
    fi
fi


if is_fedora; then
    # Disable selinux to avoid configuring to allow Apache access
    # to Horizon files (LP#1175444)
    if selinuxenabled; then
        sudo setenforce 0
    fi
fi

# RHEL6
# -----

if [[ $DISTRO =~ (rhel6) ]]; then

    # If the ``dbus`` package was installed by DevStack dependencies the
    # uuid may not be generated because the service was never started (PR#598200),
    # causing Nova to stop later on complaining that ``/var/lib/dbus/machine-id``
    # does not exist.
    sudo service messagebus restart

    # The following workarounds break xenserver
    if [ "$VIRT_DRIVER" != 'xenserver' ]; then
        # An old version of ``python-crypto`` (2.0.1) may be installed on a
        # fresh system via Anaconda and the dependency chain
        # ``cas`` -> ``python-paramiko`` -> ``python-crypto``.
        # ``pip uninstall pycrypto`` will remove the packaged ``.egg-info``
        # file but leave most of the actual library files behind in
        # ``/usr/lib64/python2.6/Crypto``. Later ``pip install pycrypto``
        # will install over the packaged files resulting
        # in a useless mess of old, rpm-packaged files and pip-installed files.
        # Remove the package so that ``pip install python-crypto`` installs
        # cleanly.
        # Note: other RPM packages may require ``python-crypto`` as well.
        # For example, RHEL6 does not install ``python-paramiko packages``.
        uninstall_package python-crypto

        # A similar situation occurs with ``python-lxml``, which is required by
        # ``ipa-client``, an auditing package we don't care about.  The
        # build-dependencies needed for ``pip install lxml`` (``gcc``,
        # ``libxml2-dev`` and ``libxslt-dev``) are present in
        # ``files/rpms/general``.
        uninstall_package python-lxml
    fi

    # ``setup.py`` contains a ``setup_requires`` package that is supposed
    # to be transient.  However, RHEL6 distribute has a bug where
    # ``setup_requires`` registers entry points that are not cleaned
    # out properly after the setup-phase resulting in installation failures
    # (bz#924038).  Pre-install the problem package so the ``setup_requires``
    # dependency is satisfied and it will not be installed transiently.
    # Note we do this before the track-depends in ``stack.sh``.
    pip_install hgtools


    # RHEL6's version of ``python-nose`` is incompatible with Tempest.
    # Install nose 1.1 (Tempest-compatible) from EPEL
    install_package python-nose1.1
    # Add a symlink for the new nosetests to allow tox for Tempest to
    # work unmolested.
    sudo ln -sf /usr/bin/nosetests1.1 /usr/local/bin/nosetests

    # workaround for https://code.google.com/p/unittest-ext/issues/detail?id=79
    install_package python-unittest2 patch
    pip_install discover
    (cd /usr/lib/python2.6/site-packages/; sudo patch <"$FILES/patches/unittest2-discover.patch" || echo 'Assume already applied')
    # Make sure the discover.pyc is up to date
    sudo rm /usr/lib/python2.6/site-packages/discover.pyc || true
    sudo python -c 'import discover'
fi
