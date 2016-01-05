..
  Note to reviewers: the intent of this file is to be easy for
  community members to update. As such fast approving (single core +2)
  is fine as long as you've identified that the plugin listed actually exists.

==========================
 DevStack Plugin Registry
==========================

Since we've created the external plugin mechanism, it's gotten used by
a lot of projects. The following is a list of plugins that currently
exist. Any project that wishes to list their plugin here is welcomed
to.

Official OpenStack Projects
===========================

The following are plugins that exist for official OpenStack projects.

+------------------+---------------------------------------------+--------------------+
|Plugin Name       |URL                                          |Comments            |
+------------------+---------------------------------------------+--------------------+
|aodh              |git://git.openstack.org/openstack/aodh       | alarming           |
+------------------+---------------------------------------------+--------------------+
|barbican          |git://git.openstack.org/openstack/barbican   | key management     |
+------------------+---------------------------------------------+--------------------+
|ceilometer        |git://git.openstack.org/openstack/ceilometer | metering           |
+------------------+---------------------------------------------+--------------------+
|congress          |git://git.openstack.org/openstack/congress   | governance         |
+------------------+---------------------------------------------+--------------------+
|cue               |git://git.openstack.org/openstack/cue        | message-broker     |
+------------------+---------------------------------------------+--------------------+
|gnocchi           |git://git.openstack.org/openstack/gnocchi    | metric             |
+------------------+---------------------------------------------+--------------------+
|ironic            |git://git.openstack.org/openstack/ironic     | baremetal          |
+------------------+---------------------------------------------+--------------------+
|magnum            |git://git.openstack.org/openstack/magnum     |                    |
+------------------+---------------------------------------------+--------------------+
|manila            |git://git.openstack.org/openstack/manila     | file shares        |
+------------------+---------------------------------------------+--------------------+
|mistral           |git://git.openstack.org/openstack/mistral    |                    |
+------------------+---------------------------------------------+--------------------+
|rally             |git://git.openstack.org/openstack/rally      |                    |
+------------------+---------------------------------------------+--------------------+
|sahara            |git://git.openstack.org/openstack/sahara     |                    |
+------------------+---------------------------------------------+--------------------+
|trove             |git://git.openstack.org/openstack/trove      |                    |
+------------------+---------------------------------------------+--------------------+
|zaqar             |git://git.openstack.org/openstack/zaqar      |                    |
+------------------+---------------------------------------------+--------------------+



Drivers
=======

+--------------------+-------------------------------------------------+------------------+
|Plugin Name         |URL                                              |Comments          |
+--------------------+-------------------------------------------------+------------------+
|dragonflow          |git://git.openstack.org/openstack/dragonflow     |[d1]_             |
+--------------------+-------------------------------------------------+------------------+
|odl                 |git://git.openstack.org/openstack/networking-odl |[d2]_             |
+--------------------+-------------------------------------------------+------------------+

.. [d1] demonstrates example of installing 3rd party SDN controller
.. [d2] demonstrates a pretty advanced set of modes that that allow
        one to run OpenDayLight either from a pre-existing install, or
        also from source

Alternate Configs
=================

+-------------+------------------------------------------------------------+------------+
| Plugin Name | URL                                                        | Comments   |
|             |                                                            |            |
+-------------+------------------------------------------------------------+------------+
|glusterfs    |git://git.openstack.org/openstack/devstack-plugin-glusterfs |            |
+-------------+------------------------------------------------------------+------------+
|             |                                                            |            |
+-------------+------------------------------------------------------------+------------+

Additional Services
===================

+-----------------+------------------------------------------------------------+------------+
| Plugin Name     | URL                                                        | Comments   |
|                 |                                                            |            |
+-----------------+------------------------------------------------------------+------------+
|amqp1            |git://git.openstack.org/openstack/devstack-plugin-amqp1     |            |
+-----------------+------------------------------------------------------------+------------+
|bdd              |git://git.openstack.org/openstack/devstack-plugin-bdd       |            |
+-----------------+------------------------------------------------------------+------------+
|ec2-api          |git://git.openstack.org/openstack/ec2-api                   |[as1]_      |
+-----------------+------------------------------------------------------------+------------+
|glusterfs        |git://git.openstack.org/openstack/devstack-plugin-glusterfs |            |
+-----------------+------------------------------------------------------------+------------+
|hdfs             |git://git.openstack.org/openstack/devstack-plugin-hdfs      |            |
+-----------------+------------------------------------------------------------+------------+
|ironic-inspector |git://git.openstack.org/openstack/ironic-inspector          |            |
+-----------------+------------------------------------------------------------+------------+
|pika             |git://git.openstack.org/openstack/devstack-plugin-pika      |            |
+-----------------+------------------------------------------------------------+------------+
|sheepdog         |git://git.openstack.org/openstack/devstack-plugin-sheepdog  |            |
+-----------------+------------------------------------------------------------+------------+
|zmq              |git://git.openstack.org/openstack/devstack-plugin-zmq       |            |
+-----------------+------------------------------------------------------------+------------+
|                 |                                                            |            |
+-----------------+------------------------------------------------------------+------------+

.. [as1] first functional devstack plugin, hence why used in most of
         the examples.
