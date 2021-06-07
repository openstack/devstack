Verify the IPv6-only deployments

This role needs to be invoked from a playbook that
run tests. This role verifies the IPv6 setting on
devstack side and devstack deploy services on IPv6.
This role is invoked before tests are run so that
if any missing IPv6 setting or deployments can fail
the job early.


**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory.
