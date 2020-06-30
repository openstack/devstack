Generate stackviz report.

Generate stackviz report using subunit and dstat data, using
the stackviz archive embedded in test images.

**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory.

.. zuul:rolevar:: stage_dir
   :default: "{{ ansible_user_dir }}"

   The stage directory where the input data can be found and
   the output will be produced.

.. zuul:rolevar:: zuul_work_dir
   :default: {{ devstack_base_dir }}/tempest

   Directory to work in. It has to be a fully qualified path.
