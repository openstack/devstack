`DevStack </>`__

-  `Overview <overview.html>`__
-  `Changes <changes.html>`__
-  `FAQ <faq.html>`__
-  `git.openstack.org <https://git.openstack.org/cgit/openstack-dev/devstack>`__
-  `Gerrit <https://review.openstack.org/#/q/status:open+project:openstack-dev/devstack,n,z>`__

exerciserc Exercise settings
----------------------------

``exerciserc`` is used to configure settings for the exercise scripts.
The values shown below are the default values. Thse can all be
overridden by setting them in the ``localrc`` section.

ACTIVE\_TIMEOUT
    Max time to wait while vm goes from build to active state

    ::

        ACTIVE_TIMEOUT==30

ASSOCIATE\_TIMEOUT
    Max time to wait for proper IP association and dis-association.

    ::

        ASSOCIATE_TIMEOUT=15

BOOT\_TIMEOUT
    Max time till the vm is bootable

    ::

        BOOT_TIMEOUT=30

RUNNING\_TIMEOUT
    Max time from run instance command until it is running

    ::

        RUNNING_TIMEOUT=$(($BOOT_TIMEOUT + $ACTIVE_TIMEOUT))

TERMINATE\_TIMEOUT
    Max time to wait for a vm to terminate

    ::

        TERMINATE_TIMEOUT=30

© Openstack Foundation 2011-2013 — An `OpenStack
program <https://wiki.openstack.org/wiki/Programs>`__ created by
`Rackspace Cloud
Builders <http://www.rackspace.com/cloud/private_edition/>`__
