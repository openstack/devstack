#!/usr/bin/env bash

# **sec_groups.sh**

# Test security groups via the command line

echo "*********************************************************************"
echo "Begin DevStack Exercise: $0"
echo "*********************************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# Settings
# ========

# Keep track of the current directory
EXERCISE_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $EXERCISE_DIR/..; pwd)

# Import common functions
source $TOP_DIR/functions

# Import configuration
source $TOP_DIR/openrc

# Import exercise configuration
source $TOP_DIR/exerciserc

# If nova api is not enabled we exit with exitcode 55 so that
# the exercise is skipped
is_service_enabled n-api || exit 55


# Testing Security Groups
# =======================

# List security groups
nova secgroup-list

# Create random name for new sec group and create secgroup of said name
SEC_GROUP_NAME="ex-secgroup-$(openssl rand -hex 4)"
nova secgroup-create $SEC_GROUP_NAME 'a test security group'

# Add some rules to the secgroup
RULES_TO_ADD=( 22 3389 5900 )

for RULE in "${RULES_TO_ADD[@]}"; do
    nova secgroup-add-rule $SEC_GROUP_NAME tcp $RULE $RULE 0.0.0.0/0
done

# Check to make sure rules were added
SEC_GROUP_RULES=( $(nova secgroup-list-rules $SEC_GROUP_NAME | grep -v \- | grep -v 'Source Group' | cut -d '|' -f3 | tr -d ' ') )
die_if_not_set $LINENO SEC_GROUP_RULES "Failure retrieving SEC_GROUP_RULES for $SEC_GROUP_NAME"
for i in "${RULES_TO_ADD[@]}"; do
    skip=
    for j in "${SEC_GROUP_RULES[@]}"; do
        [[ $i == $j ]] && { skip=1; break; }
    done
    [[ -n $skip ]] || exit 1
done

# Delete rules and secgroup
for RULE in "${RULES_TO_ADD[@]}"; do
    nova secgroup-delete-rule $SEC_GROUP_NAME tcp $RULE $RULE 0.0.0.0/0
done

# Delete secgroup
nova secgroup-delete $SEC_GROUP_NAME || \
    die $LINENO "Failure deleting security group $SEC_GROUP_NAME"

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"
