=============
Configuration
=============

.. contents::
   :local:
   :depth: 1

local.conf
==========

DevStack configuration is modified via the file ``local.conf``.  It is
a modified INI format file that introduces a meta-section header to
carry additional information regarding the configuration files to be
changed.

A sample is provided in ``devstack/samples``

The new header is similar to a normal INI section header but with double
brackets (``[[ ... ]]``) and two internal fields separated by a pipe
(``|``):

::

    [[ <phase> | <config-file-name> ]]

where ``<phase>`` is one of a set of phase names defined by ``stack.sh``
and ``<config-file-name>`` is the configuration filename. The filename
is eval'ed in the ``stack.sh`` context so all environment variables are
available and may be used. Using the project config file variables in
the header is strongly suggested (see the ``NOVA_CONF`` example below).
If the path of the config file does not exist it is skipped.

The defined phases are:

-  **local** - extracts ``localrc`` from ``local.conf`` before
   ``stackrc`` is sourced
-  **pre-install** - runs after the system packages are installed but
   before any of the source repositories are installed
-  **install** - runs immediately after the repo installations are
   complete
-  **post-config** - runs after the layer 2 services are configured and
   before they are started
-  **extra** - runs after services are started and before any files in
   ``extra.d`` are executed

The file is processed strictly in sequence; meta-sections may be
specified more than once but if any settings are duplicated the last to
appear in the file will be used.

::

    [[post-config|$NOVA_CONF]]
    [DEFAULT]
    use_syslog = True

    [osapi_v3]
    enabled = False

A specific meta-section ``local|localrc`` is used to provide a default
``localrc`` file (actually ``.localrc.auto``). This allows all custom
settings for DevStack to be contained in a single file. If ``localrc``
exists it will be used instead to preserve backward-compatibility. More
details on the :doc:`contents of local.conf <local.conf>` are available.

::

    [[local|localrc]]
    FIXED_RANGE=10.254.1.0/24
    ADMIN_PASSWORD=speciale
    LOGFILE=$DEST/logs/stack.sh.log

Note that ``Q_PLUGIN_CONF_FILE`` is unique in that it is assumed to
*NOT* start with a ``/`` (slash) character. A slash will need to be
added:

::

    [[post-config|/$Q_PLUGIN_CONF_FILE]]

Also note that the ``localrc`` section is sourced as a shell script
fragment and MUST conform to the shell requirements, specifically no
whitespace around ``=`` (equals).

.. _minimal-configuration:

Minimal Configuration
=====================

While ``stack.sh`` is happy to run without a ``localrc`` section in
``local.conf``, devlife is better when there are a few minimal variables
set. This is an example of a minimal configuration that touches the
values that most often need to be set.

-  no logging
-  pre-set the passwords to prevent interactive prompts
-  move network ranges away from the local network (``FIXED_RANGE`` and
   ``FLOATING_RANGE``, commented out below)
-  set the host IP if detection is unreliable (``HOST_IP``, commented
   out below)

::

    [[local|localrc]]
    ADMIN_PASSWORD=secrete
    DATABASE_PASSWORD=$ADMIN_PASSWORD
    RABBIT_PASSWORD=$ADMIN_PASSWORD
    SERVICE_PASSWORD=$ADMIN_PASSWORD
    SERVICE_TOKEN=a682f596-76f3-11e3-b3b2-e716f9080d50
    #FIXED_RANGE=172.31.1.0/24
    #FLOATING_RANGE=192.168.20.0/25
    #HOST_IP=10.3.4.5

If the ``*_PASSWORD`` variables are not set here you will be prompted to
enter values for them by ``stack.sh``.

The network ranges must not overlap with any networks in use on the
host. Overlap is not uncommon as RFC-1918 'private' ranges are commonly
used for both the local networking and Nova's fixed and floating ranges.

``HOST_IP`` is normally detected on the first run of ``stack.sh`` but
often is indeterminate on later runs due to the IP being moved from an
Ethernet interface to a bridge on the host. Setting it here also makes it
available for ``openrc`` to set ``OS_AUTH_URL``. ``HOST_IP`` is not set
by default.

``HOST_IPV6`` is normally detected on the first run of ``stack.sh`` but
will not be set if there is no IPv6 address on the default Ethernet interface.
Setting it here also makes it available for ``openrc`` to set ``OS_AUTH_URL``.
``HOST_IPV6`` is not set by default.

