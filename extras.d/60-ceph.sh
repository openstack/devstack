# ceph.sh - DevStack extras script to install Ceph

if is_service_enabled ceph; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/ceph
    elif [[ "$1" == "stack" && "$2" == "pre-install" ]]; then
        echo_summary "Installing Ceph"
        install_ceph
        echo_summary "Configuring Ceph"
        configure_ceph
        # NOTE (leseb): Do everything here because we need to have Ceph started before the main
        # OpenStack components. Ceph OSD must start here otherwise we can't upload any images.
        echo_summary "Initializing Ceph"
        init_ceph
        start_ceph
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
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_ceph
        cleanup_ceph
    fi

    if [[ "$1" == "clean" ]]; then
        cleanup_ceph
    fi
fi
