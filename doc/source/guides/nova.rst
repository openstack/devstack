=================
Nova and DevStack
=================

This is a rough guide to various configuration parameters for nova
running with DevStack.


nova-serialproxy
================

In Juno, nova implemented a `spec
<https://specs.openstack.org/openstack/nova-specs/specs/juno/implemented/serial-ports.html>`_
to allow read/write access to the serial console of an instance via
`nova-serialproxy
<https://docs.openstack.org/nova/latest/cli/nova-serialproxy.html>`_.

The service can be enabled by adding ``n-sproxy`` to
``ENABLED_SERVICES``.  Further options can be enabled via
``local.conf``, e.g.

::

    [[post-config|$NOVA_CONF]]
    [serial_console]
    #
    # Options defined in nova.cmd.serialproxy
    #

    # Host on which to listen for incoming requests (string value)
    #serialproxy_host=0.0.0.0

    # Port on which to listen for incoming requests (integer
    # value)
    #serialproxy_port=6083


    #
    # Options defined in nova.console.serial
    #

    # Enable serial console related features (boolean value)
    #enabled=false
    # Do not set this manually.  Instead enable the service as
    # outlined above.

    # Range of TCP ports to use for serial ports on compute hosts
    # (string value)
    #port_range=10000:20000

    # Location of serial console proxy. (string value)
    #base_url=ws://127.0.0.1:6083/

    # IP address on which instance serial console should listen
    # (string value)
    #listen=127.0.0.1

    # The address to which proxy clients (like nova-serialproxy)
    # should connect (string value)
    #proxyclient_address=127.0.0.1


Enabling the service is enough to be functional for a single machine DevStack.

These config options are defined in `nova.conf.serial_console
<https://opendev.org/openstack/nova/src/master/nova/conf/serial_console.py>`_.

For more information on OpenStack configuration see the `OpenStack
Compute Service Configuration Reference
<https://docs.openstack.org/nova/latest/admin/configuration/index.html>`_


Fake virt driver
================

Nova has a `fake virt driver`_ which can be used for scale testing the control
plane services or testing "move" operations between fake compute nodes, for
example cold/live migration, evacuate and unshelve.

The fake virt driver does not communicate with any hypervisor, it just reports
some fake resource inventory values and keeps track of the state of the
"guests" created, moved and deleted. It is not feature-complete with the
compute API but is good enough for most API testing, and is also used within
the nova functional tests themselves so is fairly robust.

.. _fake virt driver: https://opendev.org/openstack/nova/src/branch/master/nova/virt/fake.py

Configuration
-------------

Set the following in your devstack ``local.conf``:

.. code-block:: ini

  [[local|localrc]]
  VIRT_DRIVER=fake
  NUMBER_FAKE_NOVA_COMPUTE=<number>

The ``NUMBER_FAKE_NOVA_COMPUTE`` variable controls the number of fake
``nova-compute`` services to run and defaults to 1.

When ``VIRT_DRIVER=fake`` is used, devstack will disable quota checking in
nova and neutron automatically. However, other services, like cinder, will
still enforce quota limits by default.

Scaling
-------

The actual value to use for ``NUMBER_FAKE_NOVA_COMPUTE`` depends on factors
such as:

* The size of the host (physical or virtualized) on which devstack is running.
* The number of API workers. By default, devstack will run ``max($nproc/2, 2)``
  workers per API service. If you are running several fake compute services on
  a single host, then consider setting ``API_WORKERS=1`` in ``local.conf``.

In addition, while quota will be disabled in neutron, there is no fake ML2
backend for neutron so creating fake VMs will still result in real ports being
created. To create servers without networking, you can specify ``--nic=none``
when creating the server, for example:

.. code-block:: shell

  $ openstack --os-compute-api-version 2.37 server create --flavor cirros256 \
      --image cirros-0.6.1-x86_64-disk --nic none --wait test-server

.. note:: ``--os-compute-api-version`` greater than or equal to 2.37 is
          required to use ``--nic=none``.

To avoid overhead from other services which you may not need, disable them in
your ``local.conf``, for example:

.. code-block:: ini

  disable_service horizon
  disable_service tempest
