Generate performance logs for staging

Captures usage information from mysql, systemd, apache logs, and other
parts of the system and generates a performance.json file in the
staging directory.

**Role Variables**

.. zuul:rolevar:: stage_dir
   :default: {{ ansible_user_dir }}

   The base stage directory

.. zuul:rolevar:: devstack_conf_dir
   :default: /opt/stack

   The base devstack destination directory

.. zuul:rolevar:: debian_suse_apache_deref_logs

   The apache logs found in the debian/suse locations

.. zuul:rolevar:: redhat_apache_deref_logs

   The apache logs found in the redhat locations
