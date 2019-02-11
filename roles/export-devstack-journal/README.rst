Export journal files from devstack services

This performs a number of logging collection services

* Export the systemd journal in native format
* For every devstack service, export logs to text in a file named
  ``screen-*`` to maintain legacy compatability when devstack services
  used to run in a screen session and were logged separately.
* Export a syslog-style file with kernel and sudo messages for legacy
  compatability.

Writes the output to the ``logs/`` subdirectory of ``stage_dir``.

**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory. This is used to obtain the
   ``log-start-timestamp.txt``, used to filter the systemd journal.

.. zuul:rolevar:: stage_dir
   :default: {{ ansible_user_dir }}

   The base stage directory.
