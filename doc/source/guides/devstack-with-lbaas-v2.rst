Configure Load-Balancer Version 2
=================================

Starting in the OpenStack Liberty release, the
`neutron LBaaS v2 API <https://developer.openstack.org/api-ref/network/v2/index.html>`_
is now stable while the LBaaS v1 API has been deprecated.  The LBaaS v2 reference
driver is based on Octavia.


Phase 1: Create DevStack + 2 nova instances
--------------------------------------------

First, set up a vm of your choice with at least 8 GB RAM and 16 GB disk space,
make sure it is updated. Install git and any other developer tools you find useful.

Install devstack

::

    git clone https://git.openstack.org/openstack-dev/devstack
    cd devstack


Edit your ``local.conf`` to look like

::

    [[local|localrc]]
    # Load the external LBaaS plugin.
    enable_plugin neutron-lbaas https://git.openstack.org/openstack/neutron-lbaas
    enable_plugin octavia https://git.openstack.org/openstack/octavia

    # ===== BEGIN localrc =====
    DATABASE_PASSWORD=password
    ADMIN_PASSWORD=password
    SERVICE_PASSWORD=password
    RABBIT_PASSWORD=password
    # Enable Logging
    LOGFILE=$DEST/logs/stack.sh.log
    VERBOSE=True
    LOG_COLOR=True
    # Pre-requisite
    ENABLED_SERVICES=rabbit,mysql,key
    # Horizon
    ENABLED_SERVICES+=,horizon
    # Nova
    ENABLED_SERVICES+=,n-api,n-cpu,n-cond,n-sch
    # Glance
    ENABLED_SERVICES+=,g-api,g-reg
    # Neutron
    ENABLED_SERVICES+=,q-svc,q-agt,q-dhcp,q-l3,q-meta
    # Enable LBaaS v2
    ENABLED_SERVICES+=,q-lbaasv2
    ENABLED_SERVICES+=,octavia,o-cw,o-hk,o-hm,o-api
    # Cinder
    ENABLED_SERVICES+=,c-api,c-vol,c-sch
    # Tempest
    ENABLED_SERVICES+=,tempest
    # ===== END localrc =====

Run stack.sh and do some sanity checks

::

    ./stack.sh
    . ./openrc

    openstack network list  # should show public and private networks

Create two nova instances that we can use as test http servers:

::

    #create nova instances on private network
    nova boot --image $(nova image-list | awk '/ cirros-.*-x86_64-uec / {print $2}') --flavor 1 --nic net-id=$(openstack network list | awk '/ private / {print $2}') node1
    nova boot --image $(nova image-list | awk '/ cirros-.*-x86_64-uec / {print $2}') --flavor 1 --nic net-id=$(openstack network list | awk '/ private / {print $2}') node2
    nova list # should show the nova instances just created

    #add secgroup rules to allow ssh etc..
    openstack security group rule create default --protocol icmp
    openstack security group rule create default --protocol tcp --dst-port 22:22
    openstack security group rule create default --protocol tcp --dst-port 80:80

Set up a simple web server on each of these instances. ssh into each instance (username 'cirros', password 'cubswin:)') and run

::

    MYIP=$(ifconfig eth0|grep 'inet addr'|awk -F: '{print $2}'| awk '{print $1}')
    while true; do echo -e "HTTP/1.0 200 OK\r\n\r\nWelcome to $MYIP" | sudo nc -l -p 80 ; done&

Phase 2: Create your load balancers
------------------------------------

::

    neutron lbaas-loadbalancer-create --name lb1 private-subnet
    neutron lbaas-loadbalancer-show lb1  # Wait for the provisioning_status to be ACTIVE.
    neutron lbaas-listener-create --loadbalancer lb1 --protocol HTTP --protocol-port 80 --name listener1
    sleep 10  # Sleep since LBaaS actions can take a few seconds depending on the environment.
    neutron lbaas-pool-create --lb-algorithm ROUND_ROBIN --listener listener1 --protocol HTTP --name pool1
    sleep 10
    neutron lbaas-member-create  --subnet private-subnet --address 10.0.0.3 --protocol-port 80 pool1
    sleep 10
    neutron lbaas-member-create  --subnet private-subnet --address 10.0.0.5 --protocol-port 80 pool1

Please note here that the "10.0.0.3" and "10.0.0.5" in the above commands are the IPs of the nodes
(in my test run-thru, they were actually 10.2 and 10.4), and the address of the created LB will be
reported as "vip_address" from the lbaas-loadbalancer-create, and a quick test of that LB is
"curl that-lb-ip", which should alternate between showing the IPs of the two nodes.
