#!/bin/bash
#
# Initial data for Keystone using python-keystoneclient
#
# Tenant               User      Roles
# ------------------------------------------------------------------
# admin                admin     admin
# service              glance    admin
# service              nova      admin, [ResellerAdmin (swift only)]
# service              quantum   admin        # if enabled
# service              swift     admin        # if enabled
# service              cinder    admin        # if enabled
# service              heat      admin        # if enabled
# demo                 admin     admin
# demo                 demo      Member, anotherrole
# invisible_to_admin   demo      Member
# Tempest Only:
# alt_demo             alt_demo  Member
#
# Variables set before calling this script:
# SERVICE_TOKEN - aka admin_token in keystone.conf
# SERVICE_ENDPOINT - local Keystone admin endpoint
# SERVICE_TENANT_NAME - name of tenant containing service accounts
# SERVICE_HOST - host used for endpoint creation
# ENABLED_SERVICES - stack.sh's list of services to start
# DEVSTACK_DIR - Top-level DevStack directory
# KEYSTONE_CATALOG_BACKEND - used to determine service catalog creation

# Defaults
# --------

ADMIN_PASSWORD=${ADMIN_PASSWORD:-secrete}
SERVICE_PASSWORD=${SERVICE_PASSWORD:-$ADMIN_PASSWORD}
export SERVICE_TOKEN=$SERVICE_TOKEN
export SERVICE_ENDPOINT=$SERVICE_ENDPOINT
SERVICE_TENANT_NAME=${SERVICE_TENANT_NAME:-service}

function get_id () {
    echo `"$@" | awk '/ id / { print $4 }'`
}


# Tenants
# -------

ADMIN_TENANT=$(get_id keystone tenant-create --name=admin)
SERVICE_TENANT=$(get_id keystone tenant-create --name=$SERVICE_TENANT_NAME)
DEMO_TENANT=$(get_id keystone tenant-create --name=demo)
INVIS_TENANT=$(get_id keystone tenant-create --name=invisible_to_admin)


# Users
# -----

ADMIN_USER=$(get_id keystone user-create --name=admin \
                                         --pass="$ADMIN_PASSWORD" \
                                         --email=admin@example.com)
DEMO_USER=$(get_id keystone user-create --name=demo \
                                        --pass="$ADMIN_PASSWORD" \
                                        --email=demo@example.com)


# Roles
# -----

ADMIN_ROLE=$(get_id keystone role-create --name=admin)
KEYSTONEADMIN_ROLE=$(get_id keystone role-create --name=KeystoneAdmin)
KEYSTONESERVICE_ROLE=$(get_id keystone role-create --name=KeystoneServiceAdmin)
# ANOTHER_ROLE demonstrates that an arbitrary role may be created and used
# TODO(sleepsonthefloor): show how this can be used for rbac in the future!
ANOTHER_ROLE=$(get_id keystone role-create --name=anotherrole)


# Add Roles to Users in Tenants
keystone user-role-add --user_id $ADMIN_USER --role_id $ADMIN_ROLE --tenant_id $ADMIN_TENANT
keystone user-role-add --user_id $ADMIN_USER --role_id $ADMIN_ROLE --tenant_id $DEMO_TENANT
keystone user-role-add --user_id $DEMO_USER --role_id $ANOTHER_ROLE --tenant_id $DEMO_TENANT

# TODO(termie): these two might be dubious
keystone user-role-add --user_id $ADMIN_USER --role_id $KEYSTONEADMIN_ROLE --tenant_id $ADMIN_TENANT
keystone user-role-add --user_id $ADMIN_USER --role_id $KEYSTONESERVICE_ROLE --tenant_id $ADMIN_TENANT


# The Member role is used by Horizon and Swift so we need to keep it:
MEMBER_ROLE=$(get_id keystone role-create --name=Member)
keystone user-role-add --user_id $DEMO_USER --role_id $MEMBER_ROLE --tenant_id $DEMO_TENANT
keystone user-role-add --user_id $DEMO_USER --role_id $MEMBER_ROLE --tenant_id $INVIS_TENANT


# Services
# --------

# Keystone
if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
	KEYSTONE_SERVICE=$(get_id keystone service-create \
		--name=keystone \
		--type=identity \
		--description="Keystone Identity Service")
	keystone endpoint-create \
	    --region RegionOne \
		--service_id $KEYSTONE_SERVICE \
		--publicurl "http://$SERVICE_HOST:\$(public_port)s/v2.0" \
		--adminurl "http://$SERVICE_HOST:\$(admin_port)s/v2.0" \
		--internalurl "http://$SERVICE_HOST:\$(admin_port)s/v2.0"
