import string

api_server_conf_template = string.Template("""
[DEFAULTS]
reset_config=True
ifmap_server_ip=$__contrail_ifmap_server_ip__
ifmap_server_port=$__contrail_ifmap_server_port__
ifmap_username=$__contrail_ifmap_username__
ifmap_password=$__contrail_ifmap_password__
redis_server_port=6379
cassandra_server_list=$__contrail_cassandra_server_list__
listen_ip_addr=$__contrail_listen_ip_addr__
listen_port=$__contrail_listen_port__
auth=keystone
multi_tenancy=$__contrail_multi_tenancy__
log_file=$__contrail_log_file__
disc_server_ip=$__contrail_disc_server_ip__
disc_server_port=$__contrail_disc_server_port__

[SECURITY]
use_certs=$__contrail_use_certs__
keyfile=$__contrail_keyfile_location__
certfile=$__contrail_certfile_location__
ca_certs=$__contrail_cacertfile_location__

[KEYSTONE]
auth_host=$__contrail_openstack_ip__
auth_protocol=http
admin_user=$__contrail_admin_user__
admin_password=$__contrail_admin_password__
admin_tenant_name=$__contrail_admin_tenant_name__
$__contrail_memcached_opt__
""")

quantum_conf_template = string.Template("""
[APISERVER]
api_server_ip = $__contrail_api_server_ip__
api_server_port = $__contrail_api_server_port__
multi_tenancy = $__contrail_multi_tenancy__

[KEYSTONE]
;auth_url = http://$__contrail_keystone_ip__:35357/v2.0
;admin_token = $__contrail_admin_token__
admin_user=$__contrail_admin_user__
admin_password=$__contrail_admin_password__
admin_tenant_name=$__contrail_admin_tenant_name__
""")

schema_transformer_conf_template = string.Template("""
[DEFAULTS]
ifmap_server_ip=$__contrail_ifmap_server_ip__
ifmap_server_port=$__contrail_ifmap_server_port__
ifmap_username=$__contrail_ifmap_username__
ifmap_password=$__contrail_ifmap_password__
api_server_ip=$__contrail_api_server_ip__
api_server_port=$__contrail_api_server_port__
zk_server_ip=$__contrail_zookeeper_server_ip__
zk_server_port=$__contrail_zookeeper_server_port__
log_file=$__contrail_log_file__
cassandra_server_list=$__contrail_cassandra_server_list__
disc_server_ip=$__contrail_disc_server_ip__
disc_server_port=$__contrail_disc_server_port__

[SECURITY]
use_certs=$__contrail_use_certs__
keyfile=$__contrail_keyfile_location__
certfile=$__contrail_certfile_location__
ca_certs=$__contrail_cacertfile_location__

[KEYSTONE]
admin_user=$__contrail_admin_user__
admin_password=$__contrail_admin_password__
admin_tenant_name=$__contrail_admin_tenant_name__
""")

svc_monitor_conf_template = string.Template("""
[DEFAULTS]
ifmap_server_ip=$__contrail_ifmap_server_ip__
ifmap_server_port=$__contrail_ifmap_server_port__
ifmap_username=$__contrail_ifmap_username__
ifmap_password=$__contrail_ifmap_password__
api_server_ip=$__contrail_api_server_ip__
api_server_port=$__contrail_api_server_port__
zk_server_ip=$__contrail_zookeeper_server_ip__
zk_server_port=$__contrail_zookeeper_server_port__
log_file=$__contrail_log_file__
cassandra_server_list=$__contrail_cassandra_server_list__
disc_server_ip=$__contrail_disc_server_ip__
disc_server_port=$__contrail_disc_server_port__

[SECURITY]
use_certs=$__contrail_use_certs__
keyfile=$__contrail_keyfile_location__
certfile=$__contrail_certfile_location__
ca_certs=$__contrail_cacertfile_location__

[KEYSTONE]
auth_host=$__contrail_openstack_ip__
admin_user=$__contrail_admin_user__
admin_password=$__contrail_admin_password__
admin_tenant_name=$__contrail_admin_tenant_name__
""")

