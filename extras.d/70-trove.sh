# trove.sh - Devstack extras script to install Trove

if is_service_enabled trove; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/trove
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Trove"
        install_trove
        install_troveclient
        cleanup_trove
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring Trove"
        configure_troveclient
        configure_trove

        if is_service_enabled key; then
            create_trove_accounts
        fi

    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        # Initialize trove
        init_trove

        # Start the trove API and trove taskmgr components
        echo_summary "Starting Trove"
        start_trove
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_trove
    fi
fi
