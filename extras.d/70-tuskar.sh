# Install and start the **Tuskar** service
#
# To enable, add the following to your localrc
#
# enable_service tuskar
# enable_service tuskar-api


if is_service_enabled tuskar; then
    if [[ "$1" == "source" ]]; then
        # Initial source, do nothing as functions sourced
        # are below rather than in lib/tuskar
        echo_summary "source extras tuskar"
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Tuskar"
        install_tuskarclient
        install_tuskar
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring Tuskar"
        configure_tuskar
        configure_tuskarclient

        if is_service_enabled key; then
            create_tuskar_accounts
        fi

    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing Tuskar"
        init_tuskar
        start_tuskar
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_tuskar
    fi
fi

# library code (equivalent to lib/tuskar)
# ---------
# - install_tuskarclient
# - install_tuskar
# - configure_tuskarclient
# - configure_tuskar
# - init_tuskar
# - start_tuskar
# - stop_tuskar
# - cleanup_tuskar

# Save trace setting
XTRACE=$(set +o | grep xtrace)
set +o xtrace


# Defaults
# --------

# tuskar repos
TUSKAR_REPO=${TUSKAR_REPO:-${GIT_BASE}/openstack/tuskar.git}
TUSKAR_BRANCH=${TUSKAR_BRANCH:-master}

TUSKARCLIENT_REPO=${TUSKARCLIENT_REPO:-${GIT_BASE}/openstack/python-tuskarclient.git}
TUSKARCLIENT_BRANCH=${TUSKARCLIENT_BRANCH:-master}

# set up default directories
TUSKAR_DIR=$DEST/tuskar
TUSKARCLIENT_DIR=$DEST/python-tuskarclient
TUSKAR_AUTH_CACHE_DIR=${TUSKAR_AUTH_CACHE_DIR:-/var/cache/tuskar}
TUSKAR_STANDALONE=$(trueorfalse False TUSKAR_STANDALONE)
TUSKAR_CONF_DIR=/etc/tuskar
TUSKAR_CONF=$TUSKAR_CONF_DIR/tuskar.conf
TUSKAR_API_HOST=${TUSKAR_API_HOST:-$HOST_IP}
TUSKAR_API_PORT=${TUSKAR_API_PORT:-8585}

# Tell Tempest this project is present
TEMPEST_SERVICES+=,tuskar

# Functions
# ---------

# Test if any Tuskar services are enabled
# is_tuskar_enabled
function is_tuskar_enabled {
    [[ ,${ENABLED_SERVICES} =~ ,"tuskar-" ]] && return 0
    return 1
}

# cleanup_tuskar() - Remove residual data files, anything left over from previous
# runs that a clean run would need to clean up
function cleanup_tuskar {
    sudo rm -rf $TUSKAR_AUTH_CACHE_DIR
}

# configure_tuskar() - Set config files, create data dirs, etc
function configure_tuskar {
    setup_develop $TUSKAR_DIR

    if [[ ! -d $TUSKAR_CONF_DIR ]]; then
        sudo mkdir -p $TUSKAR_CONF_DIR
    fi
    sudo chown $STACK_USER $TUSKAR_CONF_DIR
    # remove old config files
    rm -f $TUSKAR_CONF_DIR/tuskar-*.conf

    TUSKAR_POLICY_FILE=$TUSKAR_CONF_DIR/policy.json

    cp $TUSKAR_DIR/etc/tuskar/policy.json $TUSKAR_POLICY_FILE
    cp $TUSKAR_DIR/etc/tuskar/tuskar.conf.sample $TUSKAR_CONF

    # common options
    iniset $TUSKAR_CONF database connection `database_connection_url tuskar`

    # logging
    iniset $TUSKAR_CONF DEFAULT debug $ENABLE_DEBUG_LOG_LEVEL
    iniset $TUSKAR_CONF DEFAULT use_syslog $SYSLOG
    if [ "$LOG_COLOR" == "True" ] && [ "$SYSLOG" == "False" ]; then
        # Add color to logging output
        setup_colorized_logging $TUSKAR_CONF DEFAULT tenant user
    fi

    configure_auth_token_middleware $TUSKAR_CONF tuskar $TUSKAR_AUTH_CACHE_DIR

    if is_ssl_enabled_service "key"; then
        iniset $TUSKAR_CONF clients_keystone ca_file $SSL_BUNDLE_FILE
    fi

    iniset $TUSKAR_CONF tuskar_api bind_port $TUSKAR_API_PORT

}

# init_tuskar() - Initialize database
function init_tuskar {

    # (re)create tuskar database
    recreate_database tuskar

    tuskar-dbsync --config-file $TUSKAR_CONF
    create_tuskar_cache_dir
}

# create_tuskar_cache_dir() - Part of the init_tuskar() process
function create_tuskar_cache_dir {
    # Create cache dirs
    sudo mkdir -p $TUSKAR_AUTH_CACHE_DIR
    sudo chown $STACK_USER $TUSKAR_AUTH_CACHE_DIR
}

# install_tuskarclient() - Collect source and prepare
function install_tuskarclient {
    git_clone $TUSKARCLIENT_REPO $TUSKARCLIENT_DIR $TUSKARCLIENT_BRANCH
    setup_develop $TUSKARCLIENT_DIR
}

# configure_tuskarclient() - Set config files, create data dirs, etc
function configure_tuskarclient {
    setup_develop $TUSKARCLIENT_DIR
}

# install_tuskar() - Collect source and prepare
function install_tuskar {
    git_clone $TUSKAR_REPO $TUSKAR_DIR $TUSKAR_BRANCH
}

# start_tuskar() - Start running processes, including screen
function start_tuskar {
    run_process tuskar-api "tuskar-api --config-file=$TUSKAR_CONF"
}

# stop_tuskar() - Stop running processes
function stop_tuskar {
    # Kill the screen windows
    local serv
    for serv in tuskar-api; do
        stop_process $serv
    done
}

# create_tuskar_accounts() - Set up common required tuskar accounts
function create_tuskar_accounts {
    # migrated from files/keystone_data.sh
    local service_tenant=$(openstack project list | awk "/ $SERVICE_TENANT_NAME / { print \$2 }")
    local admin_role=$(openstack role list | awk "/ admin / { print \$2 }")

    local tuskar_user=$(get_or_create_user "tuskar" \
        "$SERVICE_PASSWORD" $service_tenant)
    get_or_add_user_role $admin_role $tuskar_user $service_tenant

    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then

        local tuskar_service=$(get_or_create_service "tuskar" \
                "management" "Tuskar Management Service")
        get_or_create_endpoint $tuskar_service \
            "$REGION_NAME" \
            "$SERVICE_PROTOCOL://$TUSKAR_API_HOST:$TUSKAR_API_PORT" \
            "$SERVICE_PROTOCOL://$TUSKAR_API_HOST:$TUSKAR_API_PORT" \
            "$SERVICE_PROTOCOL://$TUSKAR_API_HOST:$TUSKAR_API_PORT"
    fi
}

# Restore xtrace
$XTRACE

# Tell emacs to use shell-script-mode
## Local variables:
## mode: shell-script
## End:
