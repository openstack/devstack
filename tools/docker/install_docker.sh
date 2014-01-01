#!/usr/bin/env bash

# **install_docker.sh** - Do the initial Docker installation and configuration

# install_docker.sh
#
# Install docker package and images
# * downloads a base busybox image and a glance registry image if necessary
# * install the images in Docker's image cache


# Keep track of the current directory
SCRIPT_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $SCRIPT_DIR/../..; pwd)

# Import common functions
source $TOP_DIR/functions

# Load local configuration
source $TOP_DIR/stackrc

FILES=$TOP_DIR/files

# Get our defaults
source $TOP_DIR/lib/nova_plugins/hypervisor-docker

SERVICE_TIMEOUT=${SERVICE_TIMEOUT:-60}


# Install Docker Service
# ======================

# Stop the auto-repo updates and do it when required here
NO_UPDATE_REPOS=True

# Set up home repo
curl https://get.docker.io/gpg | sudo apt-key add -
install_package python-software-properties && \
    sudo sh -c "echo deb $DOCKER_APT_REPO docker main > /etc/apt/sources.list.d/docker.list"
apt_get update
install_package --force-yes lxc-docker socat

# Start the daemon - restart just in case the package ever auto-starts...
restart_service docker

echo "Waiting for docker daemon to start..."
DOCKER_GROUP=$(groups | cut -d' ' -f1)
CONFIGURE_CMD="while ! /bin/echo -e 'GET /v1.3/version HTTP/1.0\n\n' | socat - unix-connect:$DOCKER_UNIX_SOCKET 2>/dev/null | grep -q '200 OK'; do
    # Set the right group on docker unix socket before retrying
    sudo chgrp $DOCKER_GROUP $DOCKER_UNIX_SOCKET
    sudo chmod g+rw $DOCKER_UNIX_SOCKET
    sleep 1
done"
if ! timeout $SERVICE_TIMEOUT sh -c "$CONFIGURE_CMD"; then
    die $LINENO "docker did not start"
fi


# Get Docker image
if [[ ! -r $FILES/docker-ut.tar.gz ]]; then
    (cd $FILES; curl -OR $DOCKER_IMAGE)
fi
if [[ ! -r $FILES/docker-ut.tar.gz ]]; then
    die $LINENO "Docker image unavailable"
fi
docker import - $DOCKER_IMAGE_NAME <$FILES/docker-ut.tar.gz

# Get Docker registry image
if [[ ! -r $FILES/docker-registry.tar.gz ]]; then
    (cd $FILES; curl -OR $DOCKER_REGISTRY_IMAGE)
fi
if [[ ! -r $FILES/docker-registry.tar.gz ]]; then
    die $LINENO "Docker registry image unavailable"
fi
docker import - $DOCKER_REGISTRY_IMAGE_NAME <$FILES/docker-registry.tar.gz
