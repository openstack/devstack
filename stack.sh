#!/usr/bin/env bash

# **stack.sh** is an opinionated openstack developer installation.

# This script installs and configures *nova*, *glance*, *horizon* and *keystone*

# This script allows you to specify configuration options of what git
# repositories to use, enabled services, network configuration and various
# passwords.  If you are crafty you can run the script on multiple nodes using
# shared settings for common resources (mysql, rabbitmq) and build a multi-node
# developer install.

# To keep this script simple we assume you are running on an **Ubuntu 11.10
# Oneiric** machine.  It should work in a VM or physical server.  Additionally
# we put the list of *apt* and *pip* dependencies and other configuration files
# in this repo.  So start by grabbing this script and the dependencies.

# Learn more and get the most recent version at http://devstack.org

# Sanity Check
# ============

# Warn users who aren't on oneiric, but allow them to override check and attempt
# installation with ``FORCE=yes ./stack``
DISTRO=$(lsb_release -c -s)

if [[ ! ${DISTRO} =~ (oneiric) ]]; then
    echo "WARNING: this script has only been tested on oneiric"
    if [[ "$FORCE" != "yes" ]]; then
        echo "If you wish to run this script anyway run with FORCE=yes"
        exit 1
    fi
fi

# Keep track of the current devstack directory.
TOP_DIR=$(cd $(dirname "$0") && pwd)

# stack.sh keeps the list of **apt** and **pip** dependencies in external
# files, along with config templates and other useful files.  You can find these
# in the ``files`` directory (next to this script).  We will reference this
# directory using the ``FILES`` variable in this script.
FILES=$TOP_DIR/files
if [ ! -d $FILES ]; then
    echo "ERROR: missing devstack/files - did you grab more than just stack.sh?"
    exit 1
fi



# Settings
# ========

# This script is customizable through setting environment variables.  If you
# want to override a setting you can either::
#
#     export MYSQL_PASSWORD=anothersecret
#     ./stack.sh
#
# You can also pass options on a single line ``MYSQL_PASSWORD=simple ./stack.sh``
#
# Additionally, you can put any local variables into a ``localrc`` file, like::
#
#     MYSQL_PASSWORD=anothersecret
#     MYSQL_USER=hellaroot
#
# We try to have sensible defaults, so you should be able to run ``./stack.sh``
# in most cases.
#
# We source our settings from ``stackrc``.  This file is distributed with devstack
# and contains locations for what repositories to use.  If you want to use other
# repositories and branches, you can add your own settings with another file called
# ``localrc``
#
# If ``localrc`` exists, then ``stackrc`` will load those settings.  This is
# useful for changing a branch or repository to test other versions.  Also you
# can store your other settings like **MYSQL_PASSWORD** or **ADMIN_PASSWORD** instead
# of letting devstack generate random ones for you.
source ./stackrc

# Destination path for installation ``DEST``
DEST=${DEST:-/opt/stack}

# Configure services to syslog instead of writing to individual log files
SYSLOG=${SYSLOG:-False}

# apt-get wrapper to just get arguments set correctly
function apt_get() {
    local sudo="sudo"
    [ "$(id -u)" = "0" ] && sudo="env"
    $sudo DEBIAN_FRONTEND=noninteractive apt-get \
        --option "Dpkg::Options::=--force-confold" --assume-yes "$@"
}


# OpenStack is designed to be run as a regular user (Horizon will fail to run
# as root, since apache refused to startup serve content from root user).  If
# stack.sh is run as root, it automatically creates a stack user with
# sudo privileges and runs as that user.

if [[ $EUID -eq 0 ]]; then
    ROOTSLEEP=${ROOTSLEEP:-10}
    echo "You are running this script as root."
    echo "In $ROOTSLEEP seconds, we will create a user 'stack' and run as that user"
    sleep $ROOTSLEEP

    # since this script runs as a normal user, we need to give that user
    # ability to run sudo
    dpkg -l sudo || apt_get update && apt_get install sudo

    if ! getent passwd stack >/dev/null; then
        echo "Creating a user called stack"
        useradd -U -G sudo -s /bin/bash -d $DEST -m stack
    fi

    echo "Giving stack user passwordless sudo priviledges"
    # some uec images sudoers does not have a '#includedir'. add one.
    grep -q "^#includedir.*/etc/sudoers.d" /etc/sudoers ||
        echo "#includedir /etc/sudoers.d" >> /etc/sudoers
    ( umask 226 && echo "stack ALL=(ALL) NOPASSWD:ALL" \
        > /etc/sudoers.d/50_stack_sh )

    echo "Copying files to stack user"
    STACK_DIR="$DEST/${PWD##*/}"
    cp -r -f "$PWD" "$STACK_DIR"
    chown -R stack "$STACK_DIR"
    if [[ "$SHELL_AFTER_RUN" != "no" ]]; then
        exec su -c "set -e; cd $STACK_DIR; bash stack.sh; bash" stack
    else
        exec su -c "set -e; cd $STACK_DIR; bash stack.sh" stack
    fi
    exit 1
else
    # Our user needs passwordless priviledges for certain commands which nova
    # uses internally.
    # Natty uec images sudoers does not have a '#includedir'. add one.
    sudo grep -q "^#includedir.*/etc/sudoers.d" /etc/sudoers ||
        echo "#includedir /etc/sudoers.d" | sudo tee -a /etc/sudoers
    TEMPFILE=`mktemp`
    cat $FILES/sudo/nova > $TEMPFILE
    sed -e "s,%USER%,$USER,g" -i $TEMPFILE
    chmod 0440 $TEMPFILE
    sudo chown root:root $TEMPFILE
    sudo mv $TEMPFILE /etc/sudoers.d/stack_sh_nova
fi

# Set the destination directories for openstack projects
NOVA_DIR=$DEST/nova
HORIZON_DIR=$DEST/horizon
GLANCE_DIR=$DEST/glance
KEYSTONE_DIR=$DEST/keystone
NOVACLIENT_DIR=$DEST/python-novaclient
OPENSTACKX_DIR=$DEST/openstackx
NOVNC_DIR=$DEST/noVNC
SWIFT_DIR=$DEST/swift
SWIFT_KEYSTONE_DIR=$DEST/swift-keystone2
QUANTUM_DIR=$DEST/quantum

# Default Quantum Plugin
Q_PLUGIN=${Q_PLUGIN:-openvswitch}

# Specify which services to launch.  These generally correspond to screen tabs
ENABLED_SERVICES=${ENABLED_SERVICES:-g-api,g-reg,key,n-api,n-cpu,n-net,n-sch,n-vnc,horizon,mysql,rabbit,openstackx}

# Name of the lvm volume group to use/create for iscsi volumes
VOLUME_GROUP=${VOLUME_GROUP:-nova-volumes}

# Nova hypervisor configuration.  We default to libvirt whth  **kvm** but will
# drop back to **qemu** if we are unable to load the kvm module.  Stack.sh can
# also install an **LXC** based system.
VIRT_DRIVER=${VIRT_DRIVER:-libvirt}
LIBVIRT_TYPE=${LIBVIRT_TYPE:-kvm}

