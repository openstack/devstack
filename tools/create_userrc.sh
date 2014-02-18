#!/usr/bin/env bash

# **create_userrc.sh**

# Pre-create rc files and credentials for the default users.

# Warning: This script just for development purposes

set -o errexit
set -o xtrace

ACCOUNT_DIR=./accrc

display_help()
{
cat <<EOF

usage: $0 <options..>

This script creates certificates and sourcable rc files per tenant/user.

Target account directory hierarchy:
target_dir-|
           |-cacert.pem
           |-tenant1-name|
           |             |- user1
           |             |- user1-cert.pem
           |             |- user1-pk.pem
           |             |- user2
           |             ..
           |-tenant2-name..
           ..

Optional Arguments
-P include password to the rc files; with -A it assume all users password is the same
-A try with all user
-u <username> create files just for the specified user
-C <tanent_name> create user and tenant, the specifid tenant will be the user's tenant
-r <name> when combined with -C and the (-u) user exists it will be the user's tenant role in the (-C)tenant (default: Member)
-p <userpass> password for the user
--os-username <username>
--os-password <admin password>
--os-tenant-name <tenant_name>
--os-tenant-id <tenant_id>
--os-auth-url <auth_url>
--os-cacert <cert file>
--target-dir <target_directory>
--skip-tenant <tenant-name>
--debug

Example:
$0 -AP
$0 -P -C mytenant -u myuser -p mypass
EOF
}

if ! options=$(getopt -o hPAp:u:r:C: -l os-username:,os-password:,os-tenant-name:,os-tenant-id:,os-auth-url:,target-dir:,skip-tenant:,os-cacert:,help,debug -- "$@")
then
    #parse error
    display_help
    exit 1
fi
eval set -- $options
ADDPASS=""

# The services users usually in the service tenant.
# rc files for service users, is out of scope.
# Supporting different tanent for services is out of scope.
SKIP_TENANT=",service," # tenant names are between commas(,)
MODE=""
ROLE=Member
USER_NAME=""
USER_PASS=""
while [ $# -gt 0 ]; do
    case "$1" in
    -h|--help) display_help; exit 0 ;;
    --os-username) export OS_USERNAME=$2; shift ;;
    --os-password) export OS_PASSWORD=$2; shift ;;
    --os-tenant-name) export OS_TENANT_NAME=$2; shift ;;
    --os-tenant-id) export OS_TENANT_ID=$2; shift ;;
    --skip-tenant) SKIP_TENANT="$SKIP_TENANT$2,"; shift ;;
    --os-auth-url) export OS_AUTH_URL=$2; shift ;;
    --os-cacert) export OS_CACERT=$2; shift ;;
    --target-dir) ACCOUNT_DIR=$2; shift ;;
    --debug) set -o xtrace ;;
    -u) MODE=${MODE:-one};  USER_NAME=$2; shift ;;
    -p) USER_PASS=$2; shift ;;
    -A) MODE=all; ;;
    -P) ADDPASS="yes" ;;
    -C) MODE=create; TENANT=$2; shift ;;
    -r) ROLE=$2; shift ;;
    (--) shift; break ;;
    (-*) echo "$0: error - unrecognized option $1" >&2; display_help; exit 1 ;;
    (*)  echo "$0: error - unexpected argument $1" >&2; display_help; exit 1 ;;
    esac
    shift
done

if [ -z "$OS_PASSWORD" ]; then
    if [ -z "$ADMIN_PASSWORD" ];then
        echo "The admin password is required option!"  >&2
        exit 2
    else
        OS_PASSWORD=$ADMIN_PASSWORD
    fi
fi

if [ -z "$OS_TENANT_NAME" -a -z "$OS_TENANT_ID" ]; then
    export OS_TENANT_NAME=admin
fi

if [ -z "$OS_USERNAME" ]; then
    export OS_USERNAME=admin
fi

if [ -z "$OS_AUTH_URL" ]; then
    export OS_AUTH_URL=http://localhost:5000/v2.0/
fi

USER_PASS=${USER_PASS:-$OS_PASSWORD}
USER_NAME=${USER_NAME:-$OS_USERNAME}

