=============
 Quo Vadimus
=============

Where are we going?

This is a document in Devstack to outline where we are headed in the
future. The future might be near or far, but this is where we'd like
to be.

This is intended to help people contribute, because it will be a
little clearer if a contribution takes us closer to or further away to
our end game.

==================
 Default Services
==================

Devstack is designed as a development environment first. There are a
lot of ways to compose the OpenStack services, but we do need one
default.

That should be the Compute Layer (currently Glance + Nova + Cinder +
Neutron Core (not advanced services) + Keystone). It should be the
base building block going forward, and the introduction point of
people to OpenStack via Devstack.

================
 Service Howtos
================

Starting from the base building block all services included in
OpenStack should have an overview page in the Devstack
documentation. That should include the following:

- A helpful high level overview of that service
- What it depends on (both other OpenStack services and other system
  components)
- What new daemons are needed to be started, including where they
  should live

This provides a map for people doing multinode testing to understand
what portions are control plane, which should live on worker nodes.

Service how to pages will start with an ugly "This team has provided
no information about this service" until someone does.

===================
 Included Services
===================

Devstack doesn't need to eat the world. Given the existence of the
external devstack plugin architecture, the future direction is to move
the bulk of the support code out of devstack itself and into external
plugins.

This will also promote a more clean separation between services.

=============================
 Included Backends / Drivers
=============================

Upstream Devstack should only include Open Source backends / drivers,
it's intent is for Open Source development of OpenStack. Proprietary
drivers should be supported via external plugins.

Just being Open Source doesn't mean it should be in upstream Devstack
if it's not required for base development of OpenStack
components. When in doubt, external plugins should be used.

========================================
 OpenStack Services vs. System Services
========================================

ENABLED_SERVICES is currently entirely too overloaded. We should have
a separation of actual OpenStack services that you have to run (n-cpu,
g-api) and required backends like mysql and rabbitmq.

===========================
 Splitting up of Functions
===========================

The functions-common file has grown over time, and needs to be split
up into smaller libraries that handle specific domains.

======================
 Testing of Functions
======================

Every function in a functions file should get tests. The devstack
testing framework is young, but we do have some unit tests for the
tree, and those should be enhanced.

==============================
 Not Co-Gating with the World
==============================

As projects spin up functional test jobs, Devstack should not be
co-gated with every single one of those. The Devstack team has one of
the fastest turn arounds for blocking bugs of any Open Stack
project.

Basic service validation should be included as part of Devstack
installation to mitigate this.

============================
 Documenting all the things
============================

Devstack started off as an explanation as much as an install
script. We would love contributions to that further enhance the
comments and explanations about what is happening, even if it seems a
little pedantic at times.
