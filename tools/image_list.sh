#!/bin/bash

# Print out a list of image and other files to download for caching.
# This is mostly used by the OpenStack infrasturucture during daily
# image builds to save the large images to /opt/cache/files (see [1])
#
# The two lists of URL's downloaded are the IMAGE_URLS and
# EXTRA_CACHE_URLS, which are setup in stackrc
#
# [1] project-config:nodepool/elements/cache-devstack/extra-data.d/55-cache-devstack-repos

# Keep track of the DevStack directory
TOP_DIR=$(cd $(dirname "$0")/.. && pwd)

# The following "source" implicitly calls get_default_host_ip() in
# stackrc and will die if the selected default IP happens to lie
# in the default ranges for FIXED_RANGE or FLOATING_RANGE. Since we
# do not really need HOST_IP to be properly set in the remainder of
# this script, just set it to some dummy value and make stackrc happy.
HOST_IP=SKIP
source $TOP_DIR/functions

# Possible virt drivers, if we have more, add them here. Always keep
# dummy in the end position to trigger the fall through case.
DRIVERS="openvz ironic libvirt vsphere dummy"

# Extra variables to trigger getting additional images.
export ENABLED_SERVICES="h-api,tr-api"
HEAT_FETCHED_TEST_IMAGE="Fedora-i386-20-20131211.1-sda"
PRECACHE_IMAGES=True

# Loop over all the virt drivers and collect all the possible images
ALL_IMAGES=""
for driver in $DRIVERS; do
    VIRT_DRIVER=$driver
    URLS=$(source $TOP_DIR/stackrc && echo $IMAGE_URLS)
    if [[ ! -z "$ALL_IMAGES" ]]; then
        ALL_IMAGES+=,
    fi
    ALL_IMAGES+=$URLS
done

# Sanity check - ensure we have a minimum number of images
num=$(echo $ALL_IMAGES | tr ',' '\n' | sort | uniq | wc -l)
if [[ "$num" -lt 4 ]]; then
    echo "ERROR: We only found $num images in $ALL_IMAGES, which can't be right."
    exit 1
fi

# This is extra non-image files that we want pre-cached.  This is kept
# in a separate list because devstack loops over the IMAGE_LIST to
# upload files glance and these aren't images.  (This was a bit of an
# after-thought which is why the naming around this is very
# image-centric)
URLS=$(source $TOP_DIR/stackrc && echo $EXTRA_CACHE_URLS)
ALL_IMAGES+=$URLS

# Make a nice combined list
echo $ALL_IMAGES | tr ',' '\n' | sort | uniq
