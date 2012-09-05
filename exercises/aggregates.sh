#!/usr/bin/env bash

# **aggregates.sh**

# This script demonstrates how to use host aggregates:
#  *  Create an Aggregate
#  *  Updating Aggregate details
#  *  Testing Aggregate metadata
#  *  Testing Aggregate delete
#  *  Testing General Aggregates (https://blueprints.launchpad.net/nova/+spec/general-host-aggregates)
#  *  Testing add/remove hosts (with one host)

echo "**************************************************"
echo "Begin DevStack Exercise: $0"
echo "**************************************************"

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

# run test as the admin user
_OLD_USERNAME=$OS_USERNAME
OS_USERNAME=admin


# Create an aggregate
# ===================

AGGREGATE_NAME=test_aggregate_$RANDOM
AGGREGATE2_NAME=test_aggregate_$RANDOM
AGGREGATE_A_ZONE=nova

exit_if_aggregate_present() {
    aggregate_name=$1

    if [ `nova aggregate-list | grep -c " $aggregate_name "` == 0 ]; then
        echo "SUCCESS $aggregate_name not present"
    else
        echo "ERROR found aggregate: $aggregate_name"
        exit -1
    fi
}

exit_if_aggregate_present $AGGREGATE_NAME

AGGREGATE_ID=`nova aggregate-create $AGGREGATE_NAME $AGGREGATE_A_ZONE | grep " $AGGREGATE_NAME " | get_field 1`
AGGREGATE2_ID=`nova aggregate-create $AGGREGATE2_NAME $AGGREGATE_A_ZONE | grep " $AGGREGATE2_NAME " | get_field 1`

# check aggregate created
nova aggregate-list | grep -q " $AGGREGATE_NAME " || die "Aggregate $AGGREGATE_NAME not created"


# Ensure creating a duplicate fails
# =================================

if nova aggregate-create $AGGREGATE_NAME $AGGREGATE_A_ZONE; then
    echo "ERROR could create duplicate aggregate"
    exit -1
fi


# Test aggregate-update (and aggregate-details)
# =============================================
AGGREGATE_NEW_NAME=test_aggregate_$RANDOM

nova aggregate-update $AGGREGATE_ID $AGGREGATE_NEW_NAME
nova aggregate-details $AGGREGATE_ID | grep $AGGREGATE_NEW_NAME
nova aggregate-details $AGGREGATE_ID | grep $AGGREGATE_A_ZONE

nova aggregate-update $AGGREGATE_ID $AGGREGATE_NAME $AGGREGATE_A_ZONE
nova aggregate-details $AGGREGATE_ID | grep $AGGREGATE_NAME
nova aggregate-details $AGGREGATE_ID | grep $AGGREGATE_A_ZONE


# Test aggregate-set-metadata
# ===========================
META_DATA_1_KEY=asdf
META_DATA_2_KEY=foo
META_DATA_3_KEY=bar

#ensure no metadata is set
nova aggregate-details $AGGREGATE_ID | grep {}

nova aggregate-set-metadata $AGGREGATE_ID ${META_DATA_1_KEY}=123
nova aggregate-details $AGGREGATE_ID | grep $META_DATA_1_KEY
nova aggregate-details $AGGREGATE_ID | grep 123

nova aggregate-set-metadata $AGGREGATE_ID ${META_DATA_2_KEY}=456
nova aggregate-details $AGGREGATE_ID | grep $META_DATA_1_KEY
nova aggregate-details $AGGREGATE_ID | grep $META_DATA_2_KEY

nova aggregate-set-metadata $AGGREGATE_ID $META_DATA_2_KEY ${META_DATA_3_KEY}=789
nova aggregate-details $AGGREGATE_ID | grep $META_DATA_1_KEY
nova aggregate-details $AGGREGATE_ID | grep $META_DATA_3_KEY

nova aggregate-details $AGGREGATE_ID | grep $META_DATA_2_KEY && die "ERROR metadata was not cleared"

nova aggregate-set-metadata $AGGREGATE_ID $META_DATA_3_KEY $META_DATA_1_KEY
nova aggregate-details $AGGREGATE_ID | grep {}


# Test aggregate-add/remove-host
# ==============================
if [ "$VIRT_DRIVER" == "xenserver" ]; then
    echo "TODO(johngarbutt) add tests for add/remove host from pool aggregate"
fi
FIRST_HOST=`nova host-list | grep compute | get_field 1 | head -1`
# Make sure can add two aggregates to same host
nova aggregate-add-host $AGGREGATE_ID $FIRST_HOST
nova aggregate-add-host $AGGREGATE2_ID $FIRST_HOST
if nova aggregate-add-host $AGGREGATE2_ID $FIRST_HOST; then
    echo "ERROR could add duplicate host to single aggregate"
    exit -1
fi
nova aggregate-remove-host $AGGREGATE2_ID $FIRST_HOST
nova aggregate-remove-host $AGGREGATE_ID $FIRST_HOST

# Test aggregate-delete
# =====================
nova aggregate-delete $AGGREGATE_ID
nova aggregate-delete $AGGREGATE2_ID
exit_if_aggregate_present $AGGREGATE_NAME


# Test complete
# =============
OS_USERNAME=$_OLD_USERNAME
echo "AGGREGATE TEST PASSED"

set +o xtrace
echo "**************************************************"
echo "End DevStack Exercise: $0"
echo "**************************************************"
