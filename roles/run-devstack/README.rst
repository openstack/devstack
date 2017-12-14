Run devstack

**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory.

.. zuul:rolevar:: devstack_early_log
   :default: /opt/stack/log/devstack-early.txt

   The full devstack log that includes the whatever stack.sh logs before
   the LOGFILE variable in local.conf is honoured.
