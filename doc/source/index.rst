DevStack - an OpenStack Community Production
============================================

.. toctree::
   :glob:
   :maxdepth: 1

   overview
   configuration
   plugins
   faq
   changes
   contributing

   guides/*


Quick Start This ain't your first rodeo
---------------------------------------

#. Select a Linux Distribution

   Only Ubuntu 14.04 (Trusty), Fedora 20 and CentOS/RHEL 6.5 are
   documented here. OpenStack also runs and is packaged on other flavors
   of Linux such as OpenSUSE and Debian.

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

   We recommend at least a `minimal
   configuration <configuration.html>`__ be set up.

#. Start the install

   ::

       cd devstack; ./stack.sh

   It takes a few minutes, we recommend `reading the
   script <stack.sh.html>`__ while it is building.

Guides
======

Walk through various setups used by stackers

OpenStack on VMs
----------------

These guides tell you how to virtualize your OpenStack cloud in virtual
machines. This means that you can get started without having to purchase
any hardware.

Virtual Machine
~~~~~~~~~~~~~~~

`Run OpenStack in a VM <guides/single-vm.html>`__. The VMs launched in your cloud will be slow as
they are running in QEMU (emulation), but it is useful if you don't have
spare hardware laying around. `[Read] <guides/single-vm.html>`__

OpenStack on Hardware
---------------------

These guides tell you how to deploy a development environment on real
hardware. Guides range from running OpenStack on a single laptop to
running a multi-node deployment on datacenter hardware.

All-In-One
~~~~~~~~~~

`Run OpenStack on dedicated hardware <guides/single-machine.html>`__ to get real performance in your VMs.
This can include a server-class machine or a laptop at home. `[Read] <guides/single-machine.html>`__

Multi-Node + VLANs
~~~~~~~~~~~~~~~~~~

`Setup a multi-node cluster <guides/multinode-lab.html>`__ with dedicated VLANs for VMs & Management. `[Read] <guides/multinode-lab.html>`__

Documentation
=============

Overview
--------

`An overview of DevStack goals and priorities <overview.html>`__

Configuration
-------------

`Configuring and customizing the stack <configuration.html>`__

Plugins
-------

`Extending DevStack with new features <plugins.html>`__

Recent Changes
--------------

`An incomplete summary of recent changes <changes.html>`__

FAQ
---

`The DevStack FAQ <faq.html>`__

Contributing
------------

`Pitching in to make DevStack a better place <contributing.html>`__

Code
====

A look at the bits that make it all go

Scripts
-------

Generated documentation of DevStack scripts.

+-------------------------------+----------------------------------------------+
| Filename                      | Link                                         |
+===============================+==============================================+
| stack.sh                      | `Read » <stack.sh.html>`__                   |
+-------------------------------+----------------------------------------------+
| functions                     | `Read » <functions.html>`__                  |
+-------------------------------+----------------------------------------------+
| functions-common              | `Read » <functions-common.html>`__           |
+-------------------------------+----------------------------------------------+
| lib/apache                    | `Read » <lib/apache.html>`__                 |
+-------------------------------+----------------------------------------------+
| lib/baremetal                 | `Read » <lib/baremetal.html>`__              |
+-------------------------------+----------------------------------------------+
| lib/ceilometer                | `Read » <lib/ceilometer.html>`__             |
+-------------------------------+----------------------------------------------+
| lib/cinder                    | `Read » <lib/cinder.html>`__                 |
+-------------------------------+----------------------------------------------+
| lib/config                    | `Read » <lib/config.html>`__                 |
+-------------------------------+----------------------------------------------+
| lib/database                  | `Read » <lib/database.html>`__               |
+-------------------------------+----------------------------------------------+
| lib/glance                    | `Read » <lib/glance.html>`__                 |
+-------------------------------+----------------------------------------------+
| lib/heat                      | `Read » <lib/heat.html>`__                   |
+-------------------------------+----------------------------------------------+
| lib/horizon                   | `Read » <lib/horizon.html>`__                |
+-------------------------------+----------------------------------------------+
| lib/infra                     | `Read » <lib/infra.html>`__                  |
+-------------------------------+----------------------------------------------+
| lib/ironic                    | `Read » <lib/ironic.html>`__                 |
+-------------------------------+----------------------------------------------+
| lib/keystone                  | `Read » <lib/keystone.html>`__               |
+-------------------------------+----------------------------------------------+
| lib/ldap                      | `Read » <lib/ldap.html>`__                   |
+-------------------------------+----------------------------------------------+
| lib/zaqar                     | `Read » <lib/zaqar.html>`__                  |
+-------------------------------+----------------------------------------------+
| lib/neutron                   | `Read » <lib/neutron.html>`__                |
+-------------------------------+----------------------------------------------+
| lib/nova                      | `Read » <lib/nova.html>`__                   |
+-------------------------------+----------------------------------------------+
| lib/oslo                      | `Read » <lib/oslo.html>`__                   |
+-------------------------------+----------------------------------------------+
| lib/rpc\_backend              | `Read » <lib/rpc_backend.html>`__            |
+-------------------------------+----------------------------------------------+
| lib/sahara                    | `Read » <lib/sahara.html>`__                 |
+-------------------------------+----------------------------------------------+
| lib/savanna                   | `Read » <lib/savanna.html>`__                |
+-------------------------------+----------------------------------------------+
| lib/stackforge                | `Read » <lib/stackforge.html>`__             |
+-------------------------------+----------------------------------------------+
| lib/swift                     | `Read » <lib/swift.html>`__                  |
+-------------------------------+----------------------------------------------+
| lib/tempest                   | `Read » <lib/tempest.html>`__                |
+-------------------------------+----------------------------------------------+
| lib/tls                       | `Read » <lib/tls.html>`__                    |
+-------------------------------+----------------------------------------------+
| lib/trove                     | `Read » <lib/trove.html>`__                  |
+-------------------------------+----------------------------------------------+
| unstack.sh                    | `Read » <unstack.sh.html>`__                 |
+-------------------------------+----------------------------------------------+
| clean.sh                      | `Read » <clean.sh.html>`__                   |
+-------------------------------+----------------------------------------------+
| run\_tests.sh                 | `Read » <run_tests.sh.html>`__               |
+-------------------------------+----------------------------------------------+
| extras.d/50-ironic.sh         | `Read » <extras.d/50-ironic.html>`__         |
+-------------------------------+----------------------------------------------+
| extras.d/70-zaqar.sh          | `Read » <extras.d/70-zaqar.html>`__          |
+-------------------------------+----------------------------------------------+
| extras.d/70-sahara.sh         | `Read » <extras.d/70-sahara.html>`__         |
+-------------------------------+----------------------------------------------+
| extras.d/70-savanna.sh        | `Read » <extras.d/70-savanna.html>`__        |
+-------------------------------+----------------------------------------------+
| extras.d/70-trove.sh          | `Read » <extras.d/70-trove.html>`__          |
+-------------------------------+----------------------------------------------+
| extras.d/80-opendaylight.sh   | `Read » <extras.d/80-opendaylight.html>`__   |
+-------------------------------+----------------------------------------------+
| extras.d/80-tempest.sh        | `Read » <extras.d/80-tempest.html>`__        |
+-------------------------------+----------------------------------------------+

Configuration
-------------

+--------------+--------------------------------+
| Filename     | Link                           |
+==============+================================+
| local.conf   | `Read » <local.conf.html>`__   |
+--------------+--------------------------------+
| stackrc      | `Read » <stackrc.html>`__      |
+--------------+--------------------------------+
| openrc       | `Read » <openrc.html>`__       |
+--------------+--------------------------------+
| exerciserc   | `Read » <exerciserc.html>`__   |
+--------------+--------------------------------+
| eucarc       | `Read » <eucarc.html>`__       |
+--------------+--------------------------------+

Tools
-----

+-----------------------------+----------------------------------------------+
| Filename                    | Link                                         |
+=============================+==============================================+
| tools/info.sh               | `Read » <tools/info.sh.html>`__              |
+-----------------------------+----------------------------------------------+
| tools/build\_docs.sh        | `Read » <tools/build_docs.sh.html>`__        |
+-----------------------------+----------------------------------------------+
| tools/create\_userrc.sh     | `Read » <tools/create_userrc.sh.html>`__     |
+-----------------------------+----------------------------------------------+
| tools/fixup\_stuff.sh       | `Read » <tools/fixup_stuff.sh.html>`__       |
+-----------------------------+----------------------------------------------+
| tools/install\_prereqs.sh   | `Read » <tools/install_prereqs.sh.html>`__   |
+-----------------------------+----------------------------------------------+
| tools/install\_pip.sh       | `Read » <tools/install_pip.sh.html>`__       |
+-----------------------------+----------------------------------------------+
| tools/upload\_image.sh      | `Read » <tools/upload_image.sh.html>`__      |
+-----------------------------+----------------------------------------------+

Samples
-------

Generated documentation of DevStack sample files.

+------------+--------------------------------------+
| Filename   | Link                                 |
+============+======================================+
| local.sh   | `Read » <samples/local.sh.html>`__   |
+------------+--------------------------------------+
| localrc    | `Read » <samples/localrc.html>`__    |
+------------+--------------------------------------+

Exercises
---------

+---------------------------------+-------------------------------------------------+
| Filename                        | Link                                            |
+=================================+=================================================+
| exercise.sh                     | `Read » <exercise.sh.html>`__                   |
+---------------------------------+-------------------------------------------------+
| exercises/aggregates.sh         | `Read » <exercises/aggregates.sh.html>`__       |
+---------------------------------+-------------------------------------------------+
| exercises/boot\_from\_volume.sh | `Read » <exercises/boot_from_volume.sh.html>`__ |
+---------------------------------+-------------------------------------------------+
| exercises/bundle.sh             | `Read » <exercises/bundle.sh.html>`__           |
+---------------------------------+-------------------------------------------------+
| exercises/client-args.sh        | `Read » <exercises/client-args.sh.html>`__      |
+---------------------------------+-------------------------------------------------+
| exercises/client-env.sh         | `Read » <exercises/client-env.sh.html>`__       |
+---------------------------------+-------------------------------------------------+
| exercises/euca.sh               | `Read » <exercises/euca.sh.html>`__             |
+---------------------------------+-------------------------------------------------+
| exercises/floating\_ips.sh      | `Read » <exercises/floating_ips.sh.html>`__     |
+---------------------------------+-------------------------------------------------+
| exercises/horizon.sh            | `Read » <exercises/horizon.sh.html>`__          |
+---------------------------------+-------------------------------------------------+
| exercises/neutron-adv-test.sh   | `Read » <exercises/neutron-adv-test.sh.html>`__ |
+---------------------------------+-------------------------------------------------+
| exercises/sahara.sh             | `Read » <exercises/sahara.sh.html>`__           |
+---------------------------------+-------------------------------------------------+
| exercises/savanna.sh            | `Read » <exercises/savanna.sh.html>`__          |
+---------------------------------+-------------------------------------------------+
| exercises/sec\_groups.sh        | `Read » <exercises/sec_groups.sh.html>`__       |
+---------------------------------+-------------------------------------------------+
| exercises/swift.sh              | `Read » <exercises/swift.sh.html>`__            |
+---------------------------------+-------------------------------------------------+
| exercises/trove.sh              | `Read » <exercises/trove.sh.html>`__            |
+---------------------------------+-------------------------------------------------+
| exercises/volumes.sh            | `Read » <exercises/volumes.sh.html>`__          |
+---------------------------------+-------------------------------------------------+
| exercises/zaqar.sh              | `Read » <exercises/zaqar.sh.html>`__            |
+---------------------------------+-------------------------------------------------+

.. toctree::
   :glob:
   :maxdepth: 1

   *
