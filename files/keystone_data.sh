#!/bin/bash
BIN_DIR=${BIN_DIR:-.}
# Tenants
$BIN_DIR/keystone-manage $* tenant add admin
$BIN_DIR/keystone-manage $* tenant add demo

# Users
$BIN_DIR/keystone-manage $* user add admin secrete 1
$BIN_DIR/keystone-manage $* user add demo secrete 2

# Roles
$BIN_DIR/keystone-manage $* role add Admin
$BIN_DIR/keystone-manage $* role add Member
$BIN_DIR/keystone-manage $* role grant Admin admin

#endpointTemplates
# $BIN_DIR/keystone-manage $* endpointTemplates add RegionOne swift http://%HOST_IP%:8080/v1/AUTH_%tenant_id% http://%HOST_IP%:8080/ http://%HOST_IP%:8080/v1/AUTH_%tenant_id% 1 1
$BIN_DIR/keystone-manage $* endpointTemplates add RegionOne nova_compat http://%HOST_IP%:8774/v1.0/ http://%HOST_IP%:8774/v1.0  http://%HOST_IP%:8774/v1.0 1 1
$BIN_DIR/keystone-manage $* endpointTemplates add RegionOne nova http://%HOST_IP%:8774/v1.1/%tenant_id% http://%HOST_IP%:8774/v1.1/%tenant_id%  http://%HOST_IP%:8774/v1.1/%tenant_id% 1 1
$BIN_DIR/keystone-manage $* endpointTemplates add RegionOne glance http://%HOST_IP%:9292/v1.1/%tenant_id% http://%HOST_IP%:9292/v1.1/%tenant_id% http://%HOST_IP%:9292/v1.1/%tenant_id% 1 1
$BIN_DIR/keystone-manage $* endpointTemplates add RegionOne identity http://%HOST_IP%:5000/v2.0 http://%HOST_IP%:5001/v2.0 http://%HOST_IP%:5000/v2.0 1 1

# Tokens
$BIN_DIR/keystone-manage $* token add 999888777666 1 1 2015-02-05T00:00

#Tenant endpoints
$BIN_DIR/keystone-manage $* endpoint add 1 1
$BIN_DIR/keystone-manage $* endpoint add 1 2
$BIN_DIR/keystone-manage $* endpoint add 1 3
$BIN_DIR/keystone-manage $* endpoint add 1 4
$BIN_DIR/keystone-manage $* endpoint add 1 5
$BIN_DIR/keystone-manage $* endpoint add 1 6

$BIN_DIR/keystone-manage $* endpoint add 2 1
$BIN_DIR/keystone-manage $* endpoint add 2 2
$BIN_DIR/keystone-manage $* endpoint add 2 3
$BIN_DIR/keystone-manage $* endpoint add 2 4
$BIN_DIR/keystone-manage $* endpoint add 2 5
$BIN_DIR/keystone-manage $* endpoint add 2 6

$BIN_DIR/keystone-manage $* credentials add admin EC2 'admin:admin' admin admin || echo "no support for adding credentials"
