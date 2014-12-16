# sahara.sh - DevStack extras script to install Sahara

if is_service_enabled sahara; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/sahara
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing sahara"
        install_sahara
        install_python_saharaclient
        cleanup_sahara
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring sahara"
        configure_sahara
        create_sahara_accounts
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing sahara"
        sahara_register_images
        start_sahara
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_sahara
    fi

    if [[ "$1" == "clean" ]]; then
        cleanup_sahara
    fi
fi
