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
# - Fedora:
#   - set selinux not enforcing
#   - uninstall firewalld (f20 only)


# If ``TOP_DIR`` is set we're being sourced rather than running stand-alone
# or in a sub-shell
if [[ -z "$TOP_DIR" ]]; then
    set -o errexit
    set -o xtrace

    # Keep track of the current directory
    TOOLS_DIR=$(cd $(dirname "$0") && pwd)
    TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

    # Change dir to top of DevStack
    cd $TOP_DIR

    # Import common functions
    source $TOP_DIR/functions

    FILES=$TOP_DIR/files
fi

# Keystone Port Reservation
# -------------------------
# Reserve and prevent ``KEYSTONE_AUTH_PORT`` and ``KEYSTONE_AUTH_PORT_INT`` from
# being used as ephemeral ports by the system. The default(s) are 35357 and
# 35358 which are in the Linux defined ephemeral port range (in disagreement
# with the IANA ephemeral port range). This is a workaround for bug #1253482
# where Keystone will try and bind to the port and the port will already be
# in use as an ephemeral port by another process. This places an explicit
# exception into the Kernel for the Keystone AUTH ports.
function fixup_keystone {
    keystone_ports=${KEYSTONE_AUTH_PORT:-35357},${KEYSTONE_AUTH_PORT_INT:-35358}

    # Only do the reserved ports when available, on some system (like containers)
    # where it's not exposed we are almost pretty sure these ports would be
    # exclusive for our DevStack.
    if sysctl net.ipv4.ip_local_reserved_ports >/dev/null 2>&1; then
        # Get any currently reserved ports, strip off leading whitespace
        reserved_ports=$(sysctl net.ipv4.ip_local_reserved_ports | awk -F'=' '{print $2;}' | sed 's/^ //')

        if [[ -z "${reserved_ports}" ]]; then
            # If there are no currently reserved ports, reserve the keystone ports
            sudo sysctl -w net.ipv4.ip_local_reserved_ports=${keystone_ports}
        else
            # If there are currently reserved ports, keep those and also reserve the
            # Keystone specific ports. Duplicate reservations are merged into a single
            # reservation (or range) automatically by the kernel.
            sudo sysctl -w net.ipv4.ip_local_reserved_ports=${keystone_ports},${reserved_ports}
        fi
    else
        echo_summary "WARNING: unable to reserve keystone ports"
    fi
}

# Ubuntu Cloud Archive
#---------------------
# We've found that Libvirt on Xenial is flaky and crashes enough to be
# a regular top e-r bug. Opt into Ubuntu Cloud Archive if on Xenial to
# get newer Libvirt.
# Make it possible to switch this based on an environment variable as
# libvirt 2.5.0 doesn't handle nested virtualization quite well and this
# is required for the trove development environment.
# The Pike UCA has qemu 2.10 but libvirt 3.6, therefore if
# ENABLE_VOLUME_MULTIATTACH is True, we can't use the Pike UCA
# because multiattach won't work with those package versions.
# We can remove this check when the UCA has libvirt>=3.10.
function fixup_uca {
    if [[ "${ENABLE_UBUNTU_CLOUD_ARCHIVE}" == "False" || "$DISTRO" != "xenial" || \
            "${ENABLE_VOLUME_MULTIATTACH}" == "True" ]]; then
        return
    fi

    # This pulls in apt-add-repository
    install_package "software-properties-common"
    # Use UCA for newer libvirt. Should give us libvirt 2.5.0.
    if [[ -f /etc/ci/mirror_info.sh ]] ; then
        # If we are on a nodepool provided host and it has told us about where
        # we can find local mirrors then use that mirror.
        source /etc/ci/mirror_info.sh

        sudo apt-add-repository -y "deb $NODEPOOL_UCA_MIRROR xenial-updates/pike main"
    else
        # Otherwise use upstream UCA
        sudo add-apt-repository -y cloud-archive:pike
    fi

    # Disable use of libvirt wheel since a cached wheel build might be
    # against older libvirt binary.  Particularly a problem if using
    # the openstack wheel mirrors, but can hit locally too.
    # TODO(clarkb) figure out how to use upstream wheel again.
    iniset -sudo /etc/pip.conf "global" "no-binary" "libvirt-python"

    # Force update our APT repos, since we added UCA above.
    REPOS_UPDATED=False
    apt_get_update
}

# Python Packages
# ---------------

# get_package_path python-package    # in import notation
function get_package_path {
    local package=$1
    echo $(python -c "import os; import $package; print(os.path.split(os.path.realpath($package.__file__))[0])")
}


