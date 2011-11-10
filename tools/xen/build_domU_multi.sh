#!/usr/bin/env bash

# Echo commands
set -o xtrace

# Head node host, which runs glance, api, keystone
HEAD_PUB_IP=${HEAD_PUB_IP:-192.168.1.57}
HEAD_MGT_IP=${HEAD_MGT_IP:-172.16.100.57}

COMPUTE_PUB_IP=${COMPUTE_PUB_IP:-192.168.1.58}
COMPUTE_MGT_IP=${COMPUTE_MGT_IP:-172.16.100.58}

# Networking params
FLOATING_RANGE=${FLOATING_RANGE:-192.168.1.196/30}

# Variables common amongst all hosts in the cluster
COMMON_VARS="$STACKSH_PARAMS MYSQL_HOST=$HEAD_MGT_IP RABBIT_HOST=$HEAD_MGT_IP GLANCE_HOSTPORT=$HEAD_MGT_IP:9292 FLOATING_RANGE=$FLOATING_RANGE"

# Helper to launch containers
function build_domU {
    GUEST_NAME=$1 PUB_IP=$2 MGT_IP=$3 DO_SHUTDOWN=$4 TERMINATE=$TERMINATE STACKSH_PARAMS="$COMMON_VARS $5" ./build_domU.sh
}

# Launch the head node - headnode uses a non-ip domain name,
# because rabbit won't launch with an ip addr hostname :(
build_domU HEADNODE $HEAD_PUB_IP $HEAD_MGT_IP 1 "ENABLED_SERVICES=g-api,g-reg,key,n-api,n-sch,n-vnc,horizon,mysql,rabbit"

# Wait till the head node is up
while ! curl -L http://$HEAD_PUB_IP | grep -q username; do
    echo "Waiting for head node ($HEAD_PUB_IP) to start..."
    sleep 5
done

# Build the HA compute host
build_domU $COMPUTE_PUB_IP $COMPUTE_PUB_IP $COMPUTE_MGT_IP 0 "ENABLED_SERVICES=n-cpu,n-net,n-api"
