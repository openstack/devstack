Quantum plugin specific files
=============================
Quantum plugins require plugin specific behavior.
The files under the directory, ``lib/quantum_plugins/``, will be used
when their service is enabled.
Each plugin has ``lib/quantum_plugins/$Q_PLUGIN`` and define the following
functions.
Plugin specific configuration variables should be in this file.

* filename: ``$Q_PLUGIN``
  * The corresponding file name MUST be the same to plugin name ``$Q_PLUGIN``.
    Plugin specific configuration variables should be in this file.

functions
---------
``lib/quantum`` calls the following functions when the ``$Q_PLUGIN`` is enabled

* ``quantum_plugin_create_nova_conf`` :
  set ``NOVA_VIF_DRIVER`` and optionally set options in nova_conf
  e.g.
  NOVA_VIF_DRIVER=${NOVA_VIF_DRIVER:-"nova.virt.libvirt.vif.LibvirtGenericVIFDriver"}
* ``quantum_plugin_install_agent_packages`` :
  install packages that is specific to plugin agent
  e.g.
  install_package bridge-utils
* ``quantum_plugin_configure_common`` :
  set plugin-specific variables, ``Q_PLUGIN_CONF_PATH``, ``Q_PLUGIN_CONF_FILENAME``,
  ``Q_DB_NAME``, ``Q_PLUGIN_CLASS``
* ``quantum_plugin_configure_debug_command``
* ``quantum_plugin_configure_dhcp_agent``
* ``quantum_plugin_configure_l3_agent``
* ``quantum_plugin_configure_plugin_agent``
* ``quantum_plugin_configure_service``
* ``quantum_plugin_setup_interface_driver``
* ``has_quantum_plugin_security_group``:
  return 0 if the plugin support quantum security group otherwise return 1
* ``quantum_plugin_check_adv_test_requirements``:
  return 0 if requirements are satisfied otherwise return 1
