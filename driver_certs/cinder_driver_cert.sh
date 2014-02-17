#!/usr/bin/env bash

# **cinder_cert.sh**

# This script is a simple wrapper around the tempest volume api tests
# It requires that you have a working and functional devstack install
# and that you've enabled your device driver by making the necessary
# modifications to /etc/cinder/cinder.conf

# This script will refresh your openstack repo's and restart the cinder
# services to pick up your driver changes.
# please NOTE; this script assumes your devstack install is functional
# and includes tempest. A good first step is to make sure you can
# create volumes on your device before you even try and run this script.

# It also assumes default install location (/opt/stack/xxx)
# to aid in debug, you should also verify that you've added
# an output directory for screen logs:
#
#     SCREEN_LOGDIR=/opt/stack/screen-logs

CERT_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $CERT_DIR/..; pwd)

source $TOP_DIR/functions
source $TOP_DIR/stackrc
source $TOP_DIR/openrc
source $TOP_DIR/lib/infra
source $TOP_DIR/lib/tempest
source $TOP_DIR/lib/cinder

TEMPFILE=`mktemp`
RECLONE=True

function log_message() {
    MESSAGE=$1
    STEP_HEADER=$2
    if [[ "$STEP_HEADER" = "True" ]]; then
        echo -e "\n========================================================" | tee -a $TEMPFILE
    fi
    echo -e `date +%m/%d/%y/%T:`"${MESSAGE}" | tee -a $TEMPFILE
    if [[ "$STEP_HEADER" = "True" ]]; then
        echo -e "========================================================" | tee -a $TEMPFILE
    fi
}

if [[ "$OFFLINE" = "True" ]]; then
    echo "ERROR: Driver cert requires fresh clone/pull from ${CINDER_BRANCH}"
    echo "       Please set OFFLINE=False and retry."
    exit 1
fi

log_message "RUNNING CINDER DRIVER CERTIFICATION CHECK", True
log_message "Output is being logged to: $TEMPFILE"

cd $CINDER_DIR
log_message "Cloning to ${CINDER_REPO}...", True
install_cinder

log_message "Pull a fresh Clone of cinder repo...", True
git status | tee -a $TEMPFILE
git log --pretty=oneline -n 1 | tee -a $TEMPFILE

log_message "Gathering copy of cinder.conf file (passwords will be scrubbed)...", True
cat /etc/cinder/cinder.conf | egrep -v "(^#.*|^$)" | tee -a $TEMPFILE
sed -i "s/\(.*password.*=\).*$/\1 xxx/i" $TEMPFILE
log_message "End of cinder.conf.", True

cd $TOP_DIR
# Verify tempest is installed/enabled
if ! is_service_enabled tempest; then
    log_message "ERROR!!! Cert requires tempest in enabled_services!", True
    log_message"       Please add tempest to enabled_services and retry."
    exit 1
fi

cd $TEMPEST_DIR
install_tempest

log_message "Verify tempest is current....", True
git status | tee -a $TEMPFILE
log_message "Check status and get latest commit..."
git log --pretty=oneline -n 1 | tee -a $TEMPFILE


#stop and restart cinder services
log_message "Restart Cinder services...", True
stop_cinder
sleep 1
start_cinder
sleep 5

# run tempest api/volume/test_*
log_message "Run the actual tempest volume tests (./tools/pretty_tox.sh api.volume)...", True
./tools/pretty_tox.sh api.volume 2>&1 | tee -a $TEMPFILE
if [[ $? = 0 ]]; then
    log_message "CONGRATULATIONS!!!  Device driver PASSED!", True
    log_message "Submit output: ($TEMPFILE)"
    exit 0
else
    log_message "SORRY!!!  Device driver FAILED!", True
    log_message "Check output in $TEMPFILE"
    exit 1
fi
