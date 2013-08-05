# DevStack on Docker

Using Docker as Nova's hypervisor requries two steps:

* Configure DevStack by adding the following to `localrc`::

    VIRT_DRIVER=docker

* Download and install the Docker service and images::

    tools/docker/install_docker.sh

After this, `stack.sh` should run as normal.