fi

# Nova
if [[ "$ENABLED_SERVICES" =~ "n-cpu" ]]; then
    NOVA_USER=$(get_id keystone user-create \
        --name=nova \
        --pass="$SERVICE_PASSWORD" \
        --tenant_id $SERVICE_TENANT \
        --email=nova@example.com)
    keystone user-role-add \
        --tenant_id $SERVICE_TENANT \
        --user_id $NOVA_USER \
        --role_id $ADMIN_ROLE
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        NOVA_SERVICE=$(get_id keystone service-create \
            --name=nova \
            --type=compute \
            --description="Nova Compute Service")
        keystone endpoint-create \
            --region RegionOne \
            --service_id $NOVA_SERVICE \
            --publicurl "http://$SERVICE_HOST:\$(compute_port)s/v1.1/\$(tenant_id)s" \
            --adminurl "http://$SERVICE_HOST:\$(compute_port)s/v1.1/\$(tenant_id)s" \
            --internalurl "http://$SERVICE_HOST:\$(compute_port)s/v1.1/\$(tenant_id)s"
    fi
    # Nova needs ResellerAdmin role to download images when accessing
    # swift through the s3 api. The admin role in swift allows a user
    # to act as an admin for their tenant, but ResellerAdmin is needed
    # for a user to act as any tenant. The name of this role is also
    # configurable in swift-proxy.conf
    RESELLER_ROLE=$(get_id keystone role-create --name=ResellerAdmin)
    keystone user-role-add \
        --tenant_id $SERVICE_TENANT \
        --user_id $NOVA_USER \
        --role_id $RESELLER_ROLE
fi

