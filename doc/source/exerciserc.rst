==============================
exerciserc - Exercise Settings
==============================

``exerciserc`` is used to configure settings for the exercise scripts.
The values shown below are the default values. Thse can all be
overridden by setting them in the ``localrc`` section.

ACTIVE\_TIMEOUT
    Max time to wait while vm goes from build to active state

    ::

        ACTIVE_TIMEOUT==30

ASSOCIATE\_TIMEOUT
    Max time to wait for proper IP association and dis-association.

    ::

        ASSOCIATE_TIMEOUT=15

BOOT\_TIMEOUT
    Max time till the vm is bootable

    ::

        BOOT_TIMEOUT=30

RUNNING\_TIMEOUT
    Max time from run instance command until it is running

    ::

        RUNNING_TIMEOUT=$(($BOOT_TIMEOUT + $ACTIVE_TIMEOUT))

TERMINATE\_TIMEOUT
    Max time to wait for a vm to terminate

    ::

        TERMINATE_TIMEOUT=30
