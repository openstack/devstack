# gantt.sh - Devstack extras script to install Gantt

if is_service_enabled n-sch; then
    disable_service gantt
fi

if is_service_enabled gantt; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/gantt
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing Gantt"
        install_gantt
        cleanup_gantt
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "Configuring Gantt"
        configure_gantt

    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        # Initialize gantt
        init_gantt

        # Start gantt
        echo_summary "Starting Gantt"
        start_gantt
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_gantt
    fi
fi
