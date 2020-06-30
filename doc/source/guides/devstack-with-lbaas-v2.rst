Devstack with Octavia Load Balancing
====================================

Starting with the OpenStack Pike release, Octavia is now a standalone service
providing load balancing services for OpenStack.

This guide will show you how to create a devstack with `Octavia API`_ enabled.

.. _Octavia API: https://docs.openstack.org/api-ref/load-balancer/v2/index.html

Phase 1: Create DevStack + 2 nova instances
--------------------------------------------

First, set up a vm of your choice with at least 8 GB RAM and 16 GB disk space,
make sure it is updated. Install git and any other developer tools you find
useful.

Install devstack

::

    git clone https://opendev.org/openstack/devstack
    cd devstack/tools
    sudo ./create-stack-user.sh
    cd ../..
    sudo mv devstack /opt/stack
    sudo chown -R stack.stack /opt/stack/devstack

This will clone the current devstack code locally, then setup the "stack"
account that devstack services will run under. Finally, it will move devstack
into its default location in /opt/stack/devstack.

Edit your ``/opt/stack/devstack/local.conf`` to look like

::

    [[local|localrc]]
    enable_plugin octavia https://opendev.org/openstack/octavia
    # If you are enabling horizon, include the octavia dashboard
    # enable_plugin octavia-dashboard https://opendev.org/openstack/octavia-dashboard.git
    # If you are enabling barbican for TLS offload in Octavia, include it here.
    # enable_plugin barbican https://opendev.org/openstack/barbican

    # ===== BEGIN localrc =====
    DATABASE_PASSWORD=password
    ADMIN_PASSWORD=password
    SERVICE_PASSWORD=password
    SERVICE_TOKEN=password
    RABBIT_PASSWORD=password
    # Enable Logging
    LOGFILE=$DEST/logs/stack.sh.log
    VERBOSE=True
    LOG_COLOR=True
    # Pre-requisite
    ENABLED_SERVICES=rabbit,mysql,key
    # Horizon - enable for the OpenStack web GUI
    # ENABLED_SERVICES+=,horizon
    # Nova
    ENABLED_SERVICES+=,n-api,n-crt,n-cpu,n-cond,n-sch,n-api-meta,n-sproxy
    ENABLED_SERVICES+=,placement-api,placement-client
    # Glance
    ENABLED_SERVICES+=,g-api
    # Neutron
    ENABLED_SERVICES+=,q-svc,q-agt,q-dhcp,q-l3,q-meta,neutron
    ENABLED_SERVICES+=,octavia,o-cw,o-hk,o-hm,o-api
    # Cinder
    ENABLED_SERVICES+=,c-api,c-vol,c-sch
    # Tempest
    ENABLED_SERVICES+=,tempest
    # Barbican - Optionally used for TLS offload in Octavia
    # ENABLED_SERVICES+=,barbican
    # ===== END localrc =====

Run stack.sh and do some sanity checks

::

    sudo su - stack
    cd /opt/stack/devstack
    ./stack.sh
    . ./openrc

    openstack network list  # should show public and private networks

Create two nova instances that we can use as test http servers:

::

    #create nova instances on private network
    openstack server create --image $(openstack image list | awk '/ cirros-.*-x86_64-.* / {print $2}') --flavor 1 --nic net-id=$(openstack network list | awk '/ private / {print $2}') node1
    openstack server create --image $(openstack image list | awk '/ cirros-.*-x86_64-.* / {print $2}') --flavor 1 --nic net-id=$(openstack network list | awk '/ private / {print $2}') node2
    openstack server list # should show the nova instances just created

    #add secgroup rules to allow ssh etc..
    openstack security group rule create default --protocol icmp
    openstack security group rule create default --protocol tcp --dst-port 22:22
    openstack security group rule create default --protocol tcp --dst-port 80:80

Set up a simple web server on each of these instances. ssh into each instance (username 'cirros', password 'cubswin:)' or 'gocubsgo') and run

::

    MYIP=$(ifconfig eth0|grep 'inet addr'|awk -F: '{print $2}'| awk '{print $1}')
    while true; do echo -e "HTTP/1.0 200 OK\r\n\r\nWelcome to $MYIP" | sudo nc -l -p 80 ; done&

Phase 2: Create your load balancer
----------------------------------

Make sure you have the 'openstack loadbalancer' commands:

::

    pip install python-octaviaclient

Create your load balancer:

::

    openstack loadbalancer create --name lb1 --vip-subnet-id private-subnet
    openstack loadbalancer show lb1  # Wait for the provisioning_status to be ACTIVE.
    openstack loadbalancer listener create --protocol HTTP --protocol-port 80 --name listener1 lb1
    openstack loadbalancer show lb1  # Wait for the provisioning_status to be ACTIVE.
    openstack loadbalancer pool create --lb-algorithm ROUND_ROBIN --listener listener1 --protocol HTTP --name pool1
    openstack loadbalancer show lb1  # Wait for the provisioning_status to be ACTIVE.
    openstack loadbalancer healthmonitor create --delay 5 --timeout 2 --max-retries 1 --type HTTP pool1
    openstack loadbalancer show lb1  # Wait for the provisioning_status to be ACTIVE.
    openstack loadbalancer member create --subnet-id private-subnet --address <web server 1 address> --protocol-port 80 pool1
    openstack loadbalancer show lb1  # Wait for the provisioning_status to be ACTIVE.
    openstack loadbalancer member create --subnet-id private-subnet --address <web server 2 address> --protocol-port 80 pool1

Please note: The <web server # address> fields are the IP addresses of the nova
servers created in Phase 1.
Also note, using the API directly you can do all of the above commands in one
API call.

Phase 3: Test your load balancer
--------------------------------

::

    openstack loadbalancer show lb1 # Note the vip_address
    curl http://<vip_address>
    curl http://<vip_address>

This should show the "Welcome to <IP>" message from each member server.
