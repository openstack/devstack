#!/usr/bin/env bash

# **exercise.sh** - using the cloud can be fun

# we will use the ``nova`` cli tool provided by the ``python-novaclient``
# package

# Settings/Options
# ================

HOST=${HOST:-localhost}
export NOVA_PROJECT_ID=${TENANT:-admin}
export NOVA_USERNAME=${USERNAME:-admin}
export NOVA_API_KEY=${PASS:-secrete}

# keystone is the authentication system.  We use the **auth** 2.0 protocol.
# Upon successful authentication, we are return a token and catalog of 
# endpoints (for openstack services)
export NOVA_URL="http://$HOST:5000/v2.0/"
export NOVA_VERSION=1.1

export

nova list
