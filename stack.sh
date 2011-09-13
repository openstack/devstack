#!/usr/bin/env bash

# **stack.sh** is rackspace cloudbuilder's opinionated openstack dev installation.

# FIXME: commands should be: stack.sh should allow specifying a subset of services

# Quit script on error
set -o errexit

# Log commands as they are run for debugging
set -o xtrace

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

# Use the first IP unless an explicit is set by a HOST_IP environment variable
if [ ! -n "$HOST_IP" ]; then
    HOST_IP=`LC_ALL=C ifconfig  | grep -m 1 'inet addr:'| cut -d: -f2 | awk '{print $1}'`
fi

# NOVA network / hypervisor configuration
INTERFACE=${INTERFACE:-eth0}
FLOATING_RANGE=${FLOATING_RANGE:-10.6.0.0/27}
FIXED_RANGE=${FIXED_RANGE:-10.0.0.0/24}
LIBVIRT_TYPE=${LIBVIRT_TYPE:-qemu}
NET_MAN=${NET_MAN:-VlanManager}
# NOTE(vish): If you are using FlatDHCP on multiple hosts, set the interface
#             below but make sure that the interface doesn't already have an
#             ip or you risk breaking things.
# FLAT_INTERFACE=eth0

# TODO: switch to mysql for all services
MYSQL_PASS=${MYSQL_PASS:-nova}
SQL_CONN=${SQL_CONN:-mysql://root:$MYSQL_PASS@localhost/nova}
# TODO: set rabbitmq conn string explicitly as well

# seed configuration with mysql password
cat <<MYSQL_PRESEED | debconf-set-selections
mysql-server-5.1 mysql-server/root_password password $MYSQL_PASS
mysql-server-5.1 mysql-server/root_password_again password $MYSQL_PASS
mysql-server-5.1 mysql-server/start_on_boot boolean true
MYSQL_PRESEED

# install apt requirements
apt-get install -y -q `cat $DIR/apts/* | cut -d\# -f1`

# install python requirements
pip install `cat $DIR/pips/*`

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

# setup our checkouts so they are installed into python path
# allowing `import nova` or `import glance.client`
cd $NOVACLIENT_DIR; python setup.py develop
cd $KEYSTONE_DIR; python setup.py develop
cd $GLANCE_DIR; python setup.py develop
cd $API_DIR; python setup.py develop
cd $DASH_DIR/django-openstack; python setup.py develop
cd $DASH_DIR/openstack-dashboard; python setup.py develop

# attempt to load modules: kvm (hardware virt) and nbd (network block 
# device - used to manage qcow images)
modprobe nbd || true
modprobe kvm || true
# if kvm wasn't running before we need to restart libvirt to enable it
/etc/init.d/libvirt-bin restart

# FIXME(ja): should LIBVIRT_TYPE be kvm if kvm module is loaded?

# setup nova instance directory
mkdir -p $NOVA_DIR/instances

# if there is a partition labeled nova-instances use it (ext filesystems
# can be labeled via e2label)
# FIXME: if already mounted this blows up...
if [ -L /dev/disk/by-label/nova-instances ]; then
    mount -L nova-instances $NOVA_DIR/instances
fi

# *Dashboard*: setup django application to serve via apache/wsgi

# Dash currently imports quantum even if you aren't using it.  Instead 
# of installing quantum we can create a simple module that will pass the 
# initial imports
mkdir $DASH_DIR/openstack-dashboard/quantum || true
touch $DASH_DIR/openstack-dashboard/quantum/__init__.py
touch $DASH_DIR/openstack-dashboard/quantum/client.py

cd $DASH_DIR/openstack-dashboard
cp local/local_settings.py.example local/local_settings.py
dashboard/manage.py syncdb

# ## Setup Apache
# create an empty directory to use as our 
mkdir $DASH_DIR/.blackhole

# FIXME(ja): can't figure out how to make $DASH_DIR work in sed, also install to available/a2e it 
cat $DIR/files/000-default.template | sed 's/%DASH_DIR%/\/opt\/dash/g' > /etc/apache2/sites-enabled/000-default
chown -R www-data:www-data $DASH_DIR

mkdir -p /var/log/glance

# add useful screenrc
cp $DIR/files/screenrc ~/.screenrc

# TODO: update current user to allow sudo for all commands in files/sudo/*

NL=`echo -ne '\015'`


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
add_nova_flag "--sql_connection=$SQL_CONN"
add_nova_flag "--libvirt_type=$LIBVIRT_TYPE"
add_nova_flag "--osapi_extensions_path=$API_DIR/extensions"
add_nova_flag "--vncproxy_url=http://$HOST_IP:6080"
add_nova_flag "--vncproxy_wwwroot=$NOVNC_DIR/noVNC/noVNC"
add_nova_flag "--api_paste_config=$KEYSTONE_DIR/examples/paste/nova-api-paste.ini"
add_nova_flag "--image_service=nova.image.glance.GlanceImageService"
if [ -n "$FLAT_INTERFACE" ]; then
    add_nova_flag "--flat_interface=$FLAT_INTERFACE"
fi

# create a new named screen to store things in
screen -d -m -S nova -t nova
sleep 1

# Clean out the instances directory
rm -rf $NOVA_DIR/instances/*

# delete traces of nova networks from prior runs
killall dnsmasq || true
rm -rf $NOVA_DIR/networks
mkdir -p $NOVA_DIR/networks

# (re)create nova database
mysql -p$MYSQL_PASS -e 'DROP DATABASE nova;' || true
mysql -p$MYSQL_PASS -e 'CREATE DATABASE nova;'
$NOVA_DIR/bin/nova-manage db sync

# initialize keystone with default users/endpoints
rm -f /opt/keystone/keystone.db
BIN_DIR=$KEYSTONE_DIR/bin bash $DIR/files/keystone_data.sh

# create a small network
$NOVA_DIR/bin/nova-manage network create private $FIXED_RANGE 1 32

# create some floating ips
$NOVA_DIR/bin/nova-manage floating create $FLOATING_RANGE

# delete existing glance images/database.  Glance will recreate the db
# when it is ran.
rm -rf /var/lib/glance/images/*
rm -f $GLANCE_DIR/glance.sqlite

# nova api crashes if we start it with a regular screen command,
# so send the start command by forcing text into the window.
function screen_it {
    screen -S nova -X screen -t $1
    screen -S nova -p $1 -X stuff "$2$NL"
}

screen_it g-api "cd $GLANCE_DIR; bin/glance-api --config-file=etc/glance-api.conf"
screen_it g-reg "cd $GLANCE_DIR; bin/glance-registry --config-file=etc/glance-registry.conf"
screen_it key "$KEYSTONE_DIR/bin/keystone --config-file $KEYSTONE_DIR/etc/keystone.conf"
screen_it n-api "$NOVA_DIR/bin/nova-api"
screen_it n-cpu "$NOVA_DIR/bin/nova-compute"
screen_it n-net "$NOVA_DIR/bin/nova-network"
screen_it n-sch "$NOVA_DIR/bin/nova-scheduler"
screen_it n-vnc "$NOVA_DIR/bin/nova-vncproxy"
screen_it dash "/etc/init.d/apache2 restart; tail -f /var/log/apache2/error.log"


# ---- download an install images ----

mkdir -p $DEST/images
cd $DEST/images
# prepare initial images for loading into glance
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

