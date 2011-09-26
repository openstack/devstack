#!/usr/bin/env bash

# **stack.sh** is an opinionated openstack dev installation.

# To keep this script simple we assume you are running on an **Ubuntu 11.04
# Natty** machine.  It should work in a VM or physical server.  Additionally we
# put the list of *apt* and *pip* dependencies and other configuration files in
# this repo.  So start by grabbing this script and the dependencies.

# You can grab the most recent version of this script and files from Rackspace
# Cloud Builders at https://github.com/cloudbuilders/devstack

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

#The following makes fresh mininmal installs (i.e. LXCs) happy
apt-get update
apt-get install -y sudo

# stack.sh keeps the list of **apt** and **pip** dependencies in external
# files, along with config templates and other useful files.  You can find these
# in the ``files`` directory (next to this script).  We will reference this
# directory using the ``FILES`` variable in this script.
FILES=`pwd`/files
if [ ! -d $FILES ]; then
    echo "ERROR: missing devstack/files - did you grab more than just stack.sh?"
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
# We try to have sensible defaults, so you should be able to run ``./stack.sh``
# in most cases.

# So that errors don't compound we exit on any errors so you see only the
# first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# Destination path for installation ``DEST``
DEST=${DEST:-/opt}

# Set the destination directories for openstack projects
NOVA_DIR=$DEST/nova
DASH_DIR=$DEST/dash
NIXON_DIR=$DEST/dash/openstack-dashboard/dashboard/nixon
GLANCE_DIR=$DEST/glance
KEYSTONE_DIR=$DEST/keystone
NOVACLIENT_DIR=$DEST/python-novaclient
API_DIR=$DEST/openstackx
NOVNC_DIR=$DEST/noVNC
MUNIN_DIR=$DEST/openstack-munin

# Specify which services to launch.  These generally correspond to screen tabs
ENABLED_SERVICES=${ENABLED_SERVICES:-g-api,g-reg,key,n-api,n-cpu,n-net,n-sch,n-vnc,dash,mysql,rabbit,munin}

# Use the first IP unless an explicit is set by ``HOST_IP`` environment variable
if [ ! -n "$HOST_IP" ]; then
    HOST_IP=`LC_ALL=C /sbin/ifconfig  | grep -m 1 'inet addr:'| cut -d: -f2 | awk '{print $1}'`
fi

# Nova network configuration
PUBLIC_INTERFACE=${PUBLIC_INTERFACE:-eth0}
VLAN_INTERFACE=${VLAN_INTERFACE:-$PUBLIC_INTERFACE}
FLOATING_RANGE=${FLOATING_RANGE:-172.24.4.1/28}
FIXED_RANGE=${FIXED_RANGE:-10.0.0.0/24}
FIXED_NETWORK_SIZE=${FIXED_NETWORK_SIZE:-256}
NET_MAN=${NET_MAN:-FlatDHCPManager}
EC2_DMZ_HOST=${EC2_DMZ_HOST:-$HOST_IP}
FLAT_NETWORK_BRIDGE=${FLAT_NETWORK_BRIDGE:-br100}
SCHEDULER=${SCHEDULER:-nova.scheduler.simple.SimpleScheduler}

# If you are using FlatDHCP on multiple hosts, set the ``FLAT_INTERFACE``
# variable but make sure that the interface doesn't already have an
# ip or you risk breaking things.
FLAT_INTERFACE=${FLAT_INTERFACE:-eth0}

# Nova hypervisor configuration.  We default to **kvm** but will drop back to
# **qemu** if we are unable to load the kvm module.
LIBVIRT_TYPE=${LIBVIRT_TYPE:-kvm}

