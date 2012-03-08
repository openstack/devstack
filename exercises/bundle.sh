#!/usr/bin/env bash

# we will use the ``euca2ools`` cli tool that wraps the python boto
# library to test ec2 compatibility

echo "**************************************************"
echo "Begin DevStack Exercise: $0"
echo "**************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# Settings
# ========

# Keep track of the current directory
EXERCISE_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $EXERCISE_DIR/..; pwd)

# Import common functions
source $TOP_DIR/functions

# Import EC2 configuration
source $TOP_DIR/eucarc

# Remove old certificates
rm -f $TOP_DIR/cacert.pem
rm -f $TOP_DIR/cert.pem
rm -f $TOP_DIR/pk.pem

# Get Certificates
nova x509-get-root-cert $TOP_DIR/cacert.pem
nova x509-create-cert $TOP_DIR/pk.pem $TOP_DIR/cert.pem

# Max time to wait for image to be registered
REGISTER_TIMEOUT=${REGISTER_TIMEOUT:-15}

BUCKET=testbucket
IMAGE=bundle.img
truncate -s 5M /tmp/$IMAGE
euca-bundle-image -i /tmp/$IMAGE
die_if_error "Failure bundling image $IMAGE"


euca-upload-bundle -b $BUCKET -m /tmp/$IMAGE.manifest.xml
die_if_error "Failure uploading bundle $IMAGE to $BUCKET"

AMI=`euca-register $BUCKET/$IMAGE.manifest.xml | cut -f2`
die_if_not_set AMI "Failure registering $BUCKET/$IMAGE"

# Wait for the image to become available
if ! timeout $REGISTER_TIMEOUT sh -c "while euca-describe-images | grep '$AMI' | grep 'available'; do sleep 1; done"; then
    echo "Image $AMI not available within $REGISTER_TIMEOUT seconds"
    exit 1
fi

# Clean up
euca-deregister $AMI
die_if_error "Failure deregistering $AMI"

set +o xtrace
echo "**************************************************"
echo "End DevStack Exercise: $0"
echo "**************************************************"
