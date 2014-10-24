`DevStack </>`__

-  `Overview <overview.html>`__
-  `Changes <changes.html>`__
-  `FAQ <faq.html>`__
-  `git.openstack.org <https://git.openstack.org/cgit/openstack-dev/devstack>`__
-  `Gerrit <https://review.openstack.org/#/q/status:open+project:openstack-dev/devstack,n,z>`__

Overview DevStack from a cloud-height view
------------------------------------------

DevStack has evolved to support a large number of configuration options
and alternative platforms and support services. That evolution has grown
well beyond what was originally intended and the majority of
configuration combinations are rarely, if ever, tested. DevStack is not
a general OpenStack installer and was never meant to be everything to
everyone..

Below is a list of what is specifically is supported (read that as
"tested") going forward.

Supported Components
--------------------

Base OS
~~~~~~~

*The OpenStack Technical Committee (TC) has defined the current CI
strategy to include the latest Ubuntu release and the latest RHEL
release (for Python 2.6 testing).*

-  Ubuntu: current LTS release plus current development release
-  Fedora: current release plus previous release
-  RHEL: current major release
-  Other OS platforms may continue to be included but the maintenance of
   those platforms shall not be assumed simply due to their presence.
   Having a listed point-of-contact for each additional OS will greatly
   increase its chance of being well-maintained.
-  Patches for Ubuntu and/or Fedora will not be held up due to
   side-effects on other OS platforms.

Databases
~~~~~~~~~

*As packaged by the host OS*

-  MySQL
-  PostgreSQL

Queues
~~~~~~

*As packaged by the host OS*

-  Rabbit
-  Qpid

Web Server
~~~~~~~~~~

*As packaged by the host OS*

-  Apache

OpenStack Network
~~~~~~~~~~~~~~~~~

*Default to Nova Network, optionally use Neutron*

-  Nova Network: FlatDHCP
-  Neutron: A basic configuration approximating the original FlatDHCP
   mode using linuxbridge or OpenVSwitch.

Services
~~~~~~~~

The default services configured by DevStack are Identity (Keystone),
Object Storage (Swift), Image Storage (Glance), Block Storage (Cinder),
Compute (Nova), Network (Nova), Dashboard (Horizon), Orchestration
(Heat)

Additional services not included directly in DevStack can be tied in to
``stack.sh`` using the `plugin mechanism <plugins.html>`__ to call
scripts that perform the configuration and startup of the service.

Node Configurations
~~~~~~~~~~~~~~~~~~~

-  single node
-  multi-node is not tested regularly by the core team, and even then
   only minimal configurations are reviewed

Exercises
~~~~~~~~~

The DevStack exercise scripts are no longer used as integration and gate
testing as that job has transitioned to Tempest. They are still
maintained as a demonstrations of using OpenStack from the command line
and for quick operational testing.

© Openstack Foundation 2011-2014 — An
`OpenStack <https://www.openstack.org/>`__
`program <https://wiki.openstack.org/wiki/Programs>`__
