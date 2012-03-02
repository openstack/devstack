#!/usr/bin/env bash

# Test OpenStack client enviroment variable handling

echo "**************************************************"
echo "Begin DevStack Exercise: $0"
echo "**************************************************"

# Verify client workage
VERIFY=${1:-""}

# Settings
# ========

# Use openrc + stackrc + localrc for settings
pushd $(cd $(dirname "$0")/.. && pwd) >/dev/null

# Import common functions
source ./functions

# Import configuration
source ./openrc
popd >/dev/null

# Unset all of the known NOVA_ vars
unset NOVA_API_KEY
unset NOVA_ENDPOINT_NAME
unset NOVA_PASSWORD
unset NOVA_PROJECT_ID
unset NOVA_REGION_NAME
unset NOVA_URL
unset NOVA_USERNAME
unset NOVA_VERSION

for i in OS_TENANT_NAME OS_USERNAME OS_PASSWORD OS_AUTH_URL; do
    is_set $i
    if [[ $? -ne 0 ]]; then
        echo "$i expected to be set"
        ABORT=1
    fi
done
if [[ -n "$ABORT" ]]; then
    exit 1
fi

# Set global return
RETURN=0

# Keystone client
# ---------------
if [[ "$ENABLED_SERVICES" =~ "key" ]]; then
    if [[ "$SKIP_EXERCISES" =~ "key" ]] ; then
        STATUS_KEYSTONE="Skipped"
    else
        echo -e "\nTest Keystone"
        if keystone service-list; then
            STATUS_KEYSTONE="Succeeded"
        else
            STATUS_KEYSTONE="Failed"
            RETURN=1
        fi
    fi
fi

# Nova client
# -----------

if [[ "$ENABLED_SERVICES" =~ "n-api" ]]; then
    if [[ "$SKIP_EXERCISES" =~ "n-api" ]] ; then
        STATUS_NOVA="Skipped"
    else
        echo -e "\nTest Nova"
        if nova flavor-list; then
            STATUS_NOVA="Succeeded"
        else
            STATUS_NOVA="Failed"
            RETURN=1
        fi
    fi
fi

# Glance client
# -------------

if [[ "$ENABLED_SERVICES" =~ "g-api" ]]; then
    if [[ "$SKIP_EXERCISES" =~ "g-api" ]] ; then
        STATUS_GLANCE="Skipped"
    else
        echo -e "\nTest Glance"
        if glance index; then
            STATUS_GLANCE="Succeeded"
        else
            STATUS_GLANCE="Failed"
            RETURN=1
        fi
    fi
fi

# Swift client
# ------------

if [[ "$ENABLED_SERVICES" =~ "swift" ]]; then
    if [[ "$SKIP_EXERCISES" =~ "swift" ]] ; then
        STATUS_SWIFT="Skipped"
    else
        echo -e "\nTest Swift"
        if swift stat; then
            STATUS_SWIFT="Succeeded"
        else
            STATUS_SWIFT="Failed"
            RETURN=1
        fi
    fi
fi

# Results
# -------

function report() {
    if [[ -n "$2" ]]; then
        echo "$1: $2"
    fi
}

echo -e "\n"
report "Keystone" $STATUS_KEYSTONE
report "Nova" $STATUS_NOVA
report "Glance" $STATUS_GLANCE
report "Swift" $STATUS_SWIFT

echo "**************************************************"
echo "End DevStack Exercise: $0"
echo "**************************************************"

exit $RETURN
