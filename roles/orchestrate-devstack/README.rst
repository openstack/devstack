Orchestrate a devstack

Runs devstack in a multinode scenario, with one controller node
and a group of subnodes.

The reason for this role is so that jobs in other repository may
run devstack in their plays with no need for re-implementing the
orchestration logic.

The "run-devstack" role is available to run devstack with no
orchestration.

This role sets up the controller and CA first, it then pushes CA
data to sub-nodes and run devstack there. The only requirement for
this role is for the controller inventory_hostname to be "controller"
and for all sub-nodes to be defined in a group called "subnode".

This role needs to be invoked from a playbook that uses a "linear" strategy.

**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory.
