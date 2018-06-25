Write the local.conf file for use by devstack

**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory.

.. zuul:rolevar:: devstack_local_conf_path
   :default: {{ devstack_base_dir }}/devstack/local.conf

   The path of the local.conf file.

.. zuul:rolevar:: devstack_localrc
   :type: dict

   A dictionary of variables that should be written to the localrc
   section of local.conf.  The values (which are strings) may contain
   bash shell variables, and will be ordered so that variables used by
   later entries appear first.

   As a special case, the variable ``LIBS_FROM_GIT`` will be
   constructed automatically from the projects which appear in the
   ``required-projects`` list defined by the job plus the project of
   the change under test.  To instruct devstack to install a library
   from source rather than pypi, simply add that library to the job's
   ``required-projects`` list.  To override the
   automatically-generated value, set ``LIBS_FROM_GIT`` in
   ``devstack_localrc`` to the desired value.

.. zuul:rolevar:: devstack_local_conf
   :type: dict

   A complex argument consisting of nested dictionaries which combine
   to form the meta-sections of the local_conf file.  The top level is
   a dictionary of phases, followed by dictionaries of filenames, then
   sections, which finally contain key-value pairs for the INI file
   entries in those sections.

   The keys in this dictionary are the devstack phases.

   .. zuul:rolevar:: [phase]
      :type: dict

      The keys in this dictionary are the filenames for this phase.

      .. zuul:rolevar:: [filename]
         :type: dict

         The keys in this dictionary are the INI sections in this file.

         .. zuul:rolevar:: [section]
            :type: dict

            This is a dictionary of key-value pairs which comprise
            this section of the INI file.

.. zuul:rolevar:: devstack_base_services
   :type: list
   :default: {{ base_services | default(omit) }}

   A list of base services which are enabled. Services can be added or removed
   from this list via the ``devstack_services`` variable. This is ignored if
   ``base`` is set to ``False`` in ``devstack_services``.

.. zuul:rolevar:: devstack_services
   :type: dict

   A dictionary mapping service names to boolean values.  If the
   boolean value is ``false``, a ``disable_service`` line will be
   emitted for the service name.  If it is ``true``, then
   ``enable_service`` will be emitted. All other values are ignored.

   The special key ``base`` can be used to enable or disable the base set of
   services enabled by default. If ``base`` is found, it will processed before
   all other keys. If its value is ``False`` a ``disable_all_services`` will be
   emitted; if its value is ``True`` services from ``devstack_base_services``
   will be emitted via ``ENABLED_SERVICES``.

.. zuul:rolevar:: devstack_plugins
   :type: dict

   A dictionary mapping a plugin name to a git repo location.  If the
   location is a non-empty string, then an ``enable_plugin`` line will
   be emmitted for the plugin name.

   If a plugin declares a dependency on another plugin (via
   ``plugin_requires`` in the plugin's settings file), this role will
   automatically emit ``enable_plugin`` lines in the correct order.
