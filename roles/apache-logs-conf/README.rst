Prepare apache configs and logs for staging

Make sure apache config files and log files are available in a linux flavor
independent location. Note that this relies on hard links, to the staging
directory must be in the same partition where the logs and configs are.

**Role Variables**

.. zuul:rolevar:: stage_dir
   :default: {{ ansible_user_dir }}

   The base stage directory.