# nova supports pluggable schedulers.  ``SimpleScheduler`` should work in most
# cases unless you are working on multi-zone mode.
SCHEDULER=${SCHEDULER:-nova.scheduler.simple.SimpleScheduler}

# Use the eth0 IP unless an explicit is set by ``HOST_IP`` environment variable
if [ ! -n "$HOST_IP" ]; then
    HOST_IP=`LC_ALL=C /sbin/ifconfig eth0 | grep -m 1 'inet addr:'| cut -d: -f2 | awk '{print $1}'`
    if [ "$HOST_IP" = "" ]; then
        echo "Could not determine host ip address."
        echo "If this is not your first run of stack.sh, it is "
        echo "possible that nova moved your eth0 ip address to the FLAT_NETWORK_BRIDGE."
        echo "Please specify your HOST_IP in your localrc."
        exit 1
    fi
fi

# Service startup timeout
SERVICE_TIMEOUT=${SERVICE_TIMEOUT:-60}

# Generic helper to configure passwords
function read_password {
    set +o xtrace
    var=$1; msg=$2
    pw=${!var}

    localrc=$TOP_DIR/localrc

    # If the password is not defined yet, proceed to prompt user for a password.
    if [ ! $pw ]; then
        # If there is no localrc file, create one
        if [ ! -e $localrc ]; then
            touch $localrc
        fi

        # Presumably if we got this far it can only be that our localrc is missing
        # the required password.  Prompt user for a password and write to localrc.
        echo ''
        echo '################################################################################'
        echo $msg
        echo '################################################################################'
        echo "This value will be written to your localrc file so you don't have to enter it again."
        echo "It is probably best to avoid spaces and weird characters."
        echo "If you leave this blank, a random default value will be used."
        echo "Enter a password now:"
        read -e $var
        pw=${!var}
        if [ ! $pw ]; then
            pw=`openssl rand -hex 10`
        fi
        eval "$var=$pw"
        echo "$var=$pw" >> $localrc
    fi
    set -o xtrace
}


# Nova Network Configuration
# --------------------------

# FIXME: more documentation about why these are important flags.  Also
# we should make sure we use the same variable names as the flag names.

PUBLIC_INTERFACE=${PUBLIC_INTERFACE:-eth0}
FIXED_RANGE=${FIXED_RANGE:-10.0.0.0/24}
FIXED_NETWORK_SIZE=${FIXED_NETWORK_SIZE:-256}
FLOATING_RANGE=${FLOATING_RANGE:-172.24.4.224/28}
NET_MAN=${NET_MAN:-FlatDHCPManager}
EC2_DMZ_HOST=${EC2_DMZ_HOST:-$HOST_IP}
FLAT_NETWORK_BRIDGE=${FLAT_NETWORK_BRIDGE:-br100}
VLAN_INTERFACE=${VLAN_INTERFACE:-$PUBLIC_INTERFACE}

# Multi-host is a mode where each compute node runs its own network node.  This
# allows network operations and routing for a VM to occur on the server that is
# running the VM - removing a SPOF and bandwidth bottleneck.
MULTI_HOST=${MULTI_HOST:-False}

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
# occurring.
FLAT_INTERFACE=${FLAT_INTERFACE:-eth0}

## FIXME(ja): should/can we check that FLAT_INTERFACE is sane?

# Using Quantum networking:
#
# Make sure that q-svc is enabled in ENABLED_SERVICES.  If it is the network
# manager will be set to the QuantumManager.
#
# If you're planning to use the Quantum openvswitch plugin, set Q_PLUGIN to
# "openvswitch" and make sure the q-agt service is enabled in
# ENABLED_SERVICES.
#
# With Quantum networking the NET_MAN variable is ignored.


# MySQL & RabbitMQ
# ----------------

# We configure Nova, Horizon, Glance and Keystone to use MySQL as their
# database server.  While they share a single server, each has their own
# database and tables.

# By default this script will install and configure MySQL.  If you want to
# use an existing server, you can pass in the user/password/host parameters.
# You will need to send the same ``MYSQL_PASSWORD`` to every host if you are doing
# a multi-node devstack installation.
MYSQL_HOST=${MYSQL_HOST:-localhost}
MYSQL_USER=${MYSQL_USER:-root}
read_password MYSQL_PASSWORD "ENTER A PASSWORD TO USE FOR MYSQL."

