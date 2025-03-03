=====================
 DevStack Networking
=====================

An important part of the DevStack experience is networking that works
by default for created guests. This might not be optimal for your
particular testing environment, so this document tries its best to
explain what's going on.

Defaults
========

If you don't specify any configuration you will get the following:

* neutron (including l3 with openvswitch)
* private project networks for each openstack project
* a floating ip range of 172.24.4.0/24 with the gateway of 172.24.4.1
* the demo project configured with fixed ips on a subnet allocated from
  the 10.0.0.0/22 range
* a ``br-ex`` interface controlled by neutron for all its networking
  (this is not connected to any physical interfaces).
* DNS resolution for guests based on the resolv.conf for your host
* an ip masq rule that allows created guests to route out

This creates an environment which is isolated to the single
host. Guests can get to the external network for package
updates. Tempest tests will work in this environment.

.. note::

   By default all OpenStack environments have security group rules
   which block all inbound packets to guests. If you want to be able
   to ssh / ping your created guests you should run the following.

   .. code-block:: bash

      openstack security group rule create --proto icmp --dst-port 0 default
      openstack security group rule create --proto tcp --dst-port 22 default

Locally Accessible Guests
=========================

If you want to make your guests accessible from other machines on your
network, we have to connect ``br-ex`` to a physical interface.

Dedicated Guest Interface
-------------------------

If you have 2 or more interfaces on your devstack server, you can
allocate an interface to neutron to fully manage. This **should not**
be the same interface you use to ssh into the devstack server itself.

This is done by setting with the ``PUBLIC_INTERFACE`` attribute.

.. code-block:: bash

   [[local|localrc]]
   PUBLIC_INTERFACE=eth1

That will put all layer 2 traffic from your guests onto the main
network. When running in this mode the ip masq rule is **not** added
in your devstack, you are responsible for making routing work on your
local network.

Shared Guest Interface
----------------------

.. warning::

   This is not a recommended configuration. Because of interactions
   between OVS and bridging, if you reboot your box with active
   networking you may lose network connectivity to your system.

If you need your guests accessible on the network, but only have 1
interface (using something like a NUC), you can share your one
network. But in order for this to work you need to manually set a lot
of addresses, and have them all exactly correct.

.. code-block:: bash

   [[local|localrc]]
   PUBLIC_INTERFACE=eth0
   HOST_IP=10.42.0.52
   FLOATING_RANGE=10.42.0.0/24
   PUBLIC_NETWORK_GATEWAY=10.42.0.1
   Q_FLOATING_ALLOCATION_POOL=start=10.42.0.250,end=10.42.0.254

In order for this scenario to work the floating ip network must match
the default networking on your server. This breaks HOST_IP detection,
as we exclude the floating range by default, so you have to specify
that manually.

The ``PUBLIC_NETWORK_GATEWAY`` is the gateway that server would normally
use to get off the network. ``Q_FLOATING_ALLOCATION_POOL`` controls
the range of floating ips that will be handed out. As we are sharing
your existing network, you'll want to give it a slice that your local
dhcp server is not allocating. Otherwise you could easily have
conflicting ip addresses, and cause havoc with your local network.


Private Network Addressing
==========================

The private networks addresses are controlled by the ``IPV4_ADDRS_SAFE_TO_USE``
and the ``IPV6_ADDRS_SAFE_TO_USE`` variables. This allows users to specify one
single variable of safe internal IPs to use that will be referenced whether or
not subnetpools are in use.

For IPv4, ``FIXED_RANGE`` and ``SUBNETPOOL_PREFIX_V4`` will just default to
the value of ``IPV4_ADDRS_SAFE_TO_USE`` directly.

For IPv6, ``FIXED_RANGE_V6`` will default to the first /64 of the value of
``IPV6_ADDRS_SAFE_TO_USE``. If ``IPV6_ADDRS_SAFE_TO_USE`` is /64 or smaller,
``FIXED_RANGE_V6`` will just use the value of that directly.
``SUBNETPOOL_PREFIX_V6`` will just default to the value of
``IPV6_ADDRS_SAFE_TO_USE`` directly.

.. _ssh:

SSH access to instances
=======================

