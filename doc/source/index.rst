.. Documentation Architecture for the devstack docs.

   It is really easy for online docs to meander over time as people
   attempt to add the small bit of additional information they think
   people need, into an existing information architecture. In order to
   prevent that we need to be a bit strict as to what's on this front
   page.

   This should *only* be the quick start narrative. Which should end
   with 2 sections: what you can do with devstack once it's set up,
   and how to go beyond this setup. Both should be a set of quick
   links to other documents to let people explore from there.

==========
 DevStack
==========

.. image:: assets/images/logo-blue.png

DevStack is a series of extensible scripts used to quickly bring up a
complete OpenStack environment based on the latest versions of
everything from git master.  It is used interactively as a development
environment and as the basis for much of the OpenStack project's
functional testing.

The source is available at
`<https://git.openstack.org/cgit/openstack-dev/devstack>`__.

.. warning::

   DevStack will make substantial changes to your system during
   installation. Only run DevStack on servers or virtual machines that
   are dedicated to this purpose.

Quick Start
===========

Install Linux
-------------

Start with a clean and minimal install of a Linux system. Devstack
attempts to support Ubuntu 16.04/17.04, Fedora 24/25, CentOS/RHEL 7,
as well as Debian and OpenSUSE.

If you do not have a preference, Ubuntu 16.04 is the most tested, and
will probably go the smoothest.

Add Stack User
--------------

Devstack should be run as a non-root user with sudo enabled
(standard logins to cloud images such as "ubuntu" or "cloud-user"
are usually fine).

You can quickly create a separate `stack` user to run DevStack with

::

   $ sudo useradd -s /bin/bash -d /opt/stack -m stack

Since this user will be making many changes to your system, it should
have sudo privileges:

::

    $ echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack
    $ sudo su - stack

Download DevStack
-----------------

::

   $ git clone https://git.openstack.org/openstack-dev/devstack
   $ cd devstack

The ``devstack`` repo contains a script that installs OpenStack and
templates for configuration files

Create a local.conf
-------------------

Create a ``local.conf`` file with 4 passwords preset at the root of the
devstack git repo.
::

   [[local|localrc]]
   ADMIN_PASSWORD=secret
   DATABASE_PASSWORD=$ADMIN_PASSWORD
   RABBIT_PASSWORD=$ADMIN_PASSWORD
   SERVICE_PASSWORD=$ADMIN_PASSWORD

This is the minimum required config to get started with DevStack.

Start the install
-----------------

::

   ./stack.sh

This will take a 15 - 20 minutes, largely depending on the speed of
your internet connection. Many git trees and packages will be
installed during this process.

Profit!
-------

You now have a working DevStack! Congrats!

Your devstack will have installed ``keystone``, ``glance``, ``nova``,
``cinder``, ``neutron``, and ``horizon``. Floating IPs will be
available, guests have access to the external world.

You can access horizon to experience the web interface to
OpenStack, and manage vms, networks, volumes, and images from
there.

You can ``source openrc`` in your shell, and then use the
``openstack`` command line tool to manage your devstack.

You can ``cd /opt/stack/tempest`` and run tempest tests that have
been configured to work with your devstack.

You can :doc:`make code changes to OpenStack and validate them
<development>`.

Going further
-------------

Learn more about our :doc:`configuration system <configuration>` to
customize devstack for your needs. Including making adjustments to the
default :doc:`networking <networking>`.

Read :doc:`guides <guides>` for specific setups people have (note:
guides are point in time contributions, and may not always be kept
up to date to the latest devstack).

Enable :doc:`devstack plugins <plugins>` to support additional
services, features, and configuration not present in base devstack.

Get :doc:`the big picture <overview>` of what we are trying to do
with devstack, and help us by :doc:`contributing to the project
<hacking>`.

Contents
--------

.. toctree::
   :glob:
   :maxdepth: 2

   *
