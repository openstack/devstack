#!/bin/bash
#
# Copyright 2015 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# Ping a neutron guest using a network namespace probe

set -o errexit
set -o pipefail

TOP_DIR=$(cd $(dirname "$0")/.. && pwd)

# This *must* be run as the admin tenant
source $TOP_DIR/openrc admin admin

function usage {
    cat - <<EOF
ping_neutron.sh <net_name> [ping args]

This provides a wrapper to ping neutron guests that are on isolated
tenant networks that the caller can't normally reach. It does so by
using either the DHCP or Metadata network namespace to support both
ML2/OVS and OVN.

It takes arguments like ping, except the first arg must be the network
name.

Note: in environments with duplicate network names, the results are
non deterministic.

This should *really* be in the neutron cli.

EOF
    exit 1
}

# BUG: with duplicate network names, this fails pretty hard since it
# will just pick the first match.
function _get_net_id {
    openstack --os-cloud devstack-admin --os-region-name="$REGION_NAME" --os-project-name admin --os-username admin --os-password $ADMIN_PASSWORD network list | grep $1 | head -n 1 | awk '{print $2}'
}

NET_NAME=$1

if [[ -z "$NET_NAME" ]]; then
    echo "Error: net_name is required"
    usage
fi

REMAINING_ARGS="${@:2}"

NET_ID=`_get_net_id $NET_NAME`
NET_NS=$(ip netns list | grep "$NET_ID" | head -n 1)

# This runs a command inside the specific netns
NET_NS_CMD="ip netns exec $NET_NS"

PING_CMD="sudo $NET_NS_CMD ping $REMAINING_ARGS"
echo "Running $PING_CMD"
$PING_CMD
