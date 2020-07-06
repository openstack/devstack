#!/usr/bin/env bash

# **create_userrc.sh**

# Pre-create rc files and credentials for the default users.

# Warning: This script just for development purposes

set -o errexit

# short_source prints out the current location of the caller in a way
# that strips redundant directories. This is useful for PS4
# usage. Needed before we start tracing due to how we set
# PS4. Normally we'd pick this up from stackrc, but that's not sourced
# here.
function short_source {
    saveIFS=$IFS
    IFS=" "
    called=($(caller 0))
    IFS=$saveIFS
    file=${called[2]}
    file=${file#$RC_DIR/}
    printf "%-40s " "$file:${called[1]}:${called[0]}"
}
# PS4 is exported to child shells and uses the 'short_source' function, so
# export it so child shells have access to the 'short_source' function also.
export -f short_source

set -o xtrace

ACCOUNT_DIR=./accrc

function display_help {
cat <<EOF

usage: $0 <options..>

This script creates certificates and sourcable rc files per project/user.

Target account directory hierarchy:
target_dir-|
           |-cacert.pem
           |-project1-name|
           |              |- user1
           |              |- user1-cert.pem
           |              |- user1-pk.pem
           |              |- user2
           |              ..
           |-project2-name..
           ..

Optional Arguments
-P include password to the rc files; with -A it assume all users password is the same
-A try with all user
-u <username> create files just for the specified user
-C <project_name> create user and project, the specifid project will be the user's project
-r <name> when combined with -C and the (-u) user exists it will be the user's project role in the (-C)project (default: Member)
-p <userpass> password for the user
--heat-url <heat_url>
--os-username <username>
--os-password <admin password>
--os-project-name <project_name>
--os-project-id <project_id>
--os-user-domain-id <user_domain_id>
--os-user-domain-name <user_domain_name>
--os-project-domain-id <project_domain_id>
--os-project-domain-name <project_domain_name>
--os-auth-url <auth_url>
--os-cacert <cert file>
--target-dir <target_directory>
--skip-project <project-name>
--debug

Example:
$0 -AP
$0 -P -C myproject -u myuser -p mypass
EOF
}

if ! options=$(getopt -o hPAp:u:r:C: -l os-username:,os-password:,os-tenant-id:,os-tenant-name:,os-project-name:,os-project-id:,os-project-domain-id:,os-project-domain-name:,os-user-domain-id:,os-user-domain-name:,os-auth-url:,target-dir:,heat-url:,skip-project:,os-cacert:,help,debug -- "$@"); then
    display_help
    exit 1
fi
eval set -- $options
ADDPASS=""
HEAT_URL=""

# The services users usually in the service project.
# rc files for service users, is out of scope.
# Supporting different project for services is out of scope.
SKIP_PROJECT="service"
MODE=""
ROLE=Member
USER_NAME=""
USER_PASS=""
while [ $# -gt 0 ]; do
    case "$1" in
    -h|--help) display_help; exit 0 ;;
    --os-username) export OS_USERNAME=$2; shift ;;
    --os-password) export OS_PASSWORD=$2; shift ;;
    --os-tenant-name) export OS_PROJECT_NAME=$2; shift ;;
    --os-tenant-id) export OS_PROJECT_ID=$2; shift ;;
    --os-project-name) export OS_PROJECT_NAME=$2; shift ;;
    --os-project-id) export OS_PROJECT_ID=$2; shift ;;
    --os-user-domain-id) export OS_USER_DOMAIN_ID=$2; shift ;;
    --os-user-domain-name) export OS_USER_DOMAIN_NAME=$2; shift ;;
    --os-project-domain-id) export OS_PROJECT_DOMAIN_ID=$2; shift ;;
    --os-project-domain-name) export OS_PROJECT_DOMAIN_NAME=$2; shift ;;
    --skip-tenant) SKIP_PROJECT="$SKIP_PROJECT$2,"; shift ;;
    --skip-project) SKIP_PROJECT="$SKIP_PROJECT$2,"; shift ;;
    --os-auth-url) export OS_AUTH_URL=$2; shift ;;
    --os-cacert) export OS_CACERT=$2; shift ;;
    --target-dir) ACCOUNT_DIR=$2; shift ;;
    --heat-url) HEAT_URL=$2; shift ;;
    --debug) set -o xtrace ;;
    -u) MODE=${MODE:-one};  USER_NAME=$2; shift ;;
    -p) USER_PASS=$2; shift ;;
    -A) MODE=all; ;;
    -P) ADDPASS="yes" ;;
    -C) MODE=create; PROJECT=$2; shift ;;
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

if [ -z "$OS_PROJECT_ID" -a "$OS_TENANT_ID" ]; then
    export OS_PROJECT_ID=$OS_TENANT_ID
fi

if [ -z "$OS_PROJECT_NAME" -a "$OS_TENANT_NAME" ]; then
    export OS_PROJECT_NAME=$OS_TENANT_NAME
