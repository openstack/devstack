#!/bin/bash
# Echo commands, exit on error
set -o xtrace
set -o errexit

TOP_DIR=$(cd ../../.. && pwd)
HEAD_IP=`cat $TOP_DIR/addresses | grep HEAD | cut -d "=" -f2`
die_if_not_set $LINENO HEAD_IP "Failure retrieving HEAD_IP"
ssh stack@$HEAD_IP 'cd devstack && source openrc && cd exercises &&  ./euca.sh'
