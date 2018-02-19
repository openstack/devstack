Prepare OpenStack project configurations for staging

Prepare all relevant config files for staging.
This is helpful to avoid staging the entire /etc.

**Role Variables**

.. zuul:rolevar:: stage_dir
   :default: {{ ansible_user_dir }}

   The base stage directory.