bgp_param_template = string.Template("""
IFMAP_SERVER=$__contrail_ifmap_srv_ip__
IFMAP_PORT=$__contrail_ifmap_srv_port__
IFMAP_USER=$__contrail_ifmap_usr__
IFMAP_PASWD=$__contrail_ifmap_paswd__
COLLECTOR=$__contrail_collector__
COLLECTOR_PORT=$__contrail_collector_port__
DISCOVERY=$__contrail_discovery_ip__
HOSTNAME=$__contrail_hostname__
HOSTIP=$__contrail_host_ip__
BGP_PORT=$__contrail_bgp_port__
CERT_OPTS=$__contrail_cert_ops__
CONTROL_LOGFILE=$__contrail_logfile__
LOG_LOCAL=$__contrail_log_local__
""")

dns_param_template = string.Template("""
IFMAP_SERVER=$__contrail_ifmap_srv_ip__
IFMAP_PORT=$__contrail_ifmap_srv_port__
IFMAP_USER=$__contrail_ifmap_usr__
IFMAP_PASWD=$__contrail_ifmap_paswd__
COLLECTOR=$__contrail_collector__
COLLECTOR_PORT=$__contrail_collector_port__
DISCOVERY=$__contrail_discovery_ip__
HOSTIP=$__contrail_host_ip__
CERT_OPTS=$__contrail_cert_ops__
DNS_LOGFILE=$__contrail_logfile__
LOG_LOCAL=$__contrail_log_local__
""")


discovery_conf_template = string.Template("""
[DEFAULTS]
zk_server_ip=127.0.0.1
zk_server_port=$__contrail_zk_server_port__
listen_ip_addr=$__contrail_listen_ip_addr__
listen_port=$__contrail_listen_port__
log_local=$__contrail_log_local__
log_file=$__contrail_log_file__

# minimim time to allow client to cache service information (seconds)
ttl_min=300

# maximum time to allow client to cache service information (seconds)
ttl_max=1800

# maximum hearbeats to miss before server will declare publisher out of
# service. 
hc_max_miss=3

# use short TTL for agressive rescheduling if all services are not up
ttl_short=1

######################################################################
# Other service specific knobs ...
 
# use short TTL for agressive rescheduling if all services are not up
# ttl_short=1
 
# specify policy to use when assigning services
# policy = [load-balance | round-robin | fixed]
######################################################################
""")

vizd_param_template = string.Template("""
CASSANDRA_SERVER_LIST=$__contrail_cassandra_server_list__
REDIS_SERVER=$__contrail_redis_server__
REDIS_SERVER_PORT=$__contrail_redis_server_port__
DISCOVERY=$__contrail_discovery_ip__
HOST_IP=$__contrail_host_ip__
LISTEN_PORT=$__contrail_listen_port__
HTTP_SERVER_PORT=$__contrail_http_server_port__
LOG_FILE=$__contrail_log_file__
LOG_LOCAL=$__contrail_log_local__
LOG_LEVEL=$__contrail_log_level__
""")

qe_param_template = string.Template("""
CASSANDRA_SERVER_LIST=$__contrail_cassandra_server_list__
REDIS_SERVER=$__contrail_redis_server__
REDIS_SERVER_PORT=$__contrail_redis_server_port__
DISCOVERY=$__contrail_discovery_ip__
HOST_IP=$__contrail_host_ip__
LISTEN_PORT=$__contrail_listen_port__
HTTP_SERVER_PORT=$__contrail_http_server_port__
LOG_FILE=$__contrail_log_file__
LOG_LOCAL=$__contrail_log_local__
LOG_LEVEL=$__contrail_log_level__
""")

opserver_param_template = string.Template("""
REDIS_SERVER=$__contrail_redis_server__
REDIS_SERVER_PORT=$__contrail_redis_server_port__
REDIS_QUERY_PORT=$__contrail_redis_query_port__
COLLECTOR=$__contrail_collector__
COLLECTOR_PORT=$__contrail_collector_port__
HTTP_SERVER_PORT=$__contrail_http_server_port__
REST_API_PORT=$__contrail_rest_api_port__
LOG_FILE=$__contrail_log_file__
LOG_LOCAL=$__contrail_log_local__
LOG_LEVEL=$__contrail_log_level__
DISCOVERY=$__contrail_discovery_ip__
""")

