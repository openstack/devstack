#!/usr/bin/env bash

# **fixup_stuff.sh**

# fixup_stuff.sh
#
# All distro and package specific hacks go in here


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

# Python Packages
# ---------------

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

    # Since pip10, pip will refuse to uninstall files from packages
    # that were created with distutils (rather than more modern
    # setuptools).  This is because it technically doesn't have a
    # manifest of what to remove.  However, in most cases, simply
    # overwriting works.  So this hacks around those packages that
    # have been dragged in by some other system dependency
    sudo rm -rf /usr/lib64/python3*/site-packages/PyYAML-*.egg-info

    # After updating setuptools based on the requirements, the files from the
    # python3-setuptools RPM are deleted, it breaks some tools such as semanage
    # (used in diskimage-builder) that use the -s flag of the python
    # interpreter, enforcing the use of the packages from /usr/lib.
    # Importing setuptools/pkg_resources in a such environment fails.
    # Enforce the package re-installation to fix those applications.
    if is_package_installed python3-setuptools; then
        sudo dnf reinstall -y python3-setuptools
    fi
    # Workaround CentOS 8-stream iputils and systemd Bug
    # https://bugzilla.redhat.com/show_bug.cgi?id=2037807
    if [[ $os_VENDOR == "CentOSStream" && $os_RELEASE -eq 8 ]]; then
        sudo sysctl -w net.ipv4.ping_group_range='0 2147483647'
    fi
}

function fixup_ovn_centos {
    if [[ $os_VENDOR != "CentOS" ]]; then
        return
    fi
    # OVN packages are part of this release for CentOS
    yum_install centos-release-openstack-victoria
}

function fixup_ubuntu {
    if ! is_ubuntu; then
        return
    fi

    # Since pip10, pip will refuse to uninstall files from packages
    # that were created with distutils (rather than more modern
    # setuptools).  This is because it technically doesn't have a
    # manifest of what to remove.  However, in most cases, simply
    # overwriting works.  So this hacks around those packages that
    # have been dragged in by some other system dependency
    sudo rm -rf /usr/lib/python3/dist-packages/PyYAML-*.egg-info
    sudo rm -rf /usr/lib/python3/dist-packages/pyasn1_modules-*.egg-info
    sudo rm -rf /usr/lib/python3/dist-packages/simplejson-*.egg-info
}

function fixup_all {
    fixup_ubuntu
    fixup_fedora
}
