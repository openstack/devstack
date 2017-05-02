DevStack is a set of scripts and utilities to quickly deploy an OpenStack cloud.

Goals
=====

* To quickly build dev OpenStack environments in a clean Ubuntu or Fedora
  environment
* To describe working configurations of OpenStack (which code branches
  work together?  what do config files look like for those branches?)
* To make it easier for developers to dive into OpenStack so that they can
  productively contribute without having to understand every part of the
  system at once
* To make it easy to prototype cross-project features
* To provide an environment for the OpenStack CI testing on every commit
  to the projects

Read more at http://docs.openstack.org/developer/devstack

IMPORTANT: Be sure to carefully read `stack.sh` and any other scripts you
execute before you run them, as they install software and will alter your
networking configuration.  We strongly recommend that you run `stack.sh`
in a clean and disposable vm when you are first getting started.

Versions
========

The DevStack master branch generally points to trunk versions of OpenStack
components.  For older, stable versions, look for branches named
stable/[release] in the DevStack repo.  For example, you can do the
following to create a Newton OpenStack cloud::

    git checkout stable/newton
    ./stack.sh

You can also pick specific OpenStack project releases by setting the appropriate
`*_BRANCH` variables in the ``localrc`` section of `local.conf` (look in
`stackrc` for the default set).  Usually just before a release there will be
milestone-proposed branches that need to be tested::

    GLANCE_REPO=git://git.openstack.org/openstack/glance.git
    GLANCE_BRANCH=milestone-proposed

Start A Dev Cloud
=================

Installing in a dedicated disposable VM is safer than installing on your
dev machine!  Plus you can pick one of the supported Linux distros for
your VM.  To start a dev cloud run the following NOT AS ROOT (see
**DevStack Execution Environment** below for more on user accounts):

    ./stack.sh

When the script finishes executing, you should be able to access OpenStack
endpoints, like so:

* Horizon: http://myhost/
* Keystone: http://myhost:5000/v2.0/

We also provide an environment file that you can use to interact with your
cloud via CLI::

    # source openrc file to load your environment with OpenStack CLI creds
    . openrc
    # list instances
    openstack server list

DevStack Execution Environment
==============================

DevStack runs rampant over the system it runs on, installing things and
uninstalling other things.  Running this on a system you care about is a recipe
for disappointment, or worse.  Alas, we're all in the virtualization business
here, so run it in a VM.  And take advantage of the snapshot capabilities
of your hypervisor of choice to reduce testing cycle times.  You might even save
enough time to write one more feature before the next feature freeze...

``stack.sh`` needs to have root access for a lot of tasks, but uses
``sudo`` for all of those tasks.  However, it needs to be not-root for
most of its work and for all of the OpenStack services.  ``stack.sh``
specifically does not run if started as root.

DevStack will not automatically create the user, but provides a helper
script in ``tools/create-stack-user.sh``.  Run that (as root!) or just
check it out to see what DevStack's expectations are for the account
it runs under.  Many people simply use their usual login (the default
'ubuntu' login on a UEC image for example).

Customizing
===========

DevStack can be extensively configured via the configuration file
`local.conf`.  It is likely that you will need to provide and modify
this file if you want anything other than the most basic setup.  Start
by reading the `configuration guide
<https://docs.openstack.org/developer/devstack/configuration.html>_`
for details of the configuration file and the many available options.
