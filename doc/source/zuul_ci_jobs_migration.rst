===============================
Migrating Zuul V2 CI jobs to V3
===============================

The OpenStack CI system moved from Zuul v2 to Zuul v3, and all CI jobs moved to
the new CI system. All jobs have been migrated automatically to a format
compatible with Zuul v3; the jobs produced in this way however are suboptimal
and do not use the capabilities introduced by Zuul v3, which allow for re-use of
job parts, in the form of Ansible roles, as well as inheritance between jobs.

DevStack hosts a set of roles, plays and jobs that can be used by other
repositories to define their DevStack based jobs. To benefit from them, jobs
must be migrated from the legacy v2 ones into v3 native format.

This document provides guidance and examples to make the migration process as
painless and smooth as possible.

Where to host the job definitions.
==================================

In Zuul V3 jobs can be defined in the repository that contains the code they
excercise. If you are writing CI jobs for an OpenStack service you can define
your DevStack based CI jobs in one of the repositories that host the code for
your service. If you have a branchless repo, like a Tempest plugin, that is
a convenient choice to host the job definitions since job changes do not have
to be backported. For example, see the beginning of the ``.zuul.yaml`` from the
sahara Tempest plugin repo:

.. code:: yaml

  # In https://opendev.org/openstack/sahara-tests/src/branch/master/.zuul.yaml:
  - job:
      name: sahara-tests-tempest
      description: |
        Run Tempest tests from the Sahara plugin.
      parent: devstack-tempest

Which base job to start from
============================

If your job needs an OpenStack cloud deployed via DevStack, but you don't plan
on running Tempest tests, you can start from one of the base
:doc:`jobs <zuul_jobs>` defined in the DevStack repo.

The ``devstack`` job can be used for both single-node jobs and multi-node jobs,
and it includes the list of services used in the integrated gate (keystone,
glance, nova, cinder, neutron and swift). Different topologies can be achieved
by switching the nodeset used in the child job.

The ``devstack-base`` job is similar to ``devstack`` but it does not specify any
required repo or service to be run in DevStack. It can be useful to setup
children jobs that use a very narrow DevStack setup.

If your job needs an OpenStack cloud deployed via DevStack, and you do plan
on running Tempest tests, you can start from one of the base jobs defined in the
Tempest repo.

The ``devstack-tempest`` job can be used for both single-node jobs and
multi-node jobs. Different topologies can be achieved by switching the nodeset
used in the child job.

Jobs can be customized as follows without writing any Ansible code:

- add and/or remove DevStack services
- add or modify DevStack and services configuration
- install DevStack plugins
- extend the number of sub-nodes (multinode only)
- define extra log files and/or directories to be uploaded on logs.o.o
- define extra log file extensions to be rewritten to .txt for ease of access

Tempest jobs can be further customized as follows:

- define the Tempest tox environment to be used
- define the test concurrency
- define the test regular expression

Writing Ansible code, or importing existing custom roles, jobs can be further
extended by:

- adding pre and/or post playbooks
- overriding the run playbook, add custom roles

The (partial) example below extends a Tempest single node base job
"devstack-tempest" in the Kuryr repository. The parent job name is defined in
job.parent.

.. code:: yaml

  # https://opendev.org/openstack/kuryr-kubernetes/src/branch/master/.zuul.d/base.yaml:
  - job:
      name: kuryr-kubernetes-tempest-base
      parent: devstack-tempest
      description: Base kuryr-kubernetes-job
      required-projects:
        - openstack/devstack-plugin-container
        - openstack/kuryr
        - openstack/kuryr-kubernetes
        - openstack/kuryr-tempest-plugin
        - openstack/neutron-lbaas
      vars:
        tempest_test_regex: '^(kuryr_tempest_plugin.tests.)'
        tox_envlist: 'all'
        devstack_localrc:
          KURYR_K8S_API_PORT: 8080
        devstack_services:
          kubernetes-api: true
          kubernetes-controller-manager: true
          kubernetes-scheduler: true
          kubelet: true
          kuryr-kubernetes: true
          (...)
        devstack_plugins:
          kuryr-kubernetes: https://opendev.org/openstack/kuryr
          devstack-plugin-container: https://opendev.org/openstack/devstack-plugin-container
          neutron-lbaas: https://opendev.org/openstack/neutron-lbaas
        tempest_plugins:
          - kuryr-tempest-plugin
        (...)

