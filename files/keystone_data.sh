#!/bin/bash
BIN_DIR=${BIN_DIR:-.}
# Tenants
ADMIN_TENANT=`$BIN_DIR/keystone-manage tenant --id-only create \
                                       tenant_name=admin`
DEMO_TENANT=`$BIN_DIR/keystone-manage tenant --id-only create \
                                      tenant_name=demo`
INVIS_TENANT=`$BIN_DIR/keystone-manage tenant --id-only create \
                                       tenant_name=invisible_to_admin`


# Users
ADMIN_USER=`$BIN_DIR/keystone-manage user --id-only create \
                                          name=admin \
                                          "password=%ADMIN_PASSWORD%" \
                                          email=admin@example.com`
DEMO_USER=`$BIN_DIR/keystone-manage user --id-only create \
                                         name=demo \
                                         "password=%ADMIN_PASSWORD%" \
                                         email=demo@example.com`

# Roles
ADMIN_ROLE=`$BIN_DIR/keystone-manage role --id-only create \
                                          name=admin`
MEMBER_ROLE=`$BIN_DIR/keystone-manage role --id-only create \
                                           name=Member`
KEYSTONEADMIN_ROLE=`$BIN_DIR/keystone-manage role --id-only create \
                                                  name=KeystoneAdmin`
KEYSTONESERVICE_ROLE=`$BIN_DIR/keystone-manage role --id-only create \
                                                         name=KeystoneServiceAdmin`
SYSADMIN_ROLE=`$BIN_DIR/keystone-manage role --id-only create \
                                             name=sysadmin`
NETADMIN_ROLE=`$BIN_DIR/keystone-manage role --id-only create \
                                             name=netadmin`


# Add Roles to Users in Tenants

$BIN_DIR/keystone-manage role add_user_role \
                              role=$ADMIN_ROLE \
                              user=$ADMIN_USER \
                              tenant=$ADMIN_TENANT
$BIN_DIR/keystone-manage role add_user_role \
                              role=$MEMBER_ROLE \
                              user=$DEMO_USER \
                              tenant=$DEMO_TENANT
$BIN_DIR/keystone-manage role add_user_role \
                              role=$SYSADMIN_ROLE \
                              user=$DEMO_USER \
                              tenant=$DEMO_TENANT
$BIN_DIR/keystone-manage role add_user_role \
                              role=$NETADMIN_ROLE \
                              user=$DEMO_USER \
                              tenant=$DEMO_TENANT
$BIN_DIR/keystone-manage role add_user_role \
                              role=$MEMBER_ROLE \
                              user=$DEMO_USER \
                              tenant=$INVIS_TENANT
$BIN_DIR/keystone-manage role add_user_role \
                              role=$ADMIN_ROLE \
                              user=$ADMIN_USER \
                              tenant=$DEMO_TENANT

# TODO(termie): these two might be dubious
$BIN_DIR/keystone-manage role add_user_role \
                              role=$KEYSTONEADMIN_ROLE \
                              user=$ADMIN_USER \
                              tenant=$ADMIN_TENANT
$BIN_DIR/keystone-manage role add_user_role \
                              role=$KEYSTONESERVICE_ROLE \
                              user=$ADMIN_USER \
                              tenant=$ADMIN_TENANT

# Services
$BIN_DIR/keystone-manage service create \
                                 name=nova \
                                 service_type=compute \
                                 "description=Nova Compute Service"

$BIN_DIR/keystone-manage service create \
                                 name=ec2 \
                                 service_type=ec2 \
                                 "description=EC2 Compatibility Layer"

$BIN_DIR/keystone-manage service create \
                                 name=glance \
                                 service_type=image \
                                 "description=Glance Image Service"

$BIN_DIR/keystone-manage service create \
                                 name=keystone \
                                 service_type=identity \
                                 "description=Keystone Identity Service"
if [[ "$ENABLED_SERVICES" =~ "swift" ]]; then
    $BIN_DIR/keystone-manage service create \
                                     name=swift \
                                     service_type=object-store \
                                     "description=Swift Service"
fi

# create ec2 creds and parse the secret and access key returned
RESULT=`$BIN_DIR/keystone-manage ec2 create user_id=$ADMIN_USER tenant_id=$ADMIN_TENANT`
ADMIN_ACCESS=`echo $RESULT | python -c "import sys; import json; result = json.loads(sys.stdin.read()); print result['access'];"`
ADMIN_SECRET=`echo $RESULT | python -c "import sys; import json; result = json.loads(sys.stdin.read()); print result['secret'];"`


RESULT=`$BIN_DIR/keystone-manage ec2 create user_id=$DEMO_USER tenant_id=$DEMO_TENANT`
DEMO_ACCESS=`echo $RESULT | python -c "import sys; import json; result = json.loads(sys.stdin.read()); print result['access'];"`
DEMO_SECRET=`echo $RESULT | python -c "import sys; import json; result = json.loads(sys.stdin.read()); print result['secret'];"`

# write the secret and access to ec2rc
cat > $DEVSTACK_DIR/ec2rc <<EOF
ADMIN_ACCESS=$ADMIN_ACCESS
ADMIN_SECRET=$ADMIN_SECRET
DEMO_ACCESS=$DEMO_ACCESS
DEMO_SECRET=$DEMO_SECRET
EOF


#endpointTemplates
#$BIN_DIR/keystone-manage $* endpointTemplates add \
#      RegionOne nova
#      http://%SERVICE_HOST%:8774/v1.1/%tenant_id%
#      http://%SERVICE_HOST%:8774/v1.1/%tenant_id%
#      http://%SERVICE_HOST%:8774/v1.1/%tenant_id% 1 1
#$BIN_DIR/keystone-manage $* endpointTemplates add
#      RegionOne ec2
#      http://%SERVICE_HOST%:8773/services/Cloud
#      http://%SERVICE_HOST%:8773/services/Admin
#      http://%SERVICE_HOST%:8773/services/Cloud 1 1
#$BIN_DIR/keystone-manage $* endpointTemplates add
#      RegionOne glance
#      http://%SERVICE_HOST%:9292/v1
#      http://%SERVICE_HOST%:9292/v1
#      http://%SERVICE_HOST%:9292/v1 1 1
#$BIN_DIR/keystone-manage $* endpointTemplates add
#      RegionOne keystone
#      http://%SERVICE_HOST%:5000/v2.0
#      http://%SERVICE_HOST%:35357/v2.0
#      http://%SERVICE_HOST%:5000/v2.0 1 1
#if [[ "$ENABLED_SERVICES" =~ "swift" ]]; then
#    $BIN_DIR/keystone-manage $* endpointTemplates add
#        RegionOne swift
#        http://%SERVICE_HOST%:8080/v1/AUTH_%tenant_id%
#        http://%SERVICE_HOST%:8080/
#        http://%SERVICE_HOST%:8080/v1/AUTH_%tenant_id% 1 1
#fi

# Tokens
#$BIN_DIR/keystone-manage token add %SERVICE_TOKEN% admin admin 2015-02-05T00:00

