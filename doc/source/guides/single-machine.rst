=========================
All-In-One Single Machine
=========================

Things are about to get real! Using OpenStack in containers or VMs is
nice for kicking the tires, but doesn't compare to the feeling you get
with hardware.

Prerequisites Linux & Network
=============================

Minimal Install
---------------

You need to have a system with a fresh install of Linux. You can
download the `Minimal
CD <https://help.ubuntu.com/community/Installation/MinimalCD>`__ for
Ubuntu releases since DevStack will download & install all the
additional dependencies. The netinstall ISO is available for
`Fedora <http://mirrors.kernel.org/fedora/releases/>`__
and
`CentOS/RHEL <http://mirrors.kernel.org/centos/>`__.
You may be tempted to use a desktop distro on a laptop, it will probably
work but you may need to tell Network Manager to keep its fingers off
the interface(s) that OpenStack uses for bridging.

Network Configuration
---------------------

Determine the network configuration on the interface used to integrate
your OpenStack cloud with your existing network. For example, if the IPs
given out on your network by DHCP are 192.168.1.X - where X is between
100 and 200 you will be able to use IPs 201-254 for **floating ips**.

To make things easier later change your host to use a static IP instead
of DHCP (i.e. 192.168.1.201).

Installation shake and bake
===========================

Add your user
-------------

We need to add a user to install DevStack. (if you created a user during
install you can skip this step and just give the user sudo privileges
below)

.. code-block:: console

    $ sudo useradd -s /bin/bash -d /opt/stack -m stack

Ensure home directory for the ``stack`` user has executable permission for all,
as RHEL based distros create it with ``700`` and Ubuntu 21.04+ with ``750``
which can cause issues during deployment.

.. code-block:: console

    $ sudo chmod +x /opt/stack

Since this user will be making many changes to your system, it will need
to have sudo privileges:

.. code-block:: console

    $ apt-get install sudo -y || yum install -y sudo
    $ echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack

.. note:: On some systems you may need to use ``sudo visudo``.

From here on you should use the user you created. **Logout** and
**login** as that user:

.. code-block:: console

    $ sudo su stack && cd ~

Download DevStack
-----------------

We'll grab the latest version of DevStack via https:

.. code-block:: console

    $ sudo apt-get install git -y || sudo yum install -y git
    $ git clone https://opendev.org/openstack/devstack
    $ cd devstack

Run DevStack
------------

Now to configure ``stack.sh``. DevStack includes a sample in
``devstack/samples/local.conf``. Create ``local.conf`` as shown below to
do the following:

-  Set ``FLOATING_RANGE`` to a range not used on the local network, i.e.
   192.168.1.224/27. This configures IP addresses ending in 225-254 to
   be used as floating IPs.
-  Set ``FIXED_RANGE`` to configure the internal address space used by the
   instances.
-  Set the administrative password. This password is used for the
   **admin** and **demo** accounts set up as OpenStack users.
-  Set the MySQL administrative password. The default here is a random
   hex string which is inconvenient if you need to look at the database
   directly for anything.
-  Set the RabbitMQ password.
-  Set the service password. This is used by the OpenStack services
   (Nova, Glance, etc) to authenticate with Keystone.

.. warning:: Only use alphanumeric characters in your passwords, as some
   services fail to work when using special characters.

``local.conf`` should look something like this:

.. code-block:: ini

    [[local|localrc]]
    FLOATING_RANGE=192.168.1.224/27
    FIXED_RANGE=10.11.12.0/24
    ADMIN_PASSWORD=supersecret
    DATABASE_PASSWORD=iheartdatabases
    RABBIT_PASSWORD=flopsymopsy
    SERVICE_PASSWORD=iheartksl

.. note:: There is a sample :download:`local.conf </assets/local.conf>` file
    under the *samples* directory in the devstack repository.

Run DevStack:

.. code-block:: console

    $ ./stack.sh

A seemingly endless stream of activity ensues. When complete you will
see a summary of ``stack.sh``'s work, including the relevant URLs,
accounts and passwords to poke at your shiny new OpenStack.

Using OpenStack
---------------

At this point you should be able to access the dashboard from other
computers on the local network. In this example that would be
http://192.168.1.201/ for the dashboard (aka Horizon). Launch VMs and if
you give them floating IPs and security group access those VMs will be
accessible from other machines on your network.