Job variables
=============

Variables can be added to the job in three different places:

- job.vars: these are global variables available to all node in the nodeset
- job.host-vars.[HOST]: these are variables available only to the specified HOST
- job.group-vars.[GROUP]: these are variables available only to the specified
  GROUP

Zuul merges dict variables through job inheritance. Host and group variables
override variables with the same name defined as global variables.

In the example below, for the sundaes job, hosts that are not part of the
subnode group will run vanilla and chocolate. Hosts in the subnode group will
run stracciatella and strawberry.

.. code:: yaml

  - job:
      name: ice-creams
      vars:
        devstack_service:
          vanilla: true
          chocolate: false
      group-vars:
        subnode:
          devstack_service:
            pistacchio: true
            stracciatella: true

  - job:
      name: sundaes
      parent: ice-creams
      vars:
        devstack_service:
          chocolate: true
      group-vars:
        subnode:
          devstack_service:
            strawberry: true
            pistacchio: false


DevStack Gate Flags
===================

The old CI system worked using a combination of DevStack, Tempest and
devstack-gate to setup a test environment and run tests against it. With Zuul
V3, the logic that used to live in devstack-gate is moved into different repos,
including DevStack, Tempest and grenade.

DevStack-gate exposes an interface for job definition based on a number of
DEVSTACK_GATE_* environment variables, or flags. This guide shows how to map
DEVSTACK_GATE flags into the new
system.

The repo column indicates in which repository is hosted the code that replaces
the devstack-gate flag. The new implementation column explains how to reproduce
the same or a similar behaviour in Zuul v3 jobs. For localrc settings,
devstack-gate defined a default value. In ansible jobs the default is either the
value defined in the parent job, or the default from DevStack, if any.

.. list-table:: **DevStack Gate Flags**
   :widths: 20 10 60
   :header-rows: 1

   * - DevStack gate flag
     - Repo
     - New implementation
   * - OVERRIDE_ZUUL_BRANCH
     - zuul
     - override-checkout: [branch] in the job definition.
   * - DEVSTACK_GATE_NET_OVERLAY
     - zuul-jobs
     - A bridge called br-infra is set up for all jobs that inherit
       from multinode with a dedicated `bridge role
       <https://zuul-ci.org/docs/zuul-jobs/general-roles.html#role-multi-node-bridge>`_.
   * - DEVSTACK_CINDER_VOLUME_CLEAR
     - devstack
     - *CINDER_VOLUME_CLEAR: true/false* in devstack_localrc in the
       job vars.
   * - DEVSTACK_GATE_NEUTRON
     - devstack
     - True by default. To disable, disable all neutron services in
       devstack_services in the job definition.
   * - DEVSTACK_GATE_CONFIGDRIVE
     - devstack
     - *FORCE_CONFIG_DRIVE: true/false* in devstack_localrc in the job
       vars.
   * - DEVSTACK_GATE_INSTALL_TESTONLY
     - devstack
     - *INSTALL_TESTONLY_PACKAGES: true/false* in devstack_localrc in
       the job vars.
   * - DEVSTACK_GATE_VIRT_DRIVER
     - devstack
     - *VIRT_DRIVER: [virt driver]* in devstack_localrc in the job
       vars.
   * - DEVSTACK_GATE_LIBVIRT_TYPE
     - devstack
     - *LIBVIRT_TYPE: [libvirt type]* in devstack_localrc in the job
       vars.
   * - DEVSTACK_GATE_TEMPEST
     - devstack and tempest
     - Defined by the job that is used. The ``devstack`` job only runs
       devstack. The ``devstack-tempest`` one triggers a Tempest run
       as well.
   * - DEVSTACK_GATE_TEMPEST_FULL
     - tempest
     - *tox_envlist: full* in the job vars.
   * - DEVSTACK_GATE_TEMPEST_ALL
     - tempest
     - *tox_envlist: all* in the job vars.
   * - DEVSTACK_GATE_TEMPEST_ALL_PLUGINS
     - tempest
     - *tox_envlist: all-plugin* in the job vars.
   * - DEVSTACK_GATE_TEMPEST_SCENARIOS
     - tempest
     - *tox_envlist: scenario* in the job vars.
   * - TEMPEST_CONCURRENCY
     - tempest
     - *tempest_concurrency: [value]* in the job vars. This is
       available only on jobs that inherit from ``devstack-tempest``
       down.
   * - DEVSTACK_GATE_TEMPEST_NOTESTS
     - tempest
     - *tox_envlist: venv-tempest* in the job vars. This will create
       Tempest virtual environment but run no tests.
   * - DEVSTACK_GATE_SMOKE_SERIAL
     - tempest
     - *tox_envlist: smoke-serial* in the job vars.
   * - DEVSTACK_GATE_TEMPEST_DISABLE_TENANT_ISOLATION
     - tempest
     - *tox_envlist: full-serial* in the job vars.
       *TEMPEST_ALLOW_TENANT_ISOLATION: false* in devstack_localrc in
       the job vars.


