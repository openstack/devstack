# zaqar.sh - Devstack extras script to install Zaqar

if is_service_enabled zaqar-server; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/zaqar
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Zaqar"
        install_zaqarclient
        install_zaqar
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring Zaqar"
        configure_zaqar
        configure_zaqarclient

        if is_service_enabled key; then
            create_zaqar_accounts
        fi

    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing Zaqar"
        init_zaqar
        start_zaqar
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_zaqar
    fi
fi
