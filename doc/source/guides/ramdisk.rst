`DevStack </>`__

-  `Overview <../overview.html>`__
-  `Changes <../changes.html>`__
-  `FAQ <../faq.html>`__
-  `git.openstack.org <https://git.openstack.org/cgit/openstack-dev/devstack>`__
-  `Gerrit <https://review.openstack.org/#/q/status:open+project:openstack-dev/devstack,n,z>`__

Stack-in-a-Box: Try before you mkfs
===================================

Run DevStack from a RAM disk to give it a whirl before making the
commitment to install it. We'll cover booting from a USB drive or over
the network via PXE. We'll even thow in configuring a home router to
handle the PXE boot. You will need a minimum of 3GB for both of these
configurations as the RAM disk itself is 2GB.

Prerequisites Hardware
----------------------

USB Boot
~~~~~~~~

`This guide <usb-boot.html>`__ covers the creation of a bootable USB
drive. Your computer BIOS must support booting from USB.

PXE Boot
~~~~~~~~

`This guide <pxe-boot.html>`__ covers the installation of OpenWRT on a
home router and configuring it as a PXE server, plus the creation of the
boot images and PXE support files.

Installation bit blasting
-------------------------

Install DevStack
~~~~~~~~~~~~~~~~

Grab the latest version of DevStack via https:

::

    sudo apt-get install git -y
    git clone https://git.openstack.org/openstack-dev/devstack
    cd devstack

Prepare the Boot RAMdisk
~~~~~~~~~~~~~~~~~~~~~~~~

Pick your boot method and follow the guide to prepare to build the RAM
disk and set up the boot process:

-  `USB boot <usb-boot.html>`__
-  `PXE boot <pxe-boot.html>`__

Fire It Up
~~~~~~~~~~

-  Boot the computer into the RAM disk. The details will vary from
   machine to machine but most BIOSes have a method to select the boot
   device, often by pressing F12 during POST.
-  Select 'DevStack' from the Boot Menu.
-  Log in with the 'stack' user and 'pass' password.
-  Create ``devstack/localrc`` if you wish to change any of the
   configuration variables. You will probably want to at least set the
   admin login password to something memorable rather than the default
   20 random characters:

   ::

       ADMIN_PASSWORD=openstack

-  Fire up OpenStack!

   ::

       ./run.sh

-  See the processes running in screen:

   ::

       screen -x

-  Connect to the dashboard at ``http://<ip-address>/``

© Openstack Foundation 2011-2013 — this is not an official OpenStack
project...
