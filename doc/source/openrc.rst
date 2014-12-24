=====================================
openrc - User Authentication Settings
=====================================

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

        OS_PASSWORD=secrete

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

        OS_AUTH_URL=http://$SERVICE_HOST:5000/v2.0

KEYSTONECLIENT\_DEBUG, NOVACLIENT\_DEBUG
    Set command-line client log level to ``DEBUG``. These are commented
    out by default.

    ::

        # export KEYSTONECLIENT_DEBUG=1
        # export NOVACLIENT_DEBUG=1
