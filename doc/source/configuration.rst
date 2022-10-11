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
(``|``). Note that there are no spaces between the double brackets and the
internal fields. Likewise, there are no spaces between the pipe and the
internal fields:
::

    '[[' <phase> '|' <config-file-name> ']]'

where ``<phase>`` is one of a set of phase names defined by ``stack.sh``
and ``<config-file-name>`` is the configuration filename. The filename
is eval'ed in the ``stack.sh`` context so all environment variables are
available and may be used. Using the project config file variables in
the header is strongly suggested (see the ``NOVA_CONF`` example below).
If the path of the config file does not exist it is skipped.

The defined phases are:

-  **local** - extracts ``localrc`` from ``local.conf`` before
   ``stackrc`` is sourced
-  **post-config** - runs after the layer 2 services are configured and
   before they are started
-  **extra** - runs after services are started and before any files in
   ``extra.d`` are executed
-  **post-extra** - runs after files in ``extra.d`` are executed
-  **test-config** - runs after tempest (and plugins) are configured

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
exists it will be used instead to preserve backward-compatibility.

::

    [[local|localrc]]
    IPV4_ADDRS_SAFE_TO_USE=10.254.1.0/24
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

openrc
======

``openrc`` configures login credentials suitable for use with the
OpenStack command-line tools. ``openrc`` sources ``stackrc`` at the
beginning (which in turn sources the ``localrc`` section of
``local.conf``) in order to pick up ``HOST_IP`` and/or ``SERVICE_HOST``
to use in the endpoints. The values shown below are the default values.

OS\_PROJECT\_NAME (OS\_TENANT\_NAME)
    Keystone has
    standardized the term *project* as the entity that owns resources. In
    some places references still exist to the previous term
    *tenant* for this use. Also, *project\_name* is preferred to
    *project\_id*.  OS\_TENANT\_NAME remains supported for compatibility
    with older tools.

    ::

        OS_PROJECT_NAME=demo

OS\_USERNAME
    In addition to the owning entity (project), OpenStack calls the entity
    performing the action *user*.

    ::

        OS_USERNAME=demo

OS\_PASSWORD
    Keystone's default authentication requires a password be provided.
    The usual cautions about putting passwords in environment variables
    apply, for most DevStack uses this may be an acceptable tradeoff.

    ::

        OS_PASSWORD=secret

HOST\_IP, SERVICE\_HOST
    Set API endpoint host using ``HOST_IP``. ``SERVICE_HOST`` may also
    be used to specify the endpoint, which is convenient for some
    ``local.conf`` configurations. Typically, ``HOST_IP`` is set in the
    ``localrc`` section.

    ::

        HOST_IP=127.0.0.1
        SERVICE_HOST=$HOST_IP

OS\_AUTH\_URL
    Authenticating against an OpenStack cloud using Keystone returns a
    *Token* and *Service Catalog*. The catalog contains the endpoints
    for all services the user/tenant has access to - including Nova,
    Glance, Keystone and Swift.

    ::

        OS_AUTH_URL=http://$SERVICE_HOST:5000/v3.0

KEYSTONECLIENT\_DEBUG, NOVACLIENT\_DEBUG
    Set command-line client log level to ``DEBUG``. These are commented
    out by default.

    ::

        # export KEYSTONECLIENT_DEBUG=1
        # export NOVACLIENT_DEBUG=1



.. _minimal-configuration:

Minimal Configuration
=====================

While ``stack.sh`` is happy to run without a ``localrc`` section in
``local.conf``, devlife is better when there are a few minimal variables
set. This is an example of a minimal configuration that touches the
values that most often need to be set.

-  no logging
-  pre-set the passwords to prevent interactive prompts
-  move network ranges away from the local network (``IPV4_ADDRS_SAFE_TO_USE``
   and ``FLOATING_RANGE``, commented out below)
-  set the host IP if detection is unreliable (``HOST_IP``, commented
   out below)

::

    [[local|localrc]]
    ADMIN_PASSWORD=secret
    DATABASE_PASSWORD=$ADMIN_PASSWORD
    RABBIT_PASSWORD=$ADMIN_PASSWORD
    SERVICE_PASSWORD=$ADMIN_PASSWORD
    #IPV4_ADDRS_SAFE_TO_USE=172.31.1.0/24
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

For architecture specific configurations which differ from the x86 default
here, see `arch-configuration`_.

Historical Notes
================

