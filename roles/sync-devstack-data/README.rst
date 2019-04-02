Sync devstack data for multinode configurations

Sync any data files which include certificates to be used if TLS is enabled.
This role must be executed on the controller and it pushes data to all
subnodes.

**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory.

.. zuul:rolevar:: devstack_data_base_dir
   :default: {{ devstack_base_dir }}

   The devstack base directory for data/.
   Useful for example when multiple executions of devstack (i.e. grenade)
   share the same data directory.