if [ -z "$MODE" ]; then
    echo "You must specify at least -A or -u parameter!"  >&2
    echo
    display_help
    exit 3
fi

export -n SERVICE_TOKEN SERVICE_ENDPOINT OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT

EC2_URL=http://localhost:8773/service/Cloud
S3_URL=http://localhost:3333

ec2=`keystone endpoint-get --service ec2 | awk '/\|[[:space:]]*ec2.publicURL/ {print $4}'`
[ -n "$ec2" ] && EC2_URL=$ec2

s3=`keystone endpoint-get --service s3 | awk '/\|[[:space:]]*s3.publicURL/ {print $4}'`
[ -n "$s3" ] && S3_URL=$s3


mkdir -p "$ACCOUNT_DIR"
ACCOUNT_DIR=`readlink -f "$ACCOUNT_DIR"`
EUCALYPTUS_CERT=$ACCOUNT_DIR/cacert.pem
if [ -e "$EUCALYPTUS_CERT" ]; then
    mv "$EUCALYPTUS_CERT" "$EUCALYPTUS_CERT.old"
fi
if ! nova x509-get-root-cert "$EUCALYPTUS_CERT"; then
    echo "Failed to update the root certificate: $EUCALYPTUS_CERT" >&2
    if [ -e "$EUCALYPTUS_CERT.old" ]; then
        mv "$EUCALYPTUS_CERT.old" "$EUCALYPTUS_CERT"
    fi
fi


function add_entry(){
    local user_id=$1
    local user_name=$2
    local tenant_id=$3
    local tenant_name=$4
    local user_passwd=$5

    # The admin user can see all user's secret AWS keys, it does not looks good
    local line=`keystone ec2-credentials-list --user_id $user_id | grep -E "^\\|[[:space:]]*($tenant_name|$tenant_id)[[:space:]]*\\|" | head -n 1`
    if [ -z "$line" ]; then
        keystone ec2-credentials-create --user-id $user_id --tenant-id $tenant_id 1>&2
        line=`keystone ec2-credentials-list --user_id $user_id | grep -E "^\\|[[:space:]]*($tenant_name|$tenant_id)[[:space:]]*\\|" | head -n 1`
    fi
    local ec2_access_key ec2_secret_key
    read ec2_access_key ec2_secret_key <<<  `echo $line | awk '{print $4 " " $6 }'`
    mkdir -p "$ACCOUNT_DIR/$tenant_name"
    local rcfile="$ACCOUNT_DIR/$tenant_name/$user_name"
    # The certs subject part are the tenant ID "dash" user ID, but the CN should be the first part of the DN
    # Generally the subject DN parts should be in reverse order like the Issuer
    # The Serial does not seams correctly marked either
    local ec2_cert="$rcfile-cert.pem"
    local ec2_private_key="$rcfile-pk.pem"
    # Try to preserve the original file on fail (best effort)
    if [ -e "$ec2_private_key" ]; then
        mv -f "$ec2_private_key" "$ec2_private_key.old"
    fi
    if [ -e "$ec2_cert" ]; then
        mv -f "$ec2_cert" "$ec2_cert.old"
    fi
    # It will not create certs when the password is incorrect
    if ! nova --os-password "$user_passwd" --os-username "$user_name" --os-tenant-name "$tenant_name" x509-create-cert "$ec2_private_key" "$ec2_cert"; then
        if [ -e "$ec2_private_key.old" ]; then
            mv -f "$ec2_private_key.old" "$ec2_private_key"
        fi
        if [ -e "$ec2_cert.old" ]; then
            mv -f "$ec2_cert.old" "$ec2_cert"
        fi
    fi
    cat >"$rcfile" <<EOF
# you can source this file
export EC2_ACCESS_KEY="$ec2_access_key"
export EC2_SECRET_KEY="$ec2_secret_key"
export EC2_URL="$EC2_URL"
export S3_URL="$S3_URL"
# OpenStack USER ID = $user_id
export OS_USERNAME="$user_name"
# OpenStack Tenant ID = $tenant_id
export OS_TENANT_NAME="$tenant_name"
export OS_AUTH_URL="$OS_AUTH_URL"
export OS_CACERT="$OS_CACERT"
export EC2_CERT="$ec2_cert"
export EC2_PRIVATE_KEY="$ec2_private_key"
export EC2_USER_ID=42 #not checked by nova (can be a 12-digit id)
export EUCALYPTUS_CERT="$ACCOUNT_DIR/cacert.pem"
export NOVA_CERT="$ACCOUNT_DIR/cacert.pem"
EOF
    if [ -n "$ADDPASS" ]; then
        echo "export OS_PASSWORD=\"$user_passwd\"" >>"$rcfile"
    fi
}