# Pre-install affected packages so we can fix the permissions
# These can go away once we are confident that pip 1.4.1+ is available everywhere

function fixup_python_packages {
    # Fix prettytable 0.7.2 permissions
    # Don't specify --upgrade so we use the existing package if present
    pip_install 'prettytable>=0.7'
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
}

function fixup_fedora {
    if ! is_fedora; then
        return
    fi
    # Disable selinux to avoid configuring to allow Apache access
    # to Horizon files (LP#1175444)
    if selinuxenabled; then
        sudo setenforce 0
    fi

    FORCE_FIREWALLD=$(trueorfalse False FORCE_FIREWALLD)
    if [[ $FORCE_FIREWALLD == "False" ]]; then
        # On Fedora 20 firewalld interacts badly with libvirt and
        # slows things down significantly (this issue was fixed in
        # later fedoras).  There was also an additional issue with
        # firewalld hanging after install of libvirt with polkit [1].
        # firewalld also causes problems with neturon+ipv6 [2]
        #
        # Note we do the same as the RDO packages and stop & disable,
        # rather than remove.  This is because other packages might
        # have the dependency [3][4].
        #
        # [1] https://bugzilla.redhat.com/show_bug.cgi?id=1099031
        # [2] https://bugs.launchpad.net/neutron/+bug/1455303
        # [3] https://github.com/redhat-openstack/openstack-puppet-modules/blob/master/firewall/manifests/linux/redhat.pp
        # [4] https://docs.openstack.org/devstack/latest/guides/neutron.html
        if is_package_installed firewalld; then
            sudo systemctl disable firewalld
            # The iptables service files are no longer included by default,
            # at least on a baremetal Fedora 21 Server install.
            install_package iptables-services
            sudo systemctl enable iptables
            sudo systemctl stop firewalld
            sudo systemctl start iptables
        fi
    fi

    if  [[ "$os_VENDOR" == "Fedora" ]] && [[ "$os_RELEASE" -ge "22" ]]; then
        # requests ships vendored version of chardet/urllib3, but on
        # fedora these are symlinked back to the primary versions to
        # avoid duplication of code on disk.  This is fine when
        # maintainers keep things in sync, but since devstack takes
        # over and installs later versions via pip we can end up with
        # incompatible versions.
        #
        # The rpm package is not removed to preserve the dependent
        # packages like cloud-init; rather we remove the symlinks and
        # force a re-install of requests so the vendored versions it
        # wants are present.
        #
        # Realted issues:
        # https://bugs.launchpad.net/glance/+bug/1476770
        # https://bugzilla.redhat.com/show_bug.cgi?id=1253823

        base_path=$(get_package_path requests)/packages
        if [ -L $base_path/chardet -o -L $base_path/urllib3 ]; then
            sudo rm -f $base_path/{chardet,urllib3}
            # install requests with the bundled urllib3 to avoid conflicts
            pip_install --upgrade --force-reinstall requests
        fi
    fi
}

# The version of pip(1.5.4) supported by python-virtualenv(1.11.4) has
# connection issues under proxy so re-install the latest version using
# pip. To avoid having pip's virtualenv overwritten by the distro's
# package (e.g. due to installing a distro package with a dependency
# on python-virtualenv), first install the distro python-virtualenv
# to satisfy any dependencies then use pip to overwrite it.

# ... but, for infra builds, the pip-and-virtualenv [1] element has
# already done this to ensure the latest pip, virtualenv and
# setuptools on the base image for all platforms.  It has also added
# the packages to the yum/dnf ignore list to prevent them being
# overwritten with old versions.  F26 and dnf 2.0 has changed
# behaviour that means re-installing python-virtualenv fails [2].
# Thus we do a quick check if we're in the infra environment by
# looking for the mirror config script before doing this, and just
# skip it if so.

# [1] https://git.openstack.org/cgit/openstack/diskimage-builder/tree/ \
#        diskimage_builder/elements/pip-and-virtualenv/ \
#            install.d/pip-and-virtualenv-source-install/04-install-pip
# [2] https://bugzilla.redhat.com/show_bug.cgi?id=1477823

function fixup_virtualenv {
    if [[ ! -f /etc/ci/mirror_info.sh ]]; then
        install_package python-virtualenv
        pip_install -U --force-reinstall virtualenv
    fi
}

function fixup_all {
    fixup_keystone
    fixup_uca
    fixup_python_packages
    fixup_fedora
    fixup_virtualenv
}