Historically DevStack obtained all local configuration and
customizations from a ``localrc`` file.  In Oct 2013 the
``local.conf`` configuration method was introduced (in `review 46768
<https://review.opendev.org/#/c/46768/>`__) to simplify this
process.

Configuration Notes
===================

.. contents::
   :local:

Service Repos
-------------

The Git repositories used to check out the source for each service are
controlled by a pair of variables set for each service.  ``*_REPO``
points to the repository and ``*_BRANCH`` selects which branch to
check out. These may be overridden in ``local.conf`` to pull source
from a different repo for testing, such as a Gerrit branch
proposal. ``GIT_BASE`` points to the primary repository server.

::

    NOVA_REPO=$GIT_BASE/openstack/nova.git
    NOVA_BRANCH=master

To pull a branch directly from Gerrit, get the repo and branch from
the Gerrit review page::

    git fetch https://review.opendev.org/openstack/nova \
        refs/changes/50/5050/1 && git checkout FETCH_HEAD

The repo is the stanza following ``fetch`` and the branch is the
stanza following that::

    NOVA_REPO=https://review.opendev.org/openstack/nova
    NOVA_BRANCH=refs/changes/50/5050/1


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

.. _enable_logging:

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

    LOGDAYS=2

Some coloring is used during the DevStack runs to make it easier to
see what is going on. This can be disabled with::

    LOG_COLOR=False

When using the logfile, by default logs are sent to the console and
the file.  You can set ``VERBOSE`` to ``false`` if you only wish the
logs to be sent to the file (this may avoid having double-logging in
some cases where you are capturing the script output and the log
files).  If ``VERBOSE`` is ``true`` you can additionally set
``VERBOSE_NO_TIMESTAMP`` to avoid timestamps being added to each
output line sent to the console.  This can be useful in some
situations where the console output is being captured by a runner or
framework (e.g. Ansible) that adds its own timestamps.  Note that the
log lines sent to the ``LOGFILE`` will still be prefixed with a
timestamp.

Logging the Service Output
~~~~~~~~~~~~~~~~~~~~~~~~~~

By default, services run under ``systemd`` and are natively logging to
the systemd journal.

To query the logs use the ``journalctl`` command, such as::

  sudo journalctl --unit devstack@*

More examples can be found in :ref:`journalctl-examples`.

Example Logging Configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For example, non-interactive installs probably wish to save output to
a file, keep service logs and disable color in the stored files.

::

   [[local|localrc]]
   DEST=/opt/stack/
   LOGFILE=$LOGDIR/stack.sh.log
   LOG_COLOR=False

Database Backend
----------------

Multiple database backends are available. The available databases are defined
in the lib/databases directory.
``mysql`` is the default database, choose a different one by putting the
following in the ``localrc`` section::

  disable_service mysql
  enable_service postgresql

``mysql`` is the default database.

RPC Backend
-----------

Support for a RabbitMQ RPC backend is included. Additional RPC
backends may be available via external plugins.  Enabling or disabling
RabbitMQ is handled via the usual service functions and
``ENABLED_SERVICES``.

Example disabling RabbitMQ in ``local.conf``::

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

Example (Keystone)::

    KEYSTONE_USE_MOD_WSGI="True"

Example (Nova)::

    NOVA_USE_MOD_WSGI="True"

Example (Swift)::

    SWIFT_USE_MOD_WSGI="True"

Example (Heat)::

    HEAT_USE_MOD_WSGI="True"

Example (Cinder)::

    CINDER_USE_MOD_WSGI="True"


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

Setting the variable to ``ALL`` will activate the download for all
libraries.

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

Guest Images
------------

Images provided in URLS via the comma-separated ``IMAGE_URLS``
variable will be downloaded and uploaded to glance by DevStack.

Default guest-images are predefined for each type of hypervisor and
their testing-requirements in ``stack.sh``.  Setting
``DOWNLOAD_DEFAULT_IMAGES=False`` will prevent DevStack downloading
these default images; in that case, you will want to populate
``IMAGE_URLS`` with sufficient images to satisfy testing-requirements.

::

  DOWNLOAD_DEFAULT_IMAGES=False
  IMAGE_URLS="http://foo.bar.com/image.qcow,"
  IMAGE_URLS+="http://foo.bar.com/image2.qcow"


Instance Type
-------------

``DEFAULT_INSTANCE_TYPE`` can be used to configure the default instance
type. When this parameter is not specified, Devstack creates additional
micro & nano flavors for really small instances to run Tempest tests.

