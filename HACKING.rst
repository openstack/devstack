Contributing to DevStack
========================


General
-------

DevStack is written in POSIX shell script.  This choice was made because
it best illustrates the configuration steps that this implementation takes
on setting up and interacting with OpenStack components.  DevStack specifically
uses Bash and is compatible with Bash 3.

DevStack's official repository is located on GitHub at
https://github.com/openstack-dev/devstack.git.  Besides the master branch that
tracks the OpenStack trunk branches a separate branch is maintained for all
OpenStack releases starting with Diablo (stable/diablo).

Contributing code to DevStack follows the usual OpenStack process as described
in `How To Contribute`__ in the OpenStack wiki.  `DevStack's LaunchPad project`__
contains the usual links for blueprints, bugs, tec.

__ contribute_
.. _contribute: http://wiki.openstack.org/HowToContribute.

__ lp_
.. _lp: https://launchpad.net/~devstack

The primary script in DevStack is ``stack.sh``, which performs the bulk of the
work for DevStack's use cases.  There is a subscript ``functions`` that contains
generally useful shell functions and is used by a number of the scripts in
DevStack.

The ``lib`` directory contains sub-scripts for projects or packages that ``stack.sh``
sources to perform much of the work related to those projects.  These sub-scripts
contain configuration defaults and functions to configure, start and stop the project
or package.  These variables and functions are also used by related projects,
such as Grenade, to manage a DevStack installation.

A number of additional scripts can be found in the ``tools`` directory that may
be useful in supporting DevStack installations.  Of particular note are ``info.sh``
to collect and report information about the installed system, and ``install_prereqs.sh``
that handles installation of the prerequisite packages for DevStack.  It is
suitable, for example, to pre-load a system for making a snapshot.


Scripts
-------

DevStack scripts should generally begin by calling ``env(1)`` in the shebang line::

    #!/usr/bin/env bash

Sometimes the script needs to know the location of the DevStack install directory.
``TOP_DIR`` should always point there, even if the script itself is located in
a subdirectory::

    # Keep track of the current devstack directory.
    TOP_DIR=$(cd $(dirname "$0") && pwd)

Many scripts will utilize shared functions from the ``functions`` file.  There are
also rc files (``stackrc`` and ``openrc``) that are often included to set the primary
configuration of the user environment::

    # Keep track of the current devstack directory.
    TOP_DIR=$(cd $(dirname "$0") && pwd)

    # Import common functions
    source $TOP_DIR/functions

    # Import configuration
    source $TOP_DIR/openrc

``stack.sh`` is a rather large monolithic script that flows through from beginning
to end.  It has been broken down into project-specific subscripts (as noted above)
located in ``lib`` to make ``stack.sh`` more manageable and to promote code reuse.

These library sub-scripts have a number of fixed entry points, some of which may
just be stubs.  These entry points will be called by ``stack.sh`` in the
following order::

    install_XXXX
    configure_XXXX
    init_XXXX
    start_XXXX
    stop_XXXX
    cleanup_XXXX

There is a sub-script template in ``lib/templates`` to be used in creating new
service sub-scripts.  The comments in ``<>`` are meta comments describing
how to use the template and should be removed.

In order to show the dependencies and conditions under which project functions
are executed the top-level conditional testing for things like ``is_service_enabled``
should be done in ``stack.sh``.  There may be nested conditionals that need
to be in the sub-script, such as testing for keystone being enabled in
``configure_swift()``.


stackrc
-------

``stackrc`` is the global configuration file for DevStack.  It is responsible for
calling ``localrc`` if it exists so configuration can be overridden by the user.

The criteria for what belongs in ``stackrc`` can be vaguely summarized as
follows:

* All project respositories and branches (for historical reasons)
* Global configuration that may be referenced in ``localrc``, i.e. ``DEST``, ``DATA_DIR``
* Global service configuration like ``ENABLED_SERVICES``
* Variables used by multiple services that do not have a clear owner, i.e.
  ``VOLUME_BACKING_FILE_SIZE`` (nova-volumes and cinder) or ``PUBLIC_NETWORK_NAME``
  (nova-network and neutron)