Historical Notes
================

Historically DevStack obtained all local configuration and
customizations from a ``localrc`` file.  In Oct 2013 the
``local.conf`` configuration method was introduced (in `review 46768
<https://review.openstack.org/#/c/46768/>`__) to simplify this
process.

Configuration Notes
===================

.. contents::
   :local:

Installation Directory
----------------------

The DevStack install directory is set by the ``DEST`` variable.  By
default it is ``/opt/stack``.

By setting it early in the ``localrc`` section you can reference it in
later variables.  It can be useful to set it even though it is not
changed from the default value.

    ::

        DEST=/opt/stack

Logging
-------

Enable Logging
~~~~~~~~~~~~~~

By default ``stack.sh`` output is only written to the console where it
runs. It can be sent to a file in addition to the console by setting
``LOGFILE`` to the fully-qualified name of the destination log file. A
timestamp will be appended to the given filename for each run of
``stack.sh``.

    ::

        LOGFILE=$DEST/logs/stack.sh.log

Old log files are cleaned automatically if ``LOGDAYS`` is set to the
number of days of old log files to keep.

    ::

        LOGDAYS=1

The some of the project logs (Nova, Cinder, etc) will be colorized by
default (if ``SYSLOG`` is not set below); this can be turned off by
setting ``LOG_COLOR`` to ``False``.

    ::

        LOG_COLOR=False

Logging the Service Output
~~~~~~~~~~~~~~~~~~~~~~~~~~

DevStack will log the ``stdout`` output of the services it starts.
When using ``screen`` this logs the output in the screen windows to a
file.  Without ``screen`` this simply redirects stdout of the service
process to a file in ``LOGDIR``.

    ::

        LOGDIR=$DEST/logs

*Note the use of ``DEST`` to locate the main install directory; this
is why we suggest setting it in ``local.conf``.*

Enabling Syslog
~~~~~~~~~~~~~~~

Logging all services to a single syslog can be convenient. Enable
syslogging by setting ``SYSLOG`` to ``True``. If the destination log
host is not localhost ``SYSLOG_HOST`` and ``SYSLOG_PORT`` can be used
to direct the message stream to the log host.  |

    ::

        SYSLOG=True
        SYSLOG_HOST=$HOST_IP
        SYSLOG_PORT=516


Example Logging Configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For example, non-interactive installs probably wish to save output to
a file, keep service logs and disable color in the stored files.

   ::

       [[local|localrc]]
       DEST=/opt/stack/
       LOGDIR=$DEST/logs
       LOGFILE=$LOGDIR/stack.sh.log
       LOG_COLOR=False

Database Backend
----------------

Multiple database backends are available. The available databases are defined
in the lib/databases directory.
`mysql` is the default database, choose a different one by putting the
following in the `localrc` section:

   ::

      disable_service mysql
      enable_service postgresql

`mysql` is the default database.

RPC Backend
-----------

Support for a RabbitMQ RPC backend is included. Additional RPC
backends may be available via external plugins.  Enabling or disabling
RabbitMQ is handled via the usual service functions and
``ENABLED_SERVICES``.

Example disabling RabbitMQ in ``local.conf``:

::
    disable_service rabbit


Apache Frontend
---------------

The Apache web server can be enabled for wsgi services that support
being deployed under HTTPD + mod_wsgi. By default, services that
recommend running under HTTPD + mod_wsgi are deployed under Apache. To
use an alternative deployment strategy (e.g. eventlet) for services
that support an alternative to HTTPD + mod_wsgi set
``ENABLE_HTTPD_MOD_WSGI_SERVICES`` to ``False`` in your
``local.conf``.

Each service that can be run under HTTPD + mod_wsgi also has an
override toggle available that can be set in your ``local.conf``.

Keystone is run under Apache with ``mod_wsgi`` by default.

Example (Keystone)

::

    KEYSTONE_USE_MOD_WSGI="True"

Example (Nova):

::

    NOVA_USE_MOD_WSGI="True"

Example (Swift):

::

    SWIFT_USE_MOD_WSGI="True"



Libraries from Git
------------------

