#!/bin/bash
#
# Initial data for Keystone using python-keystoneclient
#
# Tenant               User       Roles
# ------------------------------------------------------------------
# service              glance     admin
# service              swift      service        # if enabled
# service              heat       service        # if enabled
# service              ceilometer service        # if enabled
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

# Lookups
SERVICE_TENANT=$(keystone tenant-list | awk "/ $SERVICE_TENANT_NAME / { print \$2 }")
ADMIN_ROLE=$(keystone role-list | awk "/ admin / { print \$2 }")
MEMBER_ROLE=$(keystone role-list | awk "/ Member / { print \$2 }")


# Roles
# -----

# The ResellerAdmin role is used by Nova and Ceilometer so we need to keep it.
# The admin role in swift allows a user to act as an admin for their tenant,
# but ResellerAdmin is needed for a user to act as any tenant. The name of this
# role is also configurable in swift-proxy.conf
RESELLER_ROLE=$(get_id keystone role-create --name=ResellerAdmin)
# Service role, so service users do not have to be admins
SERVICE_ROLE=$(get_id keystone role-create --name=service)


# Services
# --------

if [[ "$ENABLED_SERVICES" =~ "n-api" ]] && [[ "$ENABLED_SERVICES" =~ "s-proxy" || "$ENABLED_SERVICES" =~ "swift" ]]; then
    NOVA_USER=$(keystone user-list | awk "/ nova / { print \$2 }")
    # Nova needs ResellerAdmin role to download images when accessing
    # swift through the s3 api.
    keystone user-role-add \
        --tenant_id $SERVICE_TENANT \
        --user_id $NOVA_USER \
        --role_id $RESELLER_ROLE
fi

# Heat
if [[ "$ENABLED_SERVICES" =~ "heat" ]]; then
    HEAT_USER=$(get_id keystone user-create --name=heat \
                                              --pass="$SERVICE_PASSWORD" \
                                              --tenant_id $SERVICE_TENANT \
                                              --email=heat@example.com)
    keystone user-role-add --tenant_id $SERVICE_TENANT \
                           --user_id $HEAT_USER \
                           --role_id $SERVICE_ROLE
    # heat_stack_user role is for users created by Heat
    keystone role-create --name heat_stack_user
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        HEAT_CFN_SERVICE=$(get_id keystone service-create \
            --name=heat-cfn \
            --type=cloudformation \
            --description="Heat CloudFormation Service")
        keystone endpoint-create \
            --region RegionOne \
            --service_id $HEAT_CFN_SERVICE \
            --publicurl "http://$SERVICE_HOST:$HEAT_API_CFN_PORT/v1" \
            --adminurl "http://$SERVICE_HOST:$HEAT_API_CFN_PORT/v1" \
            --internalurl "http://$SERVICE_HOST:$HEAT_API_CFN_PORT/v1"
        HEAT_SERVICE=$(get_id keystone service-create \
            --name=heat \
            --type=orchestration \
            --description="Heat Service")
        keystone endpoint-create \
            --region RegionOne \
            --service_id $HEAT_SERVICE \
            --publicurl "http://$SERVICE_HOST:$HEAT_API_PORT/v1/\$(tenant_id)s" \
            --adminurl "http://$SERVICE_HOST:$HEAT_API_PORT/v1/\$(tenant_id)s" \
            --internalurl "http://$SERVICE_HOST:$HEAT_API_PORT/v1/\$(tenant_id)s"
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
            --publicurl "http://$SERVICE_HOST:9292" \
            --adminurl "http://$SERVICE_HOST:9292" \
            --internalurl "http://$SERVICE_HOST:9292"
    fi
fi

# Swift

if [[ "$ENABLED_SERVICES" =~ "swift" || "$ENABLED_SERVICES" =~ "s-proxy" ]]; then
    SWIFT_USER=$(get_id keystone user-create \
        --name=swift \
        --pass="$SERVICE_PASSWORD" \
        --tenant_id $SERVICE_TENANT \
        --email=swift@example.com)
    keystone user-role-add \
        --tenant_id $SERVICE_TENANT \
        --user_id $SWIFT_USER \
        --role_id $SERVICE_ROLE
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        SWIFT_SERVICE=$(get_id keystone service-create \
            --name=swift \
            --type="object-store" \
            --description="Swift Service")
        keystone endpoint-create \
            --region RegionOne \
            --service_id $SWIFT_SERVICE \
            --publicurl "http://$SERVICE_HOST:8080/v1/AUTH_\$(tenant_id)s" \
            --adminurl "http://$SERVICE_HOST:8080" \
            --internalurl "http://$SERVICE_HOST:8080/v1/AUTH_\$(tenant_id)s"
    fi
fi

if [[ "$ENABLED_SERVICES" =~ "ceilometer" ]]; then
    CEILOMETER_USER=$(get_id keystone user-create --name=ceilometer \
                                              --pass="$SERVICE_PASSWORD" \
                                              --tenant_id $SERVICE_TENANT \
                                              --email=ceilometer@example.com)
    keystone user-role-add --tenant_id $SERVICE_TENANT \
                           --user_id $CEILOMETER_USER \
                           --role_id $SERVICE_ROLE
    # Ceilometer needs ResellerAdmin role to access swift account stats.
    keystone user-role-add --tenant_id $SERVICE_TENANT \
                           --user_id $CEILOMETER_USER \
                           --role_id $RESELLER_ROLE
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        CEILOMETER_SERVICE=$(get_id keystone service-create \
            --name=ceilometer \
            --type=metering \
            --description="Ceilometer Service")
        keystone endpoint-create \
            --region RegionOne \
            --service_id $CEILOMETER_SERVICE \
            --publicurl "http://$SERVICE_HOST:8777" \
            --adminurl "http://$SERVICE_HOST:8777" \
            --internalurl "http://$SERVICE_HOST:8777"
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
if [[ "$ENABLED_SERVICES" =~ "n-obj" || "$ENABLED_SERVICES" =~ "swift3" ]]; then
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
