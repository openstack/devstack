Guides
======

.. warning::

   The guides are point in time contributions, and may not always be
   up to date with the latest work in devstack.

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
   guides/devstack-with-ldap

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

Deploying DevStack with LDAP
----------------------------

Guide to setting up :doc:`DevStack with LDAP <guides/devstack-with-ldap>`.