# Mysql connection info
MYSQL_USER=${MYSQL_USER:-root}
MYSQL_PASS=${MYSQL_PASS:-nova}
MYSQL_HOST=${MYSQL_HOST:-localhost}
# don't specify /db in this string, so we can use it for multiple services
BASE_SQL_CONN=${BASE_SQL_CONN:-mysql://$MYSQL_USER:$MYSQL_PASS@$MYSQL_HOST}

# Rabbit connection info
RABBIT_HOST=${RABBIT_HOST:-localhost}

# Glance connection info.  Note the port must be specified.
GLANCE_HOSTPORT=${GLANCE_HOSTPORT:-$HOST_IP:9292}

# Install Packages
# ================
#
# Openstack uses a fair number of other projects.

# Seed configuration with mysql password so that apt-get install doesn't
# prompt us for a password upon install.
cat <<MYSQL_PRESEED | sudo debconf-set-selections
mysql-server-5.1 mysql-server/root_password password $MYSQL_PASS
mysql-server-5.1 mysql-server/root_password_again password $MYSQL_PASS
mysql-server-5.1 mysql-server/start_on_boot boolean true
MYSQL_PRESEED

# install apt requirements
sudo apt-get install -y -q `cat $FILES/apts/* | cut -d\# -f1 | grep -Ev "mysql-server|rabbitmq-server"`

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
    fi
}

# compute service
# FIXME - need to factor out these repositories
# git_clone https://github.com/cloudbuilders/nova.git $NOVA_DIR
if [ ! -d $NOVA_DIR ]; then
    bzr clone lp:~hudson-openstack/nova/milestone-proposed/ $NOVA_DIR
fi
# image catalog service
git_clone https://github.com/cloudbuilders/glance.git $GLANCE_DIR
# unified auth system (manages accounts/tokens)
git_clone https://github.com/cloudbuilders/keystone.git $KEYSTONE_DIR
# a websockets/html5 or flash powered VNC console for vm instances
git_clone https://github.com/cloudbuilders/noVNC.git $NOVNC_DIR
# django powered web control panel for openstack
git_clone https://github.com/cloudbuilders/openstack-dashboard.git $DASH_DIR
# FIXME - need to factor out logic like this
cd $DASH_DIR && sudo git fetch && sudo git checkout origin/keystone_diablo
# add nixon, will use this to show munin graphs in dashboard
git_clone https://github.com/cloudbuilders/nixon.git $NIXON_DIR
# python client library to nova that dashboard (and others) use
git_clone https://github.com/cloudbuilders/python-novaclient.git $NOVACLIENT_DIR
# openstackx is a collection of extensions to openstack.compute & nova
# that is *deprecated*.  The code is being moved into python-novaclient & nova.
git_clone https://github.com/cloudbuilders/openstackx.git $API_DIR
# openstack-munin is a collection of munin plugins for monitoring the stack
git_clone https://github.com/cloudbuilders/openstack-munin.git $MUNIN_DIR

# Initialization
# ==============


# setup our checkouts so they are installed into python path
# allowing ``import nova`` or ``import glance.client``
cd $NOVA_DIR; sudo python setup.py develop
cd $NOVACLIENT_DIR; sudo python setup.py develop
cd $KEYSTONE_DIR; sudo python setup.py develop
cd $GLANCE_DIR; sudo python setup.py develop
cd $API_DIR; sudo python setup.py develop
cd $DASH_DIR/django-openstack; sudo python setup.py develop
cd $DASH_DIR/openstack-dashboard; sudo python setup.py develop

# Add a useful screenrc.  This isn't required to run openstack but is we do
# it since we are going to run the services in screen for simple
cp $FILES/screenrc ~/.screenrc

## TODO: update current user to allow sudo for all commands in files/sudo/*

# Rabbit
# ---------
#
if [[ "$ENABLED_SERVICES" =~ "rabbit" ]]; then
    # Install and start rabbitmq-server
    sudo apt-get install -y -q rabbitmq-server
fi

# Mysql
# ---------
#
if [[ "$ENABLED_SERVICES" =~ "mysql" ]]; then
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
#
# Setup the django application to serve via apache/wsgi

