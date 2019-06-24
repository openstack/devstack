===
FAQ
===

.. contents::
   :local:

General Questions
=================

Can I use DevStack for production?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DevStack is targeted at developers and CI systems to use the raw
upstream code.  It makes many choices that are not appropriate for
production systems.

Your best choice is probably to choose a `distribution of OpenStack
<https://www.openstack.org/marketplace/distros/>`__.

Can I use DevStack as a development environment?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Sure, you can. That said, there are a couple of things you should note before
doing so:

- DevStack makes a lot of configuration changes to your system and should not
  be run in your main development environment.

- All the repositories that DevStack clones when deploying are considered
  volatile by default and thus are subject to hard resets. This is necessary to
  keep you in sync with the latest upstream, which is what you want in a CI
  situation, but it can result in branches being overwritten and files being
  removed.

  The corollary of this is that if you are working on a specific project, using
  the DevStack project repository (defaulted to ``/opt/stack/<project>``) as
  the single master repository for storing all your work is not recommended.
  This behavior can be overridden by setting the ``RECLONE`` config option to
  ``no``.  Alternatively, you can avoid running ``stack.sh`` to redeploy by
  restarting services manually. In any case, you should generally ensure work
  in progress is pushed to Gerrit or otherwise backed up before running
  ``stack.sh``.

- If you use DevStack within a VM, you may wish to mount a local OpenStack
  directory, such as ``~/src/openstack``, inside the VM and configure DevStack
  to use this as the clone location using the ``{PROJECT}_REPO`` config
  variables. For example, assuming you're using Vagrant and sharing your home
  directory, you should place the following in ``local.conf``:

  .. code-block:: shell

     NEUTRON_REPO=/home/vagrant/src/neutron
     NOVA_REPO=/home/vagrant/src/nova
     KEYSTONE_REPO=/home/vagrant/src/keystone
     GLANCE_REPO=/home/vagrant/src/glance
     SWIFT_REPO=/home/vagrant/src/swift
     HORIZON_REPO=/home/vagrant/src/horizon
     CINDER_REPO=/home/vagrant/src/cinder
     HEAT_REPO=/home/vagrant/src/heat
     TEMPEST_REPO=/home/vagrant/src/tempest
     HEATCLIENT_REPO=/home/vagrant/src/python-heatclient
     GLANCECLIENT_REPO=/home/vagrant/src/python-glanceclient
     NOVACLIENT_REPO=/home/vagrant/src/python-novaclient
     NEUTRONCLIENT_REPO=/home/vagrant/src/python-neutronclient
     OPENSTACKCLIENT_REPO=/home/vagrant/src/python-openstackclient
     HEAT_CFNTOOLS_REPO=/home/vagrant/src/heat-cfntools
     HEAT_TEMPLATES_REPO=/home/vagrant/src/heat-templates
     NEUTRON_FWAAS_REPO=/home/vagrant/src/neutron-fwaas
     # ...

Why a shell script, why not chef/puppet/...
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The script is meant to be read by humans (as well as ran by
computers); it is the primary documentation after all. Using a recipe
system requires everyone to agree and understand chef or puppet.

I'd like to help!
~~~~~~~~~~~~~~~~~

That isn't a question, but please do! The source for DevStack is at
`opendev.org <https://opendev.org/openstack/devstack>`__ and bug
reports go to `LaunchPad
<https://bugs.launchpad.net/devstack/>`__. Contributions follow the
usual process as described in the `developer guide
<https://docs.openstack.org/infra/manual/developers.html>`__. This
Sphinx documentation is housed in the doc directory.

Why not use packages?
~~~~~~~~~~~~~~~~~~~~~

Unlike packages, DevStack leaves your cloud ready to develop -
checkouts of the code and services running locally under systemd,
making it easy to hack on and test new patches. However, many people
are doing the hard work of packaging and recipes for production
deployments.

Why isn't $MY\_FAVORITE\_DISTRO supported?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DevStack is meant for developers and those who want to see how
OpenStack really works. DevStack is known to run on the distro/release
combinations listed in ``README.md``. DevStack is only supported on
releases other than those documented in ``README.md`` on a best-effort
basis.

Are there any differences between Ubuntu and CentOS/Fedora support?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Both should work well and are tested by DevStack CI.

Why can't I use another shell?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DevStack now uses some specific bash-ism that require Bash 4, such as
associative arrays. Simple compatibility patches have been accepted in
the past when they are not complex, at this point no additional
compatibility patches will be considered except for shells matching
the array functionality as it is very ingrained in the repo and
project management.

Can I test on OS/X?
~~~~~~~~~~~~~~~~~~~

Some people have success with bash 4 installed via homebrew to keep
running tests on OS/X.

Can I at least source ``openrc`` with ``zsh``?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

People have reported success with a special function to run ``openrc``
through bash for this

.. code-block:: bash

   function sourceopenrc {
       pushd ~/devstack >/dev/null
       eval $(bash -c ". openrc $1 $2 >/dev/null;env|sed -n '/OS_/ { s/^/export /;p}'")
       popd >/dev/null
   }


Operation and Configuration
===========================

Can DevStack handle a multi-node installation?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Yes, see :doc:`multinode lab guide <guides/multinode-lab>`

How can I document the environment that DevStack is using?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DevStack includes a script (``tools/info.sh``) that gathers the
versions of the relevant installed apt packages, pip packages and git
repos. This is a good way to verify what Python modules are
installed.

How do I turn off a service that is enabled by default?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Services can be turned off by adding ``disable_service xxx`` to
``local.conf`` (using ``c-vol`` in this example):

    ::

        disable_service c-vol

Is enabling a service that defaults to off done with the reverse of the above?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Of course!

    ::

        enable_service q-svc

How do I run a specific OpenStack release?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DevStack master tracks the upstream master of all the projects. If you
would like to run a stable branch of OpenStack, you should use the
corresponding stable branch of DevStack as well. For instance the
``stable/ocata`` version of DevStack will already default to all the
projects running at ``stable/ocata`` levels.

Note: it's also possible to manually adjust the ``*_BRANCH`` variables
further if you would like to test specific milestones, or even custom
out of tree branches. This is done with entries like the following in
your ``local.conf``

::

        [[local|localrc]]
        GLANCE_BRANCH=11.0.0.0rc1
        NOVA_BRANCH=12.0.0.0.rc1


Upstream DevStack is only tested with master and stable
branches. Setting custom BRANCH definitions is not guaranteed to
produce working results.

What can I do about RabbitMQ not wanting to start on my fresh new VM?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This is often caused by ``erlang`` not being happy with the hostname
resolving to a reachable IP address. Make sure your hostname resolves
to a working IP address; setting it to 127.0.0.1 in ``/etc/hosts`` is
often good enough for a single-node installation. And in an extreme
case, use ``clean.sh`` to eradicate it and try again.

Why are my configuration changes ignored?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You may have run into the package prerequisite installation
timeout. ``tools/install_prereqs.sh`` has a timer that skips the
package installation checks if it was run within the last
``PREREQ_RERUN_HOURS`` hours (default is 2). To override this, set
``FORCE_PREREQ=1`` and the package checks will never be skipped.

Miscellaneous
=============

``tools/fixup_stuff.sh`` is broken and shouldn't 'fix' just one version of packages.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Stuff in there is to correct problems in an environment that need to
be fixed elsewhere or may/will be fixed in a future release. In the
case of ``httplib2`` and ``prettytable`` specific problems with
specific versions are being worked around. If later releases have
those problems than we'll add them to the script. Knowing about the
broken future releases is valuable rather than polling to see if it
has been fixed.
