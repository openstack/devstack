Set up the devstack log directory

Create a log directory on the ephemeral disk partition to save space
on the root device.

**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory.
