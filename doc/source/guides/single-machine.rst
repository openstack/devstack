`DevStack </>`__

-  `Overview <../overview.html>`__
-  `Changes <../changes.html>`__
-  `FAQ <../faq.html>`__
-  `git.openstack.org <https://git.openstack.org/cgit/openstack-dev/devstack>`__
-  `Gerrit <https://review.openstack.org/#/q/status:open+project:openstack-dev/devstack,n,z>`__

All-In-One: Dedicated Hardware
==============================

Things are about to get real! Using OpenStack in containers or VMs is
nice for kicking the tires, but doesn't compare to the feeling you get
with hardware.

Prerequisites Linux & Network
-----------------------------

Minimal Install
~~~~~~~~~~~~~~~

You need to have a system with a fresh install of Linux. You can
download the `Minimal
CD <https://help.ubuntu.com/community/Installation/MinimalCD>`__ for
Ubuntu releases since DevStack will download & install all the
additional dependencies. The netinstall ISO is available for
`Fedora <http://mirrors.kernel.org/fedora/releases/18/Fedora/x86_64/iso/Fedora-20-x86_64-netinst.iso>`__
and
`CentOS/RHEL <http://mirrors.kernel.org/centos/6.5/isos/x86_64/CentOS-6.5-x86_64-netinstall.iso>`__.
You may be tempted to use a desktop distro on a laptop, it will probably
work but you may need to tell Network Manager to keep its fingers off
the interface(s) that OpenStack uses for bridging.

Network Configuration
~~~~~~~~~~~~~~~~~~~~~

Determine the network configuration on the interface used to integrate
your OpenStack cloud with your existing network. For example, if the IPs
given out on your network by DHCP are 192.168.1.X - where X is between
100 and 200 you will be able to use IPs 201-254 for **floating ips**.

To make things easier later change your host to use a static IP instead
of DHCP (i.e. 192.168.1.201).

Installation shake and bake
---------------------------

Add your user
~~~~~~~~~~~~~

We need to add a user to install DevStack. (if you created a user during
install you can skip this step and just give the user sudo privileges
below)

::

    adduser stack

Since this user will be making many changes to your system, it will need
to have sudo privileges:

::

    apt-get install sudo -y || yum install -y sudo
    echo "stack ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

From here on you should use the user you created. **Logout** and
**login** as that user.

Download DevStack
~~~~~~~~~~~~~~~~~

We'll grab the latest version of DevStack via https:

::

    sudo apt-get install git -y || yum install -y git
    git clone https://git.openstack.org/openstack-dev/devstack
    cd devstack

Run DevStack
~~~~~~~~~~~~

Now to configure ``stack.sh``. DevStack includes a sample in
``devstack/samples/local.conf``. Create ``local.conf`` as shown below to
do the following:

-  Set ``FLOATING_RANGE`` to a range not used on the local network, i.e.
   192.168.1.224/27. This configures IP addresses ending in 225-254 to
   be used as floating IPs.
-  Set ``FIXED_RANGE`` and ``FIXED_NETWORK_SIZE`` to configure the
   internal address space used by the instances.
-  Set ``FLAT_INTERFACE`` to the Ethernet interface that connects the
   host to your local network. This is the interface that should be
   configured with the static IP address mentioned above.
-  Set the administrative password. This password is used for the
   **admin** and **demo** accounts set up as OpenStack users.
-  Set the MySQL administrative password. The default here is a random
   hex string which is inconvenient if you need to look at the database
   directly for anything.
-  Set the RabbitMQ password.
-  Set the service password. This is used by the OpenStack services
   (Nova, Glance, etc) to authenticate with Keystone.

``local.conf`` should look something like this:

::

    [[local|localrc]]
    FLOATING_RANGE=192.168.1.224/27
    FIXED_RANGE=10.11.12.0/24
    FIXED_NETWORK_SIZE=256
    FLAT_INTERFACE=eth0
    ADMIN_PASSWORD=supersecret
    MYSQL_PASSWORD=iheartdatabases
    RABBIT_PASSWORD=flopsymopsy
    SERVICE_PASSWORD=iheartksl

Run DevStack:

::

    ./stack.sh

A seemingly endless stream of activity ensues. When complete you will
see a summary of ``stack.sh``'s work, including the relevant URLs,
accounts and passwords to poke at your shiny new OpenStack.

Using OpenStack
~~~~~~~~~~~~~~~

At this point you should be able to access the dashboard from other
computers on the local network. In this example that would be
http://192.168.1.201/ for the dashboard (aka Horizon). Launch VMs and if
you give them floating IPs and security group access those VMs will be
accessible from other machines on your network.

Some examples of using the OpenStack command-line clients ``nova`` and
``glance`` are in the shakedown scripts in ``devstack/exercises``.
``exercise.sh`` will run all of those scripts and report on the results.

© Openstack Foundation 2011-2013 — An `OpenStack
program <https://wiki.openstack.org/wiki/Programs>`__ created by
`Rackspace Cloud
Builders <http://www.rackspace.com/cloud/private_edition/>`__