For guests with larger memory requirements, ``DEFAULT_INSTANCE_TYPE``
should be specified in the configuration file so Tempest selects the
default flavors instead.

KVM on Power with QEMU 2.4 requires 512 MB to load the firmware -
`QEMU 2.4 - PowerPC <https://wiki.qemu.org/ChangeLog/2.4>`__ so users
running instances on ppc64/ppc64le can choose one of the default
created flavors as follows:

::

  DEFAULT_INSTANCE_TYPE=m1.tiny


IP Version
----------

``IP_VERSION`` can be used to configure Neutron to create either an
IPv4, IPv6, or dual-stack self-service project data-network by with
either ``IP_VERSION=4``, ``IP_VERSION=6``, or ``IP_VERSION=4+6``
respectively.

::

  IP_VERSION=4+6

The following optional variables can be used to alter the default IPv6
behavior:

::

  IPV6_RA_MODE=slaac
  IPV6_ADDRESS_MODE=slaac
  IPV6_ADDRS_SAFE_TO_USE=fd$IPV6_GLOBAL_ID::/56
  IPV6_PRIVATE_NETWORK_GATEWAY=fd$IPV6_GLOBAL_ID::1

*Note*: ``IPV6_ADDRS_SAFE_TO_USE`` and ``IPV6_PRIVATE_NETWORK_GATEWAY``
can be configured with any valid IPv6 prefix. The default values make
use of an auto-generated ``IPV6_GLOBAL_ID`` to comply with RFC4193.

Service IP Version
~~~~~~~~~~~~~~~~~~

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
optionally be used to alter the default IPv6 address::

  HOST_IPV6=${some_local_ipv6_address}

Tunnel IP Version
~~~~~~~~~~~~~~~~~

DevStack can enable tunnel operation over either IPv4 or IPv6 by
setting ``TUNNEL_IP_VERSION`` to either ``TUNNEL_IP_VERSION=4`` or
``TUNNEL_IP_VERSION=6`` respectively.

When set to ``4`` Neutron will use an IPv4 address for tunnel endpoints,
for example, ``HOST_IP``.

When set to ``6`` Neutron will use an IPv6 address for tunnel endpoints,
for example, ``HOST_IPV6``.

The default value for this setting is ``4``.  Dual-mode support, for
example ``4+6`` is not supported, as this value must match the address
family of the local tunnel endpoint IP(v6) address.

The value of ``TUNNEL_IP_VERSION`` has a direct relationship to the
setting of ``TUNNEL_ENDPOINT_IP``, which will default to ``HOST_IP``
when set to ``4``, and ``HOST_IPV6`` when set to ``6``.

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
VM.

If you would like to enable Swift you can add this to your ``localrc``
section:

::

    enable_service s-proxy s-object s-container s-account

If you want a minimal Swift install with only Swift and Keystone you
can have this instead in your ``localrc`` section:

::

    disable_all_services
    enable_service key mysql s-proxy s-object s-container s-account

If you only want to do some testing of a real normal swift cluster
with multiple replicas you can do so by customizing the variable
``SWIFT_REPLICAS`` in your ``localrc`` section (usually to 3).

You can manually override the ring building to use specific storage
nodes, for example when you want to test a multinode environment. In
this case you have to set a space-separated list of IPs in
``SWIFT_STORAGE_IPS`` in your ``localrc`` section that should be used
as Swift storage nodes.
Please note that this does not create a multinode setup, it is only
used when adding nodes to the Swift rings.

::

    SWIFT_STORAGE_IPS="192.168.1.10 192.168.1.11 192.168.1.12"

Swift S3
++++++++

If you are enabling ``s3api`` in ``ENABLED_SERVICES`` DevStack will
install the s3api middleware emulation. Swift will be configured to
act as a S3 endpoint for Keystone so effectively replacing the
``nova-objectstore``.

Only Swift proxy server is launched in the systemd system all other
services are started in background and managed by ``swift-init`` tool.

Tempest
~~~~~~~

If tempest has been successfully configured, a basic set of smoke
tests can be run as follows:

::

    $ cd /opt/stack/tempest
    $ tox -e smoke

By default tempest is downloaded and the config file is generated, but the
tempest package is not installed in the system's global site-packages (the
package install includes installing dependences). So tempest won't run
outside of tox. If you would like to install it add the following to your
``localrc`` section:

::

    INSTALL_TEMPEST=True


Cinder
~~~~~~

