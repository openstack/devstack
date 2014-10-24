`DevStack </>`__

-  `Overview <../overview.html>`__
-  `Changes <../changes.html>`__
-  `FAQ <../faq.html>`__
-  `git.openstack.org <https://git.openstack.org/cgit/openstack-dev/devstack>`__
-  `Gerrit <https://review.openstack.org/#/q/status:open+project:openstack-dev/devstack,n,z>`__

Running a Cloud in a VM
=======================

Use the cloud to build the cloud! Use your cloud to launch new versions
of OpenStack in about 5 minutes. When you break it, start over! The VMs
launched in the cloud will be slow as they are running in QEMU
(emulation), but their primary use is testing OpenStack development and
operation. Speed not required.

Prerequisites Cloud & Image
---------------------------

Virtual Machine
~~~~~~~~~~~~~~~

DevStack should run in any virtual machine running a supported Linux
release. It will perform best with 2Gb or more of RAM.

OpenStack Deployment & cloud-init
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If the cloud service has an image with ``cloud-init`` pre-installed, use
it. You can get one from `Ubuntu's Daily
Build <http://uec-images.ubuntu.com>`__ site if necessary. This will
enable you to launch VMs with userdata that installs everything at boot
time. The userdata script below will install and run DevStack with a
minimal configuration. The use of ``cloud-init`` is outside the scope of
this document, refer to the ``cloud-init`` docs for more information.

If you are directly using a hypervisor like Xen, kvm or VirtualBox you
can manually kick off the script below as a non-root user in a
bare-bones server installation.

Installation shake and bake
---------------------------

Launching With Cloud-Init
~~~~~~~~~~~~~~~~~~~~~~~~~

This cloud config grabs the latest version of DevStack via git, creates
a minimal ``local.conf`` file and kicks off ``stack.sh``. It should be
passed as the user-data file when booting the VM.

::

    #cloud-config

    users:
      - default
      - name: stack
        lock_passwd: False
        sudo: ["ALL=(ALL) NOPASSWD:ALL\nDefaults:stack !requiretty"]
        shell: /bin/bash

    write_files:
      - content: |
            #!/bin/sh
            DEBIAN_FRONTEND=noninteractive sudo apt-get -qqy update || sudo yum update -qy
            DEBIAN_FRONTEND=noninteractive sudo apt-get install -qqy git || sudo yum install -qy git
            sudo chown stack:stack /home/stack
            cd /home/stack
            git clone https://git.openstack.org/openstack-dev/devstack
            cd devstack
            echo '[[local|localrc]]' > local.conf
            echo ADMIN_PASSWORD=password >> local.conf
            echo MYSQL_PASSWORD=password >> local.conf
            echo RABBIT_PASSWORD=password >> local.conf
            echo SERVICE_PASSWORD=password >> local.conf
            echo SERVICE_TOKEN=tokentoken >> local.conf
            ./stack.sh
        path: /home/stack/start.sh
        permissions: 0755

    runcmd:
      - su -l stack ./start.sh

As DevStack will refuse to run as root, this configures ``cloud-init``
to create a non-root user and run the ``start.sh`` script as that user.

Launching By Hand
~~~~~~~~~~~~~~~~~

Using a hypervisor directly, launch the VM and either manually perform
the steps in the embedded shell script above or copy it into the VM.

Using OpenStack
~~~~~~~~~~~~~~~

At this point you should be able to access the dashboard. Launch VMs and
if you give them floating IPs access those VMs from other machines on
your network.

One interesting use case is for developers working on a VM on their
laptop. Once ``stack.sh`` has completed once, all of the pre-requisite
packages are installed in the VM and the source trees checked out.
Setting ``OFFLINE=True`` in ``local.conf`` enables ``stack.sh`` to run
multiple times without an Internet connection. DevStack, making hacking
at the lake possible since 2012!

© Openstack Foundation 2011-2014 — An
`OpenStack <https://www.openstack.org/>`__
`program <https://wiki.openstack.org/wiki/Programs>`__
