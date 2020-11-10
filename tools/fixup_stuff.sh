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

# Ubuntu Repositories
#--------------------
# Enable universe for bionic since it is missing when installing from ISO.
function fixup_ubuntu {
    if [[ "$DISTRO" != "bionic" ]]; then
        return
    fi

    # This pulls in apt-add-repository
    install_package "software-properties-common"

    # Enable universe
    sudo add-apt-repository -y universe

    if [[ -f /etc/ci/mirror_info.sh ]] ; then
        # If we are on a nodepool provided host and it has told us about
        # where we can find local mirrors then use that mirror.
        source /etc/ci/mirror_info.sh
        sudo apt-add-repository -y "deb $NODEPOOL_UCA_MIRROR bionic-updates/ussuri main"
    else
        # Enable UCA:train for updated versions of QEMU and libvirt
        sudo add-apt-repository -y cloud-archive:ussuri
    fi
    REPOS_UPDATED=False
    apt_get_update

    # Since pip10, pip will refuse to uninstall files from packages
    # that were created with distutils (rather than more modern
    # setuptools).  This is because it technically doesn't have a
    # manifest of what to remove.  However, in most cases, simply
    # overwriting works.  So this hacks around those packages that
    # have been dragged in by some other system dependency
    sudo rm -rf /usr/lib/python3/dist-packages/httplib2-*.egg-info
    sudo rm -rf /usr/lib/python3/dist-packages/pyasn1_modules-*.egg-info
    sudo rm -rf /usr/lib/python3/dist-packages/PyYAML-*.egg-info
}

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

    # NOTE(lyarwood): Workaround a known issue on Fedora with dnsmasq >= 2.81
    # by downgrading to 2.80 for the time being.
    # https://bugs.launchpad.net/neutron/+bug/1896945
    if [[ "$DISTRO" == "f32" ]] && [[ $(rpm --queryformat %{VERSION} -q dnsmasq) != "2.80" ]]; then
        sudo dnf downgrade dnsmasq-2.80 -y
    fi
}

function fixup_suse {
    if ! is_suse; then
        return
    fi

    # Deactivate and disable apparmor profiles in openSUSE and SLE
    # distros to avoid issues with haproxy and dnsmasq.  In newer
    # releases, systemctl stop apparmor is actually a no-op, so we
    # have to use aa-teardown to make sure we've deactivated the
    # profiles:
    #
    # https://www.suse.com/releasenotes/x86_64/SUSE-SLES/15/#fate-325343
    # https://gitlab.com/apparmor/apparmor/merge_requests/81
    # https://build.opensuse.org/package/view_file/openSUSE:Leap:15.2/apparmor/apparmor.service?expand=1
    if sudo systemctl is-active -q apparmor; then
        sudo systemctl stop apparmor
    fi
    if [ -x /usr/sbin/aa-teardown ]; then
        sudo /usr/sbin/aa-teardown
    fi
    if sudo systemctl is-enabled -q apparmor; then
        sudo systemctl disable apparmor
    fi

    # Since pip10, pip will refuse to uninstall files from packages
    # that were created with distutils (rather than more modern
    # setuptools).  This is because it technically doesn't have a
    # manifest of what to remove.  However, in most cases, simply
    # overwriting works.  So this hacks around those packages that
    # have been dragged in by some other system dependency
    sudo rm -rf /usr/lib/python3.6/site-packages/ply-*.egg-info
    sudo rm -rf /usr/lib/python3.6/site-packages/six-*.egg-info

    # Ensure trusted CA certificates are up to date
    # See https://bugzilla.suse.com/show_bug.cgi?id=1154871
    # May be removed once a new opensuse-15 image is available in nodepool
    sudo zypper up -y p11-kit ca-certificates-mozilla
}

function fixup_all {
    fixup_keystone
    fixup_ubuntu
    fixup_fedora
    fixup_suse
}
