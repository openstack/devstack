`DevStack </>`__

-  `Overview <../overview.html>`__
-  `Changes <../changes.html>`__
-  `FAQ <../faq.html>`__
-  `git.openstack.org <https://git.openstack.org/cgit/openstack-dev/devstack>`__
-  `Gerrit <https://review.openstack.org/#/q/status:open+project:openstack-dev/devstack,n,z>`__

PXE Boot Server Guide: Magic Dust for Network Boot
==================================================

Boot DevStack from a PXE server to a RAM disk.

Prerequisites Hardware & OpenWRT
--------------------------------

Hardware
~~~~~~~~

The whole point of this exercise is to have a highly portable boot
server, so using a small router with a USB port is the desired platform.
This guide uses a Buffalo WZR-HP-G300NH as an example, but it is easily
generalized for other supported platforms. See openwrt.org for more.

OpenWRT
~~~~~~~

Any recent 'Backfire' build of OpenWRT will work for the boot server
project. We build from trunk and have made the images available at
`http://openwrt.xr7.org/openwrt <http://openwrt.xr7.org/openwrt>`__.

Installation bit blasting
-------------------------

Install the Image
~~~~~~~~~~~~~~~~~

This process follows `the OpenWRT doc OEM
Install <http://wiki.openwrt.org/toh/buffalo/wzr-hp-g300h>`__ to tftp
the new image onto the router. You need a computer to set up the router,
we assume it is a recent Linux or OS/X installation.

-  Get openwrt-ar71xx-wzr-hp-g300nh-squashfs-tftp.bin

   ::

       wget http://openwrt.xr7.org/openwrt/ar71xx/openwrt-ar71xx-wzr-hp-g300nh-squashfs-tftp.bin

-  Connect computer to LAN port 4 (closest to WAN port)
-  Set computer interface to IP address in the 192.168.11.2
-  Add static arp entry for router

   ::

       arp -s 192.168.11.1 <mac-address>

-  Start TFTP transfer attempt

   ::

       tftp 192.168.11.1
       binary
       rexmt 1
       timeout 60
       put openwrt-ar71xx-wzr-hp-g300nh-squashfs-tftp.bin

-  Power on router. Router will reboot and initialize on 192.168.1.1.
-  Delete static arp entry for router

   ::

       arp -d 192.168.11.1

-  Set computer to DHCP, connect and telnet to router and set root
   password.

Configure the Router
~~~~~~~~~~~~~~~~~~~~

-  Update ``/etc/opkg.conf`` to point to our repo:

   ::

       src/gz packages http://192.168.5.13/openwrt/build/ar71xx/packages

-  Configure anon mounts:

   ::

       uci delete fstab.@mount[0]
       uci commit fstab
       /etc/init.d/fstab restart

-  Reset the DHCP address range. DevStack will claim the upper /25 of
   the router's LAN address space for floating IPs so the default DHCP
   address range needs to be moved:

   ::

       uci set dhcp.lan.start=65
       uci set dhcp.lan.limit=60
       uci commit dhcp

-  Enable TFTP:

   ::

       uci set dhcp.@dnsmasq[0].enable_tftp=1
       uci set dhcp.@dnsmasq[0].tftp_root=/mnt/sda1/tftpboot
       uci set dhcp.@dnsmasq[0].dhcp_boot=pxelinux.0
       uci commit dhcp
       /etc/init.d/dnsmasq restart

Set Up tftpboot
~~~~~~~~~~~~~~~

-  Create the ``/tmp/tftpboot`` structure and populate it:

   ::

       cd ~/devstack
       tools/build_pxe_boot.sh /tmp

   This calls ``tools/build_ramdisk.sh`` to create a 2GB ramdisk
   containing a complete development Oneiric OS plus the OpenStack code
   checkouts.

-  Copy ``tftpboot`` to a USB drive:

   ::

       mount /dev/sdb1 /mnt/tmp
       rsync -a /tmp/tftpboot/ /mnt/tmp/tftpboot/
       umount /mnt/tmp

-  Plug USB drive into router. It will be automounted and is ready to
   serve content.

Now `return <ramdisk.html>`__ to the RAM disk Guide to kick off your
DevStack experience.

© Openstack Foundation 2011-2013 — this is not an official OpenStack
project...
