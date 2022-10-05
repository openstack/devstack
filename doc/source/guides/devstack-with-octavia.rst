Devstack with Octavia Load Balancing
====================================

Starting with the OpenStack Pike release, Octavia is now a standalone service
providing load balancing services for OpenStack.

This guide will show you how to create a devstack with `Octavia API`_ enabled.

.. _Octavia API: https://docs.openstack.org/api-ref/load-balancer/v2/index.html

Phase 1: Create DevStack + 2 nova instances
--------------------------------------------

First, set up a VM of your choice with at least 8 GB RAM and 16 GB disk space,
make sure it is updated. Install git and any other developer tools you find
useful.

Install devstack::

    git clone https://opendev.org/openstack/devstack
    cd devstack/tools
    sudo ./create-stack-user.sh
    cd ../..
    sudo mv devstack /opt/stack
    sudo chown -R stack.stack /opt/stack/devstack

This will clone the current devstack code locally, then setup the "stack"
account that devstack services will run under. Finally, it will move devstack
into its default location in /opt/stack/devstack.

Edit your ``/opt/stack/devstack/local.conf`` to look like::

    [[local|localrc]]
    # ===== BEGIN localrc =====
    DATABASE_PASSWORD=password
    ADMIN_PASSWORD=password
    SERVICE_PASSWORD=password
    SERVICE_TOKEN=password
    RABBIT_PASSWORD=password
    GIT_BASE=https://opendev.org
    # Optional settings:
    # OCTAVIA_AMP_BASE_OS=centos
    # OCTAVIA_AMP_DISTRIBUTION_RELEASE_ID=9-stream
    # OCTAVIA_AMP_IMAGE_SIZE=3
    # OCTAVIA_LB_TOPOLOGY=ACTIVE_STANDBY
    # OCTAVIA_ENABLE_AMPHORAV2_JOBBOARD=True
    # LIBS_FROM_GIT+=octavia-lib,
    # Enable Logging
    LOGFILE=$DEST/logs/stack.sh.log
    VERBOSE=True
    LOG_COLOR=True
    enable_service rabbit
    enable_plugin neutron $GIT_BASE/openstack/neutron
    # Octavia supports using QoS policies on the VIP port:
    enable_service q-qos
    enable_service placement-api placement-client
    # Octavia services
    enable_plugin octavia $GIT_BASE/openstack/octavia master
    enable_plugin octavia-dashboard $GIT_BASE/openstack/octavia-dashboard
    enable_plugin ovn-octavia-provider $GIT_BASE/openstack/ovn-octavia-provider
    enable_plugin octavia-tempest-plugin $GIT_BASE/openstack/octavia-tempest-plugin
    enable_service octavia o-api o-cw o-hm o-hk o-da
    # If you are enabling barbican for TLS offload in Octavia, include it here.
    # enable_plugin barbican $GIT_BASE/openstack/barbican
    # enable_service barbican
    # Cinder (optional)
    disable_service c-api c-vol c-sch
    # Tempest
    enable_service tempest
    # ===== END localrc =====

.. note::
    For best performance it is highly recommended to use KVM
    virtualization instead of QEMU.
    Also make sure nested virtualization is enabled as documented in
    :ref:`the respective guide <kvm_nested_virt>`.
    By adding ``LIBVIRT_CPU_MODE="host-passthrough"`` to your
    ``local.conf`` you enable the guest VMs to make use of all features your
    host's CPU provides.

Run stack.sh and do some sanity checks::

    sudo su - stack
    cd /opt/stack/devstack
    ./stack.sh
    . ./openrc

    openstack network list  # should show public and private networks

Create two nova instances that we can use as test http servers::

    # create nova instances on private network
    openstack server create --image $(openstack image list | awk '/ cirros-.*-x86_64-.* / {print $2}') --flavor 1 --nic net-id=$(openstack network list | awk '/ private / {print $2}') node1
    openstack server create --image $(openstack image list | awk '/ cirros-.*-x86_64-.* / {print $2}') --flavor 1 --nic net-id=$(openstack network list | awk '/ private / {print $2}') node2
    openstack server list # should show the nova instances just created

    # add secgroup rules to allow ssh etc..
    openstack security group rule create default --protocol icmp
    openstack security group rule create default --protocol tcp --dst-port 22:22
    openstack security group rule create default --protocol tcp --dst-port 80:80

Set up a simple web server on each of these instances. One possibility is to use
the `Golang test server`_ that is used by the Octavia project for CI testing
as well.
Copy the binary to your instances and start it as shown below
(username 'cirros', password 'gocubsgo')::

    INST_IP=<instance IP>
    scp -O test_server.bin cirros@${INST_IP}:
    ssh -f cirros@${INST_IP} ./test_server.bin -id ${INST_IP}

When started this way the test server will respond to HTTP requests with
its own IP.

Phase 2: Create your load balancer
----------------------------------

Create your load balancer::

    openstack loadbalancer create --wait --name lb1 --vip-subnet-id private-subnet
    openstack loadbalancer listener create --wait --protocol HTTP --protocol-port 80 --name listener1 lb1
    openstack loadbalancer pool create --wait --lb-algorithm ROUND_ROBIN --listener listener1 --protocol HTTP --name pool1
    openstack loadbalancer healthmonitor create --wait --delay 5 --timeout 2 --max-retries 1 --type HTTP pool1
    openstack loadbalancer member create --wait --subnet-id private-subnet --address <web server 1 address> --protocol-port 80 pool1
    openstack loadbalancer member create --wait --subnet-id private-subnet --address <web server 2 address> --protocol-port 80 pool1

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


.. _Golang test server: https://opendev.org/openstack/octavia-tempest-plugin/src/branch/master/octavia_tempest_plugin/contrib/test_server
