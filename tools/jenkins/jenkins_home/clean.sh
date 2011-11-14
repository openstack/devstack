#!/bin/bash
# This script is not yet for general consumption.

set -o errexit

if [ ! "$FORCE" = "yes" ]; then
    echo "FORCE not set to 'yes'.  Make sure this is something you really want to do.  Exiting."
    exit 1
fi

virsh list | cut -d " " -f1 | grep -v "-" | egrep -e "[0-9]" | xargs -n 1 virsh destroy || true
virsh net-list | grep active | cut -d " " -f1 | xargs -n 1 virsh net-destroy || true
killall dnsmasq || true
if [ "$CLEAN" = "yes" ]; then
    rm -rf jobs
fi
rm /var/lib/jenkins/jobs
git checkout -f
git fetch
git merge origin/jenkins
./build_jenkins.sh
