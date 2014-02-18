Getting Started With Jenkins and Devstack
=========================================
This little corner of devstack is to show how to get an OpenStack jenkins
environment up and running quickly, using the rcb configuration methodology.


To create a jenkins server
--------------------------

    cd tools/jenkins/jenkins_home
    ./build_jenkins.sh

This will create a jenkins environment configured with sample test scripts that run against xen and kvm.

Configuring XS
--------------
In order to make the tests for XS work, you must install xs 5.6 on a separate machine,
and install the the jenkins public key on that server.  You then need to create the
/var/lib/jenkins/xenrc on your jenkins server like so:

    MYSQL_PASSWORD=secrete
    SERVICE_TOKEN=secrete
    ADMIN_PASSWORD=secrete
    RABBIT_PASSWORD=secrete
    # This is the password for your guest (for both stack and root users)
    GUEST_PASSWORD=secrete
    # Do not download the usual images yet!
    IMAGE_URLS=""
    FLOATING_RANGE=192.168.1.224/28
    VIRT_DRIVER=xenserver
    # Explicitly set multi-host
    MULTI_HOST=1
    # Give extra time for boot
    ACTIVE_TIMEOUT=45
    #  IMPORTANT: This is the ip of your xenserver
    XEN_IP=10.5.5.1
    # IMPORTANT: The following must be set to your dom0 root password!
    XENAPI_PASSWORD='MY_XEN_ROOT_PW'
