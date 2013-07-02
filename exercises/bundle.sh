#!/usr/bin/env bash

# **bundle.sh**

# we will use the ``euca2ools`` cli tool that wraps the python boto
# library to test ec2 bundle upload compatibility

echo "*********************************************************************"
echo "Begin DevStack Exercise: $0"
echo "*********************************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
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

# Import exercise configuration
source $TOP_DIR/exerciserc

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
euca-bundle-image -i /tmp/$IMAGE || die $LINENO "Failure bundling image $IMAGE"

euca-upload-bundle --debug -b $BUCKET -m /tmp/$IMAGE.manifest.xml || die $LINENO "Failure uploading bundle $IMAGE to $BUCKET"

AMI=`euca-register $BUCKET/$IMAGE.manifest.xml | cut -f2`
die_if_not_set $LINENO AMI "Failure registering $BUCKET/$IMAGE"

# Wait for the image to become available
if ! timeout $REGISTER_TIMEOUT sh -c "while euca-describe-images | grep $AMI | grep -q available; do sleep 1; done"; then
    die $LINENO "Image $AMI not available within $REGISTER_TIMEOUT seconds"
fi

# Clean up
euca-deregister $AMI || die $LINENO "Failure deregistering $AMI"

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End DevStack Exercise: $0"
echo "*********************************************************************"
