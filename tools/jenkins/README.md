Getting Started With Jenkins and Devstack
=========================================
This little corner of devstack is to show how to get an Openstack jenkins
environment up and running quickly, using the rcb configuration methodology.


To manually set up a testing environment
----------------------------------------
    ./build_configuration.sh [EXECUTOR_NUMBER] [CONFIGURATION]

For now, use "./build_configuration.sh $EXECUTOR_NUMBER kvm"

To manually run a test
----------------------
    ./run_test.sh [EXECUTOR_NUMBER] [ADAPTER] 

For now, use "./run_test.sh $EXECUTOR_NUMBER [euca|floating]"
