Getting Started With XenServer 5.6 and Devstack
===============================================
The purpose of the code in this directory it to help developers bootstrap
a XenServer 5.6 + Openstack development environment.  This file gives
some pointers on how to get started.

Step 1: Install Xenserver
------------------------
Install XenServer 5.6 on a clean box. You can get XenServer by signing
up for an account on citrix.com, and then visiting:
https://www.citrix.com/English/ss/downloads/details.asp?downloadId=2311504&productId=683148

Here are some sample Xenserver network settings for when you are just
getting started (I use settings like this with a lappy + cheap wifi router):

* XenServer Host IP: 192.168.1.10
* XenServer Netmask: 255.255.255.0
* XenServer Gateway: 192.168.1.1
* XenServer DNS: 192.168.1.1

Step 2: Prepare DOM0
-------------------
At this point, your server is missing some critical software that you will
need to run devstack (like git).  Do this to install required software:

    wget --no-check-certificate https://github.com/cloudbuilders/devstack/raw/xen/tools/xen/prepare_dom0.sh
    chmod 755 prepare_dom0.sh
    ./prepare_dom0.sh 

This script will also clone devstack in /root/devstack

Step 3: Configure your localrc
-----------------------------
Devstack uses a localrc for user-specific configuration.  Note that 
the XENAPI_PASSWORD must be your dom0 root password.
Of course, use real passwords if this machine is exposed.

    cat > /root/devstack/localrc <<EOF
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
    EOF

Step 4: Run ./build_domU.sh
--------------------------
This script does a lot of stuff, it is probably best to read it in its entirety.
But in a nutshell, it performs the following:

* Configures bridges and vlans for public, private, and management nets
* Creates and installs a OpenStack all-in-one domU in an HA-FlatDHCP configuration
* A script to create a multi-domU (ie. head node separated from compute) configuration is coming soon!

Step 5: Do cloudy stuff!
--------------------------
* Play with dashboard
* Play with the CLI
* Log bugs to devstack and core projects, and submit fixes!
