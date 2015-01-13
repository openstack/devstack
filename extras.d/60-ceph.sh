# ceph.sh - DevStack extras script to install Ceph

if is_service_enabled ceph; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/ceph
    elif [[ "$1" == "stack" && "$2" == "pre-install" ]]; then
        echo_summary "Installing Ceph"
        check_os_support_ceph
        if [ "$REMOTE_CEPH" = "False" ]; then
            install_ceph
            echo_summary "Configuring Ceph"
            configure_ceph
            # NOTE (leseb): Do everything here because we need to have Ceph started before the main
            # OpenStack components. Ceph OSD must start here otherwise we can't upload any images.
            echo_summary "Initializing Ceph"
            init_ceph
            start_ceph
        else
            install_ceph_remote
        fi
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        if is_service_enabled glance; then
            echo_summary "Configuring Glance for Ceph"
            configure_ceph_glance
        fi
        if is_service_enabled nova; then
            echo_summary "Configuring Nova for Ceph"
            configure_ceph_nova
        fi
        if is_service_enabled cinder; then
            echo_summary "Configuring Cinder for Ceph"
            configure_ceph_cinder
        fi
        if is_service_enabled cinder || is_service_enabled nova; then
            # NOTE (leseb): the part below is a requirement to attach Ceph block devices
            echo_summary "Configuring libvirt secret"
            import_libvirt_secret_ceph
        fi

        if [ "$REMOTE_CEPH" = "False" ]; then
            if is_service_enabled glance; then
                echo_summary "Configuring Glance for Ceph"
                configure_ceph_embedded_glance
            fi
            if is_service_enabled nova; then
                echo_summary "Configuring Nova for Ceph"
                configure_ceph_embedded_nova
            fi
            if is_service_enabled cinder; then
                echo_summary "Configuring Cinder for Ceph"
                configure_ceph_embedded_cinder
            fi
        fi
    fi

    if [[ "$1" == "unstack" ]]; then
        if [ "$REMOTE_CEPH" = "True" ]; then
            cleanup_ceph_remote
        else
            cleanup_ceph_embedded
            stop_ceph
        fi
        cleanup_ceph_general
    fi

    if [[ "$1" == "clean" ]]; then
        if [ "$REMOTE_CEPH" = "True" ]; then
            cleanup_ceph_remote
        else
            cleanup_ceph_embedded
        fi
        cleanup_ceph_general
    fi
fi
