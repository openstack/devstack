Reads the OS_* variables set by devstack through openrc
for the specified user and project and exports them as
the os_env_vars fact.

**WARNING**: this role is meant to be used as porting aid
for the non-unified python-<service>client jobs which
are already around, as those clients do not use clouds.yaml
as openstackclient does.
When those clients and their jobs are deprecated and removed,
or anyway when the new code is able to read from clouds.yaml
directly, this role should be removed as well.


**Role Variables**

.. zuul:rolevar:: devstack_base_dir
   :default: /opt/stack

   The devstack base directory.

.. zuul:rolevar:: openrc_file
   :default: {{ devstack_base_dir }}/devstack/openrc

   The location of the generated openrc file.

.. zuul:rolevar:: openrc_user
   :default: admin

   The user whose credentials should be retrieved.

.. zuul:rolevar:: openrc_project
   :default: admin

   The project (which openrc_user is part of) whose
   access data should be retrieved.

.. zuul:rolevar:: openrc_enable_export
   :default: false

   Set it to true to export os_env_vars.