#admin users expected
function create_or_get_tenant(){
    local tenant_name=$1
    local tenant_id=`keystone tenant-list | awk '/\|[[:space:]]*'"$tenant_name"'[[:space:]]*\|.*\|/ {print $2}'`
    if [ -n "$tenant_id" ]; then
        echo $tenant_id
    else
        keystone tenant-create --name "$tenant_name" | awk '/\|[[:space:]]*id[[:space:]]*\|.*\|/ {print $4}'
    fi
}

function create_or_get_role(){
    local role_name=$1
    local role_id=`keystone role-list| awk '/\|[[:space:]]*'"$role_name"'[[:space:]]*\|/ {print $2}'`
    if [ -n "$role_id" ]; then
        echo $role_id
    else
        keystone role-create --name "$role_name" |awk '/\|[[:space:]]*id[[:space:]]*\|.*\|/ {print $4}'
    fi
}

# Provides empty string when the user does not exists
function get_user_id(){
    local user_name=$1
    keystone user-list | awk '/^\|[^|]*\|[[:space:]]*'"$user_name"'[[:space:]]*\|.*\|/ {print $2}'
}

if [ $MODE != "create" ]; then
# looks like I can't ask for all tenant related to a specified  user
    for tenant_id_at_name in `keystone tenant-list | awk 'BEGIN {IGNORECASE = 1} /true[[:space:]]*\|$/ {print  $2 "@" $4}'`; do
        read tenant_id tenant_name <<< `echo "$tenant_id_at_name" | sed 's/@/ /'`
        if echo $SKIP_TENANT| grep -q ",$tenant_name,"; then
            continue;
        fi
        for user_id_at_name in `keystone user-list --tenant-id $tenant_id | awk 'BEGIN {IGNORECASE = 1} /true[[:space:]]*\|[^|]*\|$/ {print  $2 "@" $4}'`; do
            read user_id user_name <<< `echo "$user_id_at_name" | sed 's/@/ /'`
            if [ $MODE = one -a "$user_name" != "$USER_NAME" ]; then
                continue;
            fi

            # Checks for a specific password defined for an user.
            # Example for an username johndoe:
            #                     JOHNDOE_PASSWORD=1234
            eval SPECIFIC_UPASSWORD="\$${USER_NAME^^}_PASSWORD"
            if [ -n "$SPECIFIC_UPASSWORD" ]; then
                USER_PASS=$SPECIFIC_UPASSWORD
            fi
            add_entry "$user_id" "$user_name" "$tenant_id" "$tenant_name" "$USER_PASS"
        done
    done
else
    tenant_name=$TENANT
    tenant_id=`create_or_get_tenant "$TENANT"`
    user_name=$USER_NAME
    user_id=`get_user_id $user_name`
    if [ -z "$user_id" ]; then
        #new user
        user_id=`keystone user-create --name "$user_name" --tenant-id "$tenant_id" --pass "$USER_PASS" --email "$user_name@example.com" | awk '/\|[[:space:]]*id[[:space:]]*\|.*\|/ {print $4}'`
        #The password is in the cmd line. It is not a good thing
        add_entry "$user_id" "$user_name" "$tenant_id" "$tenant_name" "$USER_PASS"
    else
        #new role
        role_id=`create_or_get_role "$ROLE"`
        keystone user-role-add --user-id "$user_id" --tenant-id "$tenant_id" --role-id "$role_id"
        add_entry "$user_id" "$user_name" "$tenant_id" "$tenant_name" "$USER_PASS"
    fi
fi