if [[ "$ENABLED_SERVICES" =~ "dash" ]]; then

    # Dash currently imports quantum even if you aren't using it.  Instead
    # of installing quantum we can create a simple module that will pass the
    # initial imports
    sudo mkdir -p  $DASH_DIR/openstack-dashboard/quantum || true
    sudo touch $DASH_DIR/openstack-dashboard/quantum/__init__.py
    sudo touch $DASH_DIR/openstack-dashboard/quantum/client.py

    cd $DASH_DIR/openstack-dashboard

    # Includes settings for Nixon, to expose munin charts.
    sudo cp $FILES/dash_settings.py local/local_settings.py

    dashboard/manage.py syncdb

    # create an empty directory that apache uses as docroot
    sudo mkdir -p $DASH_DIR/.blackhole

    ## Configure apache's 000-default to run dashboard
    sudo cp $FILES/000-default.template /etc/apache2/sites-enabled/000-default
    sudo sed -e "s,%DASH_DIR%,$DASH_DIR,g" -i /etc/apache2/sites-enabled/000-default

    # ``python setup.py develop`` left some files owned by root in ``DASH_DIR``
    # and others are owned by the user you are using to run this script.
    # We need to change the owner to apache for dashboard to run.
    sudo chown -R www-data:www-data $DASH_DIR
fi


# Munin
# -----

# Munin is accessable via apache and was configured in the dashboard section.

if [[ "$ENABLED_SERVICES" =~ "munin" ]]; then
    # allow connections from other hosts
    sudo sed -i -e 's/Allow from localhost/Allow from all/g' /etc/munin/apache.conf

    cat >/tmp/nova <<EOF
[keystone_*]
user `whoami`

[nova_*]
user `whoami`
EOF
    sudo mv /tmp/nova /etc/munin/plugin-conf.d/nova
    # configure Munin for Nova plugins
    PLUGINS="keystone_stats nova_floating_ips nova_instance_launched nova_instance_ nova_instance_timing nova_services"
    for i in $PLUGINS; do
      sudo cp -p $MUNIN_DIR/$i /usr/share/munin/plugins
      sudo ln -sf /usr/share/munin/plugins/$i /etc/munin/plugins
    done
    sudo mv /etc/munin/plugins/nova_instance_ /etc/munin/plugins/nova_instance_launched
    sudo restart munin-node
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
    sudo sed -e "s,%DEST%,$DEST,g" -i $GLANCE_CONF

    GLANCE_API_CONF=$GLANCE_DIR/etc/glance-api.conf
    cp $FILES/glance-api.conf $GLANCE_API_CONF
    sudo sed -e "s,%DEST%,$DEST,g" -i $GLANCE_API_CONF
fi

# Nova
# ----


