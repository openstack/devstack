#!/usr/bin/env bash

# **exercise.sh** - using the cloud can be fun

# we will use the ``nova`` cli tool provided by the ``python-novaclient``
# package
#


# This script exits on an error so that errors don't compound and you see 
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers 
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# Settings
# ========

# Use stackrc and localrc for settings
source ./stackrc

HOST=${HOST:-localhost}

# Nova original used project_id as the *account* that owned resources (servers,
# ip address, ...)   With the addition of Keystone we have standardized on the
# term **tenant** as the entity that owns the resources.  **novaclient** still
# uses the old deprecated terms project_id.  Note that this field should now be
# set to tenant_name, not tenant_id.
export NOVA_PROJECT_ID=${TENANT:-demo}

# In addition to the owning entity (tenant), nova stores the entity performing
# the action as the **user**.
export NOVA_USERNAME=${USERNAME:-demo}

# With Keystone you pass the keystone password instead of an api key.
export NOVA_API_KEY=${ADMIN_PASSWORD:-secrete}

# With the addition of Keystone, to use an openstack cloud you should 
# authenticate against keystone, which returns a **Token** and **Service 
# Catalog**.  The catalog contains the endpoint for all services the user/tenant 
# has access to - including nova, glance, keystone, swift, ...  We currently 
# recommend using the 2.0 *auth api*.  
#
# *NOTE*: Using the 2.0 *auth api* does mean that compute api is 2.0.  We will
# use the 1.1 *compute api*
export NOVA_URL=${NOVA_URL:-http://$HOST:5000/v2.0/}

# Currently novaclient needs you to specify the *compute api* version.  This
# needs to match the config of your catalog returned by Keystone.
export NOVA_VERSION=1.1

# FIXME - why does this need to be specified?
export NOVA_REGION_NAME=RegionOne

# set log level to DEBUG (helps debug issues)
export NOVACLIENT_DEBUG=1

# Get a token for clients that don't support service catalog
# ==========================================================

# manually create a token by querying keystone (sending JSON data).  Keystone 
# returns a token and catalog of endpoints.  We use python to parse the token
# and save it.

TOKEN=`curl -s -d  "{\"auth\":{\"passwordCredentials\": {\"username\": \"$NOVA_USERNAME\", \"password\": \"$NOVA_API_KEY\"}}}" -H "Content-type: application/json" http://$HOST:5000/v2.0/tokens | python -c "import sys; import json; tok = json.loads(sys.stdin.read()); print tok['access']['token']['id'];"`

# Launching a server
# ==================

# List servers for tenant:
nova list

# Images
# ------

# Nova has a **deprecated** way of listing images.
nova image-list

# But we recommend using glance directly
glance -A $TOKEN index

# Let's grab the id of the first AMI image to launch
IMAGE=`glance -A $TOKEN index | egrep ami | cut -d" " -f1`

# Security Groups
# ---------------
SECGROUP=test_secgroup

# List of secgroups:
nova secgroup-list

# Create a secgroup
nova secgroup-create $SECGROUP "test_secgroup description"

# Flavors
# -------

# List of flavors:
nova flavor-list

# and grab the first flavor in the list to launch
FLAVOR=`nova flavor-list | head -n 4 | tail -n 1 | cut -d"|" -f2`

NAME="myserver"

nova boot --flavor $FLAVOR --image $IMAGE $NAME --security_groups=$SECGROUP

# let's give it 10 seconds to launch
sleep 10

# check that the status is active
nova show $NAME | grep status | grep -q ACTIVE

# get the IP of the server
IP=`nova show $NAME | grep "private network" | cut -d"|" -f3`

# ping it once (timeout of a second)
ping -c1 -w1 $IP || true

# sometimes the first ping fails (10 seconds isn't enough time for the VM's 
# network to respond?), so let's wait 5 seconds and really test ping
sleep 5

ping -c1 -w1 $IP 
# allow icmp traffic
nova secgroup-add-rule $SECGROUP icmp -1 -1 0.0.0.0/0

# List rules for a secgroup
nova secgroup-list-rules $SECGROUP

# allocate a floating ip
nova floating-ip-create

# store  floating address
FIP=`nova floating-ip-list | grep None | head -1 | cut -d '|' -f2 | sed 's/ //g'`

# add floating ip to our server
nova add-floating-ip $NAME $FIP

# sleep for a smidge
sleep 1

# ping our fip
ping -c1 -w1 $FIP

# dis-allow icmp traffic
nova secgroup-delete-rule $SECGROUP icmp -1 -1 0.0.0.0/0

# sleep for a smidge
sleep 1

# ping our fip
if ( ping -c1 -w1 $FIP); then
    print "Security group failure - ping should not be allowed!"
    exit 1
fi

# de-allocate the floating ip
nova floating-ip-delete $FIP

# shutdown the server
nova delete $NAME

# Delete a secgroup
nova secgroup-delete $SECGROUP

# FIXME: validate shutdown within 5 seconds 
# (nova show $NAME returns 1 or status != ACTIVE)?