# don't specify /db in this string, so we can use it for multiple services
BASE_SQL_CONN=${BASE_SQL_CONN:-mysql://$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST}

# Rabbit connection info
RABBIT_HOST=${RABBIT_HOST:-localhost}
read_password RABBIT_PASSWORD "ENTER A PASSWORD TO USE FOR RABBIT."

# Glance connection info.  Note the port must be specified.
GLANCE_HOSTPORT=${GLANCE_HOSTPORT:-$HOST_IP:9292}

# SWIFT
# -----
# TODO: implement glance support
# TODO: add logging to different location.

# By default the location of swift drives and objects is located inside
# the swift source directory. SWIFT_DATA_LOCATION variable allow you to redefine
# this.
SWIFT_DATA_LOCATION=${SWIFT_DATA_LOCATION:-${SWIFT_DIR}/data}

# We are going to have the configuration files inside the source
# directory, change SWIFT_CONFIG_LOCATION if you want to adjust that.
SWIFT_CONFIG_LOCATION=${SWIFT_CONFIG_LOCATION:-${SWIFT_DIR}/config}

# devstack will create a loop-back disk formatted as XFS to store the
# swift data. By default the disk size is 1 gigabyte. The variable
# SWIFT_LOOPBACK_DISK_SIZE specified in bytes allow you to change
# that.
SWIFT_LOOPBACK_DISK_SIZE=${SWIFT_LOOPBACK_DISK_SIZE:-1000000}

# The ring uses a configurable number of bits from a path’s MD5 hash as
# a partition index that designates a device. The number of bits kept
# from the hash is known as the partition power, and 2 to the partition
# power indicates the partition count. Partitioning the full MD5 hash
# ring allows other parts of the cluster to work in batches of items at
# once which ends up either more efficient or at least less complex than
# working with each item separately or the entire cluster all at once.
# By default we define 9 for the partition count (which mean 512).
SWIFT_PARTITION_POWER_SIZE=${SWIFT_PARTITION_POWER_SIZE:-9}

# We only ask for Swift Hash if we have enabled swift service.
if [[ "$ENABLED_SERVICES" =~ "swift" ]]; then
    # SWIFT_HASH is a random unique string for a swift cluster that
    # can never change.
    read_password SWIFT_HASH "ENTER A RANDOM SWIFT HASH."
fi

# Keystone
# --------

# Service Token - Openstack components need to have an admin token
# to validate user tokens.
read_password SERVICE_TOKEN "ENTER A SERVICE_TOKEN TO USE FOR THE SERVICE ADMIN TOKEN."
# Horizon currently truncates usernames and passwords at 20 characters
read_password ADMIN_PASSWORD "ENTER A PASSWORD TO USE FOR HORIZON AND KEYSTONE (20 CHARS OR LESS)."

LOGFILE=${LOGFILE:-"$PWD/stack.sh.$$.log"}
(
# So that errors don't compound we exit on any errors so you see only the
# first error that occurred.
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

# create the destination directory and ensure it is writable by the user
sudo mkdir -p $DEST
if [ ! -w $DEST ]; then
    sudo chown `whoami` $DEST
fi

# Install Packages
# ================
#
# Openstack uses a fair number of other projects.

# - We are going to install packages only for the services needed.
# - We are parsing the packages files and detecting metadatas.
#  - If there is a NOPRIME as comment mean we are not doing the install
#    just yet.
#  - If we have the meta-keyword distro:DISTRO or
#    distro:DISTRO1,DISTRO2 it will be installed only for those
#    distros (case insensitive).
function get_packages() {
    local file_to_parse="general"
    local service

    for service in ${ENABLED_SERVICES//,/ }; do
        # Allow individual services to specify dependencies
        if [[ -e $FILES/apts/${service} ]]; then
            file_to_parse="${file_to_parse} $service"
        fi
        if [[ $service == n-* ]]; then
            if [[ ! $file_to_parse =~ nova ]]; then
                file_to_parse="${file_to_parse} nova"
            fi
        elif [[ $service == g-* ]]; then
            if [[ ! $file_to_parse =~ glance ]]; then
                file_to_parse="${file_to_parse} glance"
            fi
        elif [[ $service == key* ]]; then
            if [[ ! $file_to_parse =~ keystone ]]; then
                file_to_parse="${file_to_parse} keystone"
            fi
        fi
    done

    for file in ${file_to_parse}; do
        local fname=${FILES}/apts/${file}
        local OIFS line package distros distro
        [[ -e $fname ]] || { echo "missing: $fname"; exit 1 ;}

        OIFS=$IFS
        IFS=$'\n'
        for line in $(<${fname}); do
            if [[ $line =~ "NOPRIME" ]]; then
                continue
            fi

            if [[ $line =~ (.*)#.*dist:([^ ]*) ]]; then # We are using BASH regexp matching feature.
                        package=${BASH_REMATCH[1]}
                        distros=${BASH_REMATCH[2]}
                        for distro in ${distros//,/ }; do  #In bash ${VAR,,} will lowecase VAR
                            [[ ${distro,,} == ${DISTRO,,} ]] && echo $package
                        done
                        continue
            fi

            echo ${line%#*}
        done
        IFS=$OIFS
    done
}

# install apt requirements
apt_get update
apt_get install $(get_packages)

# install python requirements
sudo PIP_DOWNLOAD_CACHE=/var/cache/pip pip install --use-mirrors `cat $FILES/pips/*`

# git clone only if directory doesn't exist already.  Since ``DEST`` might not
# be owned by the installation user, we create the directory and change the
# ownership to the proper user.
function git_clone {

    GIT_REMOTE=$1
    GIT_DEST=$2
    GIT_BRANCH=$3

    if echo $GIT_BRANCH | egrep -q "^refs"; then
        # If our branch name is a gerrit style refs/changes/...
        if [ ! -d $GIT_DEST ]; then
            git clone $GIT_REMOTE $GIT_DEST
        fi
        cd $GIT_DEST
        git fetch $GIT_REMOTE $GIT_BRANCH && git checkout FETCH_HEAD
    else
        # do a full clone only if the directory doesn't exist
        if [ ! -d $GIT_DEST ]; then
            git clone $GIT_REMOTE $GIT_DEST
            cd $GIT_DEST
            # This checkout syntax works for both branches and tags
            git checkout $GIT_BRANCH
        elif [[ "$RECLONE" == "yes" ]]; then
            # if it does exist then simulate what clone does if asked to RECLONE
            cd $GIT_DEST
            # set the url to pull from and fetch
            git remote set-url origin $GIT_REMOTE
            git fetch origin
            # remove the existing ignored files (like pyc) as they cause breakage
            # (due to the py files having older timestamps than our pyc, so python
            # thinks the pyc files are correct using them)
            find $GIT_DEST -name '*.pyc' -delete
            git checkout -f origin/$GIT_BRANCH
            # a local branch might not exist
            git branch -D $GIT_BRANCH || true
            git checkout -b $GIT_BRANCH
        fi
    fi
}

# compute service
git_clone $NOVA_REPO $NOVA_DIR $NOVA_BRANCH
# python client library to nova that horizon (and others) use
git_clone $NOVACLIENT_REPO $NOVACLIENT_DIR $NOVACLIENT_BRANCH

# glance, swift middleware and nova api needs keystone middleware
if [[ "$ENABLED_SERVICES" =~ "key" ||
      "$ENABLED_SERVICES" =~ "g-api" ||
      "$ENABLED_SERVICES" =~ "n-api" ||
      "$ENABLED_SERVICES" =~ "swift" ]]; then
    # unified auth system (manages accounts/tokens)
    git_clone $KEYSTONE_REPO $KEYSTONE_DIR $KEYSTONE_BRANCH
fi
if [[ "$ENABLED_SERVICES" =~ "swift" ]]; then
    # storage service
    git_clone $SWIFT_REPO $SWIFT_DIR $SWIFT_BRANCH
    # swift + keystone middleware
    git_clone $SWIFT_KEYSTONE_REPO $SWIFT_KEYSTONE_DIR $SWIFT_KEYSTONE_BRANCH
fi
if [[ "$ENABLED_SERVICES" =~ "g-api" ||
      "$ENABLED_SERVICES" =~ "n-api" ]]; then
    # image catalog service
    git_clone $GLANCE_REPO $GLANCE_DIR $GLANCE_BRANCH
fi
if [[ "$ENABLED_SERVICES" =~ "n-vnc" ]]; then
    # a websockets/html5 or flash powered VNC console for vm instances
    git_clone $NOVNC_REPO $NOVNC_DIR $NOVNC_BRANCH
fi
if [[ "$ENABLED_SERVICES" =~ "horizon" ]]; then
    # django powered web control panel for openstack
    git_clone $HORIZON_REPO $HORIZON_DIR $HORIZON_BRANCH $HORIZON_TAG
fi
if [[ "$ENABLED_SERVICES" =~ "openstackx" ]]; then
    # openstackx is a collection of extensions to openstack.compute & nova
    # that is *deprecated*.  The code is being moved into python-novaclient & nova.
    git_clone $OPENSTACKX_REPO $OPENSTACKX_DIR $OPENSTACKX_BRANCH
fi
if [[ "$ENABLED_SERVICES" =~ "quantum" ]]; then
    # quantum
    git_clone $QUANTUM_REPO $QUANTUM_DIR $QUANTUM_BRANCH
fi

# Initialization
# ==============


# setup our checkouts so they are installed into python path
# allowing ``import nova`` or ``import glance.client``
if [[ "$ENABLED_SERVICES" =~ "key" ||
      "$ENABLED_SERVICES" =~ "g-api" ||
      "$ENABLED_SERVICES" =~ "n-api" ||
      "$ENABLED_SERVICES" =~ "swift" ]]; then
    cd $KEYSTONE_DIR; sudo python setup.py develop
fi
if [[ "$ENABLED_SERVICES" =~ "swift" ]]; then
    cd $SWIFT_DIR; sudo python setup.py develop
    cd $SWIFT_KEYSTONE_DIR; sudo python setup.py develop
fi
if [[ "$ENABLED_SERVICES" =~ "g-api" ||
      "$ENABLED_SERVICES" =~ "n-api" ]]; then
    cd $GLANCE_DIR; sudo python setup.py develop
fi
cd $NOVACLIENT_DIR; sudo python setup.py develop
cd $NOVA_DIR; sudo python setup.py develop
if [[ "$ENABLED_SERVICES" =~ "openstackx" ]]; then
    cd $OPENSTACKX_DIR; sudo python setup.py develop
fi
if [[ "$ENABLED_SERVICES" =~ "horizon" ]]; then
    cd $HORIZON_DIR/horizon; sudo python setup.py develop
    cd $HORIZON_DIR/openstack-dashboard; sudo python setup.py develop
fi
if [[ "$ENABLED_SERVICES" =~ "quantum" ]]; then
    cd $QUANTUM_DIR; sudo python setup.py develop
fi

# Add a useful screenrc.  This isn't required to run openstack but is we do
# it since we are going to run the services in screen for simple
cp $FILES/screenrc ~/.screenrc

# Rabbit
# ---------

if [[ "$ENABLED_SERVICES" =~ "rabbit" ]]; then
    # Install and start rabbitmq-server
    # the temp file is necessary due to LP: #878600
    tfile=$(mktemp)
    apt_get install rabbitmq-server > "$tfile" 2>&1
    cat "$tfile"
    rm -f "$tfile"
    # change the rabbit password since the default is "guest"
    sudo rabbitmqctl change_password guest $RABBIT_PASSWORD
fi

# Mysql
# ---------

if [[ "$ENABLED_SERVICES" =~ "mysql" ]]; then

    # Seed configuration with mysql password so that apt-get install doesn't
    # prompt us for a password upon install.
    cat <<MYSQL_PRESEED | sudo debconf-set-selections
mysql-server-5.1 mysql-server/root_password password $MYSQL_PASSWORD
mysql-server-5.1 mysql-server/root_password_again password $MYSQL_PASSWORD
mysql-server-5.1 mysql-server/start_on_boot boolean true
MYSQL_PRESEED

    # while ``.my.cnf`` is not needed for openstack to function, it is useful
    # as it allows you to access the mysql databases via ``mysql nova`` instead
    # of having to specify the username/password each time.
    if [[ ! -e $HOME/.my.cnf ]]; then
        cat <<EOF >$HOME/.my.cnf
[client]
user=$MYSQL_USER
password=$MYSQL_PASSWORD
host=$MYSQL_HOST
EOF
        chmod 0600 $HOME/.my.cnf
    fi

    # Install and start mysql-server
    apt_get install mysql-server
    # Update the DB to give user ‘$MYSQL_USER’@’%’ full control of the all databases:
    sudo mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'%' identified by '$MYSQL_PASSWORD';"

    # Edit /etc/mysql/my.cnf to change ‘bind-address’ from localhost (127.0.0.1) to any (0.0.0.0) and restart the mysql service:
    sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
    sudo service mysql restart
fi


# Horizon
# ---------

# Setup the django horizon application to serve via apache/wsgi

if [[ "$ENABLED_SERVICES" =~ "horizon" ]]; then

    # Install apache2, which is NOPRIME'd
    apt_get install apache2 libapache2-mod-wsgi

    # Horizon currently imports quantum even if you aren't using it.  Instead
    # of installing quantum we can create a simple module that will pass the
    # initial imports
    mkdir -p  $HORIZON_DIR/openstack-dashboard/quantum || true
    touch $HORIZON_DIR/openstack-dashboard/quantum/__init__.py
    touch $HORIZON_DIR/openstack-dashboard/quantum/client.py


    # ``local_settings.py`` is used to override horizon default settings.
    local_settings=$HORIZON_DIR/openstack-dashboard/local/local_settings.py
    cp $FILES/horizon_settings.py $local_settings

    # Enable quantum in dashboard, if requested
    if [[ "$ENABLED_SERVICES" =~ "quantum" ]]; then
        sudo sed -e "s,QUANTUM_ENABLED = False,QUANTUM_ENABLED = True,g" -i $local_settings
    fi

    # Initialize the horizon database (it stores sessions and notices shown to
    # users).  The user system is external (keystone).
    cd $HORIZON_DIR/openstack-dashboard
    dashboard/manage.py syncdb

    # create an empty directory that apache uses as docroot
    sudo mkdir -p $HORIZON_DIR/.blackhole

    ## Configure apache's 000-default to run horizon
    sudo cp $FILES/000-default.template /etc/apache2/sites-enabled/000-default
    sudo sed -e "s,%USER%,$USER,g" -i /etc/apache2/sites-enabled/000-default
    sudo sed -e "s,%HORIZON_DIR%,$HORIZON_DIR,g" -i /etc/apache2/sites-enabled/000-default
    sudo service apache2 restart
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
    mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'DROP DATABASE IF EXISTS glance;'
    mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'CREATE DATABASE glance;'

    # Copy over our glance configurations and update them
    GLANCE_CONF=$GLANCE_DIR/etc/glance-registry.conf
    cp $FILES/glance-registry.conf $GLANCE_CONF
    sudo sed -e "s,%SQL_CONN%,$BASE_SQL_CONN/glance,g" -i $GLANCE_CONF
    sudo sed -e "s,%SERVICE_TOKEN%,$SERVICE_TOKEN,g" -i $GLANCE_CONF
    sudo sed -e "s,%DEST%,$DEST,g" -i $GLANCE_CONF
    sudo sed -e "s,%SYSLOG%,$SYSLOG,g" -i $GLANCE_CONF

    GLANCE_API_CONF=$GLANCE_DIR/etc/glance-api.conf
    cp $FILES/glance-api.conf $GLANCE_API_CONF
    sudo sed -e "s,%DEST%,$DEST,g" -i $GLANCE_API_CONF
    sudo sed -e "s,%SERVICE_TOKEN%,$SERVICE_TOKEN,g" -i $GLANCE_API_CONF
    sudo sed -e "s,%SYSLOG%,$SYSLOG,g" -i $GLANCE_API_CONF
fi

# Nova
# ----

if [[ "$ENABLED_SERVICES" =~ "n-api" ]]; then
    # We are going to use a sample http middleware configuration based on the
    # one from the keystone project to launch nova.  This paste config adds
    # the configuration required for nova to validate keystone tokens. We add
    # our own service token to the configuration.
    cp $FILES/nova-api-paste.ini $NOVA_DIR/bin
    sed -e "s,%SERVICE_TOKEN%,$SERVICE_TOKEN,g" -i $NOVA_DIR/bin/nova-api-paste.ini
fi

if [[ "$ENABLED_SERVICES" =~ "n-cpu" ]]; then

    # Virtualization Configuration
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    apt_get install libvirt-bin

    # attempt to load modules: network block device - used to manage qcow images
    sudo modprobe nbd || true

    # Check for kvm (hardware based virtualization).  If unable to initialize
    # kvm, we drop back to the slower emulation mode (qemu).  Note: many systems
    # come with hardware virtualization disabled in BIOS.
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
        if [[ "$DISTRO" > natty ]]; then
            apt_get install cgroup-lite
        else
            cgline="none /cgroup cgroup cpuacct,memory,devices,cpu,freezer,blkio 0 0"
            sudo mkdir -p /cgroup
            if ! grep -q cgroup /etc/fstab; then
                echo "$cgline" | sudo tee -a /etc/fstab
            fi
            if ! mount -n | grep -q cgroup; then
                sudo mount /cgroup
            fi
        fi
    fi

    # The user that nova runs as needs to be member of libvirtd group otherwise
    # nova-compute will be unable to use libvirt.
    sudo usermod -a -G libvirtd `whoami`
    # libvirt detects various settings on startup, as we potentially changed
    # the system configuration (modules, filesystems), we need to restart
    # libvirt to detect those changes.
    sudo /etc/init.d/libvirt-bin restart


    # Instance Storage
    # ~~~~~~~~~~~~~~~~

    # Nova stores each instance in its own directory.
    mkdir -p $NOVA_DIR/instances

    # You can specify a different disk to be mounted and used for backing the
    # virtual machines.  If there is a partition labeled nova-instances we
    # mount it (ext filesystems can be labeled via e2label).
    if [ -L /dev/disk/by-label/nova-instances ]; then
        if ! mount -n | grep -q $NOVA_DIR/instances; then
            sudo mount -L nova-instances $NOVA_DIR/instances
            sudo chown -R `whoami` $NOVA_DIR/instances
        fi
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

# Storage Service
if [[ "$ENABLED_SERVICES" =~ "swift" ]]; then
    # We first do a bit of setup by creating the directories and
    # changing the permissions so we can run it as our user.

    USER_GROUP=$(id -g)
    sudo mkdir -p ${SWIFT_DATA_LOCATION}/drives
    sudo chown -R $USER:${USER_GROUP} ${SWIFT_DATA_LOCATION}/drives

    # We then create a loopback disk and format it to XFS.
    if [[ ! -e ${SWIFT_DATA_LOCATION}/drives/images/swift.img ]]; then
        mkdir -p  ${SWIFT_DATA_LOCATION}/drives/images
        sudo touch  ${SWIFT_DATA_LOCATION}/drives/images/swift.img
        sudo chown $USER: ${SWIFT_DATA_LOCATION}/drives/images/swift.img

        dd if=/dev/zero of=${SWIFT_DATA_LOCATION}/drives/images/swift.img \
            bs=1024 count=0 seek=${SWIFT_LOOPBACK_DISK_SIZE}
        mkfs.xfs -f -i size=1024  ${SWIFT_DATA_LOCATION}/drives/images/swift.img
    fi

    # After the drive being created we mount the disk with a few mount
    # options to make it most efficient as possible for swift.
    mkdir -p ${SWIFT_DATA_LOCATION}/drives/sdb1
    if ! egrep -q ${SWIFT_DATA_LOCATION}/drives/sdb1 /proc/mounts; then
        sudo mount -t xfs -o loop,noatime,nodiratime,nobarrier,logbufs=8  \
            ${SWIFT_DATA_LOCATION}/drives/images/swift.img ${SWIFT_DATA_LOCATION}/drives/sdb1
    fi

    # We then create link to that mounted location so swift would know
    # where to go.
    for x in {1..4}; do sudo ln -sf ${SWIFT_DATA_LOCATION}/drives/sdb1/$x ${SWIFT_DATA_LOCATION}/$x; done

    # We now have to emulate a few different servers into one we
    # create all the directories needed for swift
    tmpd=""
    for d in ${SWIFT_DATA_LOCATION}/drives/sdb1/{1..4} \
        ${SWIFT_CONFIG_LOCATION}/{object,container,account}-server \
        ${SWIFT_DATA_LOCATION}/{1..4}/node/sdb1 /var/run/swift; do
        [[ -d $d ]] && continue
        sudo install -o ${USER} -g $USER_GROUP -d $d
    done

   # We do want to make sure this is all owned by our user.
   sudo chown -R $USER: ${SWIFT_DATA_LOCATION}/{1..4}/node
   sudo chown -R $USER: ${SWIFT_CONFIG_LOCATION}

   # swift-init has a bug using /etc/swift until bug #885595 is fixed
   # we have to create a link
   sudo ln -sf ${SWIFT_CONFIG_LOCATION} /etc/swift

   # Swift use rsync to syncronize between all the different
   # partitions (which make more sense when you have a multi-node
   # setup) we configure it with our version of rsync.
   sed -e "s/%GROUP%/${USER_GROUP}/;s/%USER%/$USER/;s,%SWIFT_DATA_LOCATION%,$SWIFT_DATA_LOCATION," $FILES/swift/rsyncd.conf | sudo tee /etc/rsyncd.conf
   sudo sed -i '/^RSYNC_ENABLE=false/ { s/false/true/ }' /etc/default/rsync

   # By default Swift will be installed with the tempauth middleware
   # which has some default username and password if you have
   # configured keystone it will checkout the directory.
   if [[ "$ENABLED_SERVICES" =~ "key" ]]; then
       swift_auth_server=keystone

       # We install the memcache server as this is will be used by the
       # middleware to cache the tokens auths for a long this is needed.
       apt_get install memcached

       # We need a special version of bin/swift which understand the
       # OpenStack api 2.0, we download it until this is getting
       # integrated in swift.
       sudo curl -s -o/usr/local/bin/swift \
           'https://review.openstack.org/gitweb?p=openstack/swift.git;a=blob_plain;f=bin/swift;hb=48bfda6e2fdf3886c98bd15649887d54b9a2574e'
   else
       swift_auth_server=tempauth
   fi

   # We do the install of the proxy-server and swift configuration
   # replacing a few directives to match our configuration.
   sed "s,%SWIFT_CONFIG_LOCATION%,${SWIFT_CONFIG_LOCATION},;s/%USER%/$USER/;s/%SERVICE_TOKEN%/${SERVICE_TOKEN}/;s/%AUTH_SERVER%/${swift_auth_server}/" \
       $FILES/swift/proxy-server.conf|sudo tee  ${SWIFT_CONFIG_LOCATION}/proxy-server.conf

   sed -e "s/%SWIFT_HASH%/$SWIFT_HASH/" $FILES/swift/swift.conf > ${SWIFT_CONFIG_LOCATION}/swift.conf

   # We need to generate a object/account/proxy configuration
   # emulating 4 nodes on different ports we have a little function
   # that help us doing that.
   function generate_swift_configuration() {
       local server_type=$1
       local bind_port=$2
       local log_facility=$3
       local node_number

       for node_number in {1..4}; do
           node_path=${SWIFT_DATA_LOCATION}/${node_number}
           sed -e "s,%SWIFT_CONFIG_LOCATION%,${SWIFT_CONFIG_LOCATION},;s,%USER%,$USER,;s,%NODE_PATH%,${node_path},;s,%BIND_PORT%,${bind_port},;s,%LOG_FACILITY%,${log_facility}," \
               $FILES/swift/${server_type}-server.conf > ${SWIFT_CONFIG_LOCATION}/${server_type}-server/${node_number}.conf
           bind_port=$(( ${bind_port} + 10 ))
           log_facility=$(( ${log_facility} + 1 ))
       done
   }
   generate_swift_configuration object 6010 2
   generate_swift_configuration container 6011 2
   generate_swift_configuration account 6012 2

   # We create two helper scripts :
   #
   # - swift-remakerings
   #   Allow to recreate rings from scratch.
   # - swift-startmain
   #   Restart your full cluster.
   #
   sed -e "s,%SWIFT_CONFIG_LOCATION%,${SWIFT_CONFIG_LOCATION},;s/%SWIFT_PARTITION_POWER_SIZE%/$SWIFT_PARTITION_POWER_SIZE/" $FILES/swift/swift-remakerings | \
       sudo tee /usr/local/bin/swift-remakerings
   sudo install -m755 $FILES/swift/swift-startmain /usr/local/bin/
   sudo chmod +x /usr/local/bin/swift-*

   # We then can start rsync.
   sudo /etc/init.d/rsync restart || :

   # Create our ring for the object/container/account.
   /usr/local/bin/swift-remakerings

   # And now we launch swift-startmain to get our cluster running
   # ready to be tested.
   /usr/local/bin/swift-startmain || :

   unset s swift_hash swift_auth_server tmpd
fi

# Volume Service
# --------------

if [[ "$ENABLED_SERVICES" =~ "n-vol" ]]; then
    #
    # Configure a default volume group called 'nova-volumes' for the nova-volume
    # service if it does not yet exist.  If you don't wish to use a file backed
    # volume group, create your own volume group called 'nova-volumes' before
    # invoking stack.sh.
    #
    # By default, the backing file is 2G in size, and is stored in /opt/stack.

    apt_get install iscsitarget-dkms iscsitarget

    if ! sudo vgdisplay | grep -q $VOLUME_GROUP; then
        VOLUME_BACKING_FILE=${VOLUME_BACKING_FILE:-$DEST/nova-volumes-backing-file}
        VOLUME_BACKING_FILE_SIZE=${VOLUME_BACKING_FILE_SIZE:-2052M}
        truncate -s $VOLUME_BACKING_FILE_SIZE $VOLUME_BACKING_FILE
        DEV=`sudo losetup -f --show $VOLUME_BACKING_FILE`
        sudo vgcreate $VOLUME_GROUP $DEV
    fi

    # Configure iscsitarget
    sudo sed 's/ISCSITARGET_ENABLE=false/ISCSITARGET_ENABLE=true/' -i /etc/default/iscsitarget
    sudo /etc/init.d/iscsitarget restart
fi

function add_nova_flag {
    echo "$1" >> $NOVA_DIR/bin/nova.conf
}

# (re)create nova.conf
rm -f $NOVA_DIR/bin/nova.conf
add_nova_flag "--verbose"
add_nova_flag "--allow_admin_api"
add_nova_flag "--scheduler_driver=$SCHEDULER"
add_nova_flag "--dhcpbridge_flagfile=$NOVA_DIR/bin/nova.conf"
add_nova_flag "--fixed_range=$FIXED_RANGE"
if [[ "$ENABLED_SERVICES" =~ "q-svc" ]]; then
    add_nova_flag "--network_manager=nova.network.quantum.manager.QuantumManager"
    if [[ "$Q_PLUGIN" = "openvswitch" ]]; then
        add_nova_flag "--libvirt_vif_type=ethernet"
        add_nova_flag "--libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtOpenVswitchDriver"
        add_nova_flag "--linuxnet_interface_driver=nova.network.linux_net.LinuxOVSInterfaceDriver"
        add_nova_flag "--quantum-use-dhcp"
    fi
else
    add_nova_flag "--network_manager=nova.network.manager.$NET_MAN"
fi
if [[ "$ENABLED_SERVICES" =~ "n-vol" ]]; then
    add_nova_flag "--volume_group=$VOLUME_GROUP"
fi
add_nova_flag "--my_ip=$HOST_IP"
add_nova_flag "--public_interface=$PUBLIC_INTERFACE"
add_nova_flag "--vlan_interface=$VLAN_INTERFACE"
add_nova_flag "--sql_connection=$BASE_SQL_CONN/nova"
add_nova_flag "--libvirt_type=$LIBVIRT_TYPE"
if [[ "$ENABLED_SERVICES" =~ "openstackx" ]]; then
    add_nova_flag "--osapi_extension=nova.api.openstack.v2.contrib.standard_extensions"
    add_nova_flag "--osapi_extension=extensions.admin.Admin"
fi
if [[ "$ENABLED_SERVICES" =~ "n-vnc" ]]; then
    VNCPROXY_URL=${VNCPROXY_URL:-"http://$HOST_IP:6080"}
    add_nova_flag "--vncproxy_url=$VNCPROXY_URL"
    add_nova_flag "--vncproxy_wwwroot=$NOVNC_DIR/"
fi
add_nova_flag "--api_paste_config=$NOVA_DIR/bin/nova-api-paste.ini"
add_nova_flag "--image_service=nova.image.glance.GlanceImageService"
add_nova_flag "--ec2_dmz_host=$EC2_DMZ_HOST"
add_nova_flag "--rabbit_host=$RABBIT_HOST"
add_nova_flag "--rabbit_password=$RABBIT_PASSWORD"
add_nova_flag "--glance_api_servers=$GLANCE_HOSTPORT"
add_nova_flag "--force_dhcp_release"
if [ -n "$INSTANCES_PATH" ]; then
    add_nova_flag "--instances_path=$INSTANCES_PATH"
fi
if [ "$MULTI_HOST" != "False" ]; then
    add_nova_flag "--multi_host"
    add_nova_flag "--send_arp_for_ha"
fi
if [ "$SYSLOG" != "False" ]; then
    add_nova_flag "--use_syslog"
fi

# You can define extra nova conf flags by defining the array EXTRA_FLAGS,
# For Example: EXTRA_FLAGS=(--foo --bar=2)
for I in "${EXTRA_FLAGS[@]}"; do
    add_nova_flag $I
done

# XenServer
# ---------

if [ "$VIRT_DRIVER" = 'xenserver' ]; then
    read_password XENAPI_PASSWORD "ENTER A PASSWORD TO USE FOR XEN."
    add_nova_flag "--connection_type=xenapi"
    add_nova_flag "--xenapi_connection_url=http://169.254.0.1"
    add_nova_flag "--xenapi_connection_username=root"
    add_nova_flag "--xenapi_connection_password=$XENAPI_PASSWORD"
    add_nova_flag "--flat_injected=False"
    add_nova_flag "--flat_interface=eth1"
    add_nova_flag "--flat_network_bridge=xenbr1"
    add_nova_flag "--public_interface=eth3"
else
    add_nova_flag "--flat_network_bridge=$FLAT_NETWORK_BRIDGE"
    if [ -n "$FLAT_INTERFACE" ]; then
        add_nova_flag "--flat_interface=$FLAT_INTERFACE"
    fi
fi

# Nova Database
# ~~~~~~~~~~~~~

# All nova components talk to a central database.  We will need to do this step
# only once for an entire cluster.

if [[ "$ENABLED_SERVICES" =~ "mysql" ]]; then
    # (re)create nova database
    mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'DROP DATABASE IF EXISTS nova;'
    mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'CREATE DATABASE nova;'

    # (re)create nova database
    $NOVA_DIR/bin/nova-manage db sync
fi


# Keystone
# --------

if [[ "$ENABLED_SERVICES" =~ "key" ]]; then
    # (re)create keystone database
    mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'DROP DATABASE IF EXISTS keystone;'
    mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'CREATE DATABASE keystone;'

    # Configure keystone.conf
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
    ENABLED_SERVICES=$ENABLED_SERVICES BIN_DIR=$KEYSTONE_DIR/bin bash $KEYSTONE_DATA
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
        if [[ "$USE_TMUX" =~ "yes" ]]; then
            tmux new-window -t stack -a -n "$1" "bash"
            tmux send-keys "$2" C-M
        else
            screen -S stack -X screen -t $1
            # sleep to allow bash to be ready to be send the command - we are
            # creating a new window in screen and then sends characters, so if
            # bash isn't running by the time we send the command, nothing happens
            sleep 1
            screen -S stack -p $1 -X stuff "$2$NL"
        fi
    fi
}

# create a new named screen to run processes in
screen -d -m -S stack -t stack
sleep 1

# launch the glance registry service
if [[ "$ENABLED_SERVICES" =~ "g-reg" ]]; then
    screen_it g-reg "cd $GLANCE_DIR; bin/glance-registry --config-file=etc/glance-registry.conf"
fi

# launch the glance api and wait for it to answer before continuing
if [[ "$ENABLED_SERVICES" =~ "g-api" ]]; then
    screen_it g-api "cd $GLANCE_DIR; bin/glance-api --config-file=etc/glance-api.conf"
    echo "Waiting for g-api ($GLANCE_HOSTPORT) to start..."
    if ! timeout $SERVICE_TIMEOUT sh -c "while ! wget -q -O- http://$GLANCE_HOSTPORT; do sleep 1; done"; then
      echo "g-api did not start"
      exit 1
    fi
fi

# launch the keystone and wait for it to answer before continuing
if [[ "$ENABLED_SERVICES" =~ "key" ]]; then
    screen_it key "cd $KEYSTONE_DIR && $KEYSTONE_DIR/bin/keystone --config-file $KEYSTONE_CONF -d"
    echo "Waiting for keystone to start..."
    if ! timeout $SERVICE_TIMEOUT sh -c "while ! wget -q -O- http://127.0.0.1:5000; do sleep 1; done"; then
      echo "keystone did not start"
      exit 1
    fi
fi

# launch the nova-api and wait for it to answer before continuing
if [[ "$ENABLED_SERVICES" =~ "n-api" ]]; then
    screen_it n-api "cd $NOVA_DIR && $NOVA_DIR/bin/nova-api"
    echo "Waiting for nova-api to start..."
    if ! timeout $SERVICE_TIMEOUT sh -c "while ! wget -q -O- http://127.0.0.1:8774; do sleep 1; done"; then
      echo "nova-api did not start"
      exit 1
    fi
fi

# Quantum
if [[ "$ENABLED_SERVICES" =~ "q-svc" ]]; then
    # Install deps
    # FIXME add to files/apts/quantum, but don't install if not needed!
    apt_get install openvswitch-switch openvswitch-datapath-dkms

    # Create database for the plugin/agent
    if [[ "$Q_PLUGIN" = "openvswitch" ]]; then
        if [[ "$ENABLED_SERVICES" =~ "mysql" ]]; then
            mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'CREATE DATABASE IF NOT EXISTS ovs_quantum;'
        else
            echo "mysql must be enabled in order to use the $Q_PLUGIN Quantum plugin."
            exit 1
        fi
    fi

    QUANTUM_PLUGIN_INI_FILE=$QUANTUM_DIR/etc/plugins.ini
    # Make sure we're using the openvswitch plugin
    sed -i -e "s/^provider =.*$/provider = quantum.plugins.openvswitch.ovs_quantum_plugin.OVSQuantumPlugin/g" $QUANTUM_PLUGIN_INI_FILE
    screen_it q-svc "cd $QUANTUM_DIR && PYTHONPATH=.:$PYTHONPATH python $QUANTUM_DIR/bin/quantum-server $QUANTUM_DIR/etc/quantum.conf"
fi

# Quantum agent (for compute nodes)
if [[ "$ENABLED_SERVICES" =~ "q-agt" ]]; then
    if [[ "$Q_PLUGIN" = "openvswitch" ]]; then
        # Set up integration bridge
        OVS_BRIDGE=${OVS_BRIDGE:-br-int}
        sudo ovs-vsctl --no-wait -- --if-exists del-br $OVS_BRIDGE
        sudo ovs-vsctl --no-wait add-br $OVS_BRIDGE
        sudo ovs-vsctl --no-wait br-set-external-id $OVS_BRIDGE bridge-id br-int
    fi

    # Start up the quantum <-> openvswitch agent
    screen_it q-agt "sleep 4; sudo python $QUANTUM_DIR/quantum/plugins/openvswitch/agent/ovs_quantum_agent.py $QUANTUM_DIR/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini -v"
fi

# If we're using Quantum (i.e. q-svc is enabled), network creation has to
# happen after we've started the Quantum service.
if [[ "$ENABLED_SERVICES" =~ "mysql" ]]; then
    # create a small network
    $NOVA_DIR/bin/nova-manage network create private $FIXED_RANGE 1 $FIXED_NETWORK_SIZE

    if [[ "$ENABLED_SERVICES" =~ "q-svc" ]]; then
        echo "Not creating floating IPs (not supported by QuantumManager)"
    else
        # create some floating ips
        $NOVA_DIR/bin/nova-manage floating create $FLOATING_RANGE
    fi
fi

# Launching nova-compute should be as simple as running ``nova-compute`` but
# have to do a little more than that in our script.  Since we add the group
# ``libvirtd`` to our user in this script, when nova-compute is run it is
# within the context of our original shell (so our groups won't be updated).
# Use 'sg' to execute nova-compute as a member of the libvirtd group.
screen_it n-cpu "cd $NOVA_DIR && sg libvirtd $NOVA_DIR/bin/nova-compute"
screen_it n-vol "cd $NOVA_DIR && $NOVA_DIR/bin/nova-volume"
screen_it n-net "cd $NOVA_DIR && $NOVA_DIR/bin/nova-network"
screen_it n-sch "cd $NOVA_DIR && $NOVA_DIR/bin/nova-scheduler"
if [[ "$ENABLED_SERVICES" =~ "n-vnc" ]]; then
    screen_it n-vnc "cd $NOVNC_DIR && ./utils/nova-wsproxy.py --flagfile $NOVA_DIR/bin/nova.conf --web . 6080"
fi
if [[ "$ENABLED_SERVICES" =~ "horizon" ]]; then
    screen_it horizon "cd $HORIZON_DIR && sudo tail -f /var/log/apache2/error.log"
fi

# Install Images
# ==============

# Upload an image to glance.
#
# The default image is a small ***TTY*** testing image, which lets you login
# the username/password of root/password.
#
# TTY also uses cloud-init, supporting login via keypair and sending scripts as
# userdata.  See https://help.ubuntu.com/community/CloudInit for more on cloud-init
#
# Override ``IMAGE_URLS`` with a comma-separated list of uec images.
#
#  * **natty**: http://uec-images.ubuntu.com/natty/current/natty-server-cloudimg-amd64.tar.gz
#  * **oneiric**: http://uec-images.ubuntu.com/oneiric/current/oneiric-server-cloudimg-amd64.tar.gz

if [[ "$ENABLED_SERVICES" =~ "g-reg" ]]; then
    # Create a directory for the downloaded image tarballs.
    mkdir -p $FILES/images

    # Option to upload legacy ami-tty, which works with xenserver
    if [ $UPLOAD_LEGACY_TTY ]; then
        if [ ! -f $FILES/tty.tgz ]; then
            wget -c http://images.ansolabs.com/tty.tgz -O $FILES/tty.tgz
        fi

        tar -zxf $FILES/tty.tgz -C $FILES/images
        RVAL=`glance add -A $SERVICE_TOKEN name="tty-kernel" is_public=true container_format=aki disk_format=aki < $FILES/images/aki-tty/image`
        KERNEL_ID=`echo $RVAL | cut -d":" -f2 | tr -d " "`
        RVAL=`glance add -A $SERVICE_TOKEN name="tty-ramdisk" is_public=true container_format=ari disk_format=ari < $FILES/images/ari-tty/image`
        RAMDISK_ID=`echo $RVAL | cut -d":" -f2 | tr -d " "`
        glance add -A $SERVICE_TOKEN name="tty" is_public=true container_format=ami disk_format=ami kernel_id=$KERNEL_ID ramdisk_id=$RAMDISK_ID < $FILES/images/ami-tty/image
    fi

    for image_url in ${IMAGE_URLS//,/ }; do
        # Downloads the image (uec ami+aki style), then extracts it.
        IMAGE_FNAME=`basename "$image_url"`
        if [ ! -f $FILES/$IMAGE_FNAME ]; then
            wget -c $image_url -O $FILES/$IMAGE_FNAME
        fi

        KERNEL=""
        RAMDISK=""
        case "$IMAGE_FNAME" in
            *.tar.gz|*.tgz)
                # Extract ami and aki files
                [ "${IMAGE_FNAME%.tar.gz}" != "$IMAGE_FNAME" ] &&
                    IMAGE_NAME="${IMAGE_FNAME%.tar.gz}" ||
                    IMAGE_NAME="${IMAGE_FNAME%.tgz}"
                xdir="$FILES/images/$IMAGE_NAME"
                rm -Rf "$xdir";
                mkdir "$xdir"
                tar -zxf $FILES/$IMAGE_FNAME -C "$xdir"
                KERNEL=$(for f in "$xdir/"*-vmlinuz*; do
                         [ -f "$f" ] && echo "$f" && break; done; true)
                RAMDISK=$(for f in "$xdir/"*-initrd*; do
                         [ -f "$f" ] && echo "$f" && break; done; true)
                IMAGE=$(for f in "$xdir/"*.img; do
                         [ -f "$f" ] && echo "$f" && break; done; true)
                [ -n "$IMAGE_NAME" ]
                IMAGE_NAME=$(basename "$IMAGE" ".img")
                ;;
            *.img)
                IMAGE="$FILES/$IMAGE_FNAME";
                IMAGE_NAME=$(basename "$IMAGE" ".img")
                ;;
            *.img.gz)
                IMAGE="$FILES/${IMAGE_FNAME}"
                IMAGE_NAME=$(basename "$IMAGE" ".img.gz")
                ;;
            *) echo "Do not know what to do with $IMAGE_FNAME"; false;;
        esac

        # Use glance client to add the kernel the root filesystem.
        # We parse the results of the first upload to get the glance ID of the
        # kernel for use when uploading the root filesystem.
        KERNEL_ID=""; RAMDISK_ID="";
        if [ -n "$KERNEL" ]; then
            RVAL=`glance add -A $SERVICE_TOKEN name="$IMAGE_NAME-kernel" is_public=true container_format=aki disk_format=aki < "$KERNEL"`
            KERNEL_ID=`echo $RVAL | cut -d":" -f2 | tr -d " "`
        fi
        if [ -n "$RAMDISK" ]; then
            RVAL=`glance add -A $SERVICE_TOKEN name="$IMAGE_NAME-ramdisk" is_public=true container_format=ari disk_format=ari < "$RAMDISK"`
            RAMDISK_ID=`echo $RVAL | cut -d":" -f2 | tr -d " "`
        fi
        glance add -A $SERVICE_TOKEN name="${IMAGE_NAME%.img}" is_public=true container_format=ami disk_format=ami ${KERNEL_ID:+kernel_id=$KERNEL_ID} ${RAMDISK_ID:+ramdisk_id=$RAMDISK_ID} < <(zcat --force "${IMAGE}")
    done
fi

# Fin
# ===


) 2>&1 | tee "${LOGFILE}"

# Check that the left side of the above pipe succeeded
for ret in "${PIPESTATUS[@]}"; do [ $ret -eq 0 ] || exit $ret; done

(
# Using the cloud
# ===============

echo ""
echo ""
echo ""

# If you installed the horizon on this server, then you should be able
# to access the site using your browser.
if [[ "$ENABLED_SERVICES" =~ "horizon" ]]; then
    echo "horizon is now available at http://$HOST_IP/"
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
