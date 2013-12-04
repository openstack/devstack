# savanna.sh - DevStack extras script to install Savanna

if is_service_enabled savanna; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/savanna
        source $TOP_DIR/lib/savanna-dashboard
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Savanna"
        install_savanna
        if is_service_enabled horizon; then
            install_savanna_dashboard
        fi
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring Savanna"
        configure_savanna
        create_savanna_accounts
        if is_service_enabled horizon; then
            configure_savanna_dashboard
        fi
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing Savanna"
        start_savanna
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_savanna
        if is_service_enabled horizon; then
            cleanup_savanna_dashboard
        fi
    fi
fi
