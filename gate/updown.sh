#!/bin/bash -xe
#
# An up / down test for gate functional testing
#
# Note: this is expected to start running as jenkins

# Step 1: give back sudoers permissions to DevStack
TEMPFILE=`mktemp`
echo "stack ALL=(root) NOPASSWD:ALL" >$TEMPFILE
chmod 0440 $TEMPFILE
sudo chown root:root $TEMPFILE
sudo mv $TEMPFILE /etc/sudoers.d/51_stack_sh

# TODO: do something to start a guest to create crud that should
# disappear

# Step 2: unstack
echo "Running unstack.sh"
sudo -H -u stack stdbuf -oL -eL bash -ex ./unstack.sh

# Step 3: clean
echo "Running clean.sh"
sudo -H -u stack stdbuf -oL -eL bash -ex ./clean.sh

