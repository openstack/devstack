DevStack
========

.. image:: assets/images/logo-blue.png

DevStack is a series of extensible scripts used to quickly bring up a
complete OpenStack environment.  It is used interactively as a
development environment and as the basis for much of the OpenStack
project's functional testing.

The source is available at
`<https://git.openstack.org/cgit/openstack-dev/devstack>`__.

.. toctree::
   :glob:
   :maxdepth: 1

   overview
   configuration
   plugins
   plugin-registry
   faq
   hacking

Quick Start
-----------

#. Select a Linux Distribution

   Only Ubuntu 14.04 (Trusty), Fedora 22 (or Fedora 23) and CentOS/RHEL
   7 are documented here. OpenStack also runs and is packaged on other
   flavors of Linux such as OpenSUSE and Debian.

#. Install Selected OS

   In order to correctly install all the dependencies, we assume a
   specific minimal version of the supported distributions to make it as
   easy as possible. We recommend using a minimal install of Ubuntu or
   Fedora server in a VM if this is your first time.

#. Download DevStack

   ::

       git clone https://git.openstack.org/openstack-dev/devstack

   The ``devstack`` repo contains a script that installs OpenStack and
   templates for configuration files

#. Configure

   We recommend at least a :ref:`minimal-configuration` be set up.

#. Add Stack User

   Devstack should be run as a non-root user with sudo enabled
   (standard logins to cloud images such as "ubuntu" or "cloud-user"
   are usually fine).

   You can quickly create a separate `stack` user to run DevStack with

   ::

       devstack/tools/create-stack-user.sh; su stack

#. Start the install

   ::

       cd devstack; ./stack.sh

   It takes a few minutes, we recommend `reading the
   script <stack.sh.html>`__ while it is building.

Guides
======

Walk through various setups used by stackers

.. toctree::
   :glob:
   :maxdepth: 1

   guides/single-vm
   guides/single-machine
   guides/lxc
   guides/multinode-lab
   guides/neutron
   guides/devstack-with-nested-kvm
   guides/nova
   guides/devstack-with-lbaas-v2

All-In-One Single VM
--------------------

Run :doc:`OpenStack in a VM <guides/single-vm>`. The VMs launched in your cloud will be slow as
they are running in QEMU (emulation), but it is useful if you don't have
spare hardware laying around. :doc:`[Read] <guides/single-vm>`

All-In-One Single Machine
-------------------------

Run :doc:`OpenStack on dedicated hardware <guides/single-machine>`  This can include a
server-class machine or a laptop at home.
:doc:`[Read] <guides/single-machine>`

All-In-One LXC Container
-------------------------

Run :doc:`OpenStack in a LXC container <guides/lxc>`. Beneficial for intermediate
and advanced users. The VMs launched in this cloud will be fully accelerated but
not all OpenStack features are supported. :doc:`[Read] <guides/lxc>`

Multi-Node Lab
--------------

Setup a :doc:`multi-node cluster <guides/multinode-lab>` with dedicated VLANs for VMs & Management.
:doc:`[Read] <guides/multinode-lab>`

DevStack with Neutron Networking
--------------------------------

Building a DevStack cluster with :doc:`Neutron Networking <guides/neutron>`.
This guide is meant for building lab environments with a dedicated
control node and multiple compute nodes.

DevStack with KVM-based Nested Virtualization
---------------------------------------------

Procedure to setup :doc:`DevStack with KVM-based Nested Virtualization
<guides/devstack-with-nested-kvm>`. With this setup, Nova instances
will be more performant than with plain QEMU emulation.

Nova and devstack
--------------------------------

Guide to working with nova features :doc:`Nova and devstack <guides/nova>`.

DevStack Documentation
======================

Overview
--------

:doc:`An overview of DevStack goals and priorities <overview>`

Configuration
-------------

:doc:`Configuring and customizing the stack <configuration>`

Plugins
-------

:doc:`Extending DevStack with new features <plugins>`

FAQ
---

:doc:`The DevStack FAQ <faq>`

Contributing
------------

:doc:`Pitching in to make DevStack a better place <hacking>`