* Variables that can not be cleanly declared in a project file due to
  dependency ordering, i.e. the order of sourcing the project files can
  not be changed for other reasons but the earlier file needs to dereference a
  variable set in the later file.  This should be rare.

Also, variable declarations in ``stackrc`` do NOT allow overriding (the form
``FOO=${FOO:-baz}``); if they did then they can already be changed in ``localrc``
and can stay in the project file.


Documentation
-------------

The official DevStack repo on GitHub does not include a gh-pages branch that
GitHub uses to create static web sites.  That branch is maintained in the
`CloudBuilders DevStack repo`__ mirror that supports the
http://devstack.org site.  This is the primary DevStack
documentation along with the DevStack scripts themselves.

__ repo_
.. _repo: https://github.com/cloudbuilders/devstack

All of the scripts are processed with shocco_ to render them with the comments
as text describing the script below.  For this reason we tend to be a little
verbose in the comments _ABOVE_ the code they pertain to.  Shocco also supports
Markdown formatting in the comments; use it sparingly.  Specifically, ``stack.sh``
uses Markdown headers to divide the script into logical sections.

.. _shocco: http://rtomayko.github.com/shocco/


Exercises
---------

The scripts in the exercises directory are meant to 1) perform basic operational
checks on certain aspects of OpenStack; and b) document the use of the
OpenStack command-line clients.

In addition to the guidelines above, exercise scripts MUST follow the structure
outlined here.  ``swift.sh`` is perhaps the clearest example of these guidelines.
These scripts are executed serially by ``exercise.sh`` in testing situations.

* Begin and end with a banner that stands out in a sea of script logs to aid
  in debugging failures, particularly in automated testing situations.  If the
  end banner is not displayed, the script ended prematurely and can be assumed
  to have failed.

  ::

    echo "**************************************************"
    echo "Begin DevStack Exercise: $0"
    echo "**************************************************"
    ...
    set +o xtrace
    echo "**************************************************"
    echo "End DevStack Exercise: $0"
    echo "**************************************************"

* The scripts will generally have the shell ``xtrace`` attribute set to display
  the actual commands being executed, and the ``errexit`` attribute set to exit
  the script on non-zero exit codes::

    # This script exits on an error so that errors don't compound and you see
    # only the first error that occurred.
    set -o errexit

    # Print the commands being run so that we can see the command that triggers
    # an error.  It is also useful for following allowing as the install occurs.
    set -o xtrace

* Settings and configuration are stored in ``exerciserc``, which must be
  sourced after ``openrc`` or ``stackrc``::

    # Import exercise configuration
    source $TOP_DIR/exerciserc

* There are a couple of helper functions in the common ``functions`` sub-script
  that will check for non-zero exit codes and unset environment variables and
  print a message and exit the script.  These should be called after most client
  commands that are not otherwise checked to short-circuit long timeouts
  (instance boot failure, for example)::

    swift post $CONTAINER
    die_if_error "Failure creating container $CONTAINER"

    FLOATING_IP=`euca-allocate-address | cut -f2`
    die_if_not_set FLOATING_IP "Failure allocating floating IP"

* If you want an exercise to be skipped when for example a service wasn't
  enabled for the exercise to be run, you can exit your exercise with the
  special exitcode 55 and it will be detected as skipped.

* The exercise scripts should only use the various OpenStack client binaries to
  interact with OpenStack.  This specifically excludes any ``*-manage`` tools
  as those assume direct access to configuration and databases, as well as direct
  database access from the exercise itself.

* If specific configuration needs to be present for the exercise to complete,
  it should be staged in ``stack.sh``, or called from ``stack.sh`` (see
  ``files/keystone_data.sh`` for an example of this).

* The ``OS_*`` environment variables should be the only ones used for all
  authentication to OpenStack clients as documented in the CLIAuth_ wiki page.

.. _CLIAuth: http://wiki.openstack.org/CLIAuth

* The exercise MUST clean up after itself if successful.  If it is not successful,
  it is assumed that state will be left behind; this allows a chance for developers
  to look around and attempt to debug the problem.  The exercise SHOULD clean up
  or graciously handle possible artifacts left over from previous runs if executed
  again.  It is acceptable to require a reboot or even a re-install of DevStack
  to restore a clean test environment.
