#!/usr/bin/env bash

# **stack.sh** is an opinionated openstack developer installation.

# This script installs and configures *nova*, *glance*, *dashboard* and *keystone*

# This script allows you to specify configuration options of what git 
# repositories to use, enabled services, network configuration and various
# passwords.  If you are crafty you can run the script on multiple nodes using
# shared settings for common resources (mysql, rabbitmq) and build a multi-node
# developer install.

# To keep this script simple we assume you are running on an **Ubuntu 11.04
# Natty** machine.  It should work in a VM or physical server.  Additionally we
# put the list of *apt* and *pip* dependencies and other configuration files in
# this repo.  So start by grabbing this script and the dependencies.

# Learn more and get the most recent version at http://devstack.org

# Sanity Check
# ============

# Warn users who aren't on natty, but allow them to override check and attempt
# installation with ``FORCE=yes ./stack``
if ! grep -q natty /etc/lsb-release; then
    echo "WARNING: this script has only been tested on natty"
    if [[ "$FORCE" != "yes" ]]; then
        echo "If you wish to run this script anyway run with FORCE=yes"
        exit 1
    fi
fi

# stack.sh keeps the list of **apt** and **pip** dependencies in external
# files, along with config templates and other useful files.  You can find these
# in the ``files`` directory (next to this script).  We will reference this
# directory using the ``FILES`` variable in this script.
FILES=`pwd`/files
if [ ! -d $FILES ]; then
    echo "ERROR: missing devstack/files - did you grab more than just stack.sh?"
    exit 1
fi

# OpenStack is designed to be run as a regular user (Dashboard will fail to run
# as root, since apache refused to startup serve content from root user).  If
# stack.sh is run as root, it automatically creates a stack user with
# sudo privileges and runs as that user.

if [[ $EUID -eq 0 ]]; then
    echo "You are running this script as root."
    echo "In 10 seconds, we will create a user 'stack' and run as that user"
    sleep 10 

    # since this script runs as a normal user, we need to give that user
    # ability to run sudo
    apt-get update
    apt-get install -y sudo

    if ! getent passwd stack >/dev/null; then
        echo "Creating a user called stack"
        useradd -U -G sudo -s /bin/bash -m stack
    fi

    echo "Giving stack user passwordless sudo priviledges"
    ( umask 226 && echo "stack ALL=(ALL) NOPASSWD: ALL" \
        >> /etc/sudoers.d/50_stack_sh )

    echo "Copying files to stack user"
    STACK_DIR="/home/stack/${PWD##*/}"
    cp -r -f "$PWD" "$STACK_DIR"
    chown -R stack "$STACK_DIR"
    if [[ "$SHELL_AFTER_RUN" != "no" ]]; then
        exec su -c "set -e; cd $STACK_DIR; bash stack.sh; bash" stack
    else
        exec su -c "set -e; cd $STACK_DIR; bash stack.sh" stack
    fi
    exit 1
fi


# Settings
# ========

# This script is customizable through setting environment variables.  If you
# want to override a setting you can either::
#
#     export MYSQL_PASS=anothersecret
#     ./stack.sh
#
# You can also pass options on a single line ``MYSQL_PASS=simple ./stack.sh``
#
# Additionally, you can put any local variables into a ``localrc`` file, like::
#
#     MYSQL_PASS=anothersecret
#     MYSQL_USER=hellaroot
#
# We try to have sensible defaults, so you should be able to run ``./stack.sh``
# in most cases.
#
# We our settings from ``stackrc``.  This file is distributed with devstack and
# contains locations for what repositories to use.  If you want to use other 
# repositories and branches, you can add your own settings with another file 
# called ``localrc``
#
# If ``localrc`` exists, then ``stackrc`` will load those settings.  This is 
# useful for changing a branch or repostiory to test other versions.  Also you
# can store your other settings like **MYSQL_PASS** or **ADMIN_PASSWORD** instead
# of letting devstack generate random ones for you.
source ./stackrc

# Destination path for installation ``DEST``
DEST=${DEST:-/opt/stack}

# Set the destination directories for openstack projects
NOVA_DIR=$DEST/nova
DASH_DIR=$DEST/dash
GLANCE_DIR=$DEST/glance
KEYSTONE_DIR=$DEST/keystone
NOVACLIENT_DIR=$DEST/python-novaclient
OPENSTACKX_DIR=$DEST/openstackx
NOVNC_DIR=$DEST/noVNC

