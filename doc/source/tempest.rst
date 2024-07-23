=======
Tempest
=======

`Tempest`_ is the OpenStack Integration test suite. It is installed by default
and is used to provide integration testing for many of the OpenStack services.
Just like DevStack itself, it is possible to extend Tempest with plugins. In
fact, many Tempest plugin packages also include DevStack plugin to do things
like pre-create required static resources.

The `Tempest documentation <Tempest>`_ provides a thorough guide to using
Tempest. However, if you simply wish to run the standard set of Tempest tests
against an existing deployment, you can do the following:

.. code-block:: shell

    cd /opt/stack/tempest
    /opt/stack/data/venv/bin/tempest run ...

The above assumes you have installed DevStack in the default location
(configured via the ``DEST`` configuration variable) and have enabled
virtualenv-based installation in the standard location (configured via the
``USE_VENV`` and ``VENV_DEST`` configuration variables, respectively).

.. _Tempest: https://docs.openstack.org/tempest/latest/
