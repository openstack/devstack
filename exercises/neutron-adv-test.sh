#!/usr/bin/env bash
#

# **neutron-adv-test.sh**

# Perform integration testing of Nova and other components with Neutron.

echo "*********************************************************************"
echo "Begin DevStack Exercise: $0"
echo "*********************************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.

set -o errtrace

trap failed ERR
failed() {
    local r=$?
    set +o errtrace
    set +o xtrace
    echo "Failed to execute"
    echo "Starting cleanup..."
    delete_all
    echo "Finished cleanup"
    exit $r
}

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# Environment
# -----------

# Keep track of the current directory
EXERCISE_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $EXERCISE_DIR/..; pwd)

# Import common functions
source $TOP_DIR/functions

# Import configuration
source $TOP_DIR/openrc

# Import neutron functions
source $TOP_DIR/lib/neutron

# If neutron is not enabled we exit with exitcode 55, which means exercise is skipped.
neutron_plugin_check_adv_test_requirements || exit 55

# Import exercise configuration
source $TOP_DIR/exerciserc

# Neutron Settings
# ----------------

TENANTS="DEMO1"
# TODO (nati)_Test public network
#TENANTS="DEMO1,DEMO2"

PUBLIC_NAME="admin"
DEMO1_NAME="demo1"
DEMO2_NAME="demo2"

PUBLIC_NUM_NET=1
DEMO1_NUM_NET=1
DEMO2_NUM_NET=2

PUBLIC_NET1_CIDR="200.0.0.0/24"
DEMO1_NET1_CIDR="10.10.0.0/24"
DEMO2_NET1_CIDR="10.20.0.0/24"
DEMO2_NET2_CIDR="10.20.1.0/24"

PUBLIC_NET1_GATEWAY="200.0.0.1"
DEMO1_NET1_GATEWAY="10.10.0.1"
DEMO2_NET1_GATEWAY="10.20.0.1"
DEMO2_NET2_GATEWAY="10.20.1.1"

PUBLIC_NUM_VM=1
DEMO1_NUM_VM=1
DEMO2_NUM_VM=2

PUBLIC_VM1_NET='admin-net1'
DEMO1_VM1_NET='demo1-net1'
# Multinic settings. But this is fail without nic setting in OS image
DEMO2_VM1_NET='demo2-net1'
DEMO2_VM2_NET='demo2-net2'

PUBLIC_NUM_ROUTER=1
DEMO1_NUM_ROUTER=1
DEMO2_NUM_ROUTER=1

PUBLIC_ROUTER1_NET="admin-net1"
DEMO1_ROUTER1_NET="demo1-net1"
DEMO2_ROUTER1_NET="demo2-net1"

KEYSTONE="keystone"

# Manually create a token by querying keystone (sending JSON data).  Keystone
# returns a token and catalog of endpoints.  We use python to parse the token
# and save it.

TOKEN=`keystone token-get | grep ' id ' | awk '{print $4}'`
die_if_not_set $LINENO TOKEN "Keystone fail to get token"

# Various functions
# -----------------