fi

if [ -z "$OS_PROJECT_NAME" -a -z "$OS_PROJECT_ID" ]; then
    export OS_PROJECT_NAME=admin
fi

if [ -z "$OS_USERNAME" ]; then
    export OS_USERNAME=admin
fi

if [ -z "$OS_AUTH_URL" ]; then
    export OS_AUTH_URL=http://localhost:5000/v3/
fi

if [ -z "$OS_USER_DOMAIN_ID" -a -z "$OS_USER_DOMAIN_NAME" ]; then
    # purposefully not exported as it would force v3 auth within this file.
    OS_USER_DOMAIN_ID=default
fi

if [ -z "$OS_PROJECT_DOMAIN_ID" -a -z "$OS_PROJECT_DOMAIN_NAME" ]; then
    # purposefully not exported as it would force v3 auth within this file.
    OS_PROJECT_DOMAIN_ID=default
fi

USER_PASS=${USER_PASS:-$OS_PASSWORD}
USER_NAME=${USER_NAME:-$OS_USERNAME}

if [ -z "$MODE" ]; then
    echo "You must specify at least -A or -u parameter!"  >&2
    echo
    display_help
    exit 3
fi

function add_entry {
    local user_id=$1
    local user_name=$2
    local project_id=$3
    local project_name=$4
    local user_passwd=$5

    mkdir -p "$ACCOUNT_DIR/$project_name"
    local rcfile="$ACCOUNT_DIR/$project_name/$user_name"

    cat >"$rcfile" <<EOF
# OpenStack USER ID = $user_id
export OS_USERNAME="$user_name"
# OpenStack project ID = $project_id
export OS_PROJECT_NAME="$project_name"
export OS_AUTH_URL="$OS_AUTH_URL"
export OS_CACERT="$OS_CACERT"
export NOVA_CERT="$ACCOUNT_DIR/cacert.pem"
EOF
    if [ -n "$ADDPASS" ]; then
        echo "export OS_PASSWORD=\"$user_passwd\"" >>"$rcfile"
    fi
    if [ -n "$HEAT_URL" ]; then
        echo "export HEAT_URL=\"$HEAT_URL/$project_id\"" >>"$rcfile"
        echo "export OS_NO_CLIENT_AUTH=True" >>"$rcfile"
    fi
    for v in OS_USER_DOMAIN_ID OS_USER_DOMAIN_NAME OS_PROJECT_DOMAIN_ID OS_PROJECT_DOMAIN_NAME; do
        if [ ${!v} ]; then
            echo "export $v=${!v}" >>"$rcfile"
        else
            echo "unset $v" >>"$rcfile"
        fi
    done
}

#admin users expected
function create_or_get_project {
    local name=$1
    local id
    eval $(openstack project show -f shell -c id $name)
    if [[ -z $id ]]; then
        eval $(openstack project create -f shell -c id $name)
    fi
    echo $id
}

function create_or_get_role {
    local name=$1
    local id
    eval $(openstack role show -f shell -c id $name)
    if [[ -z $id ]]; then
        eval $(openstack role create -f shell -c id $name)
    fi
    echo $id
}

# Provides empty string when the user does not exists
function get_user_id {
    openstack user list | grep " $1 " | cut -d " " -f2
}

if [ $MODE != "create" ]; then
    # looks like I can't ask for all project related to a specified user
    openstack project list --long --quote none -f csv | grep ',True' | grep -v "${SKIP_PROJECT}" | while IFS=, read project_id project_name desc enabled; do
        openstack user list --project $project_id --long --quote none -f csv | grep ',True' | while IFS=, read user_id user_name project email enabled; do
            if [ $MODE = one -a "$user_name" != "$USER_NAME" ]; then
                continue;
            fi

            # Checks for a specific password defined for an user.
            # Example for an username johndoe: JOHNDOE_PASSWORD=1234
            # This mechanism is used by lib/swift
            eval SPECIFIC_UPASSWORD="\$${user_name}_password"
            if [ -n "$SPECIFIC_UPASSWORD" ]; then
                USER_PASS=$SPECIFIC_UPASSWORD
            fi
            add_entry "$user_id" "$user_name" "$project_id" "$project_name" "$USER_PASS"
        done
    done
else
    project_name=$PROJECT
    project_id=$(create_or_get_project "$PROJECT")
    user_name=$USER_NAME
    user_id=`get_user_id $user_name`
    if [ -z "$user_id" ]; then
        eval $(openstack user create "$user_name" --project "$project_id" --password "$USER_PASS" --email "$user_name@example.com" -f shell -c id)
        user_id=$id
        add_entry "$user_id" "$user_name" "$project_id" "$project_name" "$USER_PASS"
    else
        role_id=$(create_or_get_role "$ROLE")
        openstack role add "$role_id" --user "$user_id" --project "$project_id"
        add_entry "$user_id" "$user_name" "$project_id" "$project_name" "$USER_PASS"
    fi
fi