The logical volume group used to hold the Cinder-managed volumes is
set by ``VOLUME_GROUP_NAME``, the logical volume name prefix is set with
``VOLUME_NAME_PREFIX`` and the size of the volume backing file is set
with ``VOLUME_BACKING_FILE_SIZE``.

::

  VOLUME_GROUP_NAME="stack-volumes"
  VOLUME_NAME_PREFIX="volume-"
  VOLUME_BACKING_FILE_SIZE=24G

When running highly concurrent tests, the default per-project quotas
for volumes, backups, or snapshots may be too small.  These can be
adjusted by setting ``CINDER_QUOTA_VOLUMES``, ``CINDER_QUOTA_BACKUPS``,
or ``CINDER_QUOTA_SNAPSHOTS`` to the desired value.  (The default for
each is 10.)


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
    REGION_NAME=RegionTwo
    KEYSTONE_REGION_NAME=RegionOne

In the devstack for RegionOne, we set REGION_NAME as RegionOne, so region of
the services started in this devstack are registered as RegionOne. In devstack
for RegionTwo, similarly, we set REGION_NAME as RegionTwo since we want
services started in this devstack to be registered in RegionTwo. But Keystone
service is started and registered in RegionOne, not RegionTwo, so we use
KEYSTONE_REGION_NAME to specify the region of Keystone service.
KEYSTONE_REGION_NAME has a default value the same as REGION_NAME thus we omit
it in the configuration of RegionOne.

Glance
++++++

The default image size quota of 1GiB may be too small if larger images
are to be used. Change the default at setup time with:

::

    GLANCE_LIMIT_IMAGE_SIZE_TOTAL=5000

or at runtime via:

::

    openstack --os-cloud devstack-system-admin registered limit update \
      --service glance --default-limit 5000 --region RegionOne image_size_total

.. _arch-configuration:

Architectures
-------------

The upstream CI runs exclusively on nodes with x86 architectures, but
OpenStack supports even more architectures. Some of them need to configure
Devstack in a certain way.

KVM on s390x (IBM z Systems)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

KVM on s390x (IBM z Systems) is supported since the *Kilo* release. For
an all-in-one setup, these minimal settings in the ``local.conf`` file
are needed::

    [[local|localrc]]
    ADMIN_PASSWORD=secret
    DATABASE_PASSWORD=$ADMIN_PASSWORD
    RABBIT_PASSWORD=$ADMIN_PASSWORD
    SERVICE_PASSWORD=$ADMIN_PASSWORD

    DOWNLOAD_DEFAULT_IMAGES=False
    IMAGE_URLS="https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-s390x-disk1.img"

    # Provide a custom etcd3 binary download URL and ints sha256.
    # The binary must be located under '/<etcd version>/etcd-<etcd-version>-linux-s390x.tar.gz'
    # on this URL.
    # Build instructions for etcd3: https://github.com/linux-on-ibm-z/docs/wiki/Building-etcd
    ETCD_DOWNLOAD_URL=<your-etcd-download-url>
    ETCD_SHA256=<your-etcd3-sha256>

    enable_service n-sproxy
    disable_service n-novnc

    [[post-config|$NOVA_CONF]]

    [serial_console]
    base_url=ws://$HOST_IP:6083/  # optional

Reasoning:

* The default image of Devstack is x86 only, so we deactivate the download
  with ``DOWNLOAD_DEFAULT_IMAGES``. The referenced guest image
  in the code above (``IMAGE_URLS``) serves as an example. The list of
  possible s390x guest images is not limited to that.

* This platform doesn't support a graphical console like VNC or SPICE.
  The technical reason is the missing framebuffer on the platform. This
  means we rely on the substitute feature *serial console* which needs the
  proxy service ``n-sproxy``. We also disable VNC's proxy ``n-novnc`` for
  that reason . The configuration in the ``post-config`` section is only
  needed if you want to use the *serial console* outside of the all-in-one
  setup.

* A link to an etcd3 binary and its sha256 needs to be provided as the
  binary for s390x is not hosted on github like it is for other
  architectures. For more details see
  https://bugs.launchpad.net/devstack/+bug/1693192. Etcd3 can easily be
  built along https://github.com/linux-on-ibm-z/docs/wiki/Building-etcd.

.. note:: To run *Tempest* against this *Devstack* all-in-one, you'll need
   to use a guest image which is smaller than 1GB when uncompressed.
   The example image from above is bigger than that!
