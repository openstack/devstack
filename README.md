DevStack is a set of scripts and utilities to quickly deploy an OpenStack cloud.

# Goals

* To quickly build dev OpenStack environments in a clean Ubuntu or Fedora environment
* To describe working configurations of OpenStack (which code branches work together?  what do config files look like for those branches?)
* To make it easier for developers to dive into OpenStack so that they can productively contribute without having to understand every part of the system at once
* To make it easy to prototype cross-project features
* To sanity-check OpenStack builds (used in gating commits to the primary repos)

Read more at http://devstack.org (built from the gh-pages branch)

IMPORTANT: Be sure to carefully read `stack.sh` and any other scripts you execute before you run them, as they install software and may alter your networking configuration.  We strongly recommend that you run `stack.sh` in a clean and disposable vm when you are first getting started.

# Devstack on Xenserver

If you would like to use Xenserver as the hypervisor, please refer to the instructions in `./tools/xen/README.md`.

# Versions

The devstack master branch generally points to trunk versions of OpenStack components.  For older, stable versions, look for branches named stable/[release] in the DevStack repo.  For example, you can do the following to create a diablo OpenStack cloud:

    git checkout stable/diablo
    ./stack.sh

You can also pick specific OpenStack project releases by setting the appropriate `*_BRANCH` variables in `localrc` (look in `stackrc` for the default set).  Usually just before a release there will be milestone-proposed branches that need to be tested::

    GLANCE_REPO=https://github.com/openstack/glance.git
    GLANCE_BRANCH=milestone-proposed

# Start A Dev Cloud

Installing in a dedicated disposable vm is safer than installing on your dev machine!  To start a dev cloud:

    ./stack.sh

When the script finishes executing, you should be able to access OpenStack endpoints, like so:

* Horizon: http://myhost/
* Keystone: http://myhost:5000/v2.0/

We also provide an environment file that you can use to interact with your cloud via CLI:

    # source openrc file to load your environment with osapi and ec2 creds
    . openrc
    # list instances
    nova list

If the EC2 API is your cup-o-tea, you can create credentials and use euca2ools:

    # source eucarc to generate EC2 credentials and set up the environment
    . eucarc
    # list instances using ec2 api
    euca-describe-instances

# Customizing

You can override environment variables used in `stack.sh` by creating file name `localrc`.  It is likely that you will need to do this to tweak your networking configuration should you need to access your cloud from a different host.

# Database Backend

Multiple database backends are available. The available databases are defined in the lib/databases directory.
`mysql` is the default database, choose a different one by putting the following in `localrc`:

    disable_service mysql
    enable_service postgresql

`mysql` is the default database.

# RPC Backend

Multiple RPC backends are available. Currently, this
includes RabbitMQ (default), Qpid, and ZeroMQ. Your backend of
choice may be selected via the `localrc`.

Note that selecting more than one RPC backend will result in a failure.

Example (ZeroMQ):

    ENABLED_SERVICES="$ENABLED_SERVICES,-rabbit,-qpid,zeromq"

Example (Qpid):

    ENABLED_SERVICES="$ENABLED_SERVICES,-rabbit,-zeromq,qpid"

# Swift

Swift is enabled by default configured with only one replica to avoid being IO/memory intensive on a small vm. When running with only one replica the account, container and object services will run directly in screen. The others services like replicator, updaters or auditor runs in background.

If you would like to disable Swift you can add this to your `localrc` :

    disable_service s-proxy s-object s-container s-account

If you want a minimal Swift install with only Swift and Keystone you can have this instead in your `localrc`:

    disable_all_services
    enable_service key mysql s-proxy s-object s-container s-account

If you only want to do some testing of a real normal swift cluster with multiple replicas you can do so by customizing the variable `SWIFT_REPLICAS` in your `localrc` (usually to 3).

# Swift S3

If you are enabling `swift3` in `ENABLED_SERVICES` devstack will install the swift3 middleware emulation. Swift will be configured to act as a S3 endpoint for Keystone so effectively replacing the `nova-objectstore`.

Only Swift proxy server is launched in the screen session all other services are started in background and managed by `swift-init` tool.

# Quantum

Basic Setup

In order to enable Quantum a single node setup, you'll need the following settings in your `localrc` :

    disable_service n-net
    enable_service q-svc
    enable_service q-agt
    enable_service q-dhcp
    enable_service q-l3
    enable_service q-meta
    enable_service quantum
    # Optional, to enable tempest configuration as part of devstack
    enable_service tempest

Then run `stack.sh` as normal.

# Tempest

If tempest has been successfully configured, a basic set of smoke tests can be run as follows:

    $ cd /opt/stack/tempest
    $ nosetests tempest/tests/network/test_network_basic_ops.py

# Multi-Node Setup

A more interesting setup involves running multiple compute nodes, with Quantum networks connecting VMs on different compute nodes.
You should run at least one "controller node", which should have a `stackrc` that includes at least:

    disable_service n-net
    enable_service q-svc
    enable_service q-agt
    enable_service q-dhcp
    enable_service q-l3
    enable_service q-meta
    enable_service quantum

You likely want to change your `localrc` to run a scheduler that will balance VMs across hosts:

    SCHEDULER=nova.scheduler.simple.SimpleScheduler

You can then run many compute nodes, each of which should have a `stackrc` which includes the following, with the IP address of the above controller node:

    ENABLED_SERVICES=n-cpu,rabbit,g-api,quantum,q-agt
    SERVICE_HOST=[IP of controller node]
    MYSQL_HOST=$SERVICE_HOST
    RABBIT_HOST=$SERVICE_HOST
    Q_HOST=$SERVICE_HOST
    MATCHMAKER_REDIS_HOST=$SERVICE_HOST

# Cells

Cells is a new scaling option with a full spec at http://wiki.openstack.org/blueprint-nova-compute-cells.

To setup a cells environment add the following to your `localrc`:

    enable_service n-cell
    enable_service n-api-meta
    MULTI_HOST=True

    # The following have not been tested with cells, they may or may not work.
    disable_service n-obj
    disable_service cinder
    disable_service c-sch
    disable_service c-api
    disable_service c-vol
    disable_service n-xvnc

Be aware that there are some features currently missing in cells, one notable one being security groups.
