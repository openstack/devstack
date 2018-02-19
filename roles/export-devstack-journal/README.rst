Export journal files from devstack services

Export the systemd journal for every devstack service in native
journal format as well as text.  Also, export a syslog-style file with
kernal and sudo messages.

Writes the output to the ``logs/`` subdirectory of
``stage_dir``.

**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory. This is used to obtain the
   ``log-start-timestamp.txt``, used to filter the systemd journal.

.. zuul:rolevar:: stage_dir
   :default: {{ ansible_user_dir }}

   The base stage directory.
