#!/usr/bin/env bash
# upload_image.sh - Retrieve and upload an image into Glance
#
# upload_image.sh <image-url>
#
# Assumes credentials are set via OS_* environment variables

function usage {
    echo "$0 - Retrieve and upload an image into Glance"
    echo ""
    echo "Usage: $0 <image-url> [...]"
    echo ""
    echo "Assumes credentials are set via OS_* environment variables"
    exit 1
}

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Import common functions
source $TOP_DIR/functions

# Import configuration
source $TOP_DIR/openrc "" "" "" ""

# Find the cache dir
FILES=$TOP_DIR/files

if [[ -z "$1" ]]; then
    usage
fi

# Get a token to authenticate to glance
TOKEN=$(keystone token-get | grep ' id ' | get_field 2)

# Glance connection info.  Note the port must be specified.
GLANCE_HOSTPORT=${GLANCE_HOSTPORT:-$GLANCE_HOST:9292}

for IMAGE in "$*"; do
    upload_image $IMAGE $TOKEN
done
