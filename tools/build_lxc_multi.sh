#!/usr/bin/env bash
# Head node host, which runs glance, api, keystone
HEAD_HOST=${HEAD_HOST:-192.168.1.52}
COMPUTE_HOSTS=${COMPUTE_HOSTS:-192.168.1.53,192.168.1.54}

# Networking params
NAMESERVER=${NAMESERVER:-192.168.1.1}
GATEWAY=${GATEWAY:-192.168.1.1}
NETMASK=${NETMASK:-255.255.255.0}
FLOATING_RANGE=${FLOATING_RANGE:-192.168.1.196/30}

# Setting this to 1 shuts down and destroys our containers without relaunching.
TERMINATE=${TERMINATE:-0}

# Variables common amongst all hosts in the cluster
COMMON_VARS="MYSQL_HOST=$HEAD_HOST RABBIT_HOST=$HEAD_HOST GLANCE_HOSTPORT=$HEAD_HOST:9292 NET_MAN=FlatDHCPManager FLAT_INTERFACE=eth0 FLOATING_RANGE=$FLOATING_RANGE MULTI_HOST=1"

# Helper to launch containers
function run_lxc {
    # For some reason container names with periods can cause issues :/
    CONTAINER_NAME=$1 CONTAINER_IP=$2 CONTAINER_NETMASK=$NETMASK CONTAINER_GATEWAY=$GATEWAY NAMESERVER=$NAMESERVER TERMINATE=$TERMINATE STACKSH_PARAMS="$COMMON_VARS $3" ./build_lxc.sh
}

# Launch the head node - headnode uses a non-ip domain name,
# because rabbit won't launch with an ip addr hostname :(
run_lxc STACKMASTER $HEAD_HOST "ENABLED_SERVICES=g-api,g-reg,key,n-api,n-sch,n-vnc,dash,mysql,rabbit"

# Wait till the head node is up
if [ ! "$TERMINATE" = "1" ]; then
    while ! wget -q -O- http://$HEAD_HOST | grep -q username; do
        echo "Waiting for head node ($HEAD_HOST) to start..."
        sleep 5
    done
fi

# Launch the compute hosts
for compute_host in ${COMPUTE_HOSTS//,/ }; do
    run_lxc $compute_host $compute_host "ENABLED_SERVICES=n-cpu,n-net,n-api"
done
