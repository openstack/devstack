Contributing to DevStack
========================


General
-------

DevStack is written in POSIX shell script.  This choice was made because
it best illustrates the configuration steps that this implementation takes
on setting up and interacting with OpenStack components.  DevStack specifies
BASH and is compatible with Bash 3.

DevStack's official repository is located on GitHub at
https://github.com/openstack-dev/devstack.git.  Besides the master branch that
tracks the OpenStack trunk branches a separate branch is maintained for all
OpenStack releases starting with Diablo (stable/diablo).

The primary script in DevStack is ``stack.sh``, which performs the bulk of the
work for DevStack's use cases.  There is a subscript ``functions`` that contains
generally useful shell functions and is used by a number of the scripts in
DevStack.

A number of additional scripts can be found in the ``tools`` directory that may
be useful in setting up special-case uses of DevStack. These include: bare metal
deployment, ramdisk deployment and Jenkins integration.


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
to end.  The process of breaking it down into project-level sub-scripts has begun
with the introduction of ``lib/cinder`` and ``lib/ceilometer``.

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
    # only the first error that occured.
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
