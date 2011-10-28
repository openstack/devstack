#!/bin/bash
BIN_DIR=${BIN_DIR:-.}
# Tenants
$BIN_DIR/keystone-manage $* tenant add admin
$BIN_DIR/keystone-manage $* tenant add demo
$BIN_DIR/keystone-manage $* tenant add invisible_to_admin

# Users
$BIN_DIR/keystone-manage $* user add admin %ADMIN_PASSWORD%
$BIN_DIR/keystone-manage $* user add demo %ADMIN_PASSWORD%

# Roles
$BIN_DIR/keystone-manage $* role add Admin
$BIN_DIR/keystone-manage $* role add Member
$BIN_DIR/keystone-manage $* role add KeystoneAdmin
$BIN_DIR/keystone-manage $* role add KeystoneServiceAdmin
$BIN_DIR/keystone-manage $* role add sysadmin
$BIN_DIR/keystone-manage $* role add netadmin
$BIN_DIR/keystone-manage $* role grant Admin admin admin
$BIN_DIR/keystone-manage $* role grant Member demo demo
$BIN_DIR/keystone-manage $* role grant sysadmin demo demo
$BIN_DIR/keystone-manage $* role grant netadmin demo demo
$BIN_DIR/keystone-manage $* role grant Member demo invisible_to_admin
$BIN_DIR/keystone-manage $* role grant Admin admin demo
$BIN_DIR/keystone-manage $* role grant Admin admin
$BIN_DIR/keystone-manage $* role grant KeystoneAdmin admin
$BIN_DIR/keystone-manage $* role grant KeystoneServiceAdmin admin

# Services
$BIN_DIR/keystone-manage $* service add nova compute "Nova Compute Service"
$BIN_DIR/keystone-manage $* service add glance image "Glance Image Service"
$BIN_DIR/keystone-manage $* service add keystone identity "Keystone Identity Service"

#endpointTemplates
$BIN_DIR/keystone-manage $* endpointTemplates add RegionOne nova http://%HOST_IP%:8774/v1.1/%tenant_id% http://%HOST_IP%:8774/v1.1/%tenant_id%  http://%HOST_IP%:8774/v1.1/%tenant_id% 1 1
$BIN_DIR/keystone-manage $* endpointTemplates add RegionOne glance http://%HOST_IP%:9292/v1.1/%tenant_id% http://%HOST_IP%:9292/v1.1/%tenant_id% http://%HOST_IP%:9292/v1.1/%tenant_id% 1 1
$BIN_DIR/keystone-manage $* endpointTemplates add RegionOne keystone http://%HOST_IP%:5000/v2.0 http://%HOST_IP%:35357/v2.0 http://%HOST_IP%:5000/v2.0 1 1
# $BIN_DIR/keystone-manage $* endpointTemplates add RegionOne swift http://%HOST_IP%:8080/v1/AUTH_%tenant_id% http://%HOST_IP%:8080/ http://%HOST_IP%:8080/v1/AUTH_%tenant_id% 1 1

# Tokens
$BIN_DIR/keystone-manage $* token add %SERVICE_TOKEN% admin admin 2015-02-05T00:00

# EC2 related creds - note we are setting the secret key to ADMIN_PASSWORD
# but keystone doesn't parse them - it is just a blob from keystone's
# point of view
$BIN_DIR/keystone-manage $* credentials add admin EC2 'admin' '%ADMIN_PASSWORD%' admin || echo "no support for adding credentials"
$BIN_DIR/keystone-manage $* credentials add demo EC2 'demo' '%ADMIN_PASSWORD%' demo || echo "no support for adding credentials"
