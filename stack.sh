#!/usr/bin/env bash

# **stack.sh** is rackspace cloudbuilder's opinionated openstack dev installation.

# Quit script on error
set -o errexit

# Log commands as they are run for debugging
set -o xtrace

DIR=`pwd`
DEST=/opt
CMD=$1

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

# NOVA CONFIGURATION
INTERFACE=${INTERFACE:-eth0}
FLOATING_RANGE=${FLOATING_RANGE:-10.6.0.0/27}
FIXED_RANGE=${FIXED_RANGE:-10.0.0.0/24}
LIBVIRT_TYPE=${LIBVIRT_TYPE:-qemu}
NET_MAN=${NET_MAN:-VlanManager}
# NOTE(vish): If you are using FlatDHCP on multiple hosts, set the interface
#             below but make sure that the interface doesn't already have an
#             ip or you risk breaking things.
# FLAT_INTERFACE=eth0

SQL_CONN=sqlite:///$NOVA_DIR/nova.sqlite

# clone a git repository to a location
function ginstall {
    git clone $1 $2
}

# You should only have to run this once
if [ "$CMD" == "install" ]; then
    # install apt requirements
    apt-get install -y -q `cat $DIR/apts/* | cut -d\# -f1`

    # install python requirements
    pip install `cat $DIR/pips/*`

    # vm service
    ginstall https://github.com/cloudbuilders/nova.git $NOVA_DIR
    # a websockets/html5 or flash powered VNC console for vm instances
    ginstall https://github.com/cloudbuilders/noVNC.git $NOVNC_DIR
    # django powered web control panel for openstack
    ginstall https://github.com/cloudbuilders/openstack-dashboard.git $DASH_DIR
    # python client library to nova that dashboard (and others) use
    ginstall https://github.com/cloudbuilders/python-novaclient.git $NOVACLIENT_DIR
    # unified auth system (manages accounts/tokens)
    ginstall https://github.com/cloudbuilders/keystone.git $KEYSTONE_DIR
    # image catalog
    ginstall https://github.com/cloudbuilders/glance.git $GLANCE_DIR
    # openstackx is a collection of extensions to openstack.compute & nova 
    # that is *deprecated*.  The code is being moved into python-novaclient & nova.
    ginstall https://github.com/cloudbuilders/openstackx.git $API_DIR

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

    # setup nova instance directory
    mkdir -p $NOVA_DIR/instances

    # if there is a partition labeled nova-instances use it (ext filesystems
    # can be labeled via e2label)
    if [ -L /dev/disk/by-label/nova-instances ]; then
        mount -L nova-instances /$NOVA_DIR/instances
    fi

    # *Dashboard*: setup django application to serve via apache/wsgi

    # Dash currently imports quantum even if you aren't using it.  Instead 
    # of installing quantum we can create a simple module that will pass the 
    # initial imports
    mkdir $DASH_DIR/openstack-dashboard/quantum
    touch $DASH_DIR/openstack-dashboard/quantum/__init__.py
    touch $DASH_DIR/openstack-dashboard/quantum/client.py
    # local_settings has 
    cd $DASH_DIR/openstack-dashboard
    cp local/local_settings.py.example local/local_settings.py
    dashboard/manage.py syncdb

    # *Setup Apache*
    # create an empty directory to use as our 
    mkdir $DASH_DIR/.blackhole
    # FIXME(ja): can't figure out how to make $DASH_DIR work in sed, also install to available/a2e it 
    cat $DIR/files/000-default.template | sed "s/%DASH_DIR%/\/opt\/dash/g" > /etc/apache2/sites-enabled/000-default

    chown -R www-data:www-data $DASH_DIR

    mkdir -p /var/log/glance

    # prepare initial images for loading into glance
    if [ ! -f $DEST/tty.tgz ]; then
        wget -c http://images.ansolabs.com/tty.tgz -O $DEST/tty.tgz
    fi

    mkdir -p $DEST/images
    tar -C $DEST/images -zxf $DEST/tty.tgz

    # add useful screenrc
    cp $DIR/files/screenrc ~/.screenrc
    exit
fi

NL=`echo -ne '\015'`

function screen_it {
    # nova api crashes if we start it with a regular screen command,
    # so send the start command by forcing text into the window.
    screen -S nova -X screen -t $1
    screen -S nova -p $1 -X stuff "$2$NL"
}

function add_nova_flag {
    echo "$1" >> $NOVA_DIR/bin/nova.conf
}

if [ "$CMD" == "run" ] || [ "$CMD" == "run_detached" ]; then

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
    rm -f $NOVA_DIR/nova.sqlite
    $NOVA_DIR/bin/nova-manage db sync

    # initialize keystone with default users/endpoints
    # FIXME(ja): move initial_data.sh into this script
    rm -f /opt/keystone/keystone.db
    curl -OL https://raw.github.com/cloudbuilders/deploy.sh/master/initial_data.sh
    BIN_DIR=$KEYSTONE_DIR/bin bash initial_data.sh

    # create a small network
    $NOVA_DIR/bin/nova-manage network create private $FIXED_RANGE 1 32

    # create some floating ips
    $NOVA_DIR/bin/nova-manage floating create $FLOATING_RANGE

    # delete existing glance images/database.  Glance will recreate the db
    # when it is ran.
    rm -rf /var/lib/glance/images/*
    rm -f $GLANCE_DIR/glance.sqlite

    screen_it n-api "$NOVA_DIR/bin/nova-api"
    screen_it g-api "cd $GLANCE_DIR; bin/glance-api --config-file=etc/glance-api.conf"
    screen_it g-reg "cd $GLANCE_DIR; bin/glance-registry --config-file=etc/glance-registry.conf"
    screen_it cpu "$NOVA_DIR/bin/nova-compute"
    screen_it net "$NOVA_DIR/bin/nova-network"
    screen_it sched "$NOVA_DIR/bin/nova-scheduler"
    screen_it key "$KEYSTONE_DIR/bin/keystone --config-file $KEYSTONE_DIR/etc/keystone.conf"
    screen_it vnc "$NOVA_DIR/bin/nova-vncproxy"
    screen_it dash "/etc/init.d/apache2 restart; tail -f /var/log/apache2/error.log"

    # FIXME: switch to just importing images
    # remove previously converted images
    rm -rf $DIR/images/[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]
    $NOVA_DIR/bin/nova-manage image convert $DIR/images

    if [ "$CMD" != "run_detached" ]; then
      screen -S nova -x
    fi
fi

if [ "$CMD" == "run" ] || [ "$CMD" == "terminate" ]; then
    virsh list | grep i- | awk '{print $1}' | xargs -n1 virsh destroy
    $NOVA_DIR/tools/clean-vlans
    echo "FIXME: clean networks?"
fi

if [ "$CMD" == "run" ] || [ "$CMD" == "clean" ]; then
    screen -S nova -X quit
    rm -f *.pid*
fi

