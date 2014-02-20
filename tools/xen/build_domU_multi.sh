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
function build_xva {
    GUEST_NAME=$1 PUB_IP=$2 MGT_IP=$3 DO_SHUTDOWN=$4 TERMINATE=$TERMINATE STACKSH_PARAMS="$COMMON_VARS $5" ./build_xva.sh
}

# Launch the head node - headnode uses a non-ip domain name,
# because rabbit won't launch with an ip addr hostname :(
build_xva HEADNODE $HEAD_PUB_IP $HEAD_MGT_IP 1 "ENABLED_SERVICES=g-api,g-reg,key,n-api,n-sch,n-vnc,horizon,mysql,rabbit"

# Build the HA compute host
build_xva COMPUTENODE $COMPUTE_PUB_IP $COMPUTE_MGT_IP 0 "ENABLED_SERVICES=n-cpu,n-net,n-api"
