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

# - We are going to check packages only for the services needed.
# - We are parsing the packages files and detecting metadatas.

if [[ "$os_PACKAGE" = "deb" ]]; then
    PKG_DIR=$FILES/apts
else
    PKG_DIR=$FILES/rpms
fi

for p in $(get_packages $PKG_DIR); do
    if [[ "$os_PACKAGE" = "deb" ]]; then
        ver=$(dpkg -s $p 2>/dev/null | grep '^Version: ' | cut -d' ' -f2)
    else
        ver=$(rpm -q --queryformat "%{VERSION}-%{RELEASE}\n" $p)
    fi
    echo "pkg|${p}|${ver}"
done


# Pips
# ----

if [[ "$os_PACKAGE" = "deb" ]]; then
    CMD_PIP=/usr/bin/pip
else
    CMD_PIP=/usr/bin/pip-python
fi

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
            #echo "unknown: $p"
            continue
        fi
        echo "pip|${p}|${ver}"
    else
        # No match in freeze file
        #echo "unknown: $p"
        continue
    fi
done <$FREEZE_FILE

rm $FREEZE_FILE


# localrc
# -------

# Dump localrc with 'localrc|' prepended and comments and passwords left out
if [[ -r $TOP_DIR/localrc ]]; then
    sed -e '
        /PASSWORD/d;
        /^#/d;
        s/^/localrc\|/;
    ' $TOP_DIR/localrc
fi
