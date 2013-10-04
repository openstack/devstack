DevStack is a set of scripts and utilities to quickly deploy an OpenStack cloud.

# Goals

* To quickly build dev OpenStack environments in a clean Ubuntu or Fedora environment
* To describe working configurations of OpenStack (which code branches work together?  what do config files look like for those branches?)
* To make it easier for developers to dive into OpenStack so that they can productively contribute without having to understand every part of the system at once
* To make it easy to prototype cross-project features
* To sanity-check OpenStack builds (used in gating commits to the primary repos)

Read more at http://devstack.org (built from the gh-pages branch)

IMPORTANT: Be sure to carefully read `stack.sh` and any other scripts you execute before you run them, as they install software and may alter your networking configuration.  We strongly recommend that you run `stack.sh` in a clean and disposable vm when you are first getting started.

# DevStack on Xenserver

If you would like to use Xenserver as the hypervisor, please refer to the instructions in `./tools/xen/README.md`.

# DevStack on Docker

If you would like to use Docker as the hypervisor, please refer to the instructions in `./tools/docker/README.md`.

# Versions

The devstack master branch generally points to trunk versions of OpenStack components.  For older, stable versions, look for branches named stable/[release] in the DevStack repo.  For example, you can do the following to create a diablo OpenStack cloud:

    git checkout stable/diablo
    ./stack.sh

You can also pick specific OpenStack project releases by setting the appropriate `*_BRANCH` variables in `localrc` (look in `stackrc` for the default set).  Usually just before a release there will be milestone-proposed branches that need to be tested::

    GLANCE_REPO=https://github.com/openstack/glance.git
    GLANCE_BRANCH=milestone-proposed

# Start A Dev Cloud

Installing in a dedicated disposable vm is safer than installing on your dev machine!  Plus you can pick one of the supported Linux distros for your VM.  To start a dev cloud run the following NOT AS ROOT (see below for more):

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

# DevStack Execution Environment

DevStack runs rampant over the system it runs on, installing things and uninstalling other things.  Running this on a system you care about is a recipe for disappointment, or worse.  Alas, we're all in the virtualization business here, so run it in a VM.  And take advantage of the snapshot capabilities of your hypervisor of choice to reduce testing cycle times.  You might even save enough time to write one more feature before the next feature freeze...

``stack.sh`` needs to have root access for a lot of tasks, but it also needs to have not-root permissions for most of its work and for all of the OpenStack services.  So ``stack.sh`` specifically does not run if you are root. This is a recent change (Oct 2013) from the previous behaviour of automatically creating a ``stack`` user.  Automatically creating a user account is not always the right response to running as root, so that bit is now an explicit step using ``tools/create-stack-user.sh``.  Run that (as root!) if you do not want to just use your normal login here, which works perfectly fine.

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

# Apache Frontend

Apache web server is enabled for wsgi services by setting `APACHE_ENABLED_SERVICES` in your localrc. But remember to enable these services at first as above.

Example:
    APACHE_ENABLED_SERVICES+=keystone,swift

# Swift

Swift is disabled by default.  When enabled, it is configured with
only one replica to avoid being IO/memory intensive on a small
vm. When running with only one replica the account, container and
object services will run directly in screen. The others services like
replicator, updaters or auditor runs in background.

If you would like to enable Swift you can add this to your `localrc` :

    enable_service s-proxy s-object s-container s-account

If you want a minimal Swift install with only Swift and Keystone you
can have this instead in your `localrc`:

    disable_all_services
    enable_service key mysql s-proxy s-object s-container s-account

If you only want to do some testing of a real normal swift cluster
with multiple replicas you can do so by customizing the variable
`SWIFT_REPLICAS` in your `localrc` (usually to 3).

# Swift S3

If you are enabling `swift3` in `ENABLED_SERVICES` devstack will
install the swift3 middleware emulation. Swift will be configured to
act as a S3 endpoint for Keystone so effectively replacing the
`nova-objectstore`.

Only Swift proxy server is launched in the screen session all other
services are started in background and managed by `swift-init` tool.

# Neutron

Basic Setup

In order to enable Neutron a single node setup, you'll need the
following settings in your `localrc` :

    disable_service n-net
    enable_service q-svc
    enable_service q-agt
    enable_service q-dhcp
    enable_service q-l3
    enable_service q-meta
    enable_service neutron
    # Optional, to enable tempest configuration as part of devstack
    enable_service tempest

Then run `stack.sh` as normal.

