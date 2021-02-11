# tempest.sh - DevStack extras script

if is_service_enabled tempest; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/tempest
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Tempest"
        async_runfunc install_tempest
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        # Tempest config must come after layer 2 services are running
        :
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        # Tempest config must come after all other plugins are run
        :
    elif [[ "$1" == "stack" && "$2" == "post-extra" ]]; then
        # local.conf Tempest option overrides
        :
    elif [[ "$1" == "stack" && "$2" == "test-config" ]]; then
        async_wait install_tempest
        echo_summary "Initializing Tempest"
        configure_tempest
        echo_summary "Installing Tempest Plugins"
        install_tempest_plugins
    fi

    if [[ "$1" == "unstack" ]]; then
        # no-op
        :
    fi

    if [[ "$1" == "clean" ]]; then
        # no-op
        :
    fi
fi
