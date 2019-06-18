================================
All-In-One Single LXC Container
================================

This guide walks you through the process of deploying OpenStack using devstack
in an LXC container instead of a VM.

The primary benefits to running devstack inside a container instead of a VM is
faster performance and lower memory overhead while still providing a suitable
level of isolation. This can be particularly useful when you want to simulate
running OpenStack on multiple nodes.

.. Warning:: Containers do not provide the same level of isolation as a virtual
   machine.

.. Note:: Not all OpenStack features support running inside of a container. See
   `Limitations`_ section below for details. :doc:`OpenStack in a VM <single-vm>`
   is recommended for beginners.

Prerequisites
==============

This guide is written for Ubuntu 14.04 but should be adaptable for any modern
Linux distribution.

Install the LXC package::

   sudo apt-get install lxc

You can verify support for containerization features in your currently running
kernel using the ``lxc-checkconfig`` command.

Container Setup
===============

Configuration
---------------

For a successful run of ``stack.sh`` and to permit use of KVM to run the VMs you
launch inside your container, we need to use the following additional
configuration options. Place the following in a file called
``devstack-lxc.conf``::

  # Permit access to /dev/loop*
  lxc.cgroup.devices.allow = b 7:* rwm
  
  # Setup access to /dev/net/tun and /dev/kvm
  lxc.mount.entry = /dev/net/tun dev/net/tun none bind,create=file 0 0
  lxc.mount.entry = /dev/kvm dev/kvm none bind,create=file 0 0
  
  # Networking
  lxc.network.type = veth
  lxc.network.flags = up
  lxc.network.link = lxcbr0


Create Container
-------------------

The configuration and rootfs for LXC containers are created using the
``lxc-create`` command.

We will name our container ``devstack`` and use the ``ubuntu`` template which
will use ``debootstrap`` to build a Ubuntu rootfs. It will default to the same
release and architecture as the host system. We also install the additional
packages ``bsdmainutils`` and ``git`` as we'll need them to run devstack::

  sudo lxc-create -n devstack -t ubuntu -f devstack-lxc.conf -- --packages=bsdmainutils,git

The first time it builds the rootfs will take a few minutes to download, unpack,
and configure all the necessary packages for a minimal installation of Ubuntu.
LXC will cache this and subsequent containers will only take seconds to create.

.. Note:: To speed up the initial rootfs creation, you can specify a mirror to
   download the Ubuntu packages from by appending ``--mirror=`` and then the URL
   of a Ubuntu mirror. To see other other template options, you can run
   ``lxc-create -t ubuntu -h``.

Start Container
----------------

To start the container, run::

  sudo lxc-start -n devstack

A moment later you should be presented with the login prompt for your container.
You can login using the username ``ubuntu`` and password ``ubuntu``.

You can also ssh into your container. On your host, run
``sudo lxc-info -n devstack`` to get the IP address (e.g. 
``ssh ubuntu@$(sudo lxc-info -n devstack | awk '/IP/ { print $2 }')``).

Run Devstack
-------------

You should now be logged into your container and almost ready to run devstack.
The commands in this section should all be run inside your container.

.. Tip:: You can greatly reduce the runtime of your initial devstack setup by
   ensuring you have your apt sources.list configured to use a fast mirror.
   Check and update ``/etc/apt/sources.list`` if necessary and then run 
   ``apt-get update``.

#. Download DevStack

   ::

       git clone https://opendev.org/openstack/devstack

#. Configure

   Refer to :ref:`minimal-configuration` if you wish to configure the behaviour
   of devstack.

#. Start the install

   ::

       cd devstack
       ./stack.sh

Cleanup
-------

To stop the container::

  lxc-stop -n devstack

To delete the container::

  lxc-destroy -n devstack

Limitations
============

Not all OpenStack features may function correctly or at all when ran from within
a container.

Cinder
-------

Unable to create LVM backed volume
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  In our configuration, we have not whitelisted access to device-mapper or LVM
  devices. Doing so will permit your container to have access and control of LVM
  on the host system. To enable, add the following to your
  ``devstack-lxc.conf`` before running ``lxc-create``::

    lxc.cgroup.devices.allow = c 10:236 rwm
    lxc.cgroup.devices.allow = b 252:* rwm

  Additionally you'll need to set ``udev_rules = 0`` in the ``activation``
  section of ``/etc/lvm/lvm.conf`` unless you mount devtmpfs in your container.

Unable to attach volume to instance
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  It is not possible to attach cinder volumes to nova instances due to parts of
  the Linux iSCSI implementation not being network namespace aware. This can be
  worked around by using network pass-through instead of a separate network
  namespace but such a setup significantly reduces the isolation of the
  container (e.g. a ``halt`` command issued in the container will cause the host
  system to shutdown).
