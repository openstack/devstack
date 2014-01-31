# marconi.sh - Devstack extras script to install Marconi

if is_service_enabled marconi-server; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/marconi
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Marconi"
        install_marconiclient
        install_marconi
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring Marconi"
        configure_marconi
        configure_marconiclient

        if is_service_enabled key; then
            create_marconi_accounts
        fi

    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing Marconi"
        init_marconi
        start_marconi
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_marconi
    fi
fi
