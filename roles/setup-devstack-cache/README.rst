Set up the devstack cache directory

If the node has a cache of devstack image files, copy it into place.

**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory.

.. zuul:rolevar:: devstack_cache_dir
   :default: /opt/cache

   The directory with the cached files.
