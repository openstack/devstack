=====================================
openrc - User Authentication Settings
=====================================

``openrc`` configures login credentials suitable for use with the
OpenStack command-line tools. ``openrc`` sources ``stackrc`` at the
beginning (which in turn sources the ``localrc`` setion of
``local.conf``) in order to pick up ``HOST_IP`` and/or ``SERVICE_HOST``
to use in the endpoints. The values shown below are the default values.

OS\_TENANT\_NAME
    The introduction of Keystone to the OpenStack ecosystem has
    standardized the term *tenant* as the entity that owns resources. In
    some places references still exist to the original Nova term
    *project* for this use. Also, *tenant\_name* is preferred to
    *tenant\_id*.

    ::

        OS_TENANT_NAME=demo

OS\_USERNAME
    In addition to the owning entity (tenant), Nova stores the entity
    performing the action as the *user*.

    ::

        OS_USERNAME=demo

OS\_PASSWORD
    With Keystone you pass the keystone password instead of an api key.
    Recent versions of novaclient use OS\_PASSWORD instead of
    NOVA\_API\_KEYs or NOVA\_PASSWORD.

    ::

        OS_PASSWORD=secrete

HOST\_IP, SERVICE\_HOST
    Set API endpoint host using ``HOST_IP``. ``SERVICE_HOST`` may also
    be used to specify the endpoint, which is convenient for some
    ``localrc`` configurations. Typically, ``HOST_IP`` is set in the
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

GLANCE\_HOST
    Some exercises call Glance directly. On a single-node installation,
    Glance should be listening on ``HOST_IP``. If its running elsewhere
    it can be set here.

    ::

        GLANCE_HOST=$HOST_IP

KEYSTONECLIENT\_DEBUG, NOVACLIENT\_DEBUG
    Set command-line client log level to ``DEBUG``. These are commented
    out by default.

    ::

        # export KEYSTONECLIENT_DEBUG=1
        # export NOVACLIENT_DEBUG=1
