# opendaylight.sh - DevStack extras script

if is_service_enabled odl-server odl-compute; then
    # Initial source
    [[ "$1" == "source" ]] && source $TOP_DIR/lib/opendaylight
fi

if is_service_enabled odl-server; then
    if [[ "$1" == "source" ]]; then
        # no-op
        :
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        install_opendaylight
        configure_opendaylight
        init_opendaylight
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        configure_ml2_odl
        # This has to start before Neutron
        start_opendaylight
    elif [[ "$1" == "stack" && "$2" == "post-extra" ]]; then
        # no-op
        :
    fi

    if [[ "$1" == "unstack" ]]; then
        stop_opendaylight
        cleanup_opendaylight
    fi

    if [[ "$1" == "clean" ]]; then
        # no-op
        :
    fi
fi

if is_service_enabled odl-compute; then
    if [[ "$1" == "source" ]]; then
        # no-op
        :
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        install_opendaylight-compute
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        create_nova_conf_neutron
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing OpenDaylight"
        ODL_LOCAL_IP=${ODL_LOCAL_IP:-$HOST_IP}
        ODL_MGR_PORT=${ODL_MGR_PORT:-6640}
        read ovstbl <<< $(sudo ovs-vsctl get Open_vSwitch . _uuid)
        sudo ovs-vsctl set-manager tcp:$ODL_MGR_IP:$ODL_MGR_PORT
        if [[ -n "$OVS_BRIDGE_MAPPINGS" ]] && [[ "$ENABLE_TENANT_VLANS" == "True" ]]; then
            sudo ovs-vsctl set Open_vSwitch $ovstbl \
                other_config:bridge_mappings=$OVS_BRIDGE_MAPPINGS
        fi
        sudo ovs-vsctl set Open_vSwitch $ovstbl other_config:local_ip=$ODL_LOCAL_IP
    elif [[ "$1" == "stack" && "$2" == "post-extra" ]]; then
        # no-op
        :
    fi

    if [[ "$1" == "unstack" ]]; then
        sudo ovs-vsctl del-manager
        BRIDGES=$(sudo ovs-vsctl list-br)
        for bridge in $BRIDGES ; do
            sudo ovs-vsctl del-controller $bridge
        done

        stop_opendaylight-compute
    fi

    if [[ "$1" == "clean" ]]; then
        # no-op
        :
    fi
fi
