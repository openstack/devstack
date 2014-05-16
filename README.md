DevStack is a set of scripts and utilities to quickly deploy an OpenStack cloud.

# Goals

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

Read more at http://devstack.org.

IMPORTANT: Be sure to carefully read `stack.sh` and any other scripts you
execute before you run them, as they install software and will alter your
networking configuration.  We strongly recommend that you run `stack.sh`
in a clean and disposable vm when you are first getting started.

# Versions

The DevStack master branch generally points to trunk versions of OpenStack
components.  For older, stable versions, look for branches named
stable/[release] in the DevStack repo.  For example, you can do the
following to create a grizzly OpenStack cloud:

    git checkout stable/grizzly
    ./stack.sh

You can also pick specific OpenStack project releases by setting the appropriate
`*_BRANCH` variables in the ``localrc`` section of `local.conf` (look in
`stackrc` for the default set).  Usually just before a release there will be
milestone-proposed branches that need to be tested::

    GLANCE_REPO=git://git.openstack.org/openstack/glance.git
    GLANCE_BRANCH=milestone-proposed

# Start A Dev Cloud

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
cloud via CLI:

    # source openrc file to load your environment with OpenStack CLI creds
    . openrc
    # list instances
    nova list

If the EC2 API is your cup-o-tea, you can create credentials and use euca2ools:

    # source eucarc to generate EC2 credentials and set up the environment
    . eucarc
    # list instances using ec2 api
    euca-describe-instances

# DevStack Execution Environment

DevStack runs rampant over the system it runs on, installing things and
uninstalling other things.  Running this on a system you care about is a recipe
for disappointment, or worse.  Alas, we're all in the virtualization business
here, so run it in a VM.  And take advantage of the snapshot capabilities
of your hypervisor of choice to reduce testing cycle times.  You might even save
enough time to write one more feature before the next feature freeze...

``stack.sh`` needs to have root access for a lot of tasks, but uses ``sudo``
for all of those tasks.  However, it needs to be not-root for most of its
work and for all of the OpenStack services.  ``stack.sh`` specifically
does not run if started as root.

This is a recent change (Oct 2013) from the previous behaviour of
automatically creating a ``stack`` user.  Automatically creating
user accounts is not the right response to running as root, so
that bit is now an explicit step using ``tools/create-stack-user.sh``.
Run that (as root!) or just check it out to see what DevStack's
expectations are for the account it runs under.  Many people simply
use their usual login (the default 'ubuntu' login on a UEC image
for example).

# Customizing

You can override environment variables used in `stack.sh` by creating file
name `local.conf` with a ``localrc`` section as shown below.  It is likely
that you will need to do this to tweak your networking configuration should
you need to access your cloud from a different host.

    [[local|localrc]]
    VARIABLE=value

See the **Local Configuration** section below for more details.

# Database Backend

Multiple database backends are available. The available databases are defined
in the lib/databases directory.
`mysql` is the default database, choose a different one by putting the
following in the `localrc` section:

    disable_service mysql
    enable_service postgresql

`mysql` is the default database.

# RPC Backend

Multiple RPC backends are available. Currently, this
includes RabbitMQ (default), Qpid, and ZeroMQ. Your backend of
choice may be selected via the `localrc` section.

Note that selecting more than one RPC backend will result in a failure.

Example (ZeroMQ):

    ENABLED_SERVICES="$ENABLED_SERVICES,-rabbit,-qpid,zeromq"

Example (Qpid):

    ENABLED_SERVICES="$ENABLED_SERVICES,-rabbit,-zeromq,qpid"

# Apache Frontend

Apache web server is enabled for wsgi services by setting
`APACHE_ENABLED_SERVICES` in your ``localrc`` section.  Remember to
enable these services at first as above.

    APACHE_ENABLED_SERVICES+=key,swift

# Swift

Swift is disabled by default.  When enabled, it is configured with
only one replica to avoid being IO/memory intensive on a small
vm. When running with only one replica the account, container and
object services will run directly in screen. The others services like
replicator, updaters or auditor runs in background.

If you would like to enable Swift you can add this to your `localrc` section:

    enable_service s-proxy s-object s-container s-account

If you want a minimal Swift install with only Swift and Keystone you
can have this instead in your `localrc` section:

    disable_all_services
    enable_service key mysql s-proxy s-object s-container s-account