devstack supports adding specific Neutron configuration flags to the service, Open vSwitch plugin and LinuxBridge plugin configuration files. To make use of this feature, the following variables are defined and can be configured in your `localrc` file:

    Variable Name             Config File  Section Modified
    -------------------------------------------------------------------------------------
    Q_SRV_EXTRA_OPTS          Plugin       `OVS` (for Open Vswitch) or `LINUX_BRIDGE` (for LinuxBridge)
    Q_AGENT_EXTRA_AGENT_OPTS  Plugin       AGENT
    Q_AGENT_EXTRA_SRV_OPTS    Plugin       `OVS` (for Open Vswitch) or `LINUX_BRIDGE` (for LinuxBridge)
    Q_SRV_EXTRA_DEFAULT_OPTS  Service      DEFAULT

An example of using the variables in your `localrc` is below:

    Q_AGENT_EXTRA_AGENT_OPTS=(tunnel_type=vxlan vxlan_udp_port=8472)
    Q_SRV_EXTRA_OPTS=(tenant_network_type=vxlan)

devstack also supports configuring the Neutron ML2 plugin. The ML2 plugin can run with the OVS, LinuxBridge, or Hyper-V agents on compute hosts. A simple way to configure the ml2 plugin is shown below:

    # VLAN configuration
    Q_PLUGIN=ml2
    ENABLE_TENANT_VLANS=True

    # GRE tunnel configuration
    Q_PLUGIN=ml2
    ENABLE_TENANT_TUNNELS=True

    # VXLAN tunnel configuration
    Q_PLUGIN=ml2
    Q_ML2_TENANT_NETWORK_TYPE=vxlan

The above will default in devstack to using the OVS on each compute host. To change this, set the `Q_AGENT` variable to the agent you want to run (e.g. linuxbridge).

    Variable Name                    Notes
    -------------------------------------------------------------------------------------
    Q_AGENT                          This specifies which agent to run with the ML2 Plugin (either `openvswitch` or `linuxbridge`).
    Q_ML2_PLUGIN_MECHANISM_DRIVERS   The ML2 MechanismDrivers to load. The default is none. Note, ML2 will work with the OVS and LinuxBridge agents by default.
    Q_ML2_PLUGIN_TYPE_DRIVERS        The ML2 TypeDrivers to load. Defaults to all available TypeDrivers.
    Q_ML2_PLUGIN_GRE_TYPE_OPTIONS    GRE TypeDriver options. Defaults to none.
    Q_ML2_PLUGIN_VXLAN_TYPE_OPTIONS  VXLAN TypeDriver options. Defaults to none.
    Q_ML2_PLUGIN_VLAN_TYPE_OPTIONS   VLAN TypeDriver options. Defaults to none.
    Q_AGENT_EXTRA_AGENT_OPTS         Extra configuration options to pass to the OVS or LinuxBridge Agent.

# Heat

Heat is disabled by default. To enable it you'll need the following settings
in your `localrc` :

    enable_service heat h-api h-api-cfn h-api-cw h-eng

Heat can also run in standalone mode, and be configured to orchestrate
on an external OpenStack cloud. To launch only Heat in standalone mode
you'll need the following settings in your `localrc` :

    disable_all_services
    enable_service rabbit mysql heat h-api h-api-cfn h-api-cw h-eng
    HEAT_STANDALONE=True
    KEYSTONE_SERVICE_HOST=...
    KEYSTONE_AUTH_HOST=...

# Tempest

If tempest has been successfully configured, a basic set of smoke tests can be run as follows:

    $ cd /opt/stack/tempest
    $ nosetests tempest/scenario/test_network_basic_ops.py

# Multi-Node Setup

A more interesting setup involves running multiple compute nodes, with Neutron networks connecting VMs on different compute nodes.
You should run at least one "controller node", which should have a `stackrc` that includes at least:

    disable_service n-net
    enable_service q-svc
    enable_service q-agt
    enable_service q-dhcp
    enable_service q-l3
    enable_service q-meta
    enable_service neutron

You likely want to change your `localrc` to run a scheduler that will balance VMs across hosts:

    SCHEDULER=nova.scheduler.simple.SimpleScheduler

You can then run many compute nodes, each of which should have a `stackrc` which includes the following, with the IP address of the above controller node:

    ENABLED_SERVICES=n-cpu,rabbit,g-api,neutron,q-agt
    SERVICE_HOST=[IP of controller node]
    MYSQL_HOST=$SERVICE_HOST
    RABBIT_HOST=$SERVICE_HOST
    Q_HOST=$SERVICE_HOST
    MATCHMAKER_REDIS_HOST=$SERVICE_HOST

# Cells

Cells is a new scaling option with a full spec at http://wiki.openstack.org/blueprint-nova-compute-cells.

To setup a cells environment add the following to your `localrc`:

    enable_service n-cell

Be aware that there are some features currently missing in cells, one notable one being security groups.  The exercises have been patched to disable functionality not supported by cells.