By default devstack installs OpenStack server components from git,
however it installs client libraries from released versions on pypi.
This is appropriate if you are working on server development, but if
you want to see how an unreleased version of the client affects the
system you can have devstack install it from upstream, or from local
git trees by specifying it in ``LIBS_FROM_GIT``.  Multiple libraries
can be specified as a comma separated list.

   ::

      LIBS_FROM_GIT=python-keystoneclient,oslo.config

Virtual Environments
--------------------

Enable the use of Python virtual environments by setting ``USE_VENV``
to ``True``.  This will enable the creation of venvs for each project
that is defined in the ``PROJECT_VENV`` array.

Each entry in the ``PROJECT_VENV`` array contains the directory name
of a venv to be used for the project.  The array index is the project
name.  Multiple projects can use the same venv if desired.

  ::

    PROJECT_VENV["glance"]=${GLANCE_DIR}.venv

``ADDITIONAL_VENV_PACKAGES`` is a comma-separated list of additional
packages to be installed into each venv.  Often projects will not have
certain packages listed in its ``requirements.txt`` file because they
are 'optional' requirements, i.e. only needed for certain
configurations.  By default, the enabled databases will have their
Python bindings added when they are enabled.

  ::

     ADDITIONAL_VENV_PACKAGES="python-foo, python-bar"


A clean install every time
--------------------------

By default ``stack.sh`` only clones the project repos if they do not
exist in ``$DEST``. ``stack.sh`` will freshen each repo on each run if
``RECLONE`` is set to ``yes``. This avoids having to manually remove
repos in order to get the current branch from ``$GIT_BASE``.

    ::

        RECLONE=yes

Upgrade packages installed by pip
---------------------------------

By default ``stack.sh`` only installs Python packages if no version is
currently installed or the current version does not match a specified
requirement. If ``PIP_UPGRADE`` is set to ``True`` then existing
required Python packages will be upgraded to the most recent version
that matches requirements.

    ::

        PIP_UPGRADE=True


Service Catalog Backend
-----------------------

By default DevStack uses Keystone's ``sql`` service catalog backend.
An alternate ``template`` backend is also available, however, it does
not support the ``service-*`` and ``endpoint-*`` commands of the
``keystone`` CLI.  To do so requires the ``sql`` backend be enabled
with ``KEYSTONE_CATALOG_BACKEND``:

    ::

        KEYSTONE_CATALOG_BACKEND=template

DevStack's default configuration in ``sql`` mode is set in
``files/keystone_data.sh``


IP Version
----------

``IP_VERSION`` can be used to configure DevStack to create either an
IPv4, IPv6, or dual-stack tenant data-network by with either
``IP_VERSION=4``, ``IP_VERSION=6``, or ``IP_VERSION=4+6``
respectively.  This functionality requires that the Neutron networking
service is enabled by setting the following options:

    ::

        disable_service n-net
        enable_service q-svc q-agt q-dhcp q-l3

The following optional variables can be used to alter the default IPv6
behavior:

    ::

        IPV6_RA_MODE=slaac
        IPV6_ADDRESS_MODE=slaac
        FIXED_RANGE_V6=fd$IPV6_GLOBAL_ID::/64
        IPV6_PRIVATE_NETWORK_GATEWAY=fd$IPV6_GLOBAL_ID::1

*Note*: ``FIXED_RANGE_V6`` and ``IPV6_PRIVATE_NETWORK_GATEWAY`` can be
configured with any valid IPv6 prefix. The default values make use of
an auto-generated ``IPV6_GLOBAL_ID`` to comply with RFC4193.

Service Version
~~~~~~~~~~~~~~~

DevStack can enable service operation over either IPv4 or IPv6 by
setting ``SERVICE_IP_VERSION`` to either ``SERVICE_IP_VERSION=4`` or
``SERVICE_IP_VERSION=6`` respectively.

When set to ``4`` devstack services will open listen sockets on
``0.0.0.0`` and service endpoints will be registered using ``HOST_IP``
as the address.

When set to ``6`` devstack services will open listen sockets on ``::``
and service endpoints will be registered using ``HOST_IPV6`` as the
address.

The default value for this setting is ``4``.  Dual-mode support, for
example ``4+6`` is not currently supported.  ``HOST_IPV6`` can
optionally be used to alter the default IPv6 address

    ::

        HOST_IPV6=${some_local_ipv6_address}

