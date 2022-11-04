============================
So You Want to Contribute...
============================

For general information on contributing to OpenStack, please check out the
`contributor guide <https://docs.openstack.org/contributors/>`_ to get started.
It covers all the basics that are common to all OpenStack projects: the accounts
you need, the basics of interacting with our Gerrit review system, how we
communicate as a community, etc.

Below will cover the more project specific information you need to get started
with Devstack.

Communication
~~~~~~~~~~~~~
* IRC channel ``#openstack-qa`` at OFTC.
* Mailing list (prefix subjects with ``[qa][devstack]`` for faster responses)
  http://lists.openstack.org/cgi-bin/mailman/listinfo/openstack-discuss

Contacting the Core Team
~~~~~~~~~~~~~~~~~~~~~~~~
Please refer to the `Devstack Core Team
<https://review.opendev.org/#/admin/groups/50,members>`_ contacts.

New Feature Planning
~~~~~~~~~~~~~~~~~~~~
If you want to propose a new feature please read `Feature Proposal Process`_
Devstack features are tracked on `Launchpad BP <https://blueprints.launchpad.net/devstack>`_.

Task Tracking
~~~~~~~~~~~~~
We track our tasks in `Launchpad <https://bugs.launchpad.net/devstack>`_.

Reporting a Bug
~~~~~~~~~~~~~~~
You found an issue and want to make sure we are aware of it? You can do so on
`Launchpad <https://bugs.launchpad.net/devstack/+filebug>`__.
More info about Launchpad usage can be found on `OpenStack docs page
<https://docs.openstack.org/contributors/common/task-tracking.html#launchpad>`_

Getting Your Patch Merged
~~~~~~~~~~~~~~~~~~~~~~~~~
All changes proposed to the Devstack require two ``Code-Review +2`` votes from
Devstack core reviewers before one of the core reviewers can approve the patch
by giving ``Workflow +1`` vote. There are 2 exceptions, approving patches to
unblock the gate and patches that do not relate to the Devstack's core logic,
like for example old job cleanups, can be approved by single core reviewers.

Project Team Lead Duties
~~~~~~~~~~~~~~~~~~~~~~~~
All common PTL duties are enumerated in the `PTL guide
<https://docs.openstack.org/project-team-guide/ptl.html>`_.

The Release Process for QA is documented in `QA Release Process
<https://wiki.openstack.org/wiki/QA/releases>`_.

.. _Feature Proposal Process: https://wiki.openstack.org/wiki/QA#Feature_Proposal_.26_Design_discussions
