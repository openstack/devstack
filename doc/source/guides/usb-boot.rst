`DevStack </>`__

-  `Overview <../overview.html>`__
-  `Changes <../changes.html>`__
-  `FAQ <../faq.html>`__
-  `git.openstack.org <https://git.openstack.org/cgit/openstack-dev/devstack>`__
-  `Gerrit <https://review.openstack.org/#/q/status:open+project:openstack-dev/devstack,n,z>`__

USB Boot: Undoable Stack Boot
=============================

Boot DevStack from a USB disk into a RAM disk.

Prerequisites
-------------

Hardware
~~~~~~~~

This guide covers the creation of a bootable USB drive. Your computer
BIOS must support booting from USB and You will want at least 3GB of
RAM. You also will need a USB drive of at least 2GB.

Software
~~~~~~~~

Ubuntu 11.10 (Oneiric Ocelot) is required on host to create images.

Installation bit blasting
-------------------------

Set Up USB Drive
~~~~~~~~~~~~~~~~

-  Insert the USB drive into the computer. Make a note of the device
   name, such as ``sdb``. Do not mount the device.
-  Install the boot system:

   ::

       tools/build_usb_boot.sh /dev/sdb1

   This calls tools/build\_ramdisk.sh to create a 2GB ramdisk containing
   a complete development Oneiric OS plus the OpenStack code checkouts.
   It then writes a syslinux boot sector to the specified device and
   creates ``/syslinux``.

-  If desired, you may now mount the device:

   ::

       mount /dev/sdb1 /mnt/tmp
       # foo
       umount /mnt/tmp

Now `return <ramdisk.html>`__ to the RAM disk Guide to kick off your
DevStack experience.

© Openstack Foundation 2011-2013 — this is not an official OpenStack
project...
