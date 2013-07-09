# Getting Started With XenServer 5.6 and Devstack
The purpose of the code in this directory it to help developers bootstrap
a XenServer 5.6 (or greater) + Openstack development environment.  This file gives
some pointers on how to get started.

Xenserver is a Type 1 hypervisor, so it needs to be installed on bare metal.
The Openstack services are configured to run within a "privileged" virtual
machine on the Xenserver host (called OS domU). The VM uses the XAPI toolstack
to communicate with the host.

The provided localrc helps to build a basic environment.
The requirements are:
 - An internet-enabled network with a DHCP server on it
 - XenServer box plugged in to the same network
This network will be used as the OpenStack management network. The VM Network
and the Public Network will not be connected to any physical interfaces, only
new virtual networks will be created by the `install_os_domU.sh` script.

Steps to follow:
 - Install XenServer
 - Download Devstack to XenServer
 - Customise `localrc`
 - Start `install_os_domU.sh` script

The `install_os_domU.sh` script will:
 - Setup XenAPI plugins
 - Create the named networks, if they don't exist
 - Preseed-Netinstall an Ubuntu Virtual Machine, with 1 network interface:
   - eth0 - Connected to `UBUNTU_INST_BRIDGE_OR_NET_NAME`, defaults to
   `MGT_BRIDGE_OR_NET_NAME`
 - After the Ubuntu install process finished, the network configuration is
 modified to:
   - eth0 - Management interface, connected to `MGT_BRIDGE_OR_NET_NAME`
   - eth1 - VM interface, connected to `VM_BRIDGE_OR_NET_NAME`
   - eth2 - Public interface, connected to `PUB_BRIDGE_OR_NET_NAME`
   - (eth3) - Optional network interface if neutron is used, to enforce xapi to
   create the underlying bridge.
 - Start devstack inside the created OpenStack VM

## Step 1: Install Xenserver
Install XenServer 5.6+ on a clean box. You can get XenServer by signing
up for an account on citrix.com, and then visiting:
https://www.citrix.com/English/ss/downloads/details.asp?downloadId=2311504&productId=683148

For details on installation, see: http://wiki.openstack.org/XenServer/Install

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

    # Do not download the usual images
    IMAGE_URLS=""
    # Explicitly set virt driver here
    VIRT_DRIVER=xenserver
    # Explicitly enable multi-host
    MULTI_HOST=1
    # Give extra time for boot
    ACTIVE_TIMEOUT=45

    # NOTE: the value of FLAT_NETWORK_BRIDGE will automatically be determined
    # by install_os_domU.sh script.
    EOF

## Step 4: Run `./install_os_domU.sh` from the `tools/xen` directory

    cd tools/xen
    ./install_os_domU.sh

Once this script finishes executing, log into the VM (openstack domU) that it
installed and tail the run.sh.log file. You will need to wait until it run.sh
has finished executing.

## Step 5: Do cloudy stuff!
* Play with horizon
* Play with the CLI
* Log bugs to devstack and core projects, and submit fixes!

## Step 6: Run from snapshot
If you want to quicky re-run devstack from a clean state,
using the same settings you used in your previous run,
you can revert the DomU to the snapshot called `before_first_boot`
