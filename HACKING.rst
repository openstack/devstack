Contributing to DevStack
========================


General
-------

DevStack is written in UNIX shell script.  It uses a number of bash-isms
and so is limited to Bash (version 4 and up) and compatible shells.
Shell script was chosen because it best illustrates the steps used to
set up and interact with OpenStack components.

DevStack's official repository is located on opendev.org at
https://opendev.org/openstack/devstack.  Besides the master branch that
tracks the OpenStack trunk branches a separate branch is maintained for all
OpenStack releases starting with Diablo (stable/diablo).

Contributing code to DevStack follows the usual OpenStack process as described
in `How To Contribute`__ in the OpenStack wiki.  `DevStack's LaunchPad project`__
contains the usual links for blueprints, bugs, etc.

__ contribute_
.. _contribute: https://docs.openstack.org/infra/manual/developers.html

__ lp_
.. _lp: https://launchpad.net/devstack

The `Gerrit review
queue <https://review.opendev.org/#/q/project:openstack/devstack>`__
is used for all commits.

The primary script in DevStack is ``stack.sh``, which performs the bulk of the
work for DevStack's use cases.  There is a subscript ``functions`` that contains
generally useful shell functions and is used by a number of the scripts in
DevStack.

A number of additional scripts can be found in the ``tools`` directory that may
be useful in supporting DevStack installations.  Of particular note are ``info.sh``
to collect and report information about the installed system, and ``install_prereqs.sh``
that handles installation of the prerequisite packages for DevStack.  It is
suitable, for example, to pre-load a system for making a snapshot.

Repo Layout
-----------

The DevStack repo generally keeps all of the primary scripts at the root
level.

``doc`` - Contains the Sphinx source for the documentation.
A complete doc build can be run with ``tox -edocs``.

``extras.d`` - Contains the dispatch scripts called by the hooks in
``stack.sh``, ``unstack.sh`` and ``clean.sh``. See :doc:`the plugins
docs <plugins>` for more information.

``files`` - Contains a variety of otherwise lost files used in
configuring and operating DevStack. This includes templates for
configuration files and the system dependency information. This is also
where image files are downloaded and expanded if necessary.

``lib`` - Contains the sub-scripts specific to each project. This is
where the work of managing a project's services is located. Each
top-level project (Keystone, Nova, etc) has a file here. Additionally
there are some for system services and project plugins.  These
variables and functions are also used by related projects, such as
Grenade, to manage a DevStack installation.

``samples`` - Contains a sample of the local files not included in the
DevStack repo.

``tests`` - the DevStack test suite is rather sparse, mostly consisting
of test of specific fragile functions in the ``functions`` and
``functions-common`` files.

``tools`` - Contains a collection of stand-alone scripts. While these
may reference the top-level DevStack configuration they can generally be
run alone.


Scripts
-------

DevStack scripts should generally begin by calling ``env(1)`` in the shebang line::

    #!/usr/bin/env bash

Sometimes the script needs to know the location of the DevStack install directory.
``TOP_DIR`` should always point there, even if the script itself is located in
a subdirectory::

    # Keep track of the current DevStack directory.
    TOP_DIR=$(cd $(dirname "$0") && pwd)

Many scripts will utilize shared functions from the ``functions`` file.  There are
also rc files (``stackrc`` and ``openrc``) that are often included to set the primary
configuration of the user environment::

    # Keep track of the current DevStack directory.
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
calling ``local.conf`` (or ``localrc`` if it exists) so local user configuration
is recognized.

The criteria for what belongs in ``stackrc`` can be vaguely summarized as
follows:

* All project repositories and branches handled directly in ``stack.sh``
* Global configuration that may be referenced in ``local.conf``, i.e. ``DEST``, ``DATA_DIR``
* Global service configuration like ``ENABLED_SERVICES``
* Variables used by multiple services that do not have a clear owner, i.e.
  ``VOLUME_BACKING_FILE_SIZE`` (nova-compute and cinder) or
  ``PUBLIC_NETWORK_NAME`` (only neutron but formerly nova-network too)
* Variables that can not be cleanly declared in a project file due to
  dependency ordering, i.e. the order of sourcing the project files can
  not be changed for other reasons but the earlier file needs to dereference a
  variable set in the later file.  This should be rare.

Also, variable declarations in ``stackrc`` before ``local.conf`` is sourced
do NOT allow overriding (the form
``FOO=${FOO:-baz}``); if they did then they can already be changed in ``local.conf``
and can stay in the project file.


Documentation
-------------

