==============
Multi-Node Lab
==============

Here is OpenStack in a realistic test configuration with multiple
physical servers.

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

Install a couple of packages to bootstrap configuration:

::

    apt-get install -y git sudo || yum install -y git sudo

Network Configuration
---------------------

The first iteration of the lab uses OpenStack's FlatDHCP network
controller so only a single network will be required. It should be on
its own subnet without DHCP; the host IPs and floating IP pool(s) will
come out of this block. This example uses the following:

-  Gateway: 192.168.42.1
-  Physical nodes: 192.168.42.11-192.168.42.99
-  Floating IPs: 192.168.42.128-192.168.42.254

Configure each node with a static IP. For Ubuntu edit
``/etc/network/interfaces``:

::

    auto eth0
    iface eth0 inet static
        address 192.168.42.11
        netmask 255.255.255.0
        gateway 192.168.42.1

For Fedora and CentOS/RHEL edit
``/etc/sysconfig/network-scripts/ifcfg-eth0``:

::

    BOOTPROTO=static
    IPADDR=192.168.42.11
    NETMASK=255.255.255.0
    GATEWAY=192.168.42.1

Installation shake and bake
===========================

Add the DevStack User
---------------------

OpenStack runs as a non-root user that has sudo access to root. There is
nothing special about the name, we'll use ``stack`` here. Every node
must use the same name and preferably uid. If you created a user during
the OS install you can use it and give it sudo privileges below.
Otherwise create the stack user:

::

    useradd -s /bin/bash -d /opt/stack -m stack

Ensure home directory for the ``stack`` user has executable permission for all,
as RHEL based distros create it with ``700`` and Ubuntu 21.04+ with ``750``
which can cause issues during deployment.

::

    chmod +x /opt/stack

This user will be making many changes to your system during installation
and operation so it needs to have sudo privileges to root without a
password:

::

    echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack

From here on use the ``stack`` user. **Logout** and **login** as the
``stack`` user.

Set Up Ssh
----------

Set up the stack user on each node with an ssh key for access:

::

    mkdir ~/.ssh; chmod 700 ~/.ssh
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCyYjfgyPazTvGpd8OaAvtU2utL8W6gWC4JdRS1J95GhNNfQd657yO6s1AH5KYQWktcE6FO/xNUC2reEXSGC7ezy+sGO1kj9Limv5vrvNHvF1+wts0Cmyx61D2nQw35/Qz8BvpdJANL7VwP/cFI/p3yhvx2lsnjFE3hN8xRB2LtLUopUSVdBwACOVUmH2G+2BWMJDjVINd2DPqRIA4Zhy09KJ3O1Joabr0XpQL0yt/I9x8BVHdAx6l9U0tMg9dj5+tAjZvMAFfye3PJcYwwsfJoFxC8w/SLtqlFX7Ehw++8RtvomvuipLdmWCy+T9hIkl+gHYE4cS3OIqXH7f49jdJf jesse@spacey.local" > ~/.ssh/authorized_keys

Download DevStack
-----------------

Grab the latest version of DevStack:

::

    git clone https://opendev.org/openstack/devstack
    cd devstack

Up to this point all of the steps apply to each node in the cluster.
From here on there are some differences between the cluster controller
(aka 'head node') and the compute nodes.

Configure Cluster Controller
----------------------------

The cluster controller runs all OpenStack services. Configure the
cluster controller's DevStack in ``local.conf``:

::

    [[local|localrc]]
    HOST_IP=192.168.42.11
    FIXED_RANGE=10.4.128.0/20
    FLOATING_RANGE=192.168.42.128/25
    LOGFILE=/opt/stack/logs/stack.sh.log
    ADMIN_PASSWORD=labstack
    DATABASE_PASSWORD=supersecret
    RABBIT_PASSWORD=supersecret
    SERVICE_PASSWORD=supersecret

In the multi-node configuration the first 10 or so IPs in the private
subnet are usually reserved. Add this to ``local.sh`` to have it run
after every ``stack.sh`` run:

::

    for i in `seq 2 10`; do /opt/stack/nova/bin/nova-manage fixed reserve 10.4.128.$i; done

Fire up OpenStack:

::

    ./stack.sh

A stream of activity ensues. When complete you will see a summary of
``stack.sh``'s work, including the relevant URLs, accounts and passwords
to poke at your shiny new OpenStack. The most recent log file is
available in ``stack.sh.log``.

Configure Compute Nodes
-----------------------

The compute nodes only run the OpenStack worker services. For additional
machines, create a ``local.conf`` with:

