#!/bin/bash

# Echo commands, exit on error
set -o xtrace
set -o errexit

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# This directory
CUR_DIR=$(cd $(dirname "$0") && pwd)

# Configure trunk jenkins!
echo "deb http://pkg.jenkins-ci.org/debian binary/" > /etc/apt/sources.list.d/jenkins.list
wget -q -O - http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
apt-get update


# Clean out old jenkins - useful if you are having issues upgrading
CLEAN_JENKINS=${CLEAN_JENKINS:-no}
if [ "$CLEAN_JENKINS" = "yes" ]; then
    apt-get remove jenkins jenkins-common
fi

# Install software
DEPS="jenkins cloud-utils"
apt-get install -y --force-yes $DEPS

# Install jenkins
if [ ! -e /var/lib/jenkins ]; then
    echo "Jenkins installation failed"
    exit 1
fi

# Make sure user has configured a jenkins ssh pubkey
if [ ! -e /var/lib/jenkins/.ssh/id_rsa.pub ]; then
    echo "Public key for jenkins is missing.  This is used to ssh into your instances."
    echo "Please run "su -c ssh-keygen jenkins" before proceeding"
    exit 1
fi

# Setup sudo
JENKINS_SUDO=/etc/sudoers.d/jenkins
cat > $JENKINS_SUDO <<EOF
jenkins ALL = NOPASSWD: ALL
EOF
chmod 440 $JENKINS_SUDO

# Setup .gitconfig
JENKINS_GITCONF=/var/lib/jenkins/hudson.plugins.git.GitSCM.xml
cat > $JENKINS_GITCONF <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<hudson.plugins.git.GitSCM_-DescriptorImpl>
  <generation>4</generation>
  <globalConfigName>Jenkins</globalConfigName>
  <globalConfigEmail>jenkins@rcb.me</globalConfigEmail>
</hudson.plugins.git.GitSCM_-DescriptorImpl>
EOF

# Add build numbers
JOBS=`ls jobs`
for job in ${JOBS// / }; do
    if [ ! -e jobs/$job/nextBuildNumber ]; then
        echo 1 > jobs/$job/nextBuildNumber
    fi
done

# Set ownership to jenkins
chown -R jenkins $CUR_DIR

# Make sure this directory is accessible to jenkins
if ! su -c "ls $CUR_DIR" jenkins; then
    echo "Your devstack directory is not accessible by jenkins."
    echo "There is a decent chance you are trying to run this from a directory in /root."
    echo "If so, try moving devstack elsewhere (eg. /opt/devstack)."
    exit 1
fi

# Move aside old jobs, if present
if [ ! -h /var/lib/jenkins/jobs ]; then
    echo "Installing jobs symlink"
    if [ -d /var/lib/jenkins/jobs ]; then
        mv /var/lib/jenkins/jobs /var/lib/jenkins/jobs.old
    fi
fi

# Set up jobs symlink
rm -f /var/lib/jenkins/jobs
ln -s $CUR_DIR/jobs /var/lib/jenkins/jobs

# List of plugins
PLUGINS=http://hudson-ci.org/downloads/plugins/build-timeout/1.6/build-timeout.hpi,http://mirrors.jenkins-ci.org/plugins/git/1.1.12/git.hpi,http://hudson-ci.org/downloads/plugins/global-build-stats/1.2/global-build-stats.hpi,http://hudson-ci.org/downloads/plugins/greenballs/1.10/greenballs.hpi,http://download.hudson-labs.org/plugins/console-column-plugin/1.0/console-column-plugin.hpi

# Configure plugins
for plugin in ${PLUGINS//,/ }; do
    name=`basename $plugin`
    dest=/var/lib/jenkins/plugins/$name
    if [ ! -e $dest ]; then
        curl -L $plugin -o $dest
    fi
done

# Restart jenkins
/etc/init.d/jenkins stop || true
/etc/init.d/jenkins start
