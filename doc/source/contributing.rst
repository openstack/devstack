`DevStack </>`__

-  `Overview <overview.html>`__
-  `Changes <changes.html>`__
-  `FAQ <faq.html>`__
-  `git.openstack.org <https://git.openstack.org/cgit/openstack-dev/devstack>`__
-  `Gerrit <https://review.openstack.org/#/q/status:open+project:openstack-dev/devstack,n,z>`__

Contributing Help us help you
-----------------------------

DevStack uses the standard OpenStack contribution process as outlined in
`the OpenStack wiki 'How To
Contribute' <https://wiki.openstack.org/wiki/How_To_Contribute>`__. This
means that you will need to meet the requirements of the Contribututors
License Agreement (CLA). If you have already done that for another
OpenStack project you are good to go.

Things To Know
~~~~~~~~~~~~~~

| 
| **Where Things Are**

The official DevStack repository is located at
``git://git.openstack.org/openstack-dev/devstack.git``, replicated from
the repo maintained by Gerrit. GitHub also has a mirror at
``git://github.com/openstack-dev/devstack.git``.

The `blueprint <https://blueprints.launchpad.net/devstack>`__ and `bug
trackers <https://bugs.launchpad.net/devstack>`__ are on Launchpad. It
should be noted that DevStack generally does not use these as strongly
as other projects, but we're trying to change that.

The `Gerrit review
queue <https://review.openstack.org/#/q/project:openstack-dev/devstack,n,z>`__
is, however, used for all commits except for the text of this website.
That should also change in the near future.

| 
| **HACKING.rst**

Like most OpenStack projects, DevStack includes a ``HACKING.rst`` file
that describes the layout, style and conventions of the project. Because
``HACKING.rst`` is in the main DevStack repo it is considered
authoritative. Much of the content on this page is taken from there.

| 
| **bashate Formatting**

Around the time of the OpenStack Havana release we added a tool to do
style checking in DevStack similar to what pep8/flake8 do for Python
projects. It is still \_very\_ simplistic, focusing mostly on stray
whitespace to help prevent -1 on reviews that are otherwise acceptable.
Oddly enough it is called ``bashate``. It will be expanded to enforce
some of the documentation rules in comments that are used in formatting
the script pages for devstack.org and possibly even simple code
formatting. Run it on the entire project with ``./run_tests.sh``.

Code
~~~~

| 
| **Repo Layout**

The DevStack repo generally keeps all of the primary scripts at the root
level.

``docs`` - Contains the source for this website. It is built using
``tools/build_docs.sh``.

``exercises`` - Contains the test scripts used to validate and
demonstrate some OpenStack functions. These scripts know how to exit
early or skip services that are not enabled.

``extras.d`` - Contains the dispatch scripts called by the hooks in
``stack.sh``, ``unstack.sh`` and ``clean.sh``. See `the plugins
docs <plugins.html>`__ for more information.

``files`` - Contains a variety of otherwise lost files used in
configuring and operating DevStack. This includes templates for
configuration files and the system dependency information. This is also
where image files are downloaded and expanded if necessary.

``lib`` - Contains the sub-scripts specific to each project. This is
where the work of managing a project's services is located. Each
top-level project (Keystone, Nova, etc) has a file here. Additionally
there are some for system services and project plugins.

``samples`` - Contains a sample of the local files not included in the
DevStack repo.

``tests`` - the DevStack test suite is rather sparse, mostly consisting
of test of specific fragile functions in the ``functions`` file.

``tools`` - Contains a collection of stand-alone scripts, some of which
have aged a bit (does anyone still do ramdisk installs?). While these
may reference the top-level DevStack configuration they can generally be
run alone. There are also some sub-directories to support specific
environments such as XenServer.

© Openstack Foundation 2011-2013 — An `OpenStack
program <https://wiki.openstack.org/wiki/Programs>`__ created by
`Rackspace Cloud
Builders <http://www.rackspace.com/cloud/private_edition/>`__