::

    [[local|localrc]]
    HOST_IP=192.168.42.12 # change this per compute node
    FIXED_RANGE=10.4.128.0/20
    FLOATING_RANGE=192.168.42.128/25
    LOGFILE=/opt/stack/logs/stack.sh.log
    ADMIN_PASSWORD=labstack
    DATABASE_PASSWORD=supersecret
    RABBIT_PASSWORD=supersecret
    SERVICE_PASSWORD=supersecret
    DATABASE_TYPE=mysql
    SERVICE_HOST=192.168.42.11
    MYSQL_HOST=$SERVICE_HOST
    RABBIT_HOST=$SERVICE_HOST
    GLANCE_HOSTPORT=$SERVICE_HOST:9292
    ENABLED_SERVICES=n-cpu,c-vol,placement-client,ovn-controller,ovs-vswitchd,ovsdb-server,q-ovn-metadata-agent
    NOVA_VNC_ENABLED=True
    NOVNCPROXY_URL="http://$SERVICE_HOST:6080/vnc_lite.html"
    VNCSERVER_LISTEN=$HOST_IP
    VNCSERVER_PROXYCLIENT_ADDRESS=$VNCSERVER_LISTEN

Fire up OpenStack:

::

    ./stack.sh

A stream of activity ensues. When complete you will see a summary of
``stack.sh``'s work, including the relevant URLs, accounts and passwords
to poke at your shiny new OpenStack. The most recent log file is
available in ``stack.sh.log``.

Starting in the Ocata release, Nova requires a `Cells v2`_ deployment. Compute
node services must be mapped to a cell before they can be used.

After each compute node is stacked, verify it shows up in the
``nova service-list --binary nova-compute`` output. The compute service is
registered in the cell database asynchronously so this may require polling.

Once the compute node services shows up, run the ``./tools/discover_hosts.sh``
script from the control node to map compute hosts to the single cell.

The compute service running on the primary control node will be
discovered automatically when the control node is stacked so this really
only needs to be performed for subnodes.

.. _Cells v2: https://docs.openstack.org/nova/latest/user/cells.html

Cleaning Up After DevStack
--------------------------

Shutting down OpenStack is now as simple as running the included
``unstack.sh`` script:

::

    ./unstack.sh

A more aggressive cleanup can be performed using ``clean.sh``. It
removes certain troublesome packages and attempts to leave the system in
a state where changing the database or queue manager can be reliably
performed.

::

    ./clean.sh

Sometimes running instances are not cleaned up. DevStack attempts to do
this when it runs but there are times it needs to still be done by hand:

::

    sudo rm -rf /etc/libvirt/qemu/inst*
    sudo virsh list | grep inst | awk '{print $1}' | xargs -n1 virsh destroy

Going further
=============

Additional Users
----------------

DevStack creates two OpenStack users (``admin`` and ``demo``) and two
projects (also ``admin`` and ``demo``). ``admin`` is exactly what it
sounds like, a privileged administrative account that is a member of
both the ``admin`` and ``demo`` projects. ``demo`` is a normal user
account that is only a member of the ``demo`` project. Creating
additional OpenStack users can be done through the dashboard, sometimes
it is easier to do them in bulk from a script, especially since they get
blown away every time ``stack.sh`` runs. The following steps are ripe
for scripting:

::

    # Get admin creds
    . openrc admin admin

    # List existing projects
    openstack project list

    # List existing users
    openstack user list

    # Add a user and project
    NAME=bob
    PASSWORD=BigSecret
    PROJECT=$NAME
    openstack project create $PROJECT
    openstack user create $NAME --password=$PASSWORD --project $PROJECT
    openstack role add Member --user $NAME --project $PROJECT
    # The Member role is created by stack.sh
    # openstack role assignment list

Swift
-----

Swift, OpenStack Object Storage, requires a significant amount of resources
and is disabled by default in DevStack. The support in DevStack is geared
toward a minimal installation but can be used for testing. To implement a
true multi-node test of swift, additional steps will be required. Enabling it is as
simple as enabling the ``swift`` service in ``local.conf``:

::

    enable_service s-proxy s-object s-container s-account

Swift, OpenStack Object Storage, will put its data files in ``SWIFT_DATA_DIR`` (default
``/opt/stack/data/swift``). The size of the data 'partition' created
(really a loop-mounted file) is set by ``SWIFT_LOOPBACK_DISK_SIZE``. The
Swift config files are located in ``SWIFT_CONF_DIR`` (default
``/etc/swift``). All of these settings can be overridden in (wait for
it...) ``local.conf``.

