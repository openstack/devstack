#!/bin/bash
# Echo commands, exit on error
set -o xtrace
set -o errexit

TOP_DIR=$(cd ../../.. && pwd)
HEAD_IP=`cat $TOP_DIR/addresses | grep HEAD | cut -d "=" -f2`
ssh stack@$HEAD_IP 'cd devstack && source openrc && cd exercises &&  ./swift.sh'