The DevStack repo now contains all of the static pages of devstack.org in
the ``doc/source`` directory. The OpenStack CI system rebuilds the docs after every
commit and updates devstack.org (now a redirect to https://docs.openstack.org/devstack/latest/).

All of the scripts are processed with shocco_ to render them with the comments
as text describing the script below.  For this reason we tend to be a little
verbose in the comments _ABOVE_ the code they pertain to.  Shocco also supports
Markdown formatting in the comments; use it sparingly.  Specifically, ``stack.sh``
uses Markdown headers to divide the script into logical sections.

.. _shocco: https://github.com/dtroyer/shocco/tree/rst_support

The script used to drive <code>shocco</code> is <code>tools/build_docs.sh</code>.
The complete docs build is also handled with <code>tox -edocs</code> per the
OpenStack project standard.


Bash Style Guidelines
~~~~~~~~~~~~~~~~~~~~~
DevStack defines a bash set of best practices for maintaining large
collections of bash scripts. These should be considered as part of the
review process.

DevStack uses the bashate_ style checker
to enforce basic guidelines, similar to pep8 and flake8 tools for Python. The
list below is not complete for what bashate checks, nor is it all checked
by bashate.  So many lines of code, so little time.

.. _bashate: https://pypi.org/project/bashate/

Whitespace Rules
----------------

- lines should not include trailing whitespace
- there should be no hard tabs in the file
- indents are 4 spaces, and all indentation should be some multiple of
  them

Control Structure Rules
-----------------------

- then should be on the same line as the if
- do should be on the same line as the for

Example::

  if [[ -r $TOP_DIR/local.conf ]]; then
      LRC=$(get_meta_section_files $TOP_DIR/local.conf local)
      for lfile in $LRC; do
          if [[ "$lfile" == "localrc" ]]; then
              if [[ -r $TOP_DIR/localrc ]]; then
                  warn $LINENO "localrc and local.conf:[[local]] both exist, using localrc"
              else
                  echo "# Generated file, do not edit" >$TOP_DIR/.localrc.auto
                  get_meta_section $TOP_DIR/local.conf local $lfile >>$TOP_DIR/.localrc.auto
              fi
          fi
      done
  fi

Variables and Functions
-----------------------

- functions should be used whenever possible for clarity
- functions should use ``local`` variables as much as possible to
  ensure they are isolated from the rest of the environment
- local variables should be lower case, global variables should be
  upper case
- function names should_have_underscores, NotCamelCase.
- functions should be declared as per the regex ^function foo {$
  with code starting on the next line


Review Criteria
---------------

There are some broad criteria that will be followed when reviewing
your change

* **Is it passing tests** -- your change will not be reviewed
  thoroughly unless the official CI has run successfully against it.

* **Does this belong in DevStack** -- DevStack reviewers have a
  default position of "no" but are ready to be convinced by your
  change.

  For very large changes, you should consider :doc:`the plugins system
  <plugins>` to see if your code is better abstracted from the main
  repository.

  For smaller changes, you should always consider if the change can be
  encapsulated by per-user settings in ``local.conf``.  A common example
  is adding a simple config-option to an ``ini`` file.  Specific flags
  are not usually required for this, although adding documentation
  about how to achieve a larger goal (which might include turning on
  various settings, etc) is always welcome.

* **Work-arounds** -- often things get broken and DevStack can be in a
  position to fix them.  Work-arounds are fine, but should be
  presented in the context of fixing the root-cause of the problem.
  This means it is well-commented in the code and the change-log and
  mostly likely includes links to changes or bugs that fix the
  underlying problem.

* **Should this be upstream** -- DevStack generally does not override
  default choices provided by projects and attempts to not
  unexpectedly modify behavior.

* **Context in commit messages** -- DevStack touches many different
  areas and reviewers need context around changes to make good
  decisions.  We also always want it to be clear to someone -- perhaps
  even years from now -- why we were motivated to make a change at the
  time.


Making Changes, Testing, and CI
-------------------------------

Changes to Devstack are tested by automated continuous integration jobs
that run on a variety of Linux Distros using a handful of common
configurations. What this means is that every change to Devstack is
self testing. One major benefit of this is that developers do not
typically need to add new non voting test jobs to add features to
Devstack. Instead the features can be added, then if testing passes
with the feature enabled the change is ready to merge (pending code
review).

A concrete example of this was the switch from screen based service
management to systemd based service management. No new jobs were
created for this. Instead the features were added to devstack, tested
locally and in CI using a change that enabled the feature, then once
the enabling change was passing and the new behavior communicated and
documented it was merged.

Using this process has been proven to be effective and leads to
quicker implementation of desired features.
