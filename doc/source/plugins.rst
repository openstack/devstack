=======
Plugins
=======

DevStack has a couple of plugin mechanisms to allow easily adding
support for additional projects and features.

Extras.d Hooks
==============

These hooks are an extension of the service calls in
``stack.sh`` at specific points in its run, plus ``unstack.sh`` and
``clean.sh``. A number of the higher-layer projects are implemented in
DevStack using this mechanism.

The script in ``extras.d`` is expected to be mostly a dispatcher to
functions in a ``lib/*`` script. The scripts are named with a
zero-padded two digits sequence number prefix to control the order that
the scripts are called, and with a suffix of ``.sh``. DevStack reserves
for itself the sequence numbers 00 through 09 and 90 through 99.

Below is a template that shows handlers for the possible command-line
arguments:

::

    # template.sh - DevStack extras.d dispatch script template

    # check for service enabled
    if is_service_enabled template; then

        if [[ "$1" == "source" ]]; then
            # Initial source of lib script
            source $TOP_DIR/lib/template
        fi

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
            ##init_template
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

The arguments are:

-  **source** - Called by each script that utilizes ``extras.d`` hooks;
   this replaces directly sourcing the ``lib/*`` script.
-  **stack** - Called by ``stack.sh`` three times for different phases
   of its run:

   -  **pre-install** - Called after system (OS) setup is complete and
      before project source is installed.
   -  **install** - Called after the layer 1 and 2 projects source and
      their dependencies have been installed.
   -  **post-config** - Called after the layer 1 and 2 services have
      been configured. All configuration files for enabled services
      should exist at this point.
   -  **extra** - Called near the end after layer 1 and 2 services have
      been started. This is the existing hook and has not otherwise
      changed.

-  **unstack** - Called by ``unstack.sh`` before other services are shut
   down.
-  **clean** - Called by ``clean.sh`` before other services are cleaned,
   but after ``unstack.sh`` has been called.


Externally Hosted Plugins
=========================

Based on the extras.d hooks, DevStack supports a standard mechansim
for including plugins from external repositories. The plugin interface
assumes the following:

An external git repository that includes a ``devstack/`` top level
directory. Inside this directory there can be 2 files.

- ``settings`` - a file containing global variables that will be
  sourced very early in the process. This is helpful if other plugins
  might depend on this one, and need access to global variables to do
  their work.

  Your settings should include any ``enable_service`` lines required
  by your plugin. This is especially important if you are kicking off
  services using ``run_process`` as it only works with enabled
  services.

- ``plugin.sh`` - the actual plugin. It will be executed by devstack
  during it's run. The run order will be done in the registration
  order for these plugins, and will occur immediately after all in
  tree extras.d dispatch at the phase in question.  The plugin.sh
  looks like the extras.d dispatcher above.

Plugins are registered by adding the following to the localrc section
of ``local.conf``.

They are added in the following format::

  [[local|localrc]]
  enable_plugin <NAME> <GITURL> [GITREF]

- ``name`` - an arbitrary name. (ex: glustfs, docker, zaqar, congress)
- ``giturl`` - a valid git url that can be cloned
- ``gitref`` - an optional git ref (branch / ref / tag) that will be
  cloned. Defaults to master.

An example would be as follows::

  enable_plugin ec2api git://git.openstack.org/stackforge/ec2api

Plugins for gate jobs
---------------------

All OpenStack plugins that wish to be used as gate jobs need to exist
in OpenStack's gerrit. Both ``openstack`` namespace and ``stackforge``
namespace are fine. This allows testing of the plugin as well as
provides network isolation against upstream git repository failures
(which we see often enough to be an issue).

Ideally plugins will be implemented as ``devstack`` directory inside
the project they are testing. For example, the stackforge/ec2-api
project has it's pluggin support in it's tree.

In the cases where there is no "project tree" per say (like
integrating a backend storage configuration such as ceph or glusterfs)
it's also allowed to build a dedicated
``stackforge/devstack-plugin-FOO`` project to house the plugin.

Note jobs must not require cloning of repositories during tests.
Tests must list their repository in the ``PROJECTS`` variable for
`devstack-gate
<https://git.openstack.org/cgit/openstack-infra/devstack-gate/tree/devstack-vm-gate-wrap.sh>`_
for the repository to be available to the test.  Further information
is provided in the project creator's guide.

Hypervisor
==========

Hypervisor plugins are fairly new and condense most hypervisor
configuration into one place.

The initial plugin implemented was for Docker support and is a useful
template for the required support. Plugins are placed in
``lib/nova_plugins`` and named ``hypervisor-<name>`` where ``<name>`` is
the value of ``VIRT_DRIVER``. Plugins must define the following
functions:

-  ``install_nova_hypervisor`` - install any external requirements
-  ``configure_nova_hypervisor`` - make configuration changes, including
   those to other services
-  ``start_nova_hypervisor`` - start any external services
-  ``stop_nova_hypervisor`` - stop any external services
-  ``cleanup_nova_hypervisor`` - remove transient data and cache

System Packages
===============

Devstack provides a framework for getting packages installed at an early
phase of its execution. This packages may be defined in a plugin as files
that contain new-line separated lists of packages required by the plugin

Supported packaging systems include apt and yum across multiple distributions.
To enable a plugin to hook into this and install package dependencies, packages
may be listed at the following locations in the top-level of the plugin
repository:

- ``./devstack/files/debs/$plugin_name`` - Packages to install when running
  on Ubuntu, Debian or Linux Mint.

- ``./devstack/files/rpms/$plugin_name`` - Packages to install when running
  on Red Hat, Fedora, CentOS or XenServer.

- ``./devstack/files/rpms-suse/$plugin_name`` - Packages to install when
  running on SUSE Linux or openSUSE.
