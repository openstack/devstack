=============
Configuration
=============

DevStack has always tried to be mostly-functional with a minimal amount
of configuration. The number of options has ballooned as projects add
features, new projects added and more combinations need to be tested.
Historically DevStack obtained all local configuration and
customizations from a ``localrc`` file. The number of configuration
variables that are simply passed-through to the individual project
configuration files is also increasing. The old mechanism for this
(``EXTRAS_OPTS`` and friends) required specific code for each file and
did not scale well.

In Oct 2013 a new configuration method was introduced (in `review
46768 <https://review.openstack.org/#/c/46768/>`__) to hopefully
simplify this process and meet the following goals:

-  contain all non-default local configuration in a single file
-  be backward-compatible with ``localrc`` to smooth the transition
   process
-  allow settings in arbitrary configuration files to be changed

local.conf
~~~~~~~~~~

The new configuration file is ``local.conf`` and resides in the root
DevStack directory like the old ``localrc`` file. It is a modified INI
format file that introduces a meta-section header to carry additional
information regarding the configuration files to be changed.

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
details on the `contents of localrc <localrc.html>`__ are available.

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
fragment amd MUST conform to the shell requirements, specifically no
whitespace around ``=`` (equals).

Minimal Configuration
~~~~~~~~~~~~~~~~~~~~~

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
Ethernet integace to a bridge on the host. Setting it here also makes it
available for ``openrc`` to set ``OS_AUTH_URL``. ``HOST_IP`` is not set
by default.

Common Configuration Variables
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Set DevStack install directory
    | *Default: ``DEST=/opt/stack``*
    |  The DevStack install directory is set by the ``DEST`` variable.
    |  By setting it early in the ``localrc`` section you can reference it
       in later variables. It can be useful to set it even though it is not
       changed from the default value.
    |

    ::

        DEST=/opt/stack

stack.sh logging
    | *Defaults: ``LOGFILE="" LOGDAYS=7 LOG_COLOR=True``*
    |  By default ``stack.sh`` output is only written to the console
       where is runs. It can be sent to a file in addition to the console
       by setting ``LOGFILE`` to the fully-qualified name of the
       destination log file. A timestamp will be appended to the given
       filename for each run of ``stack.sh``.
    |

    ::

        LOGFILE=$DEST/logs/stack.sh.log

    Old log files are cleaned automatically if ``LOGDAYS`` is set to the
    number of days of old log files to keep.

    ::

        LOGDAYS=1

    The some of the project logs (Nova, Cinder, etc) will be colorized
    by default (if ``SYSLOG`` is not set below); this can be turned off
    by setting ``LOG_COLOR`` False.

    ::

        LOG_COLOR=False

Screen logging
    | *Default: ``SCREEN_LOGDIR=""``*
    |  By default DevStack runs the OpenStack services using ``screen``
       which is useful for watching log and debug output. However, in
       automated testing the interactive ``screen`` sessions may not be
       available after the fact; setting ``SCREEN_LOGDIR`` enables logging
       of the ``screen`` sessions in the specified diretory. There will be
       one file per ``screen`` session named for the session name and a
       timestamp.
    |

    ::

        SCREEN_LOGDIR=$DEST/logs/screen

    *Note the use of ``DEST`` to locate the main install directory; this
    is why we suggest setting it in ``local.conf``.*

One syslog to bind them all
    | *Default: ``SYSLOG=False SYSLOG_HOST=$HOST_IP SYSLOG_PORT=516``*
    |  Logging all services to a single syslog can be convenient. Enable
       syslogging by setting ``SYSLOG`` to ``True``. If the destination log
       host is not localhost ``SYSLOG_HOST`` and ``SYSLOG_PORT`` can be
       used to direct the message stream to the log host.
    |

    ::

        SYSLOG=True
        SYSLOG_HOST=$HOST_IP
        SYSLOG_PORT=516

