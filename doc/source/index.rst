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

DevStack
========

.. image:: assets/images/logo-blue.png

DevStack is a series of extensible scripts used to quickly bring up a
complete OpenStack environment based on the latest versions of
everything from git master.  It is used interactively as a development
environment and as the basis for much of the OpenStack project's
functional testing.

The source is available at `<https://opendev.org/openstack/devstack>`__.

.. warning::

   DevStack will make substantial changes to your system during
   installation. Only run DevStack on servers or virtual machines that
   are dedicated to this purpose.

Quick Start
+++++++++++

Install Linux
-------------

Start with a clean and minimal install of a Linux system. DevStack
attempts to support the two latest LTS releases of Ubuntu, the
latest/current Fedora version, CentOS/RHEL/Rocky Linux 9, OpenSUSE and
openEuler.

If you do not have a preference, Ubuntu 22.04 (Jammy) is the
most tested, and will probably go the smoothest.

Add Stack User (optional)
-------------------------

DevStack should be run as a non-root user with sudo enabled
(standard logins to cloud images such as "ubuntu" or "cloud-user"
are usually fine).

If you are not using a cloud image, you can create a separate `stack` user
to run DevStack with

.. code-block:: console

   $ sudo useradd -s /bin/bash -d /opt/stack -m stack

Ensure home directory for the ``stack`` user has executable permission for all,
as RHEL based distros create it with ``700`` and Ubuntu 21.04+ with ``750``
which can cause issues during deployment.

.. code-block:: console

    $ sudo chmod +x /opt/stack

Since this user will be making many changes to your system, it should
have sudo privileges:

.. code-block:: console

    $ echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack
    $ sudo -u stack -i

Download DevStack
-----------------

.. code-block:: console

   $ git clone https://opendev.org/openstack/devstack
   $ cd devstack

The ``devstack`` repo contains a script that installs OpenStack and
templates for configuration files.

Create a local.conf
-------------------

Create a ``local.conf`` file with four passwords preset at the root of the
devstack git repo.

.. code-block:: ini

   [[local|localrc]]
   ADMIN_PASSWORD=secret
   DATABASE_PASSWORD=$ADMIN_PASSWORD
   RABBIT_PASSWORD=$ADMIN_PASSWORD
   SERVICE_PASSWORD=$ADMIN_PASSWORD

This is the minimum required config to get started with DevStack.

.. note:: There is a sample :download:`local.conf </assets/local.conf>` file
   under the *samples* directory in the devstack repository.

.. warning:: Only use alphanumeric characters in your passwords, as some
   services fail to work when using special characters.

Start the install
-----------------

.. code-block:: console

   $ ./stack.sh

This will take a 15 - 20 minutes, largely depending on the speed of
your internet connection. Many git trees and packages will be
installed during this process.

Profit!
-------

You now have a working DevStack! Congrats!

Your devstack will have installed ``keystone``, ``glance``, ``nova``,
``placement``, ``cinder``, ``neutron``, and ``horizon``. Floating IPs
will be available, guests have access to the external world.

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

Use devstack in your CI with :doc:`Ansible roles <zuul_roles>` and
:doc:`Jobs <zuul_jobs>` for Zuul V3. Migrate your devstack Zuul V2 jobs to Zuul
V3 with this full migration :doc:`how-to <zuul_ci_jobs_migration>`.

Get :doc:`the big picture <overview>` of what we are trying to do
with devstack, and help us by :doc:`contributing to the project
<hacking>`.

If you are a new contributor to devstack please refer: :doc:`contributor/contributing`

.. toctree::
   :hidden:

   contributor/contributing

Contents
++++++++

.. toctree::
   :glob:
   :maxdepth: 2

   *
