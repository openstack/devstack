=======
Plugins
=======

The OpenStack ecosystem is wide and deep, and only growing more so
every day. The value of DevStack is that it's simple enough to
understand what it's doing clearly. And yet we'd like to support as
much of the OpenStack Ecosystem as possible. We do that with plugins.

DevStack plugins are bits of bash code that live outside the DevStack
tree. They are called through a strong contract, so these plugins can
be sure that they will continue to work in the future as DevStack
evolves.

Prerequisites
=============

If you are planning to create a plugin that is going to host a service in the
service catalog (that is, your plugin will use the command
``get_or_create_service``) please make sure that you apply to the `service
types authority`_ to reserve a valid service-type. This will help to make sure
that all deployments of your service use the same service-type.

Plugin Interface
================

DevStack supports a standard mechanism for including plugins from
external repositories. The plugin interface assumes the following:

An external git repository that includes a ``devstack/`` top level
directory. Inside this directory there can be 3 files.

- ``override-defaults`` - a file containing global variables that
  will be sourced before the lib/* files. This allows the plugin
  to override the defaults that are otherwise set in the lib/*
  files.

  For example, override-defaults may export CINDER_ENABLED_BACKENDS
  to include the plugin-specific storage backend and thus be able
  to override the default lvm only storage backend for Cinder.

- ``settings`` - a file containing global variables that will be
  sourced very early in the process. This is helpful if other plugins
  might depend on this one, and need access to global variables to do
  their work.

  Your settings should include any ``enable_service`` lines required
  by your plugin. This is especially important if you are kicking off
  services using ``run_process`` as it only works with enabled
  services.

  Be careful to allow users to override global-variables for
  customizing their environment.  Usually it is best to provide a
  default value only if the variable is unset or empty; e.g. in bash
  syntax ``FOO=${FOO:-default}``.

  The file should include a ``define_plugin`` line to indicate the
  plugin's name, which is the name that should be used by users on
  "enable_plugin" lines.  It should generally be the last component of
  the git repo path (e.g., if the plugin's repo is
  openstack/foo, then the name here should be "foo") ::

    define_plugin <YOUR PLUGIN>

  If your plugin depends on another plugin, indicate it in this file
  with one or more lines like the following::

    plugin_requires <YOUR PLUGIN> <OTHER PLUGIN>

  For a complete example, if the plugin "foo" depends on "bar", the
  ``settings`` file should include::

    define_plugin foo
    plugin_requires foo bar

  Devstack does not currently use this dependency information, so it's
  important that users continue to add enable_plugin lines in the
  correct order in ``local.conf``, however adding this information
  allows other tools to consider dependency information when
  automatically generating ``local.conf`` files.

- ``plugin.sh`` - the actual plugin. It is executed by devstack at
  well defined points during a ``stack.sh`` run. The plugin.sh
  internal structure is discussed below.


Plugins are registered by adding the following to the localrc section
of ``local.conf``.

They are added in the following format::

  [[local|localrc]]
  enable_plugin <NAME> <GITURL> [GITREF]

- ``name`` - an arbitrary name. (ex: glusterfs, docker, zaqar, congress)
- ``giturl`` - a valid git url that can be cloned
- ``gitref`` - an optional git ref (branch / ref / tag) that will be
  cloned. Defaults to master.

An example would be as follows::

  enable_plugin ec2-api https://opendev.org/openstack/ec2-api

plugin.sh contract
==================

``plugin.sh`` is a bash script that will be called at specific points
during ``stack.sh``, ``unstack.sh``, and ``clean.sh``. It will be
called in the following way::

  source $PATH/TO/plugin.sh <mode> [phase]

``mode`` can be thought of as the major mode being called, currently
one of: ``stack``, ``unstack``, ``clean``. ``phase`` is used by modes
which have multiple points during their run where it's necessary to
be able to execute code. All existing ``mode`` and ``phase`` points
are considered **strong contracts** and won't be removed without a
reasonable deprecation period. Additional new ``mode`` or ``phase``
points may be added at any time if we discover we need them to support
additional kinds of plugins in devstack.

The current full list of ``mode`` and ``phase`` are:

-  **stack** - Called by ``stack.sh`` four times for different phases
   of its run:

   -  **pre-install** - Called after system (OS) setup is complete and
      before project source is installed.
   -  **install** - Called after the layer 1 and 2 projects source and
      their dependencies have been installed.
   -  **post-config** - Called after the layer 1 and 2 services have
      been configured. All configuration files for enabled services
      should exist at this point.
   -  **extra** - Called near the end after layer 1 and 2 services have
      been started.
   -  **test-config** - Called at the end of devstack used to configure tempest
      or any other test environments

-  **unstack** - Called by ``unstack.sh`` before other services are shut
   down.
-  **clean** - Called by ``clean.sh`` before other services are cleaned,
   but after ``unstack.sh`` has been called.

Example plugin
====================

An example plugin would look something as follows.

``devstack/settings``::

  # settings file for template
  enable_service template


``devstack/plugin.sh``::

    # plugin.sh - DevStack plugin.sh dispatch script template

    function install_template {
        ...
    }

    function init_template {
        ...
    }

    function configure_template {
        ...
    }

    # check for service enabled
    if is_service_enabled template; then

        if [[ "$1" == "stack" && "$2" == "pre-install" ]]; then
            # Set up system services
            echo_summary "Configuring system services Template"
            install_package cowsay

        elif [[ "$1" == "stack" && "$2" == "install" ]]; then
            # Perform installation of service source
            echo_summary "Installing Template"
            install_template

        elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
            # Configure after the other layer 1 and 2 services have been configured
            echo_summary "Configuring Template"
            configure_template

        elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
            # Initialize and start the template service
            echo_summary "Initializing Template"
            init_template
        fi

        if [[ "$1" == "unstack" ]]; then
            # Shut down template services
            # no-op
            :
        fi

        if [[ "$1" == "clean" ]]; then
            # Remove state and transient data
            # Remember clean.sh first calls unstack.sh
            # no-op
            :
        fi
    fi

Plugin Execution Order
======================

Plugins are run after in tree services at each of the stages
above. For example, if you need something to happen before Keystone
starts, you should do that at the ``post-config`` phase.

Multiple plugins can be specified in your ``local.conf``. When that
happens the plugins will be executed **in order** at each phase. This
allows plugins to conceptually depend on each other through
documenting to the user the order they must be declared. A formal
dependency mechanism is beyond the scope of the current work.

System Packages
===============



Devstack based
--------------

Devstack provides a custom framework for getting packages installed at
an early phase of its execution.  These packages may be defined in a
plugin as files that contain new-line separated lists of packages
required by the plugin

Supported packaging systems include apt and yum across multiple
distributions.  To enable a plugin to hook into this and install
package dependencies, packages may be listed at the following
locations in the top-level of the plugin repository:

- ``./devstack/files/debs/$plugin_name`` - Packages to install when running
  on Ubuntu or Debian.

- ``./devstack/files/rpms/$plugin_name`` - Packages to install when running
  on Red Hat, Fedora, or CentOS.

Although there a no plans to remove this method of installing
packages, plugins should consider it deprecated for ``bindep`` support
described below.

bindep
------

The `bindep <https://docs.openstack.org/infra/bindep>`__ project has
become the defacto standard for OpenStack projects to specify binary
dependencies.

A plugin may provide a ``./devstack/files/bindep.txt`` file, which
will be called with the *default* profile to install packages.  For
details on the syntax, etc. see the bindep documentation.

It is also possible to use the ``bindep.txt`` of projects that are
being installed from source with the ``-bindep`` flag available in
install functions.  For example

.. code-block:: bash

  if use_library_from_git "diskimage-builder"; then
     GITREPO["diskimage-builder"]=$DISKIMAGE_BUILDER_REPO_URL
     GITDIR["diskimage-builder"]=$DEST/diskimage-builder
     GITBRANCH["diskimage-builder"]=$DISKIMAGE_BUILDER_REPO_REF
     git_clone_by_name "diskimage-builder"
     setup_dev_lib -bindep "diskimage-builder"
  fi

will result in any packages required by the ``bindep.txt`` of the
``diskimage-builder`` project being installed.  Note however that jobs
that switch projects between source and released/pypi installs
(e.g. with a ``foo-dsvm`` and a ``foo-dsvm-src`` test to cover both
released dependencies and master versions) will have to deal with
``bindep.txt`` being unavailable without the source directory.


Using Plugins in the OpenStack Gate
===================================

For everyday use, DevStack plugins can exist in any git tree that's
accessible on the internet. However, when using DevStack plugins in
the OpenStack gate, they must live in projects in OpenStack's
gerrit. This allows testing of the plugin as well as provides network
isolation against upstream git repository failures (which we see often
enough to be an issue).

Ideally a plugin will be included within the ``devstack`` directory of
the project they are being tested. For example, the openstack/ec2-api
project has its plugin support in its own tree.

However, some times a DevStack plugin might be used solely to
configure a backend service that will be used by the rest of
OpenStack, so there is no "project tree" per say. Good examples
include: integration of back end storage (e.g. ceph or glusterfs),
integration of SDN controllers (e.g. ovn, OpenDayLight), or
integration of alternate RPC systems (e.g. zmq, qpid). In these cases
the best practice is to build a dedicated
``openstack/devstack-plugin-FOO`` project.

Legacy project-config jobs
--------------------------

To enable a plugin to be used in a gate job, the following lines will
be needed in your ``jenkins/jobs/<project>.yaml`` definition in
`project-config <https://opendev.org/openstack/project-config/>`_::

  # Because we are testing a non standard project, add the
  # our project repository. This makes zuul do the right
  # reference magic for testing changes.
  export PROJECTS="openstack/ec2-api $PROJECTS"

  # note the actual url here is somewhat irrelevant because it
  # caches in nodepool, however make it a valid url for
  # documentation purposes.
  export DEVSTACK_LOCAL_CONFIG="enable_plugin ec2-api https://opendev.org/openstack/ec2-api"

Zuul v3 jobs
------------

See the ``devstack_plugins`` example in :doc:`zuul_ci_jobs_migration`.

See Also
========

For additional inspiration on devstack plugins you can check out the
:doc:`Plugin Registry <plugin-registry>`.

.. _service types authority: https://specs.openstack.org/openstack/service-types-authority/
