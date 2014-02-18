# Getting Started With XenServer and Devstack

The purpose of the code in this directory it to help developers bootstrap a
XenServer 6.2 (older versions may also work) + OpenStack development
environment. This file gives some pointers on how to get started.

Xenserver is a Type 1 hypervisor, so it is best installed on bare metal.  The
OpenStack services are configured to run within a virtual machine (called OS
domU) on the XenServer host. The VM uses the XAPI toolstack to communicate with
the host over a network connection (see `MGT_BRIDGE_OR_NET_NAME`).

The provided localrc helps to build a basic environment.

## Introduction

### Requirements

 - An internet-enabled network with a DHCP server on it
 - XenServer box plugged in to the same network
This network will be used as the OpenStack management network. The VM Network
and the Public Network will not be connected to any physical interfaces, only
new virtual networks will be created by the `install_os_domU.sh` script.

### Steps to follow

 - Install XenServer
 - Download Devstack to XenServer
 - Customise `localrc`
 - Start `install_os_domU.sh` script

### Brief explanation

The `install_os_domU.sh` script will:
 - Setup XenAPI plugins
 - Create the named networks, if they don't exist
 - Preseed-Netinstall an Ubuntu Virtual Machine (NOTE: you can save and reuse
   it, see [Reuse the Ubuntu VM](#reuse-the-ubuntu-vm)), with 1 network
   interface:
   - `eth0` - Connected to `UBUNTU_INST_BRIDGE_OR_NET_NAME`, defaults to
     `MGT_BRIDGE_OR_NET_NAME`
 - After the Ubuntu install process finished, the network configuration is
 modified to:
   - `eth0` - Management interface, connected to `MGT_BRIDGE_OR_NET_NAME`. Xapi
     must be accessible through this network.
   - `eth1` - VM interface, connected to `VM_BRIDGE_OR_NET_NAME`
   - `eth2` - Public interface, connected to `PUB_BRIDGE_OR_NET_NAME`
 - Start devstack inside the created OpenStack VM

## Step 1: Install Xenserver
Install XenServer on a clean box. You can download the latest XenServer for
free from: http://www.xenserver.org/

The XenServer IP configuration depends on your local network setup. If you are
using dhcp, make a reservation for XenServer, so its IP address won't change
over time. Make a note of the XenServer's IP address, as it has to be specified
in `localrc`. The other option is to manually specify the IP setup for the
XenServer box. Please make sure, that a gateway and a nameserver is configured,
as `install_os_domU.sh` will connect to github.com to get source-code snapshots.

## Step 2: Download devstack
On your XenServer host, run the following commands as root:

    wget --no-check-certificate https://github.com/openstack-dev/devstack/zipball/master
    unzip -o master -d ./devstack
    cd devstack/*/

## Step 3: Configure your localrc inside the devstack directory
Devstack uses a localrc for user-specific configuration.  Note that
the `XENAPI_PASSWORD` must be your dom0 root password.
Of course, use real passwords if this machine is exposed.

    cat > ./localrc <<EOF
    # At the moment, we depend on github's snapshot function.
    GIT_BASE="http://github.com"

    # Passwords
    # NOTE: these need to be specified, otherwise devstack will try
    # to prompt for these passwords, blocking the install process.

    MYSQL_PASSWORD=my_super_secret
    SERVICE_TOKEN=my_super_secret
    ADMIN_PASSWORD=my_super_secret
    SERVICE_PASSWORD=my_super_secret
    RABBIT_PASSWORD=my_super_secret
    SWIFT_HASH="66a3d6b56c1f479c8b4e70ab5c2000f5"
    # This will be the password for the OpenStack VM (both stack and root users)
    GUEST_PASSWORD=my_super_secret

    # XenAPI parameters
    # NOTE: The following must be set to your XenServer root password!

    XENAPI_PASSWORD=my_xenserver_root_password

    XENAPI_CONNECTION_URL="http://address_of_your_xenserver"
    VNCSERVER_PROXYCLIENT_ADDRESS=address_of_your_xenserver

    # Download a vhd and a uec image
    IMAGE_URLS="\
    https://github.com/downloads/citrix-openstack/warehouse/cirros-0.3.0-x86_64-disk.vhd.tgz,\
    http://download.cirros-cloud.net/0.3.1/cirros-0.3.1-x86_64-uec.tar.gz"

    # Explicitly set virt driver
    VIRT_DRIVER=xenserver

    # Explicitly enable multi-host for nova-network HA
    MULTI_HOST=1

    # Give extra time for boot
    ACTIVE_TIMEOUT=45

    EOF

## Step 4: Run `./install_os_domU.sh` from the `tools/xen` directory

    cd tools/xen
    ./install_os_domU.sh

Once this script finishes executing, log into the VM (openstack domU) that it
installed and tail the run.sh.log file. You will need to wait until it run.sh
has finished executing.

# Appendix

This section contains useful information for running devstack in CI
environments / using ubuntu network mirrors.

## Use a specific Ubuntu mirror for installation

To speed up the Ubuntu installation, you can use a specific mirror. To specify
a mirror explicitly, include the following settings in your `localrc` file:

    UBUNTU_INST_HTTP_HOSTNAME="archive.ubuntu.com"
    UBUNTU_INST_HTTP_DIRECTORY="/ubuntu"

These variables set the `mirror/http/hostname` and `mirror/http/directory`
settings in the ubuntu preseed file. The minimal ubuntu VM will use the
specified parameters.

## Use an http proxy to speed up Ubuntu installation

To further speed up the Ubuntu VM and package installation, an internal http
proxy could be used. `squid-deb-proxy` has prooven to be stable. To use an http
proxy, specify:

    UBUNTU_INST_HTTP_PROXY="http://ubuntu-proxy.somedomain.com:8000"

in your `localrc` file.

## Reuse the Ubuntu VM

Performing a minimal ubuntu installation could take a lot of time, depending on
your mirror/network speed. If you run `install_os_domU.sh` script on a clean
hypervisor, you can speed up the installation, by re-using the ubuntu vm from
a previous installation.

### Export the Ubuntu VM to an XVA

Given you have an nfs export `TEMPLATE_NFS_DIR`:

    TEMPLATE_FILENAME=devstack-jeos.xva
    TEMPLATE_NAME=jeos_template_for_devstack
    mountdir=$(mktemp -d)
    mount -t nfs "$TEMPLATE_NFS_DIR" "$mountdir"
    VM="$(xe template-list name-label="$TEMPLATE_NAME" --minimal)"
    xe template-export template-uuid=$VM filename="$mountdir/$TEMPLATE_FILENAME"
    umount "$mountdir"
    rm -rf "$mountdir"

### Import the Ubuntu VM

Given you have an nfs export `TEMPLATE_NFS_DIR` where you exported the Ubuntu
VM as `TEMPLATE_FILENAME`:

    mountdir=$(mktemp -d)
    mount -t nfs "$TEMPLATE_NFS_DIR" "$mountdir"
    xe vm-import filename="$mountdir/$TEMPLATE_FILENAME"
    umount "$mountdir"
    rm -rf "$mountdir"
