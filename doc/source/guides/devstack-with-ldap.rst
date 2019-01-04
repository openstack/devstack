============================
Deploying DevStack with LDAP
============================

The OpenStack Identity service has the ability to integrate with LDAP. The goal
of this guide is to walk you through setting up an LDAP-backed OpenStack
development environment.

Introduction
============

LDAP support in keystone is read-only. You can use it to back an entire
OpenStack deployment to a single LDAP server, or you can use it to back
separate LDAP servers to specific keystone domains. Users within those domains
can authenticate against keystone, assume role assignments, and interact with
other OpenStack services.

Configuration
=============

To deploy an OpenLDAP server, make sure ``ldap`` is added to the list of
``ENABLED_SERVICES`` in the ``local.conf`` file::

    enable_service ldap

Devstack will require a password to set up an LDAP administrator. This
administrative user is also the bind user specified in keystone's configuration
files, similar to a ``keystone`` user for MySQL databases.

Devstack will prompt you for a password when running ``stack.sh`` if
``LDAP_PASSWORD`` is not set. You can add the following to your
``local.conf``::

    LDAP_PASSWORD=super_secret_password

At this point, devstack should have everything it needs to deploy OpenLDAP,
bootstrap it with a minimal set of users, and configure it to back to a domain
in keystone. You can do this by running the ``stack.sh`` script::

    $ ./stack.sh

Once ``stack.sh`` completes, you should have a running keystone deployment with
a basic set of users. It is important to note that not all users will live
within LDAP. Instead, keystone will back different domains to different
identity sources. For example, the ``default`` domain will be backed by MySQL.
This is usually where you'll find your administrative and services users. If
you query keystone for a list of domains, you should see a domain called
``Users``. This domain is set up by devstack and points to OpenLDAP.

User Management
===============

Initially, there will only be two users in the LDAP server. The ``Manager``
user is used by keystone to talk to OpenLDAP. The ``demo`` user is a generic
user that you should be able to see if you query keystone for users within the
``Users`` domain. Both of these users were added to LDAP using basic LDAP
utilities installed by devstack (e.g. ``ldap-utils``) and LDIFs. The LDIFs used
to create these users can be found in ``devstack/files/ldap/``.

Listing Users
-------------

To list all users in LDAP directly, you can use ``ldapsearch`` with the LDAP
user bootstrapped by devstack::

    $ ldapsearch -x -w LDAP_PASSWORD -D cn=Manager,dc=openstack,dc=org \
        -H ldap://localhost -b dc=openstack,dc=org

As you can see, devstack creates an OpenStack domain called ``openstack.org``
as a container for the ``Manager`` and ``demo`` users.

Creating Users
--------------

Since keystone's LDAP integration is read-only, users must be added directly to
LDAP. Users added directly to OpenLDAP will automatically be placed into the
``Users`` domain.

LDIFs can be used to add users via the command line. The following is an
example LDIF that can be used to create a new LDAP user, let's call it
``peter.ldif.in``::

    dn: cn=peter,ou=Users,dc=openstack,dc=org
    cn: peter
    displayName: Peter Quill
    givenName: Peter Quill
    mail: starlord@openstack.org
    objectClass: inetOrgPerson
    objectClass: top
    sn: peter
    uid: peter
    userPassword: im-a-better-pilot-than-rocket

Now, we use the ``Manager`` user to create a user for Peter in LDAP::

    $ ldapadd -x -w LDAP_PASSWORD -D cn=Manager,dc=openstack,dc=org \
        -H ldap://localhost -c -f peter.ldif.in

We should be able to assign Peter roles on projects. After Peter has some level
of authorization, he should be able to login to Horizon by specifying the
``Users`` domain and using his ``peter`` username and password. Authorization
can be given to Peter by creating a project within the ``Users`` domain and
giving him a role assignment on that project::

    $ openstack project create --domain Users awesome-mix-vol-1
    +-------------+----------------------------------+
    | Field       | Value                            |
    +-------------+----------------------------------+
    | description |                                  |
    | domain_id   | 61a2de23107c46bea2d758167af707b9 |
    | enabled     | True                             |
    | id          | 7d422396d54945cdac8fe1e8e32baec4 |
    | is_domain   | False                            |
    | name        | awesome-mix-vol-1                |
    | parent_id   | 61a2de23107c46bea2d758167af707b9 |
    | tags        | []                               |
    +-------------+----------------------------------+
    $ openstack role add --user peter --user-domain Users \
          --project awesome-mix-vol-1 --project-domain Users admin


Deleting Users
--------------

We can use the same basic steps to remove users from LDAP, but instead of using
LDIFs, we can just pass the ``dn`` of the user we want to delete::

    $ ldapdelete -x -w LDAP_PASSWORD -D cn=Manager,dc=openstack,dc=org \
        -H ldap://localhost cn=peter,ou=Users,dc=openstack,dc=org

Group Management
================

Like users, groups are considered specific identities. This means that groups
also fall under the same read-only constraints as users and they can be managed
directly with LDAP in the same way users are with LDIFs.

Adding Groups
-------------

Let's define a specific group with the following LDIF::

    dn: cn=guardians,ou=UserGroups,dc=openstack,dc=org
    objectClass: groupOfNames
    cn: guardians
    description: Guardians of the Galaxy
    member: cn=peter,dc=openstack,dc=org
    member: cn=gamora,dc=openstack,dc=org
    member: cn=drax,dc=openstack,dc=org
    member: cn=rocket,dc=openstack,dc=org
    member: cn=groot,dc=openstack,dc=org

We can create the group using the same ``ldapadd`` command as we did with
users::

    $ ldapadd -x -w LDAP_PASSWORD -D cn=Manager,dc=openstack,dc=org \
        -H ldap://localhost -c -f guardian-group.ldif.in

If we check the group membership in Horizon, we'll see that only Peter is a
member of the ``guardians`` group, despite the whole crew being specified in
the LDIF. Once those accounts are created in LDAP, they will automatically be
added to the ``guardians`` group. They will also assume any role assignments
given to the ``guardians`` group.

Deleting Groups
---------------

Just like users, groups can be deleted using the ``dn``::

    $ ldapdelete -x -w LDAP_PASSWORD -D cn=Manager,dc=openstack,dc=org \
        -H ldap://localhost cn=guardians,ou=UserGroups,dc=openstack,dc=org

Note that this operation will not remove users within that group. It will only
remove the group itself and the memberships any users had with that group.
