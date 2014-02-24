#!/usr/bin/env bash

# **info.sh**

# Produce a report on the state of devstack installs
#
# Output fields are separated with '|' chars
# Output types are git,localrc,os,pip,pkg:
#
#   git|<project>|<branch>[<shaq>]
#   localtc|<var>=<value>
#   os|<var>=<value>
#   pip|<package>|<version>
#   pkg|<package>|<version>

function usage {
    echo "$0 - Report on the devstack configuration"
    echo ""
    echo "Usage: $0"
    exit 1
}

if [ "$1" = "-h" ]; then
    usage
fi

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)
cd $TOP_DIR

# Import common functions
source $TOP_DIR/functions

# Source params
source $TOP_DIR/stackrc

DEST=${DEST:-/opt/stack}
FILES=$TOP_DIR/files
if [[ ! -d $FILES ]]; then
    echo "ERROR: missing devstack/files - did you grab more than just stack.sh?"
    exit 1
fi


# OS
# --

# Determine what OS we're using
GetDistro

echo "os|distro=$DISTRO"
echo "os|vendor=$os_VENDOR"
echo "os|release=$os_RELEASE"
if [ -n "$os_UPDATE" ]; then
    echo "os|version=$os_UPDATE"
fi


# Repos
# -----

# git_report <dir>
function git_report() {
    local dir=$1
    local proj ref branch head
    if [[ -d $dir/.git ]]; then
        pushd $dir >/dev/null
        proj=$(basename $dir)
        ref=$(git symbolic-ref HEAD)
        branch=${ref##refs/heads/}
        head=$(git show-branch --sha1-name $branch | cut -d' ' -f1)
        echo "git|${proj}|${branch}${head}"
        popd >/dev/null
    fi
}

for i in $DEST/*; do
    if [[ -d $i ]]; then
        git_report $i
    fi
done


# Packages
# --------

# - Only check packages for the services enabled
# - Parse version info from the package metadata, not the package/file names

for p in $(get_packages $ENABLED_SERVICES); do
    if [[ "$os_PACKAGE" = "deb" ]]; then
        ver=$(dpkg -s $p 2>/dev/null | grep '^Version: ' | cut -d' ' -f2)
    elif [[ "$os_PACKAGE" = "rpm" ]]; then
        ver=$(rpm -q --queryformat "%{VERSION}-%{RELEASE}\n" $p)
    else
        exit_distro_not_supported "finding version of a package"
    fi
    echo "pkg|${p}|${ver}"
done


# Pips
# ----

CMD_PIP=$(get_pip_command)

# Pip tells us what is currently installed
FREEZE_FILE=$(mktemp --tmpdir freeze.XXXXXX)
$CMD_PIP freeze >$FREEZE_FILE 2>/dev/null

# Loop through our requirements and look for matches
while read line; do
    if [[ -n "$line" ]]; then
        if [[ "$line" =~ \+(.*)@(.*)#egg=(.*) ]]; then
            # Handle URLs
            p=${BASH_REMATCH[1]}
            ver=${BASH_REMATCH[2]}
        elif [[ "$line" =~ (.*)[=\<\>]=(.*) ]]; then
            # Normal pip packages
            p=${BASH_REMATCH[1]}
            ver=${BASH_REMATCH[2]}
        else
            # Unhandled format in freeze file
            continue
        fi
        echo "pip|${p}|${ver}"
    else
        # No match in freeze file
        continue
    fi
done <$FREEZE_FILE

rm $FREEZE_FILE


# localrc
# -------

# Dump localrc with 'localrc|' prepended and comments and passwords left out
if [[ -r $TOP_DIR/localrc ]]; then
    RC=$TOP_DIR/localrc
elif [[ -f $RC_DIR/.localrc.auto ]]; then
    RC=$TOP_DIR/.localrc.auto
fi
if [[ -n $RC ]]; then
    sed -e '
        /^[ \t]*$/d;
        /PASSWORD/s/=.*$/=\<password\>/;
        /^#/d;
        s/^/localrc\|/;
    ' $RC
fi