# Specify which services to launch.  These generally correspond to screen tabs
ENABLED_SERVICES=${ENABLED_SERVICES:-g-api,g-reg,key,n-api,n-cpu,n-net,n-sch,n-vnc,dash,mysql,rabbit}

# Nova hypervisor configuration.  We default to **kvm** but will drop back to
# **qemu** if we are unable to load the kvm module.  Stack.sh can also install
# an **LXC** based system.
LIBVIRT_TYPE=${LIBVIRT_TYPE:-kvm}

# nova supports pluggable schedulers.  ``SimpleScheduler`` should work in most
# cases unless you are working on multi-zone mode.
SCHEDULER=${SCHEDULER:-nova.scheduler.simple.SimpleScheduler}

# Use the first IP unless an explicit is set by ``HOST_IP`` environment variable
if [ ! -n "$HOST_IP" ]; then
    HOST_IP=`LC_ALL=C /sbin/ifconfig  | grep -m 1 'inet addr:'| cut -d: -f2 | awk '{print $1}'`
fi

# Nova Network Configuration
# --------------------------

# FIXME: more documentation about why these are important flags.  Also 
# we should make sure we use the same variable names as the flag names.

PUBLIC_INTERFACE=${PUBLIC_INTERFACE:-eth0}
FIXED_RANGE=${FIXED_RANGE:-10.0.0.0/24}
FIXED_NETWORK_SIZE=${FIXED_NETWORK_SIZE:-256}
FLOATING_RANGE=${FLOATING_RANGE:-172.24.4.1/28}
NET_MAN=${NET_MAN:-FlatDHCPManager}
EC2_DMZ_HOST=${EC2_DMZ_HOST:-$HOST_IP}
FLAT_NETWORK_BRIDGE=${FLAT_NETWORK_BRIDGE:-br100}
VLAN_INTERFACE=${VLAN_INTERFACE:-$PUBLIC_INTERFACE}

# Multi-host is a mode where each compute node runs its own network node.  This
# allows network operations and routing for a VM to occur on the server that is
# running the VM - removing a SPOF and bandwidth bottleneck.
MULTI_HOST=${MULTI_HOST:-0}

# If you are using FlatDHCP on multiple hosts, set the ``FLAT_INTERFACE``
# variable but make sure that the interface doesn't already have an
# ip or you risk breaking things.
#
# **DHCP Warning**:  If your flat interface device uses DHCP, there will be a 
# hiccup while the network is moved from the flat interface to the flat network 
# bridge.  This will happen when you launch your first instance.  Upon launch 
# you will lose all connectivity to the node, and the vm launch will probably 
# fail.
# 
# If you are running on a single node and don't need to access the VMs from 
# devices other than that node, you can set the flat interface to the same
# value as ``FLAT_NETWORK_BRIDGE``.  This will stop the network hiccup from 
# occuring.
FLAT_INTERFACE=${FLAT_INTERFACE:-eth0}

## FIXME(ja): should/can we check that FLAT_INTERFACE is sane?


# MySQL & RabbitMQ
# ----------------

# We configure Nova, Dashboard, Glance and Keystone to use MySQL as their 
# database server.  While they share a single server, each has their own
# database and tables.

# By default this script will install and configure MySQL.  If you want to 
# use an existing server, you can pass in the user/password/host parameters.
# You will need to send the same ``MYSQL_PASS`` to every host if you are doing
# a multi-node devstack installation.
MYSQL_USER=${MYSQL_USER:-root}
MYSQL_PASS=${MYSQL_PASS:-`openssl rand -hex 12`}
MYSQL_HOST=${MYSQL_HOST:-localhost}

