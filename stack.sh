#!/usr/bin/env bash

# **stack.sh** is rackspace cloudbuilder's opinionated openstack installation.

# Quit script on error
set -o errexit

# Log commands as they are run for debugging
set -o xtrace

DIR=`pwd`
DEST=/opt
CMD=$1

# Set hte destination directories for openstack projects
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

# clone a git repository to a location, or if it already
# exists, fetch and checkout remote master
function clone_or_up {
    if [ -d $2 ]; then
        echo commenting out update for now for speed
        # cd $2
        # git fetch origin
        # git checkout origin/master
    else
        git clone $1 $2
    fi
}

# You should only have to run this once
if [ "$CMD" == "install" ]; then
    # install apt requirements
    apt-get install -y -q `cat $DIR/apts/* | cut -d\# -f1`

    # install python requirements
    pip install `cat $DIR/pips/*`

    # TODO: kill openstackx
    clone_or_up https://github.com/cloudbuilders/nova.git $NOVA_DIR
    clone_or_up https://github.com/cloudbuilders/openstackx.git $API_DIR
    clone_or_up https://github.com/cloudbuilders/noVNC.git $NOVNC_DIR
    clone_or_up https://github.com/cloudbuilders/openstack-dashboard.git $DASH_DIR
    clone_or_up https://github.com/cloudbuilders/python-novaclient.git $NOVACLIENT_DIR
    clone_or_up https://github.com/cloudbuilders/keystone.git $KEYSTONE_DIR
    clone_or_up https://github.com/cloudbuilders/glance.git $GLANCE_DIR

    mkdir -p $NOVA_DIR/instances
    mkdir -p $NOVA_DIR/networks

    # these components are imported into each other...
    cd $NOVACLIENT_DIR; python setup.py develop
    cd $KEYSTONE_DIR; python setup.py develop
    cd $GLANCE_DIR; python setup.py develop
    cd $API_DIR; python setup.py develop
    cd $DASH_DIR/django-openstack; python setup.py develop
    cd $DASH_DIR/openstack-dashboard; python setup.py develop
    # HACK: dash currently imports quantum even if you aren't using it
    cd $DASH_DIR/openstack-dashboard
    mkdir quantum
    touch quantum/__init__.py
    touch quantum/client.py

    # attempt to load kvm and nbd modules
    modprobe kvm || true
    modprobe nbd || true
    /etc/init.d/libvirt-bin restart

    # install dashboard
    cd $DASH_DIR/openstack-dashboard
    cp local/local_settings.py.example local/local_settings.py
    dashboard/manage.py syncdb
    # setup apache
    mkdir $DASH_DIR/.blackhole

    cat > /etc/apache2/sites-enabled/000-default <<EOF
<VirtualHost *:80>
    WSGIScriptAlias / $DASH_DIR/openstack-dashboard/dashboard/wsgi/django.wsgi
    WSGIDaemonProcess dashboard user=www-data group=www-data processes=3 threads=10
    WSGIProcessGroup dashboard

    DocumentRoot $DASH_DIR/.blackhole/
    Alias /media $DASH_DIR/openstack-dashboard/media

    <Directory />
        Options FollowSymLinks
        AllowOverride None
    </Directory>

    <Directory $DASH_DIR/>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride None
        Order allow,deny
        allow from all
    </Directory>

    ErrorLog /var/log/apache2/error.log
    LogLevel warn
    CustomLog /var/log/apache2/access.log combined
</VirtualHost>
EOF

    chown -R www-data:www-data $DASH_DIR

    mkdir -p /var/log/glance

    if [ ! -f $DEST/tty.tgz ]; then
        wget -c http://images.ansolabs.com/tty.tgz -O $DEST/tty.tgz
    fi

    mkdir -p $DEST/images
    tar -C $DEST/images -zxf $DEST/tty.tgz
    exit
fi

NL=`echo -ne '\015'`

function screen_it {
    screen -S nova -X screen -t $1
    screen -S nova -p $1 -X stuff "$2$NL"
}

function add_nova_flag {
    echo "$1" >> $NOVA_DIR/bin/nova.conf
}

if [ "$CMD" == "run" ] || [ "$CMD" == "run_detached" ]; then

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

    if [ -n "$FLAT_INTERFACE" ]; then
        add_nova_flag "--flat_interface=$FLAT_INTERFACE"
    fi

    add_nova_flag "--api_paste_config=$KEYSTONE_DIR/examples/paste/nova-api-paste.ini"
    add_nova_flag "--image_service=nova.image.glance.GlanceImageService"

    killall dnsmasq || true
    screen -d -m -S nova -t nova
    sleep 1
    rm -f $NOVA_DIR/nova.sqlite
    rm -rf $NOVA_DIR/instances/*
    mkdir -p $NOVA_DIR/instances
    # if there is a partition labeled nova-instances use it (ext filesystems
    # can be labeled via e2label)
    if [ -L /dev/disk/by-label/nova-instances ]; then
        mount -L nova-instances /$NOVA_DIR/instances
    fi
    rm -rf $NOVA_DIR/networks
    mkdir -p $NOVA_DIR/networks

    # create the database
    $NOVA_DIR/bin/nova-manage db sync
    rm -f keystone.db
    # add default data
    curl -OL https://raw.github.com/cloudbuilders/deploy.sh/master/initial_data.sh
    BIN_DIR=$KEYSTONE_DIR/bin bash initial_data.sh

    # create a small network
    $NOVA_DIR/bin/nova-manage network create private $FIXED_RANGE 1 32

    # create some floating ips
    $NOVA_DIR/bin/nova-manage floating create $FLOATING_RANGE

    rm -rf /var/lib/glance/images/*
    rm -f $GLANCE_DIR/glance.sqlite

    # nova api crashes if we start it with a regular screen command,
    # so send the start command by forcing text into the window.
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

