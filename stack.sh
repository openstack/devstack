#!/usr/bin/env bash

# **stack.sh** is rackspace cloudbuilder's opinionated openstack dev installation.

# Settings/Options
# ================

# This script is customizable through setting environment variables.  If you
# want to override a setting you can either::
#
#     export MYSQL_PASS=anothersecret
#     ./stack.sh
#
# or run on a single line ``MYSQL_PASS=simple ./stack.sh``
# or simply ``./stack.sh``

# This script exits on an error so that errors don't compound and you see 
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers 
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# Important paths: ``DIR`` is where we are executing from and ``DEST`` is 
# where we are installing openstack.
DIR=`pwd`
DEST=/opt

# Set the destination directories for openstack projects
NOVA_DIR=$DEST/nova
DASH_DIR=$DEST/dash
GLANCE_DIR=$DEST/glance
KEYSTONE_DIR=$DEST/keystone
NOVACLIENT_DIR=$DEST/python-novaclient
API_DIR=$DEST/openstackx
NOVNC_DIR=$DEST/noVNC

# Specify which services to launch.  These generally correspond to screen tabs
ENABLED_SERVICES=g-api,g-reg,key,n-api,n-cpu,n-net,n-sch,n-vnc,dash

# Use the first IP unless an explicit is set by ``HOST_IP`` environment variable
if [ ! -n "$HOST_IP" ]; then
    HOST_IP=`LC_ALL=C ifconfig  | grep -m 1 'inet addr:'| cut -d: -f2 | awk '{print $1}'`
fi

# Nova network configuration
INTERFACE=${INTERFACE:-eth0}
FLOATING_RANGE=${FLOATING_RANGE:-10.6.0.0/27}
FIXED_RANGE=${FIXED_RANGE:-10.0.0.0/24}
NET_MAN=${NET_MAN:-VlanManager}
EC2_DMZ_HOST=${EC2_DMZ_HOST:-$HOST_IP}

# If you are using FlatDHCP on multiple hosts, set the ``FLAT_INTERFACE``
# variable but make sure that the interface doesn't already have an
# ip or you risk breaking things.
# FLAT_INTERFACE=eth0

# Nova hypervisor configuration
LIBVIRT_TYPE=${LIBVIRT_TYPE:-qemu}

