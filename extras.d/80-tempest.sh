# tempest.sh - DevStack extras script

source $TOP_DIR/lib/tempest

if [[ "$1" == "stack" ]]; then
    # Configure Tempest last to ensure that the runtime configuration of
    # the various OpenStack services can be queried.
    if is_service_enabled tempest; then
        echo_summary "Configuring Tempest"
        install_tempest
        configure_tempest
        init_tempest
    fi
fi

if [[ "$1" == "unstack" ]]; then
    # no-op
    :
fi


