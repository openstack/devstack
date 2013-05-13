# Getting Started With XenServer 5.6 and Devstack
The purpose of the code in this directory it to help developers bootstrap
a XenServer 5.6 (or greater) + Openstack development environment.  This file gives
some pointers on how to get started.

Xenserver is a Type 1 hypervisor, so it needs to be installed on bare metal.
The Openstack services are configured to run within a "privileged" virtual
machine on the Xenserver host (called OS domU). The VM uses the XAPI toolstack
to communicate with the host.

## Step 1: Install Xenserver
Install XenServer 5.6+ on a clean box. You can get XenServer by signing
up for an account on citrix.com, and then visiting:
https://www.citrix.com/English/ss/downloads/details.asp?downloadId=2311504&productId=683148

For details on installation, see: http://wiki.openstack.org/XenServer/Install

Here are some sample Xenserver network settings for when you are just
getting started (Settings like this have been used with a laptop + cheap wifi router):

* XenServer Host IP: 192.168.1.10
* XenServer Netmask: 255.255.255.0
* XenServer Gateway: 192.168.1.1
* XenServer DNS: 192.168.1.1

## Step 2: Download devstack
On your XenServer host, run the following commands as root:

    wget --no-check-certificate https://github.com/openstack-dev/devstack/zipball/master
    unzip -o master -d ./devstack
    cd devstack/*/

## Step 3: Configure your localrc inside the devstack directory
Devstack uses a localrc for user-specific configuration.  Note that
the XENAPI_PASSWORD must be your dom0 root password.
Of course, use real passwords if this machine is exposed.

    cat > ./localrc <<EOF
    MYSQL_PASSWORD=my_super_secret
    SERVICE_TOKEN=my_super_secret
    ADMIN_PASSWORD=my_super_secret
    SERVICE_PASSWORD=my_super_secret
    RABBIT_PASSWORD=my_super_secret
    SWIFT_HASH="66a3d6b56c1f479c8b4e70ab5c2000f5"
    # This is the password for the OpenStack VM (for both stack and root users)
    GUEST_PASSWORD=my_super_secret

    # XenAPI parameters
    # IMPORTANT: The following must be set to your dom0 root password!
    XENAPI_PASSWORD=my_xenserver_root_password
    XENAPI_CONNECTION_URL="http://address_of_your_xenserver"
    VNCSERVER_PROXYCLIENT_ADDRESS=address_of_your_xenserver

    # Do not download the usual images yet!
    IMAGE_URLS=""
    # Explicitly set virt driver here
    VIRT_DRIVER=xenserver
    # Explicitly set multi-host
    MULTI_HOST=1
    # Give extra time for boot
    ACTIVE_TIMEOUT=45
    # Host Interface, i.e. the interface on the nova vm you want to expose the
    # services on. Usually eth2 (management network) or eth3 (public network) and
    # not eth0 (private network with XenServer host) or eth1 (VM traffic network)
    # The default is eth3.
    # HOST_IP_IFACE=eth3

    # Settings for netinstalling Ubuntu
    # UBUNTU_INST_RELEASE=precise

    # First time Ubuntu network install params
    # UBUNTU_INST_IFACE="eth3"
    # UBUNTU_INST_IP="dhcp"
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
