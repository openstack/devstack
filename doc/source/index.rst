DevStack - an OpenStack Community Production
============================================

.. image:: assets/images/logo-blue.png

.. toctree::
   :glob:
   :maxdepth: 1

   overview
   configuration
   plugins
   plugin-registry
   faq
   changes
   hacking

Quick Start
-----------

#. Select a Linux Distribution

   Only Ubuntu 14.04 (Trusty), Fedora 21 (or Fedora 22) and CentOS/RHEL
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

Recent Changes
--------------

:doc:`An incomplete summary of recent changes <changes>`

FAQ
---

:doc:`The DevStack FAQ <faq>`

Contributing
------------

:doc:`Pitching in to make DevStack a better place <hacking>`

Code
====

*A look at the bits that make it all go*

Scripts
-------

* `stack.sh <stack.sh.html>`__ - The main script
* `functions <functions.html>`__ - DevStack-specific functions
* `functions-common <functions-common.html>`__ - Functions shared with other projects
* `lib/apache <lib/apache.html>`__
* `lib/ceilometer <lib/ceilometer.html>`__
* `lib/ceph <lib/ceph.html>`__
* `lib/cinder <lib/cinder.html>`__
* `lib/database <lib/database.html>`__
* `lib/dstat <lib/dstat.html>`__
* `lib/glance <lib/glance.html>`__
* `lib/heat <lib/heat.html>`__
* `lib/horizon <lib/horizon.html>`__
* `lib/infra <lib/infra.html>`__
* `lib/ironic <lib/ironic.html>`__
* `lib/keystone <lib/keystone.html>`__
* `lib/ldap <lib/ldap.html>`__
* `lib/neutron-legacy <lib/neutron-legacy.html>`__
* `lib/nova <lib/nova.html>`__
* `lib/oslo <lib/oslo.html>`__
* `lib/rpc\_backend <lib/rpc_backend.html>`__
* `lib/swift <lib/swift.html>`__
* `lib/tempest <lib/tempest.html>`__
* `lib/tls <lib/tls.html>`__
* `lib/zaqar <lib/zaqar.html>`__
* `unstack.sh <unstack.sh.html>`__
* `clean.sh <clean.sh.html>`__
* `run\_tests.sh <run_tests.sh.html>`__

* `extras.d/50-ironic.sh <extras.d/50-ironic.sh.html>`__
* `extras.d/60-ceph.sh <extras.d/60-ceph.sh.html>`__
* `extras.d/70-tuskar.sh <extras.d/70-tuskar.sh.html>`__
* `extras.d/70-zaqar.sh <extras.d/70-zaqar.sh.html>`__
* `extras.d/80-tempest.sh <extras.d/80-tempest.sh.html>`__

* `inc/ini-config <inc/ini-config.html>`__
* `inc/meta-config <inc/meta-config.html>`__
* `inc/python <inc/python.html>`__

* `pkg/elasticsearch.sh <pkg/elasticsearch.sh.html>`_

Configuration
-------------

.. toctree::
   :glob:
   :maxdepth: 1

   local.conf
   stackrc
   openrc
   exerciserc
   eucarc

Tools
-----

* `tools/build\_docs.sh <tools/build_docs.sh.html>`__
* `tools/build\_venv.sh <tools/build_venv.sh.html>`__
* `tools/build\_wheels.sh <tools/build_wheels.sh.html>`__
* `tools/create-stack-user.sh <tools/create-stack-user.sh.html>`__
* `tools/create\_userrc.sh <tools/create_userrc.sh.html>`__
* `tools/fixup\_stuff.sh <tools/fixup_stuff.sh.html>`__
* `tools/info.sh <tools/info.sh.html>`__
* `tools/install\_pip.sh <tools/install_pip.sh.html>`__
* `tools/install\_prereqs.sh <tools/install_prereqs.sh.html>`__
* `tools/make\_cert.sh <tools/make_cert.sh.html>`__
* `tools/upload\_image.sh <tools/upload_image.sh.html>`__

Samples
-------

* `local.sh <samples/local.sh.html>`__

Exercises
---------

* `exercise.sh <exercise.sh.html>`__
* `exercises/aggregates.sh <exercises/aggregates.sh.html>`__
* `exercises/boot\_from\_volume.sh <exercises/boot_from_volume.sh.html>`__
* `exercises/bundle.sh <exercises/bundle.sh.html>`__
* `exercises/client-args.sh <exercises/client-args.sh.html>`__
* `exercises/client-env.sh <exercises/client-env.sh.html>`__
* `exercises/euca.sh <exercises/euca.sh.html>`__
* `exercises/floating\_ips.sh <exercises/floating_ips.sh.html>`__
* `exercises/horizon.sh <exercises/horizon.sh.html>`__
* `exercises/neutron-adv-test.sh <exercises/neutron-adv-test.sh.html>`__
* `exercises/sec\_groups.sh <exercises/sec_groups.sh.html>`__
* `exercises/swift.sh <exercises/swift.sh.html>`__
* `exercises/volumes.sh <exercises/volumes.sh.html>`__
* `exercises/zaqar.sh <exercises/zaqar.sh.html>`__
