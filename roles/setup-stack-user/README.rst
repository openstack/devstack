Set up the `stack` user

Create the stack user, set up its home directory, and allow it to
sudo.

**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory.

.. zuul:rolevar:: devstack_stack_home_dir
   :default: {{ devstack_base_dir }}

   The home directory for the stack user.
