Neutron plugin specific files
=============================
Neutron plugins require plugin specific behavior.
The files under the directory, ``lib/neutron_plugins/``, will be used
when their service is enabled.
Each plugin has ``lib/neutron_plugins/$Q_PLUGIN`` and define the following
functions.
Plugin specific configuration variables should be in this file.

* filename: ``$Q_PLUGIN``
  * The corresponding file name MUST be the same to plugin name ``$Q_PLUGIN``.
    Plugin specific configuration variables should be in this file.

functions
---------
``lib/neutron`` calls the following functions when the ``$Q_PLUGIN`` is enabled

* ``neutron_plugin_create_nova_conf`` :
  set ``NOVA_VIF_DRIVER`` and optionally set options in nova_conf
  e.g.
  NOVA_VIF_DRIVER=${NOVA_VIF_DRIVER:-"nova.virt.libvirt.vif.LibvirtGenericVIFDriver"}
* ``neutron_plugin_install_agent_packages`` :
  install packages that is specific to plugin agent
  e.g.
  install_package bridge-utils
* ``neutron_plugin_configure_common`` :
  set plugin-specific variables, ``Q_PLUGIN_CONF_PATH``, ``Q_PLUGIN_CONF_FILENAME``,
  ``Q_PLUGIN_CLASS``
* ``neutron_plugin_configure_debug_command``
* ``neutron_plugin_configure_dhcp_agent``
* ``neutron_plugin_configure_l3_agent``
* ``neutron_plugin_configure_plugin_agent``
* ``neutron_plugin_configure_service``
* ``neutron_plugin_setup_interface_driver``
* ``has_neutron_plugin_security_group``:
  return 0 if the plugin support neutron security group otherwise return 1
* ``neutron_plugin_check_adv_test_requirements``:
  return 0 if requirements are satisfied otherwise return 1
