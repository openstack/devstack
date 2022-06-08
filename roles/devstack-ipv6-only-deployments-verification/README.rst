Verify all addresses in IPv6-only deployments

This role needs to be invoked from a playbook that
runs tests. This role verifies the IPv6 settings on the
devstack side and that devstack deploys with all addresses
being IPv6. This role is invoked before tests are run so that
if there is any missing IPv6 setting, deployments can fail
the job early.


**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory.
