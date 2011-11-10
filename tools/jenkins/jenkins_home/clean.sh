#!/bin/bash
# This script is not yet for general consumption.

set -o errexit

if [ ! "$FORCE" = 1 ]; then
    echo "FORCE not set to 1.  Make sure this is something you really want to do.  Exiting."
    exit 1
fi

exit
virsh list | cut -d " " -f1 | grep -v "-" | egrep -e "[0-9]" | xargs -n 1 virsh destroy || true
virsh net-list | grep active | cut -d " " -f1 | xargs -n 1 virsh net-destroy || true
killall dnsmasq
rm -rf jobs
rm /var/lib/jenkins/jobs
git checkout -f
git fetch
git merge origin/jenkins
./build_jenkins.sh