# don't specify /db in this string, so we can use it for multiple services
BASE_SQL_CONN=${BASE_SQL_CONN:-mysql://$MYSQL_USER:$MYSQL_PASS@$MYSQL_HOST}

# Rabbit connection info
RABBIT_HOST=${RABBIT_HOST:-localhost}
RABBIT_PASSWORD=${RABBIT_PASSWORD:-`openssl rand -hex 12`}

# Glance connection info.  Note the port must be specified.
GLANCE_HOSTPORT=${GLANCE_HOSTPORT:-$HOST_IP:9292}

# Keystone
# --------

# Service Token - Openstack components need to have an admin token
# to validate user tokens.
SERVICE_TOKEN=${SERVICE_TOKEN:-`openssl rand -hex 12`}
# Dash currently truncates usernames and passwords at 20 characters
# so use 10 bytes
ADMIN_PASSWORD=${ADMIN_PASSWORD:-`openssl rand -hex 10`}

LOGFILE=${LOGFILE:-"$PWD/stack.sh.$$.log"}
(
# So that errors don't compound we exit on any errors so you see only the
# first error that occured.
trap failed ERR
failed() {
    local r=$?
    set +o xtrace
    [ -n "$LOGFILE" ] && echo "${0##*/} failed: full log in $LOGFILE"
    exit $r
}

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following along as the install occurs.
set -o xtrace

sudo mkdir -p $DEST
sudo chown `whoami` $DEST

# Install Packages
# ================
#
# Openstack uses a fair number of other projects.


# install apt requirements
sudo apt-get update
sudo apt-get install -qqy `cat $FILES/apts/* | cut -d\# -f1 | grep -Ev "mysql-server|rabbitmq-server"`

# install python requirements
sudo PIP_DOWNLOAD_CACHE=/var/cache/pip pip install `cat $FILES/pips/*`

# git clone only if directory doesn't exist already.  Since ``DEST`` might not
# be owned by the installation user, we create the directory and change the
# ownership to the proper user.
function git_clone {
    if [ ! -d $2 ]; then
        sudo mkdir $2
        sudo chown `whoami` $2
        git clone $1 $2
        cd $2
        # This checkout syntax works for both branches and tags
        git checkout $3
    fi
}

# compute service
git_clone $NOVA_REPO $NOVA_DIR $NOVA_BRANCH
# image catalog service
git_clone $GLANCE_REPO $GLANCE_DIR $GLANCE_BRANCH
# unified auth system (manages accounts/tokens)
git_clone $KEYSTONE_REPO $KEYSTONE_DIR $KEYSTONE_BRANCH
# a websockets/html5 or flash powered VNC console for vm instances
git_clone $NOVNC_REPO $NOVNC_DIR $NOVNC_BRANCH
# django powered web control panel for openstack
git_clone $DASH_REPO $DASH_DIR $DASH_BRANCH $DASH_TAG
# python client library to nova that dashboard (and others) use
git_clone $NOVACLIENT_REPO $NOVACLIENT_DIR $NOVACLIENT_BRANCH
# openstackx is a collection of extensions to openstack.compute & nova
# that is *deprecated*.  The code is being moved into python-novaclient & nova.
git_clone $OPENSTACKX_REPO $OPENSTACKX_DIR $OPENSTACKX_BRANCH

# Initialization
# ==============


# setup our checkouts so they are installed into python path
# allowing ``import nova`` or ``import glance.client``
cd $NOVA_DIR; sudo python setup.py develop
cd $NOVACLIENT_DIR; sudo python setup.py develop
cd $KEYSTONE_DIR; sudo python setup.py develop
cd $GLANCE_DIR; sudo python setup.py develop
cd $OPENSTACKX_DIR; sudo python setup.py develop
cd $DASH_DIR/django-openstack; sudo python setup.py develop
cd $DASH_DIR/openstack-dashboard; sudo python setup.py develop

# Add a useful screenrc.  This isn't required to run openstack but is we do
# it since we are going to run the services in screen for simple
cp $FILES/screenrc ~/.screenrc

## TODO: update current user to allow sudo for all commands in files/sudo/*

# Rabbit
# ---------

if [[ "$ENABLED_SERVICES" =~ "rabbit" ]]; then
    # Install and start rabbitmq-server
    sudo apt-get install -y -q rabbitmq-server
    # change the rabbit password since the default is "guest"
    sudo rabbitmqctl change_password guest $RABBIT_PASSWORD
fi

# Mysql
# ---------

if [[ "$ENABLED_SERVICES" =~ "mysql" ]]; then

    # Seed configuration with mysql password so that apt-get install doesn't
    # prompt us for a password upon install.
    cat <<MYSQL_PRESEED | sudo debconf-set-selections
mysql-server-5.1 mysql-server/root_password password $MYSQL_PASS
mysql-server-5.1 mysql-server/root_password_again password $MYSQL_PASS
mysql-server-5.1 mysql-server/start_on_boot boolean true
MYSQL_PRESEED

    # Install and start mysql-server
    sudo apt-get -y -q install mysql-server
    # Update the DB to give user ‘$MYSQL_USER’@’%’ full control of the all databases:
    sudo mysql -uroot -p$MYSQL_PASS -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'%' identified by '$MYSQL_PASS';"

    # Edit /etc/mysql/my.cnf to change ‘bind-address’ from localhost (127.0.0.1) to any (0.0.0.0) and restart the mysql service:
    sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
    sudo service mysql restart
fi


# Dashboard
# ---------

# Setup the django dashboard application to serve via apache/wsgi

if [[ "$ENABLED_SERVICES" =~ "dash" ]]; then

    # Dash currently imports quantum even if you aren't using it.  Instead
    # of installing quantum we can create a simple module that will pass the
    # initial imports
    mkdir -p  $DASH_DIR/openstack-dashboard/quantum || true
    touch $DASH_DIR/openstack-dashboard/quantum/__init__.py
    touch $DASH_DIR/openstack-dashboard/quantum/client.py


    # ``local_settings.py`` is used to override dashboard default settings.
    cp $FILES/dash_settings.py $DASH_DIR/openstack-dashboard/local/local_settings.py

    cd $DASH_DIR/openstack-dashboard
    dashboard/manage.py syncdb

    # create an empty directory that apache uses as docroot
    sudo mkdir -p $DASH_DIR/.blackhole

    ## Configure apache's 000-default to run dashboard
    sudo cp $FILES/000-default.template /etc/apache2/sites-enabled/000-default
    sudo sed -e "s,%USER%,$USER,g" -i /etc/apache2/sites-enabled/000-default
    sudo sed -e "s,%DASH_DIR%,$DASH_DIR,g" -i /etc/apache2/sites-enabled/000-default
fi


# Glance
# ------

if [[ "$ENABLED_SERVICES" =~ "g-reg" ]]; then
    GLANCE_IMAGE_DIR=$DEST/glance/images
    # Delete existing images
    rm -rf $GLANCE_IMAGE_DIR

    # Use local glance directories
    mkdir -p $GLANCE_IMAGE_DIR

    # (re)create glance database
    mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'DROP DATABASE IF EXISTS glance;'
    mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'CREATE DATABASE glance;'
    # Copy over our glance-registry.conf
    GLANCE_CONF=$GLANCE_DIR/etc/glance-registry.conf
    cp $FILES/glance-registry.conf $GLANCE_CONF
    sudo sed -e "s,%SQL_CONN%,$BASE_SQL_CONN/glance,g" -i $GLANCE_CONF
    sudo sed -e "s,%SERVICE_TOKEN%,$SERVICE_TOKEN,g" -i $GLANCE_CONF
    sudo sed -e "s,%DEST%,$DEST,g" -i $GLANCE_CONF

    GLANCE_API_CONF=$GLANCE_DIR/etc/glance-api.conf
    cp $FILES/glance-api.conf $GLANCE_API_CONF
    sudo sed -e "s,%DEST%,$DEST,g" -i $GLANCE_API_CONF
    sudo sed -e "s,%SERVICE_TOKEN%,$SERVICE_TOKEN,g" -i $GLANCE_API_CONF
fi

# Nova
# ----

# We are going to use the sample http middleware configuration from the keystone
# project to launch nova.  This paste config adds the configuration required
# for nova to validate keystone tokens - except we need to switch the config
# to use our admin token instead (instead of the token from their sample data).
sudo sed -e "s,999888777666,$SERVICE_TOKEN,g" -i $KEYSTONE_DIR/examples/paste/nova-api-paste.ini

if [[ "$ENABLED_SERVICES" =~ "n-cpu" ]]; then

    # Virtualization Configuration
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    # attempt to load modules: network block device - used to manage qcow images
    sudo modprobe nbd || true

    # Check for kvm (hardware based virtualization).  If unable to load kvm, 
    # set the libvirt type to qemu.  Note: many systems come with hardware 
    # virtualization disabled in BIOS.
    if [[ "$LIBVIRT_TYPE" == "kvm" ]]; then
        sudo modprobe kvm || true
        if [ ! -e /dev/kvm ]; then
            echo "WARNING: Switching to QEMU"
            LIBVIRT_TYPE=qemu
        fi
    fi

    # Install and configure **LXC** if specified.  LXC is another approach to
    # splitting a system into many smaller parts.  LXC uses cgroups and chroot
    # to simulate multiple systems.
    if [[ "$LIBVIRT_TYPE" == "lxc" ]]; then
        sudo apt-get install lxc -y
        # lxc requires cgroups to be configured on /cgroup
        sudo mkdir -p /cgroup
        if ! grep -q cgroup /etc/fstab; then
            echo none /cgroup cgroup cpuacct,memory,devices,cpu,freezer,blkio 0 0 | sudo tee -a /etc/fstab
        fi
        if ! mount -n | grep -q cgroup; then
            sudo mount /cgroup
        fi
    fi

    # User needs to be member of libvirtd group for nova-compute to use libvirt.
    sudo usermod -a -G libvirtd `whoami`
    # if kvm wasn't running before we need to restart libvirt to enable it
    sudo /etc/init.d/libvirt-bin restart


    # Instance Storage
    # ~~~~~~~~~~~~~~~~

    # Nova stores each instance in its own directory.
    mkdir -p $NOVA_DIR/instances

    # if there is a partition labeled nova-instances use it (ext filesystems
    # can be labeled via e2label)
    ## FIXME: if already mounted this blows up...
    if [ -L /dev/disk/by-label/nova-instances ]; then
        sudo mount -L nova-instances $NOVA_DIR/instances
        sudo chown -R `whoami` $NOVA_DIR/instances
    fi

    # Clean out the instances directory.
    sudo rm -rf $NOVA_DIR/instances/*
fi

if [[ "$ENABLED_SERVICES" =~ "n-net" ]]; then
    # delete traces of nova networks from prior runs
    sudo killall dnsmasq || true
    rm -rf $NOVA_DIR/networks
    mkdir -p $NOVA_DIR/networks
fi

function add_nova_flag {
    echo "$1" >> $NOVA_DIR/bin/nova.conf
}

# (re)create nova.conf
rm -f $NOVA_DIR/bin/nova.conf
add_nova_flag "--verbose"
add_nova_flag "--nodaemon"
add_nova_flag "--scheduler_driver=$SCHEDULER"
add_nova_flag "--dhcpbridge_flagfile=$NOVA_DIR/bin/nova.conf"
add_nova_flag "--network_manager=nova.network.manager.$NET_MAN"
add_nova_flag "--my_ip=$HOST_IP"
add_nova_flag "--public_interface=$PUBLIC_INTERFACE"
add_nova_flag "--vlan_interface=$VLAN_INTERFACE"
add_nova_flag "--sql_connection=$BASE_SQL_CONN/nova"
add_nova_flag "--libvirt_type=$LIBVIRT_TYPE"
add_nova_flag "--osapi_extensions_path=$OPENSTACKX_DIR/extensions"
add_nova_flag "--vncproxy_url=http://$HOST_IP:6080"
add_nova_flag "--vncproxy_wwwroot=$NOVNC_DIR/"
add_nova_flag "--api_paste_config=$KEYSTONE_DIR/examples/paste/nova-api-paste.ini"
add_nova_flag "--image_service=nova.image.glance.GlanceImageService"
add_nova_flag "--ec2_dmz_host=$EC2_DMZ_HOST"
add_nova_flag "--rabbit_host=$RABBIT_HOST"
add_nova_flag "--rabbit_password=$RABBIT_PASSWORD"
add_nova_flag "--glance_api_servers=$GLANCE_HOSTPORT"
add_nova_flag "--flat_network_bridge=$FLAT_NETWORK_BRIDGE"
if [ -n "$FLAT_INTERFACE" ]; then
    add_nova_flag "--flat_interface=$FLAT_INTERFACE"
fi
if [ -n "$MULTI_HOST" ]; then
    add_nova_flag "--multi_host=$MULTI_HOST"
fi

# Nova Database
# ~~~~~~~~~~~~~

# All nova components talk to a central database.  We will need to do this step
# only once for an entire cluster.

if [[ "$ENABLED_SERVICES" =~ "mysql" ]]; then
    # (re)create nova database
    mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'DROP DATABASE IF EXISTS nova;'
    mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'CREATE DATABASE nova;'

    # (re)create nova database
    $NOVA_DIR/bin/nova-manage db sync

    # create a small network
    $NOVA_DIR/bin/nova-manage network create private $FIXED_RANGE 1 $FIXED_NETWORK_SIZE

    # create some floating ips
    $NOVA_DIR/bin/nova-manage floating create $FLOATING_RANGE
fi


# Keystone
# --------

if [[ "$ENABLED_SERVICES" =~ "key" ]]; then
    # (re)create keystone database
    mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'DROP DATABASE IF EXISTS keystone;'
    mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'CREATE DATABASE keystone;'

    # FIXME (anthony) keystone should use keystone.conf.example
    KEYSTONE_CONF=$KEYSTONE_DIR/etc/keystone.conf
    cp $FILES/keystone.conf $KEYSTONE_CONF
    sudo sed -e "s,%SQL_CONN%,$BASE_SQL_CONN/keystone,g" -i $KEYSTONE_CONF
    sudo sed -e "s,%DEST%,$DEST,g" -i $KEYSTONE_CONF

    # keystone_data.sh creates our admin user and our ``SERVICE_TOKEN``.
    KEYSTONE_DATA=$KEYSTONE_DIR/bin/keystone_data.sh
    cp $FILES/keystone_data.sh $KEYSTONE_DATA
    sudo sed -e "s,%HOST_IP%,$HOST_IP,g" -i $KEYSTONE_DATA
    sudo sed -e "s,%SERVICE_TOKEN%,$SERVICE_TOKEN,g" -i $KEYSTONE_DATA
    sudo sed -e "s,%ADMIN_PASSWORD%,$ADMIN_PASSWORD,g" -i $KEYSTONE_DATA
    # initialize keystone with default users/endpoints
    BIN_DIR=$KEYSTONE_DIR/bin bash $KEYSTONE_DATA
fi


# Launch Services
# ===============

# nova api crashes if we start it with a regular screen command,
# so send the start command by forcing text into the window.
# Only run the services specified in ``ENABLED_SERVICES``

# our screen helper to launch a service in a hidden named screen
function screen_it {
    NL=`echo -ne '\015'`
    if [[ "$ENABLED_SERVICES" =~ "$1" ]]; then
        screen -S nova -X screen -t $1
        screen -S nova -p $1 -X stuff "$2$NL"
    fi
}

# create a new named screen to run processes in
screen -d -m -S nova -t nova
sleep 1

# launch the glance registery service
if [[ "$ENABLED_SERVICES" =~ "g-reg" ]]; then
    screen_it g-reg "cd $GLANCE_DIR; bin/glance-registry --config-file=etc/glance-registry.conf"
fi

# launch the glance api and wait for it to answer before continuing
if [[ "$ENABLED_SERVICES" =~ "g-api" ]]; then
    screen_it g-api "cd $GLANCE_DIR; bin/glance-api --config-file=etc/glance-api.conf"
    while ! wget -q -O- http://$GLANCE_HOSTPORT; do
        echo "Waiting for g-api ($GLANCE_HOSTPORT) to start..."
        sleep 1
    done
fi

# launch the keystone and wait for it to answer before continuing
if [[ "$ENABLED_SERVICES" =~ "key" ]]; then
    screen_it key "cd $KEYSTONE_DIR && $KEYSTONE_DIR/bin/keystone --config-file $KEYSTONE_CONF -d"
    while ! wget -q -O- http://127.0.0.1:5000; do
        echo "Waiting for keystone to start..."
        sleep 1
    done
fi

# launch the nova-api and wait for it to answer before continuing
if [[ "$ENABLED_SERVICES" =~ "n-api" ]]; then
    screen_it n-api "cd $NOVA_DIR && $NOVA_DIR/bin/nova-api"
    while ! wget -q -O- http://127.0.0.1:8774; do
        echo "Waiting for nova-api to start..."
        sleep 1
    done
fi
# Launching nova-compute should be as simple as running ``nova-compute`` but
# have to do a little more than that in our script.  Since we add the group
# ``libvirtd`` to our user in this script, when nova-compute is run it is
# within the context of our original shell (so our groups won't be updated).
# Use 'sg' to execute nova-compute as a member of the libvirtd group.
screen_it n-cpu "cd $NOVA_DIR && sg libvirtd $NOVA_DIR/bin/nova-compute"
screen_it n-net "cd $NOVA_DIR && $NOVA_DIR/bin/nova-network"
screen_it n-sch "cd $NOVA_DIR && $NOVA_DIR/bin/nova-scheduler"
screen_it n-vnc "cd $NOVNC_DIR && ./utils/nova-wsproxy.py 6080 --web . --flagfile=../nova/bin/nova.conf"
screen_it dash "cd $DASH_DIR && sudo /etc/init.d/apache2 restart; sudo tail -f /var/log/apache2/error.log"

# Install Images
# ==============

# Upload a couple images to glance.  **TTY** is a simple small image that use the 
# lets you login to it with username/password of user/password.  TTY is useful 
# for basic functionality.  We all include an Ubuntu cloud build of **Natty**.
# Natty uses cloud-init, supporting login via keypair and sending scripts as
# userdata.  
#
# Read more about cloud-init at https://help.ubuntu.com/community/CloudInit

if [[ "$ENABLED_SERVICES" =~ "g-reg" ]]; then
    # create a directory for the downloadedthe images tarballs.
    mkdir -p $FILES/images

    # Debug Image (TTY)
    # -----------------

    # Downloads the image (ami/aki/ari style), then extracts it.  Upon extraction
    # we upload to glance with the glance cli tool.  TTY is a stripped down 
    # version of ubuntu.
    if [ ! -f $FILES/tty.tgz ]; then
        wget -c http://images.ansolabs.com/tty.tgz -O $FILES/tty.tgz
    fi

    # extract ami-tty/image, aki-tty/image & ari-tty/image
    tar -zxf $FILES/tty.tgz -C $FILES/images

    # Use glance client to add the kernel, ramdisk and finally the root 
    # filesystem.  We parse the results of the uploads to get glance IDs of the
    # ramdisk and kernel and use them for the root filesystem.
    RVAL=`glance add -A $SERVICE_TOKEN name="tty-kernel" is_public=true container_format=aki disk_format=aki < $FILES/images/aki-tty/image`
    KERNEL_ID=`echo $RVAL | cut -d":" -f2 | tr -d " "`
    RVAL=`glance add -A $SERVICE_TOKEN name="tty-ramdisk" is_public=true container_format=ari disk_format=ari < $FILES/images/ari-tty/image`
    RAMDISK_ID=`echo $RVAL | cut -d":" -f2 | tr -d " "`
    glance add -A $SERVICE_TOKEN name="tty" is_public=true container_format=ami disk_format=ami kernel_id=$KERNEL_ID ramdisk_id=$RAMDISK_ID < $FILES/images/ami-tty/image

    # Ubuntu 11.04 aka Natty
    # ----------------------

    # Downloaded from ubuntu enterprise cloud images.  This
    # image doesn't use the ramdisk functionality
    if [ ! -f $FILES/natty.tgz ]; then
        wget -c http://uec-images.ubuntu.com/natty/current/natty-server-cloudimg-amd64.tar.gz -O $FILES/natty.tgz
    fi
    
    tar -zxf $FILES/natty.tgz -C $FILES/images

    RVAL=`glance add -A $SERVICE_TOKEN name="uec-natty-kernel" is_public=true container_format=aki disk_format=aki < $FILES/images/natty-server-cloudimg-amd64-vmlinuz-virtual`
    KERNEL_ID=`echo $RVAL | cut -d":" -f2 | tr -d " "`
    glance add -A $SERVICE_TOKEN name="uec-natty" is_public=true container_format=ami disk_format=ami kernel_id=$KERNEL_ID < $FILES/images/natty-server-cloudimg-amd64.img

fi

# Fin
# ===


) 2>&1 | tee "${LOGFILE}"

# Check that the left side of the above pipe succeeded
for ret in "${PIPESTATUS[@]}"; do [ $ret -eq 0 ] || exit $ret; done

(
# Using the cloud
# ===============

# If you installed the dashboard on this server, then you should be able
# to access the site using your browser.
if [[ "$ENABLED_SERVICES" =~ "dash" ]]; then
    echo "dashboard is now available at http://$HOST_IP/"
fi

# If keystone is present, you can point nova cli to this server
if [[ "$ENABLED_SERVICES" =~ "key" ]]; then
    echo "keystone is serving at http://$HOST_IP:5000/v2.0/"
    echo "examples on using novaclient command line is in exercise.sh"
    echo "the default users are: admin and demo"
    echo "the password: $ADMIN_PASSWORD"
fi

# indicate how long this took to run (bash maintained variable 'SECONDS')
echo "stack.sh completed in $SECONDS seconds."

) | tee -a "$LOGFILE"