if [[ "$ENABLED_SERVICES" =~ "n-cpu" ]]; then

    # attempt to load modules: nbd (network block device - used to manage
    # qcow images) and kvm (hardware based virtualization).  If unable to
    # load kvm, set the libvirt type to qemu.
    sudo modprobe nbd || true
    if [ ! -e /dev/kvm ]; then
        LIBVIRT_TYPE=qemu
    fi
    # User needs to be member of libvirtd group for nova-compute to use libvirt.
    sudo usermod -a -G libvirtd `whoami`
    # if kvm wasn't running before we need to restart libvirt to enable it
    sudo /etc/init.d/libvirt-bin restart

    # setup nova instance directory
    mkdir -p $NOVA_DIR/instances

    # if there is a partition labeled nova-instances use it (ext filesystems
    # can be labeled via e2label)
    ## FIXME: if already mounted this blows up...
    if [ -L /dev/disk/by-label/nova-instances ]; then
        sudo mount -L nova-instances $NOVA_DIR/instances
        sudo chown -R `whoami` $NOVA_DIR/instances
    fi

    # Clean out the instances directory
    rm -rf $NOVA_DIR/instances/*
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
add_nova_flag "--osapi_extensions_path=$API_DIR/extensions"
add_nova_flag "--vncproxy_url=http://$HOST_IP:6080"
add_nova_flag "--vncproxy_wwwroot=$NOVNC_DIR/"
add_nova_flag "--api_paste_config=$KEYSTONE_DIR/examples/paste/nova-api-paste.ini"
add_nova_flag "--image_service=nova.image.glance.GlanceImageService"
add_nova_flag "--ec2_dmz_host=$EC2_DMZ_HOST"
add_nova_flag "--rabbit_host=$RABBIT_HOST"
add_nova_flag "--glance_api_servers=$GLANCE_HOSTPORT"
add_nova_flag "--flat_network_bridge=$FLAT_NETWORK_BRIDGE"
if [ -n "$FLAT_INTERFACE" ]; then
    add_nova_flag "--flat_interface=$FLAT_INTERFACE"
fi
if [ -n "$MULTI_HOST" ]; then
    add_nova_flag "--multi_host=$MULTI_HOST"
fi

if [[ "$ENABLED_SERVICES" =~ "mysql" ]]; then
    # (re)create nova database
    mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'DROP DATABASE IF EXISTS nova;'
    mysql -u$MYSQL_USER -p$MYSQL_PASS -e 'CREATE DATABASE nova;'
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

    KEYSTONE_DATA=$KEYSTONE_DIR/bin/keystone_data.sh
    cp $FILES/keystone_data.sh $KEYSTONE_DATA
    sudo sed -e "s,%HOST_IP%,$HOST_IP,g" -i $KEYSTONE_DATA
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

if [[ "$ENABLED_SERVICES" =~ "g-reg" ]]; then
    screen_it g-reg "cd $GLANCE_DIR; bin/glance-registry --config-file=etc/glance-registry.conf"
fi

if [[ "$ENABLED_SERVICES" =~ "g-api" ]]; then
    screen_it g-api "cd $GLANCE_DIR; bin/glance-api --config-file=etc/glance-api.conf"
    while ! wget -q -O- http://$GLANCE_HOSTPORT; do
        echo "Waiting for g-api ($GLANCE_HOSTPORT) to start..."
        sleep 1
    done
fi

if [[ "$ENABLED_SERVICES" =~ "key" ]]; then
    screen_it key "cd $KEYSTONE_DIR && $KEYSTONE_DIR/bin/keystone --config-file $KEYSTONE_CONF -d"
    while ! wget -q -O- http://127.0.0.1:5000; do
        echo "Waiting for keystone to start..."
        sleep 1
    done
fi

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
# We can send the command nova-compute to the ``newgrp`` command to execute
# in a specific context.
screen_it n-cpu "cd $NOVA_DIR && echo $NOVA_DIR/bin/nova-compute | newgrp libvirtd"
screen_it n-net "cd $NOVA_DIR && $NOVA_DIR/bin/nova-network"
screen_it n-sch "cd $NOVA_DIR && $NOVA_DIR/bin/nova-scheduler"
# nova-vncproxy binds a privileged port, and so needs sudo
screen_it n-vnc "cd $NOVA_DIR && sudo $NOVA_DIR/bin/nova-vncproxy"
screen_it dash "cd $DASH_DIR && sudo /etc/init.d/apache2 restart; sudo tail -f /var/log/apache2/error.log"

# Install Images
# ==============

if [[ "$ENABLED_SERVICES" =~ "g-reg" ]]; then
    # Downloads a tty image (ami/aki/ari style), then extracts it.  Upon extraction
    # we upload to glance with the glance cli tool.
    if [ ! -f $FILES/tty.tgz ]; then
        wget -c http://images.ansolabs.com/tty.tgz -O $FILES/tty.tgz
    fi

    # extract ami-tty/image, aki-tty/image & ari-tty/image
    mkdir -p $FILES/images
    tar -zxf $FILES/tty.tgz -C $FILES/images

    # add images to glance
    # FIXME: kernel/ramdisk is hardcoded - use return result from add
    glance add -A 999888777666 name="tty-kernel" is_public=true container_format=aki disk_format=aki < $FILES/images/aki-tty/image
    glance add -A 999888777666 name="tty-ramdisk" is_public=true container_format=ari disk_format=ari < $FILES/images/ari-tty/image
    glance add -A 999888777666 name="tty" is_public=true container_format=ami disk_format=ami kernel_id=1 ramdisk_id=2 < $FILES/images/ami-tty/image
fi

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
fi
