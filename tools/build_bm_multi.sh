#!/usr/bin/env bash

# **build_bm_multi.sh**

# Build an OpenStack install on several bare metal machines.
SHELL_AFTER_RUN=no

# Variables common amongst all hosts in the cluster
COMMON_VARS="MYSQL_HOST=$HEAD_HOST RABBIT_HOST=$HEAD_HOST GLANCE_HOSTPORT=$HEAD_HOST:9292 NETWORK_MANAGER=FlatDHCPManager FLAT_INTERFACE=eth0 FLOATING_RANGE=$FLOATING_RANGE MULTI_HOST=1 SHELL_AFTER_RUN=$SHELL_AFTER_RUN"

# Helper to launch containers
function run_bm {
    # For some reason container names with periods can cause issues :/
    CONTAINER=$1 CONTAINER_IP=$2 CONTAINER_NETMASK=$NETMASK CONTAINER_GATEWAY=$GATEWAY NAMESERVER=$NAMESERVER TERMINATE=$TERMINATE STACKSH_PARAMS="$COMMON_VARS $3" ./tools/build_bm.sh
}

# Launch the head node - headnode uses a non-ip domain name,
# because rabbit won't launch with an ip addr hostname :(
run_bm STACKMASTER $HEAD_HOST "ENABLED_SERVICES=g-api,g-reg,key,n-api,n-sch,n-vnc,horizon,mysql,rabbit"

# Wait till the head node is up
if [ ! "$TERMINATE" = "1" ]; then
    echo "Waiting for head node ($HEAD_HOST) to start..."
    if ! timeout 60 sh -c "while ! wget -q -O- http://$HEAD_HOST | grep -q username; do sleep 1; done"; then
        echo "Head node did not start"
        exit 1
    fi
fi

PIDS=""
# Launch the compute hosts in parallel
for compute_host in ${COMPUTE_HOSTS//,/ }; do
    run_bm $compute_host $compute_host "ENABLED_SERVICES=n-cpu,n-net,n-api" &
    PIDS="$PIDS $!"
done

for x in $PIDS; do
    wait $x
done
echo "build_bm_multi complete"
