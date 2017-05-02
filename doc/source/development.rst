==========================
 Developing with Devstack
==========================

Now that you have your nifty DevStack up and running, what can you do
with it?

Inspecting Services
===================

By default most services in DevStack are running as `systemd` units
named `devstack@$servicename.service`. You can see running services
with.

.. code-block:: bash

   sudo systemctl status --unit="devstack@*"

To learn more about the basics of systemd, see :doc:`/systemd`

Patching a Service
==================

If you want to make a quick change to a running service the easiest
way to do that is to change the code directly in /opt/stack/$service
and then restart the affected daemons.

.. code-block:: bash

   sudo systemctl restart --unit=devstack@n-cpu.service

If your change impacts more than one daemon you can restart by
wildcard as well.

.. code-block:: bash

   sudo systemctl restart --unit="devstack@n-*"

.. warning::

   All changes you are making are in checked out git trees that
   DevStack thinks it has full control over. Uncommitted work, or
   work committed to the master branch, may be overwritten during
   subsequent DevStack runs.

Testing a Patch Series
======================

When testing a larger set of patches, or patches that will impact more
than one service within a project, it is often less confusing to use
custom git locations, and make all your changes in a dedicated git
tree.

In your ``local.conf`` you can add ``**_REPO``, ``**_BRANCH`` for most projects
to use a custom git tree instead of the default upstream ones.

For instance:

.. code-block:: bash

   [[local|localrc]]
   NOVA_REPO=/home/sdague/nova
   NOVA_BRANCH=fold_disk_config

Will use a custom git tree and branch when doing any devstack
operations, such as ``stack.sh``.

When testing complicated changes committing to these trees, then doing
``./unstack.sh && ./stack.sh`` is often a valuable way to
iterate. This does take longer per iteration than direct patching, as
the whole devstack needs to rebuild.

You can use this same approach to test patches that are up for review
in gerrit by using the ref name that gerrit assigns to each change.

.. code-block:: bash

   [[local|localrc]]
   NOVA_BRANCH=refs/changes/10/353710/1


Testing Changes to Libraries
============================

When testing changes to libraries consumed by OpenStack services (such
as oslo or any of the python-fooclient libraries) things are a little
more complicated. By default we only test with released versions of
these libraries that are on pypi.

You must first override this with the setting ``LIBS_FROM_GIT``. This
will enable your DevStack with the git version of that library instead
of the released version.

After that point you can also specify ``**_REPO``, ``**_BRANCH`` to use
your changes instead of just upstream master.

.. code-block:: bash

   [[local|localrc]]
   LIBS_FROM_GIT=oslo.policy
   OSLOPOLICY_REPO=/home/sdague/oslo.policy
   OSLOPOLICY_BRANCH=better_exception

As libraries are not installed `editable` by pip, after you make any
local changes you will need to:

* cd to top of library path
* sudo pip install -U .
* restart all services you want to use the new library

You can do that with wildcards such as

.. code-block:: bash

   sudo systemctl restart --unit="devstack@n-*"

which will restart all nova services.
