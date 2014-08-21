# dib.sh - Devstack extras script to install diskimage-builder

if is_service_enabled dib; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/dib
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "Installing diskimage-builder"
        install_dib
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        # no-op
        :
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        # no-op
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