Volumes
-------

DevStack will automatically use an existing LVM volume group named
``stack-volumes`` to store cloud-created volumes. If ``stack-volumes``
doesn't exist, DevStack will set up a loop-mounted file to contain
it.  If the default size is insufficient for the number and size of volumes
required, it can be overridden by setting ``VOLUME_BACKING_FILE_SIZE`` in
``local.conf`` (sizes given in ``truncate`` compatible format, e.g. ``24G``).

``stack-volumes`` can be pre-created on any physical volume supported by
Linux's LVM. The name of the volume group can be changed by setting
``VOLUME_GROUP_NAME`` in ``localrc``. ``stack.sh`` deletes all logical
volumes in ``VOLUME_GROUP_NAME`` that begin with ``VOLUME_NAME_PREFIX`` as
part of cleaning up from previous runs. It is recommended to not use the
root volume group as ``VOLUME_GROUP_NAME``.

The details of creating the volume group depends on the server hardware
involved but looks something like this:

::

    pvcreate /dev/sdc
    vgcreate stack-volumes /dev/sdc

Syslog
------

DevStack is capable of using ``rsyslog`` to aggregate logging across the
cluster. It is off by default; to turn it on set ``SYSLOG=True`` in
``local.conf``. ``SYSLOG_HOST`` defaults to ``HOST_IP``; on the compute
nodes it must be set to the IP of the cluster controller to send syslog
output there. In the example above, add this to the compute node
``local.conf``:

::

    SYSLOG_HOST=192.168.42.11

Using Alternate Repositories/Branches
-------------------------------------

The git repositories for all of the OpenStack services are defined in
``stackrc``. Since this file is a part of the DevStack package changes
to it will probably be overwritten as updates are applied. Every setting
in ``stackrc`` can be redefined in ``local.conf``.

To change the repository or branch that a particular OpenStack service
is created from, simply change the value of ``*_REPO`` or ``*_BRANCH``
corresponding to that service.

After making changes to the repository or branch, if ``RECLONE`` is not
set in ``localrc`` it may be necessary to remove the corresponding
directory from ``/opt/stack`` to force git to re-clone the repository.

For example, to pull nova, OpenStack Compute, from a proposed release candidate
in the primary nova repository:

::

    NOVA_BRANCH=rc-proposed

To pull glance, OpenStack Image service, from an experimental fork:

::

    GLANCE_BRANCH=try-something-big
    GLANCE_REPO=https://github.com/mcuser/glance.git

Notes stuff you might need to know
==================================

Set MySQL Password
------------------

If you forgot to set the root password you can do this:

::

    mysqladmin -u root -pnova password 'supersecret'

Live Migration
--------------

In order for live migration to work with the default live migration URI::

    [libvirt]
    live_migration_uri = qemu+ssh://stack@%s/system

SSH keys need to be exchanged between each compute node:

1. The SOURCE root user's public RSA key (likely in /root/.ssh/id_rsa.pub)
   needs to be in the DESTINATION stack user's authorized_keys file
   (~stack/.ssh/authorized_keys).  This can be accomplished by manually
   copying the contents from the file on the SOURCE to the DESTINATION.  If
   you have a password configured for the stack user, then you can use the
   following command to accomplish the same thing::

        ssh-copy-id -i /root/.ssh/id_rsa.pub stack@DESTINATION

2. The DESTINATION host's public ECDSA key (/etc/ssh/ssh_host_ecdsa_key.pub)
   needs to be in the SOURCE root user's known_hosts file
   (/root/.ssh/known_hosts).  This can be accomplished by running the
   following on the SOURCE machine (hostname must be used)::

        ssh-keyscan -H DEST_HOSTNAME | sudo tee -a /root/.ssh/known_hosts

3. Verify that login via ssh works without a password::

        ssh -i /root/.ssh/id_rsa stack@DESTINATION

In essence, this means that every compute node's root user's public RSA key
must exist in every other compute node's stack user's authorized_keys file and
every compute node's public ECDSA key needs to be in every other compute
node's root user's known_hosts file.  Please note that if the root or stack
user does not have a SSH key, one can be generated using::

    ssh-keygen -t rsa

The above steps are necessary because libvirtd runs as root when the
live_migration_uri uses the "qemu:///system" family of URIs.  For more
information, see the `libvirt documentation`_.

.. _libvirt documentation: https://libvirt.org/drvqemu.html#securitydriver
