#!/usr/bin/env bash

# Test swift via the command line tools that ship with it.

# This script exits on an error so that errors don't compound and you see
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace


# Settings
# ========

# Use openrc + stackrc + localrc for settings
pushd $(cd $(dirname "$0")/.. && pwd)
source ./openrc
popd


# Testing Swift
# =============

# Check if we have to swift via keystone
swift --auth-version 2 -A http://${HOST_IP}:5000/v2.0 -U admin -K $ADMIN_PASSWORD stat

# We start by creating a test container
swift --auth-version 2 -A http://${HOST_IP}:5000/v2.0 -U admin -K $ADMIN_PASSWORD post testcontainer

# add some files into it.
swift --auth-version 2 -A http://${HOST_IP}:5000/v2.0 -U admin -K $ADMIN_PASSWORD upload testcontainer /etc/issue

# list them
swift --auth-version 2 -A http://${HOST_IP}:5000/v2.0 -U admin -K $ADMIN_PASSWORD list testcontainer

# And we may want to delete them now that we have tested that
# everything works.
swift --auth-version 2 -A http://${HOST_IP}:5000/v2.0 -U admin -K $ADMIN_PASSWORD delete testcontainer