Multi-node setup
~~~~~~~~~~~~~~~~

See the :doc:`multi-node lab guide<guides/multinode-lab>`

Projects
--------

Neutron
~~~~~~~

See the :doc:`neutron configuration guide<guides/neutron>` for
details on configuration of Neutron


Swift
~~~~~

Swift is disabled by default.  When enabled, it is configured with
only one replica to avoid being IO/memory intensive on a small
VM. When running with only one replica the account, container and
object services will run directly in screen. The others services like
replicator, updaters or auditor runs in background.

If you would like to enable Swift you can add this to your `localrc`
section:

::

    enable_service s-proxy s-object s-container s-account

If you want a minimal Swift install with only Swift and Keystone you
can have this instead in your `localrc` section:

::

    disable_all_services
    enable_service key mysql s-proxy s-object s-container s-account

If you only want to do some testing of a real normal swift cluster
with multiple replicas you can do so by customizing the variable
`SWIFT_REPLICAS` in your `localrc` section (usually to 3).

Swift S3
++++++++

If you are enabling `swift3` in `ENABLED_SERVICES` DevStack will
install the swift3 middleware emulation. Swift will be configured to
act as a S3 endpoint for Keystone so effectively replacing the
`nova-objectstore`.

Only Swift proxy server is launched in the screen session all other
services are started in background and managed by `swift-init` tool.

Heat
~~~~

Heat is disabled by default (see `stackrc` file). To enable it
explicitly you'll need the following settings in your `localrc`
section

::

    enable_service heat h-api h-api-cfn h-api-cw h-eng

Heat can also run in standalone mode, and be configured to orchestrate
on an external OpenStack cloud. To launch only Heat in standalone mode
you'll need the following settings in your `localrc` section

::

    disable_all_services
    enable_service rabbit mysql heat h-api h-api-cfn h-api-cw h-eng
    HEAT_STANDALONE=True
    KEYSTONE_SERVICE_HOST=...
    KEYSTONE_AUTH_HOST=...

Tempest
~~~~~~~

If tempest has been successfully configured, a basic set of smoke
tests can be run as follows:

::

    $ cd /opt/stack/tempest
    $ tox -efull  tempest.scenario.test_network_basic_ops

By default tempest is downloaded and the config file is generated, but the
tempest package is not installed in the system's global site-packages (the
package install includes installing dependences). So tempest won't run
outside of tox. If you would like to install it add the following to your
``localrc`` section:

::

    INSTALL_TEMPEST=True


Xenserver
~~~~~~~~~

If you would like to use Xenserver as the hypervisor, please refer to
the instructions in `./tools/xen/README.md`.

Cells
~~~~~

`Cells <http://wiki.openstack.org/blueprint-nova-compute-cells>`__ is
an alternative scaling option.  To setup a cells environment add the
following to your `localrc` section:

::

    enable_service n-cell

Be aware that there are some features currently missing in cells, one
notable one being security groups.  The exercises have been patched to
disable functionality not supported by cells.

Cinder
~~~~~~

The logical volume group used to hold the Cinder-managed volumes is
set by ``VOLUME_GROUP``, the logical volume name prefix is set with
``VOLUME_NAME_PREFIX`` and the size of the volume backing file is set
with ``VOLUME_BACKING_FILE_SIZE``.

    ::

        VOLUME_GROUP="stack-volumes"
        VOLUME_NAME_PREFIX="volume-"
        VOLUME_BACKING_FILE_SIZE=10250M


Keystone
~~~~~~~~

Multi-Region Setup
++++++++++++++++++

We want to setup two devstack (RegionOne and RegionTwo) with shared
keystone (same users and services) and horizon.  Keystone and Horizon
will be located in RegionOne.  Full spec is available at:
`<https://wiki.openstack.org/wiki/Heat/Blueprints/Multi_Region_Support_for_Heat>`__.

In RegionOne:

::

    REGION_NAME=RegionOne

In RegionTwo:

::
   
    disable_service horizon
    KEYSTONE_SERVICE_HOST=<KEYSTONE_IP_ADDRESS_FROM_REGION_ONE>
    KEYSTONE_AUTH_HOST=<KEYSTONE_IP_ADDRESS_FROM_REGION_ONE>
    REGION_NAME=RegionTwo
