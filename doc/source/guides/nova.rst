=================
Nova and DevStack
=================

This is a rough guide to various configuration parameters for nova
running with DevStack.


nova-serialproxy
================

In Juno, nova implemented a `spec
<http://specs.openstack.org/openstack/nova-specs/specs/juno/implemented/serial-ports.html>`_
to allow read/write access to the serial console of an instance via
`nova-serialproxy
<http://docs.openstack.org/developer/nova/man/nova-serialproxy.html>`_.

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

These config options are defined in `nova.console.serial
<https://github.com/openstack/nova/blob/master/nova/console/serial.py#L33-L52>`_
and `nova.cmd.serialproxy
<https://github.com/openstack/nova/blob/master/nova/cmd/serialproxy.py#L26-L33>`_.

For more information on OpenStack configuration see the `OpenStack
Configuration Reference
<http://docs.openstack.org/trunk/config-reference/content/list-of-compute-config-options.html>`_
