Getting Started With XenServer 5.6 and Devstack
===============================================
The purpose of the code in this directory it to help developers bootstrap
a XenServer 5.6 + Openstack development environment.  This file gives
some pointers on how to get started.

Install Xenserver
-----------------
Install XenServer 5.6 on a clean box.
Here are some sample Xenserver network settings for when you are just
getting started (I used settings like this using a lappy + cheap wifi router):

* XenServer Host IP: 192.168.1.10
* XenServer Netmask: 255.255.255.0
* XenServer Gateway: 192.168.1.1
* XenServer DNS: 192.168.1.1

Prepare DOM0
------------
At this point, your server is missing some critical software that you will
need to run devstack (like git).  Do this to install required software:

    ./prepare_dom0.sh 

This script will also clone devstack in /root/devstack

Configure your localrc
----------------------
Devstack uses a localrc for user-specific configuration.  Note that while
the first 4 passwords are arbitrary, the XENAPI_PASSWORD must be your dom0
root password.  And of course, use a real password if this machine is exposed.

    cd /root/devstack
    
    cat > /root/devstack/localrc <<EOF
    MYSQL_PASSWORD=my_super_secret
    SERVICE_TOKEN=my_super_secret
    ADMIN_PASSWORD=my_super_secret
    RABBIT_PASSWORD=my_super_secret
    # IMPORTANT: The following must be set to your dom0 root password!
    XENAPI_PASSWORD=my_super_secret
    EOF

Run ./build_domU.sh
------------------
This script does a lot of stuff, it is probably best to read it in its entirety.
But in a nutshell, it performs the following:

* Configures bridges and vlans for public, private, and management nets
* Creates XVAs for a HEAD and COMPUTE host
* Launches those 2 instances into an HA FlatDHCP Configuration
