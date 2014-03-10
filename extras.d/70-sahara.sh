# sahara.sh - DevStack extras script to install Sahara

if is_service_enabled sahara; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/sahara
        source $TOP_DIR/lib/sahara-dashboard
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing sahara"
        install_sahara
        cleanup_sahara
        if is_service_enabled horizon; then
            install_sahara_dashboard
        fi
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring sahara"
        configure_sahara
        create_sahara_accounts
        if is_service_enabled horizon; then
            configure_sahara_dashboard
        fi
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing sahara"
        start_sahara
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_sahara
        if is_service_enabled horizon; then
            cleanup_sahara_dashboard
        fi
    fi

    if [[ "$1" == "clean" ]]; then
        cleanup_sahara
    fi
fi
