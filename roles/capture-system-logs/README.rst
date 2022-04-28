Stage a number of system type logs

Stage a number of different logs / reports:
- snapshot of iptables
- disk space available
- pip[2|3] freeze
- installed packages (dpkg/rpm)
- ceph, openswitch, gluster
- coredumps
- dns resolver
- listen53
- services
- unbound.log
- deprecation messages

**Role Variables**

.. zuul:rolevar:: stage_dir
   :default: {{ ansible_user_dir }}

   The base stage directory.