To validate connectivity, you can create an instance using the
``$PRIVATE_NETWORK_NAME`` network (default: ``private``), create a floating IP
using the ``$PUBLIC_NETWORK_NAME`` network (default: ``public``), and attach
this floating IP to the instance:

.. code-block:: shell

    openstack keypair create --public-key ~/.ssh/id_rsa.pub test-keypair
    openstack server create --network private --key-name test-keypair ... test-server
    fip_id=$(openstack floating ip create public -f value -c id)
    openstack server add floating ip test-server ${fip_id}

Once done, ensure you have enabled SSH and ICMP (ping) access for the security
group used for the instance. You can either create a custom security group and
specify it when creating the instance or add it after creation, or you can
modify the ``default`` security group created by default for each project.
Let's do the latter:

.. code-block:: shell

    openstack security group rule create --proto icmp --dst-port 0 default
    openstack security group rule create --proto tcp --dst-port 22 default

Finally, SSH into the instance. If you used the Cirros instance uploaded by
default, then you can run the following:

.. code-block:: shell

    openstack server ssh test-server -- -l cirros

This will connect using the ``cirros`` user and the keypair you configured when
creating the instance.

Remote SSH access to instances
==============================

You can also SSH to created instances on your DevStack host from other hosts.
This can be helpful if you are e.g. deploying DevStack in a VM on an existing
cloud and wish to do development on your local machine. There are a few ways to
do this.

.. rubric:: Configure instances to be locally accessible

The most obvious way is to configure guests to be locally accessible, as
described `above <Locally Accessible Guests>`__. This has the advantage of
requiring no further effort on the client. However, it is more involved and
requires either support from your cloud or some inadvisable workarounds.

.. rubric:: Use your DevStack host as a jump host

You can choose to use your DevStack host as a jump host. To SSH to a instance
this way, pass the standard ``-J`` option to the ``openstack ssh`` / ``ssh``
command. For example:

.. code-block::

    openstack server ssh test-server -- -l cirros -J username@devstack-host

(where ``test-server`` is name of an existing instance, as described
:ref:`previously <ssh>`, and ``username`` and ``devstack-host`` are the
username and hostname of your DevStack host).

This can also be configured via your ``~/.ssh/config`` file, making it rather
effortless. However, it only allows SSH access. If you want to access e.g. a
web application on the instance, you will need to configure an SSH tunnel and
forward select ports using the ``-L`` option. For example, to forward HTTP
traffic:

.. code-block::

    openstack server ssh test-server -- -l cirros -L 8080:username@devstack-host:80

(where ``test-server`` is name of an existing instance, as described
:ref:`previously <ssh>`, and ``username`` and ``devstack-host`` are the
username and hostname of your DevStack host).

As you can imagine, this can quickly get out of hand, particularly for more
complex guest applications with multiple ports.

.. rubric:: Use a proxy or VPN tool

You can use a proxy or VPN tool to enable tunneling for the floating IP
address range of the ``$PUBLIC_NETWORK_NAME`` network (default: ``public``)
defined by ``$FLOATING_RANGE`` (default: ``172.24.4.0/24``). There are many
such tools available to do this. For example, we could use a useful utility
called `shuttle`__. To enable tunneling using ``shuttle``, first ensure you
have allowed SSH and HTTP(S) traffic to your DevStack host. Allowing HTTP(S)
traffic is necessary so you can use the OpenStack APIs remotely. How you do
this will depend on where your DevStack host is running. Once this is done,
install ``sshuttle`` on your localhost:

.. code-block:: bash

    sudo apt-get install sshuttle || dnf install sshuttle

Finally, start ``sshuttle`` on your localhost using the floating IP address
range. For example, assuming you are using the default value for
``$FLOATING_RANGE``, you can do:

.. code-block:: bash

    sshuttle -r username@devstack-host 172.24.4.0/24

(where ``username`` and ``devstack-host`` are the username and hostname of your
DevStack host).

You should now be able to create an instance and SSH into it:

.. code-block:: bash

    openstack server ssh test-server -- -l cirros

(where ``test-server`` is name of an existing instance, as described
:ref:`previously <ssh>`)

.. __: https://github.com/sshuttle/sshuttle
