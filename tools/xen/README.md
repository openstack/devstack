Getting Started With XenServer 5.6 and Devstack
===============================================
The purpose of the code in this directory it to help developers bootstrap
a XenServer 5.6 + Openstack development environment.  This file gives
some pointers on how to get started.

Xenserver is a Type 1 hypervisor, so it needs to be installed on bare metal.
The Openstack services are configured to run within a "privileged" virtual
machine on the Xenserver host (called OS domU). The VM uses the XAPI toolstack
to communicate with the host.

Step 1: Install Xenserver
------------------------
Install XenServer 5.6+ on a clean box. You can get XenServer by signing
up for an account on citrix.com, and then visiting:
https://www.citrix.com/English/ss/downloads/details.asp?downloadId=2311504&productId=683148

For details on installation, see: http://wiki.openstack.org/XenServer/Install

Here are some sample Xenserver network settings for when you are just
getting started (I use settings like this with a lappy + cheap wifi router):

* XenServer Host IP: 192.168.1.10
* XenServer Netmask: 255.255.255.0
* XenServer Gateway: 192.168.1.1
* XenServer DNS: 192.168.1.1

Note:
------
It is advisable (and necessary if you are using Xenserver 6.0, due to space
limitations), to create the above mentioned OS domU, on a separate dev machine.
To do this, you will need to run Steps 2 on the dev machine (if required) as
well as the Xenserver host. Steps 3 and 4 should be run on the dev machine.
This process requires you to be root on the dev machine.

Step 2: Prepare DOM0
-------------------
At this point, your host is missing some critical software that you will
need to run devstack (like git).  Do this to install required software:

    wget --no-check-certificate https://raw.github.com/openstack-dev/devstack/master/tools/xen/prepare_dom0.sh
    chmod 755 prepare_dom0.sh
    ./prepare_dom0.sh

This step will also clone devstack in $DEVSTACKSRCROOT/devstack.
$DEVSTACKSRCROOT=/root by default.

Step 3: Configure your localrc
-----------------------------
Devstack uses a localrc for user-specific configuration.  Note that
the XENAPI_PASSWORD must be your dom0 root password.
Of course, use real passwords if this machine is exposed.

    cat > $DEVSTACKSRCROOT/devstack/localrc <<EOF
    MYSQL_PASSWORD=my_super_secret
    SERVICE_TOKEN=my_super_secret
    ADMIN_PASSWORD=my_super_secret
    RABBIT_PASSWORD=my_super_secret
    # This is the password for your guest (for both stack and root users)
    GUEST_PASSWORD=my_super_secret
    # IMPORTANT: The following must be set to your dom0 root password!
    XENAPI_PASSWORD=my_super_secret
    # Do not download the usual images yet!
    IMAGE_URLS=""
    # Explicitly set virt driver here
    VIRT_DRIVER=xenserver
    # Explicitly set multi-host
    MULTI_HOST=1
    # Give extra time for boot
    ACTIVE_TIMEOUT=45
    # Interface on which you would like to access services
    HOST_IP_IFACE=ethX
    EOF

Step 4: Run ./build_xva.sh
--------------------------
This script prepares your nova xva image. If you run this on a different machine,
copy the resulting xva file to tools/xen/xvas/[GUEST_NAME].xva
(by default tools/xen/xvas/ALLINONE.xva) on the Xenserver host.

cd $DEVSTACKSRCROOT/devstack/tools/xen
./build_xva.sh

You will also need to copy your localrc to the Xenserver host.

Step 5: Run ./build_domU.sh
--------------------------
This script does a lot of stuff, it is probably best to read it in its entirety.
But in a nutshell, it performs the following:

* Configures bridges and vlans for public, private, and management nets
* Creates and installs a OpenStack all-in-one domU in an HA-FlatDHCP configuration
* A script to create a multi-domU (ie. head node separated from compute) configuration is coming soon!

cd $DEVSTACKSRCROOT/devstack/tools/xen
./build_domU.sh

Step 6: Do cloudy stuff!
--------------------------
* Play with horizon
* Play with the CLI
* Log bugs to devstack and core projects, and submit fixes!
