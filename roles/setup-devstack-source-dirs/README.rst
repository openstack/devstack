Set up the devstack source directories

Ensure that the base directory exists, and then move the source repos
into it.

**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory.

.. zuul:rolevar:: devstack_sources_branch
   :default: None

   The target branch to be setup (where available).