vnc_api_lib_ini_template = string.Template("""
[global]
;WEB_SERVER = 127.0.0.1
;WEB_PORT = 9696  ; connection through quantum plugin

WEB_SERVER = 127.0.0.1
WEB_PORT = 8082 ; connection to api-server directly
BASE_URL = /
;BASE_URL = /tenants/infra ; common-prefix for all URLs

; Authentication settings (optional)
[auth]
AUTHN_TYPE = keystone
AUTHN_SERVER=$__contrail_openstack_ip__
AUTHN_PORT = 35357
AUTHN_URL = /v2.0/tokens
""")

agent_param_template = string.Template("""
LOG=/var/log/contrail.log
CONFIG=/etc/contrail/agent.conf
prog=/usr/bin/vnswad
kmod=vrouter/vrouter.ko
pname=vnswad
LIBDIR=/usr/lib64
VHOST_CFG=/etc/sysconfig/network-scripts/ifcfg-vhost0
VROUTER_LOGFILE=--log-file=/var/log/vrouter.log
COLLECTOR=$__contrail_collector__
$__contrail_dev__
""")

agent_conf_template = string.Template("""
<?xml version="1.0" encoding="utf-8"?>
<config>
 <agent>
  <!-- Physical ports connecting to IP Fabric -->
  <vhost>
   <name>vhost0</name>
   <ip-address>$__contrail_box_ip__</ip-address>
   <gateway>$__contrail_gateway__</gateway>
  </vhost>
  <eth-port>
   <name>$__contrail_intf__</name>
  </eth-port>
  <control>
   <ip-address>$__contrail_box_ip__</ip-address>
  </control>
  <xmpp-server>
   <ip-address>$__contrail_control_ip__</ip-address>
  </xmpp-server>
 </agent>
</config>
""")

agent_vgw_conf_template = string.Template("""
<?xml version="1.0" encoding="utf-8"?>
<config>
 <agent>
  <!-- Physical ports connecting to IP Fabric -->
  <vhost>
   <name>vhost0</name>
   <ip-address>$__contrail_box_ip__</ip-address>
   <gateway>$__contrail_gateway__</gateway>
  </vhost>
  <eth-port>
   <name>$__contrail_intf__</name>
  </eth-port>
  <control>
   <ip-address>$__contrail_control_ip__</ip-address>
  </control>
  <xmpp-server>
   <ip-address>$__contrail_control_ip__</ip-address>
  </xmpp-server>
  <gateway virtual-network="$__contrail_vgw_public_network__">
    <interface>$__contrail_vgw_interface__</interface>
    <subnet>$__contrail_vgw_public_subnet__</subnet>
  </gateway>
 </agent>
</config>
""")

ifconfig_vhost0_template = string.Template("""
#Contrail vhost0
DEVICE=vhost0
ONBOOT=yes
BOOTPROTO=none
IPV6INIT=no
USERCTL=yes
IPADDR=$__contrail_ipaddr__
NETMASK=$__contrail_netmask__
NM_CONTROLLED=no
#NETWORK MANAGER BUG WORKAROUND
SUBCHANNELS=1,2,3
$__contrail_gateway__
$__contrail_dns__
$__contrail_domain__
$__contrail_mtu__
""")

contrail_plugin_template = string.Template("""
[APISERVER]
api_server_ip=$__api_server_ip__
api_server_port=$__api_server_port__
multi_tenancy=$__multitenancy__

[KEYSTONE]
admin_user=$__contrail_admin_user__
admin_password=$__contrail_admin_password__
admin_tenant_name=$__contrail_admin_tenant_name__
""")

openstackrc_template = string.Template("""
export OS_USERNAME=$__contrail_admin_user__
export OS_PASSWORD=$__contrail_admin_password__
export OS_TENANT_NAME=$__contrail_admin_tenant_name__
export OS_AUTH_URL=http://$__contrail_keystone_ip__:5000/v2.0/
export OS_NO_CACHE=1
""")