# Mysql connection info
MYSQL_PASS=${MYSQL_PASS:-nova}
MYSQL_HOST=${MYSQL_HOST:-localhost}
# don't specify /db in this string, so we can use it for multiple services
BASE_SQL_CONN=${BASE_SQL_CONN:-mysql://root:$MYSQL_PASS@$MYSQL_HOST}

# Rabbit connection info
RABBIT_HOST=${RABBIT_HOST:-localhost}

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
sudo apt-get install -y -q `cat $DIR/apts/* | cut -d\# -f1`

# install python requirements
sudo PIP_DOWNLOAD_CACHE=/var/cache/pip pip install `cat $DIR/pips/*`

# git clone only if directory doesn't exist already
function git_clone {
    if [ ! -d $2 ]; then
        git clone $1 $2
    fi
}

# compute service
git_clone https://github.com/cloudbuilders/nova.git $NOVA_DIR
# image catalog service
git_clone https://github.com/cloudbuilders/glance.git $GLANCE_DIR
# unified auth system (manages accounts/tokens)
git_clone https://github.com/cloudbuilders/keystone.git $KEYSTONE_DIR
# a websockets/html5 or flash powered VNC console for vm instances
git_clone https://github.com/cloudbuilders/noVNC.git $NOVNC_DIR
# django powered web control panel for openstack
git_clone https://github.com/cloudbuilders/openstack-dashboard.git $DASH_DIR
# python client library to nova that dashboard (and others) use
git_clone https://github.com/cloudbuilders/python-novaclient.git $NOVACLIENT_DIR
# openstackx is a collection of extensions to openstack.compute & nova 
# that is *deprecated*.  The code is being moved into python-novaclient & nova.
git_clone https://github.com/cloudbuilders/openstackx.git $API_DIR

# Initialization
# ==============

# setup our checkouts so they are installed into python path
# allowing ``import nova`` or ``import glance.client``
cd $NOVACLIENT_DIR; sudo python setup.py develop
cd $KEYSTONE_DIR; sudo python setup.py develop
cd $GLANCE_DIR; sudo python setup.py develop
cd $API_DIR; sudo python setup.py develop
cd $DASH_DIR/django-openstack; sudo python setup.py develop
cd $DASH_DIR/openstack-dashboard; sudo python setup.py develop

# attempt to load modules: kvm (hardware virt) and nbd (network block 
# device - used to manage qcow images)
sudo modprobe nbd || true
sudo modprobe kvm || true
# user needs to be member of libvirtd group for nova-compute to use libvirt
sudo usermod -a -G libvirtd `whoami`
# if kvm wasn't running before we need to restart libvirt to enable it
sudo /etc/init.d/libvirt-bin restart

## FIXME(ja): should LIBVIRT_TYPE be kvm if kvm module is loaded?

# add useful screenrc
cp $DIR/files/screenrc ~/.screenrc

# TODO: update current user to allow sudo for all commands in files/sudo/*


# Dashboard
# ---------
#
# Setup the django application to serve via apache/wsgi

# Dash currently imports quantum even if you aren't using it.  Instead 
# of installing quantum we can create a simple module that will pass the 
# initial imports
sudo mkdir -p  $DASH_DIR/openstack-dashboard/quantum || true
sudo touch $DASH_DIR/openstack-dashboard/quantum/__init__.py
sudo touch $DASH_DIR/openstack-dashboard/quantum/client.py

cd $DASH_DIR/openstack-dashboard
sudo cp local/local_settings.py.example local/local_settings.py
dashboard/manage.py syncdb

# create an empty directory that apache uses as docroot
sudo mkdir -p $DASH_DIR/.blackhole

## Configure apache's 000-default to run dashboard
sudo cp $DIR/files/000-default.template /etc/apache2/sites-enabled/000-default
sudo sed -e "s,%DASH_DIR%,$DASH_DIR,g" -i /etc/apache2/sites-enabled/000-default

# ``python setup.py develop`` left some files owned by root in ``DASH_DIR`` and
# others by the original owner.  We need to change the owner to apache so
# dashboard can run
sudo chown -R www-data:www-data $DASH_DIR


# Glance
# ------

# Glance uses ``/var/lib/glance`` and ``/var/log/glance`` by default, so
# we need to insure that our user has permissions to use them.
sudo mkdir -p /var/log/glance
sudo chown -R `whoami` /var/log/glance 
sudo mkdir -p /var/lib/glance
sudo chown -R `whoami` /var/lib/glance

# Delete existing images/database as glance will recreate the db on startup
rm -rf /var/lib/glance/images/*
# (re)create glance database
mysql -uroot -p$MYSQL_PASS -e 'DROP DATABASE glance;' || true
mysql -uroot -p$MYSQL_PASS -e 'CREATE DATABASE glance;'
# Copy over our glance-registry.conf
GLANCE_CONF=$GLANCE_DIR/etc/glance-registry.conf
cp $DIR/files/glance-registry.conf $GLANCE_CONF
sudo sed -e "s,%SQL_CONN%,$BASE_SQL_CONN/glance,g" -i $GLANCE_CONF

# Nova
# ----

function add_nova_flag {
    echo "$1" >> $NOVA_DIR/bin/nova.conf
}

# (re)create nova.conf
rm -f $NOVA_DIR/bin/nova.conf
add_nova_flag "--verbose"
add_nova_flag "--nodaemon"
add_nova_flag "--dhcpbridge_flagfile=$NOVA_DIR/bin/nova.conf"
add_nova_flag "--network_manager=nova.network.manager.$NET_MAN"
add_nova_flag "--my_ip=$HOST_IP"
add_nova_flag "--public_interface=$INTERFACE"
add_nova_flag "--vlan_interface=$INTERFACE"
add_nova_flag "--sql_connection=$BASE_SQL_CONN/nova"
add_nova_flag "--libvirt_type=$LIBVIRT_TYPE"
add_nova_flag "--osapi_extensions_path=$API_DIR/extensions"
add_nova_flag "--vncproxy_url=http://$HOST_IP:6080"
add_nova_flag "--vncproxy_wwwroot=$NOVNC_DIR/"
add_nova_flag "--api_paste_config=$KEYSTONE_DIR/examples/paste/nova-api-paste.ini"
add_nova_flag "--image_service=nova.image.glance.GlanceImageService"
add_nova_flag "--image_service=nova.image.glance.GlanceImageService"
add_nova_flag "--ec2_dmz_host=$EC2_DMZ_HOST"
add_nova_flag "--rabbit_host=$RABBIT_HOST"
if [ -n "$FLAT_INTERFACE" ]; then
    add_nova_flag "--flat_interface=$FLAT_INTERFACE"
fi

# create a new named screen to store things in
screen -d -m -S nova -t nova
sleep 1

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

# delete traces of nova networks from prior runs
killall dnsmasq || true
rm -rf $NOVA_DIR/networks
mkdir -p $NOVA_DIR/networks

# (re)create nova database
mysql -uroot -p$MYSQL_PASS -e 'DROP DATABASE nova;' || true
mysql -uroot -p$MYSQL_PASS -e 'CREATE DATABASE nova;'
$NOVA_DIR/bin/nova-manage db sync

# create a small network
$NOVA_DIR/bin/nova-manage network create private $FIXED_RANGE 1 32

# create some floating ips
$NOVA_DIR/bin/nova-manage floating create $FLOATING_RANGE

# Keystone
# --------

# (re)create keystone database
mysql -uroot -p$MYSQL_PASS -e 'DROP DATABASE keystone;' || true
mysql -uroot -p$MYSQL_PASS -e 'CREATE DATABASE keystone;'

# FIXME (anthony) keystone should use keystone.conf.example
KEYSTONE_CONF=$KEYSTONE_DIR/etc/keystone.conf
cp $DIR/files/keystone.conf $KEYSTONE_CONF
sudo sed -e "s,%SQL_CONN%,$BASE_SQL_CONN/keystone,g" -i $KEYSTONE_CONF

# initialize keystone with default users/endpoints
BIN_DIR=$KEYSTONE_DIR/bin bash $DIR/files/keystone_data.sh


# Launch Services
# ===============

# nova api crashes if we start it with a regular screen command,
# so send the start command by forcing text into the window.
# Only run the services specified in ``ENABLED_SERVICES``

NL=`echo -ne '\015'`

function screen_it {
    if [[ "$ENABLED_SERVICES" =~ "$1" ]]; then
        screen -S nova -X screen -t $1
        screen -S nova -p $1 -X stuff "$2$NL"
    fi
}

screen_it g-api "cd $GLANCE_DIR; bin/glance-api --config-file=etc/glance-api.conf"
screen_it g-reg "cd $GLANCE_DIR; bin/glance-registry --config-file=etc/glance-registry.conf"
# keystone drops a keystone.log where if it is run, so change the path to
# where it can write
screen_it key "cd /tmp; $KEYSTONE_DIR/bin/keystone --config-file $KEYSTONE_CONF"
screen_it n-api "$NOVA_DIR/bin/nova-api"
screen_it n-cpu "$NOVA_DIR/bin/nova-compute"
screen_it n-net "$NOVA_DIR/bin/nova-network"
screen_it n-sch "$NOVA_DIR/bin/nova-scheduler"
# nova-vncproxy binds a privileged port, and so needs sudo
screen_it n-vnc "sudo $NOVA_DIR/bin/nova-vncproxy"
screen_it dash "sudo /etc/init.d/apache2 restart; sudo tail -f /var/log/apache2/error.log"

# Install Images
# ==============

# Downloads a tty image (ami/aki/ari style), then extracts it.  Upon extraction 
# we upload to glance with the glance cli tool.

mkdir -p $DEST/images
cd $DEST/images
if [ ! -f $DEST/tty.tgz ]; then
    wget -c http://images.ansolabs.com/tty.tgz -O $DEST/tty.tgz
fi

# extract ami-tty/image, aki-tty/image & ari-tty/image
tar -zxf $DEST/tty.tgz

# add images to glance 
# FIXME: kernel/ramdisk is hardcoded - use return result from add
glance add name="tty-kernel" is_public=true container_format=aki disk_format=aki < aki-tty/image 
glance add name="tty-ramdisk" is_public=true container_format=ari disk_format=ari < ari-tty/image 
glance add name="tty" is_public=true container_format=ami disk_format=ami kernel_id=1 ramdisk_id=2 < ami-tty/image