If you only want to do some testing of a real normal swift cluster
with multiple replicas you can do so by customizing the variable
`SWIFT_REPLICAS` in your `localrc` section (usually to 3).

# Swift S3

If you are enabling `swift3` in `ENABLED_SERVICES` DevStack will
install the swift3 middleware emulation. Swift will be configured to
act as a S3 endpoint for Keystone so effectively replacing the
`nova-objectstore`.

Only Swift proxy server is launched in the screen session all other
services are started in background and managed by `swift-init` tool.

# Neutron

Basic Setup

In order to enable Neutron a single node setup, you'll need the
following settings in your `local.conf`:

    disable_service n-net
    enable_service q-svc
    enable_service q-agt
    enable_service q-dhcp
    enable_service q-l3
    enable_service q-meta
    enable_service q-metering
    # Optional, to enable tempest configuration as part of DevStack
    enable_service tempest

Then run `stack.sh` as normal.

DevStack supports setting specific Neutron configuration flags to the
service, Open vSwitch plugin and LinuxBridge plugin configuration files.
To make use of this feature, the settings can be added to ``local.conf``.
The old ``Q_XXX_EXTRA_XXX_OPTS`` variables are deprecated and will be removed
in the near future.  The ``local.conf`` headers for the replacements are:

* ``Q_SRV_EXTRA_OPTS``:

    [[post-config|/$Q_PLUGIN_CONF_FILE]]
    [linuxbridge]   # or [ovs]

* ``Q_AGENT_EXTRA_AGENT_OPTS``:

    [[post-config|/$Q_PLUGIN_CONF_FILE]]
    [agent]

* ``Q_AGENT_EXTRA_SRV_OPTS``:

    [[post-config|/$Q_PLUGIN_CONF_FILE]]
    [linuxbridge]   # or [ovs]

* ``Q_SRV_EXTRA_DEFAULT_OPTS``:

    [[post-config|$NEUTRON_CONF]]
    [DEFAULT]

Example extra config in `local.conf`:

    [[post-config|/$Q_PLUGIN_CONF_FILE]]
    [agent]
    tunnel_type=vxlan
    vxlan_udp_port=8472

    [[post-config|$NEUTRON_CONF]]
    [DEFAULT]
    tenant_network_type=vxlan

DevStack also supports configuring the Neutron ML2 plugin. The ML2 plugin
can run with the OVS, LinuxBridge, or Hyper-V agents on compute hosts. This
is a simple way to configure the ml2 plugin:

    # VLAN configuration
    Q_PLUGIN=ml2
    ENABLE_TENANT_VLANS=True

    # GRE tunnel configuration
    Q_PLUGIN=ml2
    ENABLE_TENANT_TUNNELS=True

    # VXLAN tunnel configuration
    Q_PLUGIN=ml2
    Q_ML2_TENANT_NETWORK_TYPE=vxlan

The above will default in DevStack to using the OVS on each compute host.
To change this, set the `Q_AGENT` variable to the agent you want to run
(e.g. linuxbridge).

    Variable Name                    Notes
    ----------------------------------------------------------------------------
    Q_AGENT                          This specifies which agent to run with the
                                     ML2 Plugin (either `openvswitch` or `linuxbridge`).
    Q_ML2_PLUGIN_MECHANISM_DRIVERS   The ML2 MechanismDrivers to load. The default
                                     is none. Note, ML2 will work with the OVS
                                     and LinuxBridge agents by default.
    Q_ML2_PLUGIN_TYPE_DRIVERS        The ML2 TypeDrivers to load. Defaults to
                                     all available TypeDrivers.
    Q_ML2_PLUGIN_GRE_TYPE_OPTIONS    GRE TypeDriver options. Defaults to none.
    Q_ML2_PLUGIN_VXLAN_TYPE_OPTIONS  VXLAN TypeDriver options. Defaults to none.
    Q_ML2_PLUGIN_VLAN_TYPE_OPTIONS   VLAN TypeDriver options. Defaults to none.

# Heat

Heat is disabled by default. To enable it you'll need the following settings
in your `localrc` section:

    enable_service heat h-api h-api-cfn h-api-cw h-eng

Heat can also run in standalone mode, and be configured to orchestrate
on an external OpenStack cloud. To launch only Heat in standalone mode
you'll need the following settings in your `localrc` section:

    disable_all_services
    enable_service rabbit mysql heat h-api h-api-cfn h-api-cw h-eng
    HEAT_STANDALONE=True
    KEYSTONE_SERVICE_HOST=...
    KEYSTONE_AUTH_HOST=...

