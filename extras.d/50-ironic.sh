# ironic.sh - Devstack extras script to install ironic

if is_service_enabled ir-api ir-cond; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/ironic
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Ironic"
        install_ironic
        install_ironicclient
        cleanup_ironic
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring Ironic"
        configure_ironic

        if is_service_enabled key; then
            create_ironic_accounts
        fi

    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        # Initialize ironic
        init_ironic

        # Start the ironic API and ironic taskmgr components
        echo_summary "Starting Ironic"
        start_ironic
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_ironic
        cleanup_ironic
    fi
fi
