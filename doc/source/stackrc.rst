===========================
stackrc - DevStack Settings
===========================

``stackrc`` is the primary configuration file for DevStack. It contains
all of the settings that control the services started and the
repositories used to download the source for those services. ``stackrc``
sources the ``localrc`` section of ``local.conf`` to perform the default
overrides.

DATABASE\_TYPE
    Select the database backend to use. The default is ``mysql``,
    ``postgresql`` is also available.
ENABLED\_SERVICES
    Specify which services to launch. These generally correspond to
    screen tabs. The default includes: Glance (API and Registry),
    Keystone, Nova (API, Certificate, Object Store, Compute, Network,
    Scheduler, VNC proxies, Certificate Authentication), Cinder
    (Scheduler, API, Volume), Horizon, MySQL, RabbitMQ, Tempest.

    ::

        ENABLED_SERVICES=g-api,g-reg,key,n-api,n-crt,n-obj,n-cpu,n-net,n-cond,cinder,c-sch,c-api,c-vol,n-sch,n-novnc,n-xvnc,n-cauth,horizon,rabbit,tempest,$DATABASE_TYPE

    Other services that are not enabled by default can be enabled in
    ``localrc``. For example, to add Swift, use the following service
    names:

    ::

        enable_service s-proxy s-object s-container s-account

    A service can similarly be disabled:

    ::

        disable_service horizon

Service Repos
    The Git repositories used to check out the source for each service
    are controlled by a pair of variables set for each service.
    ``*_REPO`` points to the repository and ``*_BRANCH`` selects which
    branch to check out. These may be overridden in ``local.conf`` to
    pull source from a different repo for testing, such as a Gerrit
    branch proposal. ``GIT_BASE`` points to the primary repository
    server.

    ::

        NOVA_REPO=$GIT_BASE/openstack/nova.git
        NOVA_BRANCH=master

    To pull a branch directly from Gerrit, get the repo and branch from
    the Gerrit review page:

    ::

        git fetch https://review.openstack.org/p/openstack/nova refs/changes/50/5050/1 && git checkout FETCH_HEAD

    The repo is the stanza following ``fetch`` and the branch is the
    stanza following that:

    ::

        NOVA_REPO=https://review.openstack.org/p/openstack/nova
        NOVA_BRANCH=refs/changes/50/5050/1
