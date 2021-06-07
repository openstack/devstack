#!/bin/bash
#
#
# NOTE(gmann): This script is used in 'devstack-tempest-ipv6' zuul job to verify that
# services are deployed on IPv6 properly or not. This will capture if any devstck or devstack
# plugins are missing the required setting to listen on IPv6 address. This is run as part of
# run phase of zuul job and before test run. Child job of 'devstack-tempest-ipv6'
# can expand the IPv6 verification specific to project by defining the new post-run script which
# will run along with this base script.
# If there are more common verification for IPv6 then we can always extent this script.

# Keep track of the DevStack directory
TOP_DIR=$(cd $(dirname "$0")/../../devstack && pwd)
source $TOP_DIR/stackrc
source $TOP_DIR/openrc admin admin

function verify_devstack_ipv6_setting {
    local _service_host=''
    _service_host=$(echo $SERVICE_HOST | tr -d [])
    local _host_ipv6=''
    _host_ipv6=$(echo $HOST_IPV6 | tr -d [])
    local _service_listen_address=''
    _service_listen_address=$(echo $SERVICE_LISTEN_ADDRESS | tr -d [])
    local _service_local_host=''
    _service_local_host=$(echo $SERVICE_LOCAL_HOST | tr -d [])
    if [[ "$SERVICE_IP_VERSION" != 6 ]]; then
        echo $SERVICE_IP_VERSION "SERVICE_IP_VERSION is not set to 6 which is must for devstack to deploy services with IPv6 address."
        exit 1
    fi
    is_service_host_ipv6=$(python3 -c 'import oslo_utils.netutils as nutils; print(nutils.is_valid_ipv6("'$_service_host'"))')
    if [[ "$is_service_host_ipv6" != "True" ]]; then
        echo $SERVICE_HOST "SERVICE_HOST is not ipv6 which means devstack cannot deploy services on IPv6 address."
        exit 1
    fi
    is_host_ipv6=$(python3 -c 'import oslo_utils.netutils as nutils; print(nutils.is_valid_ipv6("'$_host_ipv6'"))')
    if [[ "$is_host_ipv6" != "True" ]]; then
        echo $HOST_IPV6 "HOST_IPV6 is not ipv6 which means devstack cannot deploy services on IPv6 address."
        exit 1
    fi
    is_service_listen_address=$(python3 -c 'import oslo_utils.netutils as nutils; print(nutils.is_valid_ipv6("'$_service_listen_address'"))')
    if [[ "$is_service_listen_address" != "True" ]]; then
        echo $SERVICE_LISTEN_ADDRESS "SERVICE_LISTEN_ADDRESS is not ipv6 which means devstack cannot deploy services on IPv6 address."
        exit 1
    fi
    is_service_local_host=$(python3 -c 'import oslo_utils.netutils as nutils; print(nutils.is_valid_ipv6("'$_service_local_host'"))')
    if [[ "$is_service_local_host" != "True" ]]; then
        echo $SERVICE_LOCAL_HOST "SERVICE_LOCAL_HOST is not ipv6 which means devstack cannot deploy services on IPv6 address."
        exit 1
    fi
    echo "Devstack is properly configured with IPv6"
    echo "SERVICE_IP_VERSION: " $SERVICE_IP_VERSION "HOST_IPV6: " $HOST_IPV6 "SERVICE_HOST: " $SERVICE_HOST "SERVICE_LISTEN_ADDRESS: " $SERVICE_LISTEN_ADDRESS "SERVICE_LOCAL_HOST: " $SERVICE_LOCAL_HOST
}

function sanity_check_system_ipv6_enabled {
    system_ipv6_enabled=$(python3 -c 'import oslo_utils.netutils as nutils; print(nutils.is_ipv6_enabled())')
    if [[ $system_ipv6_enabled != "True" ]]; then
        echo "IPv6 is disabled in system"
        exit 1
    fi
    echo "IPv6 is enabled in system"
}

function verify_service_listen_address_is_ipv6 {
    local endpoints_verified=False
    local all_ipv6=True
    endpoints=$(openstack endpoint list -f value -c URL)
    for endpoint in ${endpoints}; do
        local endpoint_address=''
        endpoint_address=$(echo "$endpoint" | awk -F/ '{print $3}' | awk -F] '{print $1}')
        endpoint_address=$(echo $endpoint_address | tr -d [])
        local is_endpoint_ipv6=''
        is_endpoint_ipv6=$(python3 -c 'import oslo_utils.netutils as nutils; print(nutils.is_valid_ipv6("'$endpoint_address'"))')
        if [[ "$is_endpoint_ipv6" != "True" ]]; then
            all_ipv6=False
            echo $endpoint ": This is not ipv6 endpoint which means corresponding service is not listening on IPv6 address."
            continue
        fi
        endpoints_verified=True
    done
    if [[ "$all_ipv6" == "False"  ]] || [[ "$endpoints_verified" == "False" ]]; then
        exit 1
    fi
    echo "All services deployed by devstack is on IPv6 endpoints"
    echo $endpoints
}

#First thing to verify if system has IPv6 enabled or not
sanity_check_system_ipv6_enabled
#Verify whether devstack is configured properly with IPv6 setting
verify_devstack_ipv6_setting
#Get all registrfed endpoints by devstack in keystone and verify that each endpoints address is IPv6.
verify_service_listen_address_is_ipv6
