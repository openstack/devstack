# tempest.sh - DevStack extras script

if is_service_enabled tempest; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/tempest
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Tempest"
        install_tempest
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        # Tempest config must come after layer 2 services are running
        :
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing Tempest"
        configure_tempest
        init_tempest
    elif [[ "$1" == "stack" && "$2" == "post-extra" ]]; then
        # local.conf Tempest option overrides
        :
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