The following flags have not been migrated yet or are legacy and won't be
migrated at all.

.. list-table:: **Not Migrated DevStack Gate Flags**
   :widths: 20 10 60
   :header-rows: 1

   * - DevStack gate flag
     - Status
     - Details
   * - DEVSTACK_GATE_TOPOLOGY
     - WIP
     - The topology depends on the base job that is used and more
       specifically on the nodeset attached to it. The new job format
       allows project to define the variables to be passed to every
       node/node-group that exists in the topology. Named topologies
       that include the nodeset and the matching variables can be
       defined in the form of base jobs.
   * - DEVSTACK_GATE_GRENADE
     - TBD
     - Grenade Zuul V3 jobs will be hosted in the grenade repo.
   * - GRENADE_BASE_BRANCH
     - TBD
     - Grenade Zuul V3 jobs will be hosted in the grenade repo.
   * - DEVSTACK_GATE_NEUTRON_DVR
     - TBD
     - Depends on multinode support.
   * - DEVSTACK_GATE_EXERCISES
     - TBD
     - Can be done on request.
   * - DEVSTACK_GATE_IRONIC
     - TBD
     - This will probably be implemented on ironic side.
   * - DEVSTACK_GATE_IRONIC_DRIVER
     - TBD
     - This will probably be implemented on ironic side.
   * - DEVSTACK_GATE_IRONIC_BUILD_RAMDISK
     - TBD
     - This will probably be implemented on ironic side.
   * - DEVSTACK_GATE_POSTGRES
     - Legacy
     - This flag exists in d-g but the only thing that it does is
       capture postgres logs. This is already supported by the roles
       in post, so the flag is useless in the new jobs. postgres
       itself can be enabled via the devstack_service job variable.
   * - DEVSTACK_GATE_ZEROMQ
     - Legacy
     - This has no effect in d-g.
   * - DEVSTACK_GATE_MQ_DRIVER
     - Legacy
     - This has no effect in d-g.
   * - DEVSTACK_GATE_TEMPEST_STRESS_ARGS
     - Legacy
     - Stress is not in Tempest anymore.
   * - DEVSTACK_GATE_TEMPEST_HEAT_SLOW
     - Legacy
     - This is not used anywhere.
   * - DEVSTACK_GATE_CELLS
     - Legacy
     - This has no effect in d-g.
   * - DEVSTACK_GATE_NOVA_API_METADATA_SPLIT
     - Legacy
     - This has no effect in d-g.
