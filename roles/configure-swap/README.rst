Configure a swap partition

Creates a swap partition on the ephemeral block device (the rest of which
will be mounted on /opt).

**Role Variables**

.. zuul:rolevar:: configure_swap_size
   :default: 8192

   The size of the swap partition, in MiB.
