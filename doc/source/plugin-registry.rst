..
  Note to patch submitters: this file is covered by a periodic proposal
  job.  You should edit the files data/devstack-plugins-registry.footer
  data/devstack-plugins-registry.header instead of this one.

==========================
 DevStack Plugin Registry
==========================

Since we've created the external plugin mechanism, it's gotten used by
a lot of projects. The following is a list of plugins that currently
exist. Any project that wishes to list their plugin here is welcomed
to.

Detected Plugins
================

The following are plugins that a script has found in the openstack/
namespace, which includes but is not limited to official OpenStack
projects.

+----------------------------+-------------------------------------------------------------------------+
|Plugin Name                 |URL                                                                      |
+----------------------------+-------------------------------------------------------------------------+
|aodh                        |git://git.openstack.org/openstack/aodh                                   |
+----------------------------+-------------------------------------------------------------------------+
|app-catalog-ui              |git://git.openstack.org/openstack/app-catalog-ui                         |
+----------------------------+-------------------------------------------------------------------------+
|astara                      |git://git.openstack.org/openstack/astara                                 |
+----------------------------+-------------------------------------------------------------------------+
|barbican                    |git://git.openstack.org/openstack/barbican                               |
+----------------------------+-------------------------------------------------------------------------+
|blazar                      |git://git.openstack.org/openstack/blazar                                 |
+----------------------------+-------------------------------------------------------------------------+
|ceilometer                  |git://git.openstack.org/openstack/ceilometer                             |
+----------------------------+-------------------------------------------------------------------------+
|ceilometer-powervm          |git://git.openstack.org/openstack/ceilometer-powervm                     |
+----------------------------+-------------------------------------------------------------------------+
|cerberus                    |git://git.openstack.org/openstack/cerberus                               |
+----------------------------+-------------------------------------------------------------------------+
|cloudkitty                  |git://git.openstack.org/openstack/cloudkitty                             |
+----------------------------+-------------------------------------------------------------------------+
|collectd-ceilometer-plugin  |git://git.openstack.org/openstack/collectd-ceilometer-plugin             |
+----------------------------+-------------------------------------------------------------------------+
|congress                    |git://git.openstack.org/openstack/congress                               |
+----------------------------+-------------------------------------------------------------------------+
|cue                         |git://git.openstack.org/openstack/cue                                    |
+----------------------------+-------------------------------------------------------------------------+
|designate                   |git://git.openstack.org/openstack/designate                              |
+----------------------------+-------------------------------------------------------------------------+
|devstack-plugin-amqp1       |git://git.openstack.org/openstack/devstack-plugin-amqp1                  |
+----------------------------+-------------------------------------------------------------------------+
|devstack-plugin-bdd         |git://git.openstack.org/openstack/devstack-plugin-bdd                    |
+----------------------------+-------------------------------------------------------------------------+
|devstack-plugin-ceph        |git://git.openstack.org/openstack/devstack-plugin-ceph                   |
+----------------------------+-------------------------------------------------------------------------+
|devstack-plugin-glusterfs   |git://git.openstack.org/openstack/devstack-plugin-glusterfs              |
+----------------------------+-------------------------------------------------------------------------+
|devstack-plugin-hdfs        |git://git.openstack.org/openstack/devstack-plugin-hdfs                   |
+----------------------------+-------------------------------------------------------------------------+
|devstack-plugin-pika        |git://git.openstack.org/openstack/devstack-plugin-pika                   |
+----------------------------+-------------------------------------------------------------------------+
|devstack-plugin-sheepdog    |git://git.openstack.org/openstack/devstack-plugin-sheepdog               |
+----------------------------+-------------------------------------------------------------------------+
|devstack-plugin-zmq         |git://git.openstack.org/openstack/devstack-plugin-zmq                    |
+----------------------------+-------------------------------------------------------------------------+
|dragonflow                  |git://git.openstack.org/openstack/dragonflow                             |
+----------------------------+-------------------------------------------------------------------------+
|drbd-devstack               |git://git.openstack.org/openstack/drbd-devstack                          |
+----------------------------+-------------------------------------------------------------------------+
|ec2-api                     |git://git.openstack.org/openstack/ec2-api                                |
+----------------------------+-------------------------------------------------------------------------+
|freezer                     |git://git.openstack.org/openstack/freezer                                |
+----------------------------+-------------------------------------------------------------------------+
|freezer-api                 |git://git.openstack.org/openstack/freezer-api                            |
+----------------------------+-------------------------------------------------------------------------+
|freezer-web-ui              |git://git.openstack.org/openstack/freezer-web-ui                         |
+----------------------------+-------------------------------------------------------------------------+
|gce-api                     |git://git.openstack.org/openstack/gce-api                                |
+----------------------------+-------------------------------------------------------------------------+
|gnocchi                     |git://git.openstack.org/openstack/gnocchi                                |
+----------------------------+-------------------------------------------------------------------------+
|ironic                      |git://git.openstack.org/openstack/ironic                                 |
+----------------------------+-------------------------------------------------------------------------+
|ironic-inspector            |git://git.openstack.org/openstack/ironic-inspector                       |
+----------------------------+-------------------------------------------------------------------------+
|kingbird                    |git://git.openstack.org/openstack/kingbird                               |
+----------------------------+-------------------------------------------------------------------------+
|kuryr                       |git://git.openstack.org/openstack/kuryr                                  |
+----------------------------+-------------------------------------------------------------------------+
|magnum                      |git://git.openstack.org/openstack/magnum                                 |
+----------------------------+-------------------------------------------------------------------------+
|manila                      |git://git.openstack.org/openstack/manila                                 |
+----------------------------+-------------------------------------------------------------------------+
|mistral                     |git://git.openstack.org/openstack/mistral                                |
+----------------------------+-------------------------------------------------------------------------+
|monasca-api                 |git://git.openstack.org/openstack/monasca-api                            |
+----------------------------+-------------------------------------------------------------------------+
|murano                      |git://git.openstack.org/openstack/murano                                 |
+----------------------------+-------------------------------------------------------------------------+
|networking-6wind            |git://git.openstack.org/openstack/networking-6wind                       |
+----------------------------+-------------------------------------------------------------------------+
|networking-bagpipe          |git://git.openstack.org/openstack/networking-bagpipe                     |
+----------------------------+-------------------------------------------------------------------------+
|networking-bgpvpn           |git://git.openstack.org/openstack/networking-bgpvpn                      |
+----------------------------+-------------------------------------------------------------------------+
|networking-calico           |git://git.openstack.org/openstack/networking-calico                      |
+----------------------------+-------------------------------------------------------------------------+
|networking-cisco            |git://git.openstack.org/openstack/networking-cisco                       |
+----------------------------+-------------------------------------------------------------------------+
|networking-fortinet         |git://git.openstack.org/openstack/networking-fortinet                    |
+----------------------------+-------------------------------------------------------------------------+
|networking-generic-switch   |git://git.openstack.org/openstack/networking-generic-switch              |
+----------------------------+-------------------------------------------------------------------------+
|networking-infoblox         |git://git.openstack.org/openstack/networking-infoblox                    |
+----------------------------+-------------------------------------------------------------------------+
|networking-l2gw             |git://git.openstack.org/openstack/networking-l2gw                        |
+----------------------------+-------------------------------------------------------------------------+
|networking-midonet          |git://git.openstack.org/openstack/networking-midonet                     |
+----------------------------+-------------------------------------------------------------------------+
|networking-mlnx             |git://git.openstack.org/openstack/networking-mlnx                        |
+----------------------------+-------------------------------------------------------------------------+
|networking-nec              |git://git.openstack.org/openstack/networking-nec                         |
+----------------------------+-------------------------------------------------------------------------+
|networking-odl              |git://git.openstack.org/openstack/networking-odl                         |
+----------------------------+-------------------------------------------------------------------------+
|networking-ofagent          |git://git.openstack.org/openstack/networking-ofagent                     |
+----------------------------+-------------------------------------------------------------------------+
|networking-ovn              |git://git.openstack.org/openstack/networking-ovn                         |
+----------------------------+-------------------------------------------------------------------------+
|networking-ovs-dpdk         |git://git.openstack.org/openstack/networking-ovs-dpdk                    |
+----------------------------+-------------------------------------------------------------------------+
|networking-plumgrid         |git://git.openstack.org/openstack/networking-plumgrid                    |
+----------------------------+-------------------------------------------------------------------------+
|networking-powervm          |git://git.openstack.org/openstack/networking-powervm                     |
+----------------------------+-------------------------------------------------------------------------+
|networking-sfc              |git://git.openstack.org/openstack/networking-sfc                         |
+----------------------------+-------------------------------------------------------------------------+
|networking-vsphere          |git://git.openstack.org/openstack/networking-vsphere                     |
+----------------------------+-------------------------------------------------------------------------+
|neutron                     |git://git.openstack.org/openstack/neutron                                |
+----------------------------+-------------------------------------------------------------------------+
|neutron-lbaas               |git://git.openstack.org/openstack/neutron-lbaas                          |
+----------------------------+-------------------------------------------------------------------------+
|neutron-lbaas-dashboard     |git://git.openstack.org/openstack/neutron-lbaas-dashboard                |
+----------------------------+-------------------------------------------------------------------------+
|neutron-vpnaas              |git://git.openstack.org/openstack/neutron-vpnaas                         |
+----------------------------+-------------------------------------------------------------------------+
|nova-docker                 |git://git.openstack.org/openstack/nova-docker                            |
+----------------------------+-------------------------------------------------------------------------+
|nova-powervm                |git://git.openstack.org/openstack/nova-powervm                           |
+----------------------------+-------------------------------------------------------------------------+
|octavia                     |git://git.openstack.org/openstack/octavia                                |
+----------------------------+-------------------------------------------------------------------------+
|osprofiler                  |git://git.openstack.org/openstack/osprofiler                             |
+----------------------------+-------------------------------------------------------------------------+
|rally                       |git://git.openstack.org/openstack/rally                                  |
+----------------------------+-------------------------------------------------------------------------+
|sahara                      |git://git.openstack.org/openstack/sahara                                 |
+----------------------------+-------------------------------------------------------------------------+
|sahara-dashboard            |git://git.openstack.org/openstack/sahara-dashboard                       |
+----------------------------+-------------------------------------------------------------------------+
|scalpels                    |git://git.openstack.org/openstack/scalpels                               |
+----------------------------+-------------------------------------------------------------------------+
|searchlight                 |git://git.openstack.org/openstack/searchlight                            |
+----------------------------+-------------------------------------------------------------------------+
|senlin                      |git://git.openstack.org/openstack/senlin                                 |
+----------------------------+-------------------------------------------------------------------------+
|smaug                       |git://git.openstack.org/openstack/smaug                                  |
+----------------------------+-------------------------------------------------------------------------+
|solum                       |git://git.openstack.org/openstack/solum                                  |
+----------------------------+-------------------------------------------------------------------------+
|tacker                      |git://git.openstack.org/openstack/tacker                                 |
+----------------------------+-------------------------------------------------------------------------+
|tap-as-a-service            |git://git.openstack.org/openstack/tap-as-a-service                       |
+----------------------------+-------------------------------------------------------------------------+
|tricircle                   |git://git.openstack.org/openstack/tricircle                              |
+----------------------------+-------------------------------------------------------------------------+
|trove                       |git://git.openstack.org/openstack/trove                                  |
+----------------------------+-------------------------------------------------------------------------+
|trove-dashboard             |git://git.openstack.org/openstack/trove-dashboard                        |
+----------------------------+-------------------------------------------------------------------------+
|vitrage                     |git://git.openstack.org/openstack/vitrage                                |
+----------------------------+-------------------------------------------------------------------------+
|vitrage-dashboard           |git://git.openstack.org/openstack/vitrage-dashboard                      |
+----------------------------+-------------------------------------------------------------------------+
|vmware-nsx                  |git://git.openstack.org/openstack/vmware-nsx                             |
+----------------------------+-------------------------------------------------------------------------+
|watcher                     |git://git.openstack.org/openstack/watcher                                |
+----------------------------+-------------------------------------------------------------------------+
|watcher-dashboard           |git://git.openstack.org/openstack/watcher-dashboard                      |
+----------------------------+-------------------------------------------------------------------------+
|zaqar                       |git://git.openstack.org/openstack/zaqar                                  |
+----------------------------+-------------------------------------------------------------------------+

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