# Tempest

If tempest has been successfully configured, a basic set of smoke
tests can be run as follows:

    $ cd /opt/stack/tempest
    $ nosetests tempest/scenario/test_network_basic_ops.py

# DevStack on Xenserver

If you would like to use Xenserver as the hypervisor, please refer
to the instructions in `./tools/xen/README.md`.

# Additional Projects

DevStack has a hook mechanism to call out to a dispatch script at specific
points in the execution of `stack.sh`, `unstack.sh` and `clean.sh`.  This
allows upper-layer projects, especially those that the lower layer projects
have no dependency on, to be added to DevStack without modifying the core
scripts.  Tempest is built this way as an example of how to structure the
dispatch script, see `extras.d/80-tempest.sh`.  See `extras.d/README.md`
for more information.

# Multi-Node Setup

A more interesting setup involves running multiple compute nodes, with Neutron
networks connecting VMs on different compute nodes.
You should run at least one "controller node", which should have a `stackrc`
that includes at least:

    disable_service n-net
    enable_service q-svc
    enable_service q-agt
    enable_service q-dhcp
    enable_service q-l3
    enable_service q-meta
    enable_service neutron

You likely want to change your `localrc` section to run a scheduler that
will balance VMs across hosts:

    SCHEDULER=nova.scheduler.simple.SimpleScheduler

You can then run many compute nodes, each of which should have a `stackrc`
which includes the following, with the IP address of the above controller node:

    ENABLED_SERVICES=n-cpu,rabbit,g-api,neutron,q-agt
    SERVICE_HOST=[IP of controller node]
    MYSQL_HOST=$SERVICE_HOST
    RABBIT_HOST=$SERVICE_HOST
    Q_HOST=$SERVICE_HOST
    MATCHMAKER_REDIS_HOST=$SERVICE_HOST

# Cells

Cells is a new scaling option with a full spec at:
http://wiki.openstack.org/blueprint-nova-compute-cells.

To setup a cells environment add the following to your `localrc` section:

    enable_service n-cell

Be aware that there are some features currently missing in cells, one notable
one being security groups.  The exercises have been patched to disable
functionality not supported by cells.


# Local Configuration

Historically DevStack has used ``localrc`` to contain all local configuration
and customizations. More and more of the configuration variables available for
DevStack are passed-through to the individual project configuration files.
The old mechanism for this required specific code for each file and did not
scale well.  This is handled now by a master local configuration file.

# local.conf

The new config file ``local.conf`` is an extended-INI format that introduces
a new meta-section header that provides some additional information such
as a phase name and destination config filename:

    [[ <phase> | <config-file-name> ]]

where ``<phase>`` is one of a set of phase names defined by ``stack.sh``
and ``<config-file-name>`` is the configuration filename.  The filename is
eval'ed in the ``stack.sh`` context so all environment variables are
available and may be used.  Using the project config file variables in
the header is strongly suggested (see the ``NOVA_CONF`` example below).
If the path of the config file does not exist it is skipped.

The defined phases are:

* **local** - extracts ``localrc`` from ``local.conf`` before ``stackrc`` is sourced
* **post-config** - runs after the layer 2 services are configured
                    and before they are started
* **extra** - runs after services are started and before any files
              in ``extra.d`` are executed
* **post-extra** - runs after files in ``extra.d`` are executed

The file is processed strictly in sequence; meta-sections may be specified more
than once but if any settings are duplicated the last to appear in the file
will be used.

    [[post-config|$NOVA_CONF]]
    [DEFAULT]
    use_syslog = True

    [osapi_v3]
    enabled = False

A specific meta-section ``local|localrc`` is used to provide a default
``localrc`` file (actually ``.localrc.auto``).  This allows all custom
settings for DevStack to be contained in a single file.  If ``localrc``
exists it will be used instead to preserve backward-compatibility.

    [[local|localrc]]
    FIXED_RANGE=10.254.1.0/24
    ADMIN_PASSWORD=speciale
    LOGFILE=$DEST/logs/stack.sh.log

Note that ``Q_PLUGIN_CONF_FILE`` is unique in that it is assumed to *NOT*
start with a ``/`` (slash) character.  A slash will need to be added:

    [[post-config|/$Q_PLUGIN_CONF_FILE]]