# Volume
if [[ "$ENABLED_SERVICES" =~ "n-vol" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        VOLUME_SERVICE=$(get_id keystone service-create \
            --name=volume \
            --type=volume \
            --description="Volume Service")
        keystone endpoint-create \
            --region RegionOne \
            --service_id $VOLUME_SERVICE \
            --publicurl "http://$SERVICE_HOST:8776/v1/\$(tenant_id)s" \
            --adminurl "http://$SERVICE_HOST:8776/v1/\$(tenant_id)s" \
            --internalurl "http://$SERVICE_HOST:8776/v1/\$(tenant_id)s"
    fi
fi

# Heat
if [[ "$ENABLED_SERVICES" =~ "heat" ]]; then
    HEAT_USER=$(get_id keystone user-create --name=heat \
                                              --pass="$SERVICE_PASSWORD" \
                                              --tenant_id $SERVICE_TENANT \
                                              --email=heat@example.com)
    keystone user-role-add --tenant_id $SERVICE_TENANT \
                           --user_id $HEAT_USER \
                           --role_id $ADMIN_ROLE
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        HEAT_SERVICE=$(get_id keystone service-create \
            --name=heat \
            --type=orchestration \
            --description="Heat Service")
        keystone endpoint-create \
            --region RegionOne \
            --service_id $HEAT_SERVICE \
            --publicurl "http://$SERVICE_HOST:$HEAT_API_PORT/v1" \
            --adminurl "http://$SERVICE_HOST:$HEAT_API_PORT/v1" \
            --internalurl "http://$SERVICE_HOST:$HEAT_API_PORT/v1"
    fi
fi

# Glance
if [[ "$ENABLED_SERVICES" =~ "g-api" ]]; then
    GLANCE_USER=$(get_id keystone user-create \
        --name=glance \
        --pass="$SERVICE_PASSWORD" \
        --tenant_id $SERVICE_TENANT \
        --email=glance@example.com)
    keystone user-role-add \
        --tenant_id $SERVICE_TENANT \
        --user_id $GLANCE_USER \
        --role_id $ADMIN_ROLE
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        GLANCE_SERVICE=$(get_id keystone service-create \
            --name=glance \
            --type=image \
            --description="Glance Image Service")
        keystone endpoint-create \
            --region RegionOne \
            --service_id $GLANCE_SERVICE \
            --publicurl "http://$SERVICE_HOST:9292/v1" \
            --adminurl "http://$SERVICE_HOST:9292/v1" \
            --internalurl "http://$SERVICE_HOST:9292/v1"
    fi
fi

# Swift
if [[ "$ENABLED_SERVICES" =~ "swift" ]]; then
    SWIFT_USER=$(get_id keystone user-create \
        --name=swift \
        --pass="$SERVICE_PASSWORD" \
        --tenant_id $SERVICE_TENANT \
        --email=swift@example.com)
    keystone user-role-add \
        --tenant_id $SERVICE_TENANT \
        --user_id $SWIFT_USER \
        --role_id $ADMIN_ROLE
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        SWIFT_SERVICE=$(get_id keystone service-create \
            --name=swift \
            --type="object-store" \
            --description="Swift Service")
        keystone endpoint-create \
            --region RegionOne \
            --service_id $SWIFT_SERVICE \
            --publicurl "http://$SERVICE_HOST:8080/v1/AUTH_\$(tenant_id)s" \
            --adminurl "http://$SERVICE_HOST:8080/v1" \
            --internalurl "http://$SERVICE_HOST:8080/v1/AUTH_\$(tenant_id)s"
    fi
fi

if [[ "$ENABLED_SERVICES" =~ "q-svc" ]]; then
    QUANTUM_USER=$(get_id keystone user-create \
        --name=quantum \
        --pass="$SERVICE_PASSWORD" \
        --tenant_id $SERVICE_TENANT \
        --email=quantum@example.com)
    keystone user-role-add \
        --tenant_id $SERVICE_TENANT \
        --user_id $QUANTUM_USER \
        --role_id $ADMIN_ROLE
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        QUANTUM_SERVICE=$(get_id keystone service-create \
            --name=quantum \
            --type=network \
            --description="Quantum Service")
        keystone endpoint-create \
            --region RegionOne \
            --service_id $QUANTUM_SERVICE \
            --publicurl "http://$SERVICE_HOST:9696/" \
            --adminurl "http://$SERVICE_HOST:9696/" \
            --internalurl "http://$SERVICE_HOST:9696/"
    fi
fi

# EC2
if [[ "$ENABLED_SERVICES" =~ "n-api" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        EC2_SERVICE=$(get_id keystone service-create \
            --name=ec2 \
            --type=ec2 \
            --description="EC2 Compatibility Layer")
        keystone endpoint-create \
            --region RegionOne \
            --service_id $EC2_SERVICE \
            --publicurl "http://$SERVICE_HOST:8773/services/Cloud" \
            --adminurl "http://$SERVICE_HOST:8773/services/Admin" \
            --internalurl "http://$SERVICE_HOST:8773/services/Cloud"
    fi
fi

# S3
if [[ "$ENABLED_SERVICES" =~ "n-obj" || "$ENABLED_SERVICES" =~ "swift" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        S3_SERVICE=$(get_id keystone service-create \
            --name=s3 \
            --type=s3 \
            --description="S3")
        keystone endpoint-create \
            --region RegionOne \
            --service_id $S3_SERVICE \
            --publicurl "http://$SERVICE_HOST:$S3_SERVICE_PORT" \
            --adminurl "http://$SERVICE_HOST:$S3_SERVICE_PORT" \
            --internalurl "http://$SERVICE_HOST:$S3_SERVICE_PORT"
    fi
fi

if [[ "$ENABLED_SERVICES" =~ "tempest" ]]; then
    # Tempest has some tests that validate various authorization checks
    # between two regular users in separate tenants
    ALT_DEMO_TENANT=$(get_id keystone tenant-create \
        --name=alt_demo)
    ALT_DEMO_USER=$(get_id keystone user-create \
        --name=alt_demo \
        --pass="$ADMIN_PASSWORD" \
        --email=alt_demo@example.com)
    keystone user-role-add \
        --tenant_id $ALT_DEMO_TENANT \
        --user_id $ALT_DEMO_USER \
        --role_id $MEMBER_ROLE
fi

if [[ "$ENABLED_SERVICES" =~ "c-api" ]]; then
    CINDER_USER=$(get_id keystone user-create --name=cinder \
                                              --pass="$SERVICE_PASSWORD" \
                                              --tenant_id $SERVICE_TENANT \
                                              --email=cinder@example.com)
    keystone user-role-add --tenant_id $SERVICE_TENANT \
                           --user_id $CINDER_USER \
                           --role_id $ADMIN_ROLE
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        CINDER_SERVICE=$(get_id keystone service-create \
            --name=cinder \
            --type=volume \
            --description="Cinder Service")
        keystone endpoint-create \
            --region RegionOne \
            --service_id $CINDER_SERVICE \
            --publicurl "http://$SERVICE_HOST:8776/v1/\$(tenant_id)s" \
            --adminurl "http://$SERVICE_HOST:8776/v1/\$(tenant_id)s" \
            --internalurl "http://$SERVICE_HOST:8776/v1/\$(tenant_id)s"
    fi
fi

