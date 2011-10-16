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
export NOVA_API_KEY=${PASSWORD:-secrete}

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

# List of flavors:
nova flavor-list

# Images
# ------

# Nova has a **deprecated** way of listing images.
nova image-list

# But we recommend using glance directly
glance -A $TOKEN index

# show details of the active servers::
#
#     nova show 1234
#
nova list | grep ACTIVE | cut -d \| -f2 | xargs -n1 nova show
