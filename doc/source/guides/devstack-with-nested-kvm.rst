.. _kvm_nested_virt:

=======================================================
Configure DevStack with KVM-based Nested Virtualization
=======================================================

When using virtualization technologies like KVM, one can take advantage
of "Nested VMX" (i.e. the ability to run KVM on KVM) so that the VMs in
cloud (Nova guests) can run relatively faster than with plain QEMU
emulation.

Kernels shipped with Linux distributions doesn't have this enabled by
default. This guide outlines the configuration details to enable nested
virtualization in KVM-based environments. And how to setup DevStack
(that'll run in a VM) to take advantage of this.


Nested Virtualization Configuration
===================================

Configure Nested KVM for Intel-based Machines
---------------------------------------------

Procedure to enable nested KVM virtualization on Intel-based machines.

Check if the nested KVM Kernel parameter is enabled:

::

    cat /sys/module/kvm_intel/parameters/nested
    N

Temporarily remove the KVM intel Kernel module, enable nested
virtualization to be persistent across reboots and add the Kernel
module back:

::

    sudo rmmod kvm-intel
    sudo sh -c "echo 'options kvm-intel nested=y' >> /etc/modprobe.d/dist.conf"
    sudo modprobe kvm-intel

Ensure the Nested KVM Kernel module parameter for Intel is enabled on
the host:

::

    cat /sys/module/kvm_intel/parameters/nested
    Y

    modinfo kvm_intel | grep nested
    parm:           nested:bool

Start your VM, now it should have KVM capabilities -- you can verify
that by ensuring ``/dev/kvm`` character device is present.


Configure Nested KVM for AMD-based Machines
-------------------------------------------

Procedure to enable nested KVM virtualization on AMD-based machines.

Check if the nested KVM Kernel parameter is enabled:

::

    cat /sys/module/kvm_amd/parameters/nested
    0


Temporarily remove the KVM AMD Kernel module, enable nested
virtualization to be persistent across reboots and add the Kernel module
back:

::

    sudo rmmod kvm-amd
    sudo sh -c "echo 'options kvm-amd nested=1' >> /etc/modprobe.d/dist.conf"
    sudo modprobe kvm-amd

Ensure the Nested KVM Kernel module parameter for AMD is enabled on the
host:

::

    cat /sys/module/kvm_amd/parameters/nested
    1

    modinfo kvm_amd | grep -i nested
    parm:           nested:int

To make the above value persistent across reboots, add an entry in
/etc/modprobe.d/dist.conf so it looks as below::

    cat /etc/modprobe.d/dist.conf
    options kvm-amd nested=y


Expose Virtualization Extensions to DevStack VM
-----------------------------------------------

Edit the VM's libvirt XML configuration via ``virsh`` utility:

::

    sudo virsh edit devstack-vm

Add the below snippet to expose the host CPU features to the VM:

::

    <cpu mode='host-passthrough'>
    </cpu>


Ensure DevStack VM is Using KVM
-------------------------------

Before invoking ``stack.sh`` in the VM, ensure that KVM is enabled. This
can be verified by checking for the presence of the file ``/dev/kvm`` in
your VM. If it is present, DevStack will default to using the config
attribute ``virt_type = kvm`` in ``/etc/nova.conf``; otherwise, it'll fall
back to ``virt_type=qemu``, i.e. plain QEMU emulation.

Optionally, to explicitly set the type of virtualization, to KVM, by the
libvirt driver in nova, the below config attribute can be used in
DevStack's ``local.conf``:

::

    LIBVIRT_TYPE=kvm


Once DevStack is configured successfully, verify if the Nova instances
are using KVM by noticing the QEMU CLI invoked by Nova is using the
parameter ``accel=kvm``, e.g.:

::

    ps -ef | grep -i qemu
    root     29773     1  0 11:24 ?        00:00:00 /usr/bin/qemu-system-x86_64 -machine accel=kvm [. . .]