function foreach_tenant {
    COMMAND=$1
    for TENANT in ${TENANTS//,/ };do
        eval ${COMMAND//%TENANT%/$TENANT}
    done
}

function foreach_tenant_resource {
    COMMAND=$1
    RESOURCE=$2
    for TENANT in ${TENANTS//,/ };do
        eval 'NUM=$'"${TENANT}_NUM_$RESOURCE"
        for i in `seq $NUM`;do
            local COMMAND_LOCAL=${COMMAND//%TENANT%/$TENANT}
            COMMAND_LOCAL=${COMMAND_LOCAL//%NUM%/$i}
            eval $COMMAND_LOCAL
        done
    done
}

function foreach_tenant_vm {
    COMMAND=$1
    foreach_tenant_resource "$COMMAND" 'VM'
}

function foreach_tenant_net {
    COMMAND=$1
    foreach_tenant_resource "$COMMAND" 'NET'
}

function get_image_id {
    local IMAGE_ID=$(glance image-list | egrep " $DEFAULT_IMAGE_NAME " | get_field 1)
    die_if_not_set $LINENO IMAGE_ID "Failure retrieving IMAGE_ID"
    echo "$IMAGE_ID"
}

function get_tenant_id {
    local TENANT_NAME=$1
    local TENANT_ID=`keystone tenant-list | grep " $TENANT_NAME " | head -n 1 | get_field 1`
    die_if_not_set $LINENO TENANT_ID "Failure retrieving TENANT_ID for $TENANT_NAME"
    echo "$TENANT_ID"
}

function get_user_id {
    local USER_NAME=$1
    local USER_ID=`keystone user-list | grep $USER_NAME | awk '{print $2}'`
    die_if_not_set $LINENO USER_ID "Failure retrieving USER_ID for $USER_NAME"
    echo "$USER_ID"
}

function get_role_id {
    local ROLE_NAME=$1
    local ROLE_ID=`keystone role-list | grep $ROLE_NAME | awk '{print $2}'`
    die_if_not_set $LINENO ROLE_ID "Failure retrieving ROLE_ID for $ROLE_NAME"
    echo "$ROLE_ID"
}

function get_network_id {
    local NETWORK_NAME="$1"
    local NETWORK_ID=`neutron net-list -F id  -- --name=$NETWORK_NAME | awk "NR==4" | awk '{print $2}'`
    echo $NETWORK_ID
}

function get_flavor_id {
    local INSTANCE_TYPE=$1
    local FLAVOR_ID=`nova flavor-list | grep $INSTANCE_TYPE | awk '{print $2}'`
    die_if_not_set $LINENO FLAVOR_ID "Failure retrieving FLAVOR_ID for $INSTANCE_TYPE"
    echo "$FLAVOR_ID"
}

function confirm_server_active {
    local VM_UUID=$1
    if ! timeout $ACTIVE_TIMEOUT sh -c "while ! nova show $VM_UUID | grep status | grep -q ACTIVE; do sleep 1; done"; then
        echo "server '$VM_UUID' did not become active!"
        false
    fi
}

function add_tenant {
    local TENANT=$1
    local USER=$2

    $KEYSTONE tenant-create --name=$TENANT
    $KEYSTONE user-create --name=$USER --pass=${ADMIN_PASSWORD}

    local USER_ID=$(get_user_id $USER)
    local TENANT_ID=$(get_tenant_id $TENANT)

    $KEYSTONE user-role-add --user-id $USER_ID --role-id $(get_role_id Member) --tenant-id $TENANT_ID
}

function remove_tenant {
    local TENANT=$1
    local TENANT_ID=$(get_tenant_id $TENANT)
    $KEYSTONE tenant-delete $TENANT_ID
}

function remove_user {
    local USER=$1
    local USER_ID=$(get_user_id $USER)
    $KEYSTONE user-delete $USER_ID
}

function create_tenants {
    source $TOP_DIR/openrc admin admin
    add_tenant demo1 demo1 demo1
    add_tenant demo2 demo2 demo2
    source $TOP_DIR/openrc demo demo
}

function delete_tenants_and_users {
    source $TOP_DIR/openrc admin admin
    remove_user demo1
    remove_tenant demo1
    remove_user demo2
    remove_tenant demo2
    echo "removed all tenants"
    source $TOP_DIR/openrc demo demo
}

function create_network {
    local TENANT=$1
    local GATEWAY=$2
    local CIDR=$3
    local NUM=$4
    local EXTRA=$5
    local NET_NAME="${TENANT}-net$NUM"
    local ROUTER_NAME="${TENANT}-router${NUM}"
    source $TOP_DIR/openrc admin admin
    local TENANT_ID=$(get_tenant_id $TENANT)
    source $TOP_DIR/openrc $TENANT $TENANT
    local NET_ID=$(neutron net-create --tenant-id $TENANT_ID $NET_NAME $EXTRA| grep ' id ' | awk '{print $4}' )
    die_if_not_set $LINENO NET_ID "Failure creating NET_ID for $TENANT_ID $NET_NAME $EXTRA"
    neutron subnet-create --ip-version 4 --tenant-id $TENANT_ID --gateway $GATEWAY $NET_ID $CIDR
    neutron-debug probe-create --device-owner compute $NET_ID
    source $TOP_DIR/openrc demo demo
}

function create_networks {
    foreach_tenant_net 'create_network ${%TENANT%_NAME} ${%TENANT%_NET%NUM%_GATEWAY} ${%TENANT%_NET%NUM%_CIDR} %NUM% ${%TENANT%_NET%NUM%_EXTRA}'
    #TODO(nati) test security group function
    # allow ICMP for both tenant's security groups
    #source $TOP_DIR/openrc demo1 demo1
    #$NOVA secgroup-add-rule default icmp -1 -1 0.0.0.0/0
    #source $TOP_DIR/openrc demo2 demo2
    #$NOVA secgroup-add-rule default icmp -1 -1 0.0.0.0/0
}

function create_vm {
    local TENANT=$1
    local NUM=$2
    local NET_NAMES=$3
    source $TOP_DIR/openrc $TENANT $TENANT
    local NIC=""
    for NET_NAME in ${NET_NAMES//,/ };do
        NIC="$NIC --nic net-id="`get_network_id $NET_NAME`
    done
    #TODO (nati) Add multi-nic test
    #TODO (nati) Add public-net test
    local VM_UUID=`nova boot --flavor $(get_flavor_id m1.tiny) \
        --image $(get_image_id) \
        $NIC \
        $TENANT-server$NUM | grep ' id ' | cut -d"|" -f3 | sed 's/ //g'`
    die_if_not_set $LINENO VM_UUID "Failure launching $TENANT-server$NUM"
    confirm_server_active $VM_UUID
}

function create_vms {
    foreach_tenant_vm 'create_vm ${%TENANT%_NAME} %NUM% ${%TENANT%_VM%NUM%_NET}'
}

function ping_ip {
    # Test agent connection.  Assumes namespaces are disabled, and
    # that DHCP is in use, but not L3
    local VM_NAME=$1
    local NET_NAME=$2
    IP=$(get_instance_ip $VM_NAME $NET_NAME)
    ping_check $NET_NAME $IP $BOOT_TIMEOUT
}

function check_vm {
    local TENANT=$1
    local NUM=$2
    local VM_NAME="$TENANT-server$NUM"
    local NET_NAME=$3
    source $TOP_DIR/openrc $TENANT $TENANT
    ping_ip $VM_NAME $NET_NAME
    # TODO (nati) test ssh connection
    # TODO (nati) test inter connection between vm
    # TODO (nati) test dhcp host routes
    # TODO (nati) test multi-nic
}

function check_vms {
    foreach_tenant_vm 'check_vm ${%TENANT%_NAME} %NUM% ${%TENANT%_VM%NUM%_NET}'
}

function shutdown_vm {
    local TENANT=$1
    local NUM=$2
    source $TOP_DIR/openrc $TENANT $TENANT
    VM_NAME=${TENANT}-server$NUM
    nova delete $VM_NAME
}

function shutdown_vms {
    foreach_tenant_vm 'shutdown_vm ${%TENANT%_NAME} %NUM%'
    if ! timeout $TERMINATE_TIMEOUT sh -c "while nova list | grep -q ACTIVE; do sleep 1; done"; then
        die $LINENO "Some VMs failed to shutdown"
    fi
}

function delete_network {
    local TENANT=$1
    local NUM=$2
    local NET_NAME="${TENANT}-net$NUM"
    source $TOP_DIR/openrc admin admin
    local TENANT_ID=$(get_tenant_id $TENANT)
    #TODO(nati) comment out until l3-agent merged
    #for res in port subnet net router;do
    for net_id in `neutron net-list -c id -c name | grep $NET_NAME | awk '{print $2}'`;do
        delete_probe $net_id
        neutron subnet-list | grep $net_id | awk '{print $2}' | xargs -I% neutron subnet-delete %
        neutron net-delete $net_id
    done
    source $TOP_DIR/openrc demo demo
}

function delete_networks {
    foreach_tenant_net 'delete_network ${%TENANT%_NAME} %NUM%'
    # TODO(nati) add secuirty group check after it is implemented
    # source $TOP_DIR/openrc demo1 demo1
    # nova secgroup-delete-rule default icmp -1 -1 0.0.0.0/0
    # source $TOP_DIR/openrc demo2 demo2
    # nova secgroup-delete-rule default icmp -1 -1 0.0.0.0/0
}

function create_all {
    create_tenants
    create_networks
    create_vms
}

function delete_all {
    shutdown_vms
    delete_networks
    delete_tenants_and_users
}

function all {
    create_all
    check_vms
    delete_all
}

# Test functions
# --------------

function test_functions {
    IMAGE=$(get_image_id)
    echo $IMAGE

    TENANT_ID=$(get_tenant_id demo)
    echo $TENANT_ID

    FLAVOR_ID=$(get_flavor_id m1.tiny)
    echo $FLAVOR_ID

    NETWORK_ID=$(get_network_id admin)
    echo $NETWORK_ID
}

# Usage and main
# --------------

usage() {
    echo "$0: [-h]"
    echo "  -h, --help              Display help message"
    echo "  -t, --tenant            Create tenants"
    echo "  -n, --net               Create networks"
    echo "  -v, --vm                Create vms"
    echo "  -c, --check             Check connection"
    echo "  -x, --delete-tenants    Delete tenants"
    echo "  -y, --delete-nets       Delete networks"
    echo "  -z, --delete-vms        Delete vms"
    echo "  -T, --test              Test functions"
}

main() {

    echo Description
    echo
    echo Copyright 2012, Cisco Systems
    echo Copyright 2012, VMware, Inc.
    echo Copyright 2012, NTT MCL, Inc.
    echo
    echo Please direct any questions to dedutta@cisco.com, dwendlandt@vmware.com, nachi@nttmcl.com
    echo


    if [ $# -eq 0 ] ; then
        # if no args are provided, run all tests
        all
    else

        while [ "$1" != "" ]; do
            case $1 in
                -h | --help )   usage
                                exit
                                ;;
                -n | --net )    create_networks
                                exit
                                ;;
                -v | --vm )     create_vms
                                exit
                                ;;
                -t | --tenant ) create_tenants
                                exit
                                ;;
                -c | --check )   check_vms
                                exit
                                ;;
                -T | --test )   test_functions
                                exit
                                ;;
                -x | --delete-tenants ) delete_tenants_and_users
                                exit
                                ;;
                -y | --delete-nets ) delete_networks
                                exit
                                ;;
                -z | --delete-vms ) shutdown_vms
                                exit
                                ;;
                -a | --all )    all
                                exit
                                ;;
                * )             usage
                                exit 1
            esac
            shift
        done
    fi
}

# Kick off script
# ---------------

echo $*
main $*

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"
