=======
Plugins
=======

DevStack has a couple of plugin mechanisms to allow easily adding
support for additional projects and features.

Extras.d Hooks
~~~~~~~~~~~~~~

These relatively new hooks are an extension of the existing calls from
``stack.sh`` at the end of its run, plus ``unstack.sh`` and
``clean.sh``. A number of the higher-layer projects are implemented in
DevStack using this mechanism.

The script in ``extras.d`` is expected to be mostly a dispatcher to
functions in a ``lib/*`` script. The scripts are named with a
zero-padded two digits sequence number prefix to control the order that
the scripts are called, and with a suffix of ``.sh``. DevSack reserves
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

Hypervisor
~~~~~~~~~~

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