A clean install every time
    | *Default: ``RECLONE=""``*
    |  By default ``stack.sh`` only clones the project repos if they do
       not exist in ``$DEST``. ``stack.sh`` will freshen each repo on each
       run if ``RECLONE`` is set to ``yes``. This avoids having to manually
       remove repos in order to get the current branch from ``$GIT_BASE``.
    |

    ::

        RECLONE=yes

                    Swift
                    Default: SWIFT_HASH="" SWIFT_REPLICAS=1 SWIFT_DATA_DIR=$DEST/data/swift
                    Swift is now used as the back-end for the S3-like object store.  When enabled Nova's objectstore (n-obj in ENABLED_SERVICES) is automatically disabled. Enable Swift by adding it services to ENABLED_SERVICES:
                    enable_service s-proxy s-object s-container s-account

    Setting Swift's hash value is required and you will be prompted for
    it if Swift is enabled so just set it to something already:

    ::

        SWIFT_HASH=66a3d6b56c1f479c8b4e70ab5c2000f5

    For development purposes the default number of replicas is set to
    ``1`` to reduce the overhead required. To better simulate a
    production deployment set this to ``3`` or more.

    ::

        SWIFT_REPLICAS=3

    The data for Swift is stored in the source tree by default (in
    ``$DEST/swift/data``) and can be moved by setting
    ``SWIFT_DATA_DIR``. The specified directory will be created if it
    does not exist.

    ::

        SWIFT_DATA_DIR=$DEST/data/swift

    *Note: Previously just enabling ``swift`` was sufficient to start
    the Swift services. That does not provide proper service
    granularity, particularly in multi-host configurations, and is
    considered deprecated. Some service combination tests now check for
    specific Swift services and the old blanket acceptance will longer
    work correctly.*

Service Catalog Backend
    | *Default: ``KEYSTONE_CATALOG_BACKEND=sql``*
    |  DevStack uses Keystone's ``sql`` service catalog backend. An
       alternate ``template`` backend is also available. However, it does
       not support the ``service-*`` and ``endpoint-*`` commands of the
       ``keystone`` CLI. To do so requires the ``sql`` backend be enabled:
    |

    ::

        KEYSTONE_CATALOG_BACKEND=template

    DevStack's default configuration in ``sql`` mode is set in
    ``files/keystone_data.sh``

Cinder
    | Default:
    | VOLUME_GROUP="stack-volumes" VOLUME_NAME_PREFIX="volume-" VOLUME_BACKING_FILE_SIZE=10250M
    |  The logical volume group used to hold the Cinder-managed volumes
       is set by ``VOLUME_GROUP``, the logical volume name prefix is set
       with ``VOLUME_NAME_PREFIX`` and the size of the volume backing file
       is set with ``VOLUME_BACKING_FILE_SIZE``.
    |

    ::

        VOLUME_GROUP="stack-volumes"
        VOLUME_NAME_PREFIX="volume-"
        VOLUME_BACKING_FILE_SIZE=10250M

Multi-host DevStack
    | *Default: ``MULTI_HOST=False``*
    |  Running DevStack with multiple hosts requires a custom
       ``local.conf`` section for each host. The master is the same as a
       single host installation with ``MULTI_HOST=True``. The slaves have
       fewer services enabled and a couple of host variables pointing to
       the master.
    |  **Master**

    ::

        MULTI_HOST=True

    **Slave**

    ::

        MYSQL_HOST=w.x.y.z
        RABBIT_HOST=w.x.y.z
        GLANCE_HOSTPORT=w.x.y.z:9292
        ENABLED_SERVICES=n-vol,n-cpu,n-net,n-api

API rate limits
    | Default: ``API_RATE_LIMIT=True``
    | Integration tests such as Tempest will likely run afoul of the
      default rate limits configured for Nova. Turn off rate limiting
      during testing by setting ``API_RATE_LIMIT=False``.*
    |

    ::

        API_RATE_LIMIT=False

Examples
~~~~~~~~

-  Eliminate a Cinder pass-through (``CINDER_PERIODIC_INTERVAL``):

   ::

       [[post-config|$CINDER_CONF]]
       [DEFAULT]
       periodic_interval = 60

-  Sample ``local.conf`` with screen logging enabled:

   ::

       [[local|localrc]]
       FIXED_RANGE=10.254.1.0/24
       NETWORK_GATEWAY=10.254.1.1
       LOGDAYS=1
       LOGFILE=$DEST/logs/stack.sh.log
       SCREEN_LOGDIR=$DEST/logs/screen
       ADMIN_PASSWORD=quiet
       DATABASE_PASSWORD=$ADMIN_PASSWORD
       RABBIT_PASSWORD=$ADMIN_PASSWORD
       SERVICE_PASSWORD=$ADMIN_PASSWORD
       SERVICE_TOKEN=a682f596-76f3-11e3-b3b2-e716f9080d50
