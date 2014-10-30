===
FAQ
===

-  `General Questions <#general>`__
-  `Operation and Configuration <#ops_conf>`__
-  `Miscellaneous <#misc>`__

General Questions
~~~~~~~~~~~~~~~~~

Q: Can I use DevStack for production?
    A: No. We mean it. Really. DevStack makes some implementation
    choices that are not appropriate for production deployments. We
    warned you!
Q: Then why selinux in enforcing mode?
    A: That is the default on current Fedora and RHEL releases. DevStack
    has (rightly so) a bad reputation for its security practices; it has
    always been meant as a development tool first and system integration
    later. This is changing as the security issues around OpenStack's
    use of root (for example) have been tightened and developers need to
    be better equipped to work in these environments. ``stack.sh``'s use
    of root is primarily to support the activities that would be handled
    by packaging in "real" deployments. To remove additional protections
    that will be desired/required in production would be a step
    backward.
Q: But selinux is disabled in RHEL 6!
    A: Today it is, yes. That is a specific exception that certain
    DevStack contributors fought strongly against. The primary reason it
    was allowed was to support using RHEL6 as the Python 2.6 test
    platform and that took priority time-wise. This will not be the case
    with RHEL 7.
Q: Why a shell script, why not chef/puppet/...
    A: The script is meant to be read by humans (as well as ran by
    computers); it is the primary documentation after all. Using a
    recipe system requires everyone to agree and understand chef or
    puppet.
Q: Why not use Crowbar?
    A: DevStack is optimized for documentation & developers. As some of
    us use `Crowbar <https://github.com/dellcloudedge/crowbar>`__ for
    production deployments, we hope developers documenting how they
    setup systems for new features supports projects like Crowbar.
Q: I'd like to help!
    A: That isn't a question, but please do! The source for DevStack is
    at
    `git.openstack.org <https://git.openstack.org/cgit/openstack-dev/devstack>`__
    and bug reports go to
    `LaunchPad <http://bugs.launchpad.net/devstack/>`__. Contributions
    follow the usual process as described in the `OpenStack
    wiki <http://wiki.openstack.org/HowToContribute>`__ even though
    DevStack is not an official OpenStack project. This site is housed
    in the CloudBuilder's
    `github <http://github.com/cloudbuilders/devstack>`__ in the
    gh-pages branch.
Q: Why not use packages?
    A: Unlike packages, DevStack leaves your cloud ready to develop -
    checkouts of the code and services running in screen. However, many
    people are doing the hard work of packaging and recipes for
    production deployments. We hope this script serves as a way to
    communicate configuration changes between developers and packagers.
Q: Why isn't $MY\_FAVORITE\_DISTRO supported?
    A: DevStack is meant for developers and those who want to see how
    OpenStack really works. DevStack is known to run on the
    distro/release combinations listed in ``README.md``. DevStack is
    only supported on releases other than those documented in
    ``README.md`` on a best-effort basis.
Q: What about Fedora/RHEL/CentOS?
    A: Fedora and CentOS/RHEL are supported via rpm dependency files and
    specific checks in ``stack.sh``. Support will follow the pattern set
    with the Ubuntu testing, i.e. only a single release of the distro
    will receive regular testing, others will be handled on a
    best-effort basis.
Q: Are there any differences between Ubuntu and Fedora support?
    A: Neutron is not fully supported prior to Fedora 18 due lack of
    OpenVSwitch packages.
Q: How about RHEL 6?
    A: RHEL 6 has Python 2.6 and many old modules packaged and is a
    challenge to support. There are a number of specific RHEL6
    work-arounds in ``stack.sh`` to handle this. But the testing on py26
    is valuable so we do it...

Operation and Configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Q: Can DevStack handle a multi-node installation?
    A: Indirectly, yes. You run DevStack on each node with the
    appropriate configuration in ``local.conf``. The primary
    considerations are turning off the services not required on the
    secondary nodes, making sure the passwords match and setting the
    various API URLs to the right place.
Q: How can I document the environment that DevStack is using?
    A: DevStack includes a script (``tools/info.sh``) that gathers the
    versions of the relevant installed apt packages, pip packages and
    git repos. This is a good way to verify what Python modules are
    installed.
Q: How do I turn off a service that is enabled by default?
    A: Services can be turned off by adding ``disable_service xxx`` to
    ``local.conf`` (using ``n-vol`` in this example):

    ::

        disable_service n-vol

Q: Is enabling a service that defaults to off done with the reverse of the above?
    A: Of course!

    ::

        enable_service qpid

Q: How do I run a specific OpenStack milestone?
    A: OpenStack milestones have tags set in the git repo. Set the appropriate tag in the ``*_BRANCH`` variables in ``local.conf``.  Swift is on its own release schedule so pick a tag in the Swift repo that is just before the milestone release. For example:

    ::

        [[local|localrc]]
        GLANCE_BRANCH=stable/grizzly
        HORIZON_BRANCH=stable/grizzly
        KEYSTONE_BRANCH=stable/grizzly
        NOVA_BRANCH=stable/grizzly
        GLANCE_BRANCH=stable/grizzly
        NEUTRON_BRANCH=stable/grizzly
        SWIFT_BRANCH=1.10.0

Q: Why not use [STRIKEOUT:``tools/pip-requires``]\ ``requirements.txt`` to grab project dependencies?
    [STRIKEOUT:The majority of deployments will use packages to install
    OpenStack that will have distro-based packages as dependencies.
    DevStack installs as many of these Python packages as possible to
    mimic the expected production environemnt.] Certain Linux
    distributions have a 'lack of workaround' in their Python
    configurations that installs vendor packaged Python modules and
    pip-installed modules to the SAME DIRECTORY TREE. This is causing
    heartache and moving us in the direction of installing more modules
    from PyPI than vendor packages. However, that is only being done as
    necessary as the packaging needs to catch up to the development
    cycle anyway so this is kept to a minimum.
Q: What can I do about RabbitMQ not wanting to start on my fresh new VM?
    A: This is often caused by ``erlang`` not being happy with the
    hostname resolving to a reachable IP address. Make sure your
    hostname resolves to a working IP address; setting it to 127.0.0.1
    in ``/etc/hosts`` is often good enough for a single-node
    installation. And in an extreme case, use ``clean.sh`` to eradicate
    it and try again.
Q: How can I set up Heat in stand-alone configuration?
    A: Configure ``local.conf`` thusly:

    ::

        [[local|localrc]]
        HEAT_STANDALONE=True
        ENABLED_SERVICES=rabbit,mysql,heat,h-api,h-api-cfn,h-api-cw,h-eng
        KEYSTONE_SERVICE_HOST=<keystone-host>
        KEYSTONE_AUTH_HOST=<keystone-host>

Q: Why are my configuration changes ignored?
    A: You may have run into the package prerequisite installation
    timeout. ``tools/install_prereqs.sh`` has a timer that skips the
    package installation checks if it was run within the last
    ``PREREQ_RERUN_HOURS`` hours (default is 2). To override this, set
    ``FORCE_PREREQ=1`` and the package checks will never be skipped.

Miscellaneous
~~~~~~~~~~~~~

Q: ``tools/fixup_stuff.sh`` is broken and shouldn't 'fix' just one version of packages.
    A: [Another not-a-question] No it isn't. Stuff in there is to
    correct problems in an environment that need to be fixed elsewhere
    or may/will be fixed in a future release. In the case of
    ``httplib2`` and ``prettytable`` specific problems with specific
    versions are being worked around. If later releases have those
    problems than we'll add them to the script. Knowing about the broken
    future releases is valuable rather than polling to see if it has
    been fixed.
