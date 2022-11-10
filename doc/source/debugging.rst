=====================
System-wide debugging
=====================

A lot can go wrong during a devstack run, and there are a few inbuilt
tools to help you.

dstat
-----

Enable the ``dstat`` service to produce performance logs during the
devstack run.  These will be logged to the journal and also as a CSV
file.

memory_tracker
--------------

The ``memory_tracker`` service periodically monitors RAM usage and
provides consumption output when available memory is seen to be
falling (i.e. processes are consuming memory).  It also provides
output showing locked (unswappable) memory.

file_tracker
------------

The ``file_tracker`` service periodically monitors the number of
open files in the system.

tcpdump
-------

Enable the ``tcpdump`` service to run a background tcpdump.  You must
set the ``TCPDUMP_ARGS`` variable to something suitable (there is no
default).  For example, to trace iSCSI communication during a job in
the OpenStack gate and copy the result into the log output, you might
use:

.. code-block:: yaml

   job:
     name: devstack-job
     parent: devstack
     vars:
       devstack_services:
         tcpdump: true
       devstack_localrc:
         TCPDUMP_ARGS: "-i any tcp port 3260"
       zuul_copy_output:
         '{{ devstack_log_dir }}/tcpdump.pcap': logs



