#!/usr/bin/env bash

# **fixup_stuff.sh**

# fixup_stuff.sh
#
# All distro and package specific hacks go in here
# - prettytable 0.7.2 permissions are 600 in the package and
#   pip 1.4 doesn't fix it (1.3 did)
# - httplib2 0.8 permissions are 600 in the package and
#   pip 1.4 doesn't fix it (1.3 did)

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

# Change dir to top of devstack
cd $TOP_DIR

# Import common functions
source $TOP_DIR/functions

FILES=$TOP_DIR/files

# Pre-install affected packages so we can fix the permissions
sudo pip install prettytable
sudo pip install httplib2

SITE_DIRS=$(python -c "import site; import os; print os.linesep.join(site.getsitepackages())")
for dir in $SITE_DIRS; do

    # Fix prettytable 0.7.2 permissions
    if [[ -r $dir/prettytable.py ]]; then
        sudo chmod +r $dir/prettytable-0.7.2*/*
    fi

    # Fix httplib2 0.8 permissions
    httplib_dir=httplib2-0.8.egg-info
    if [[ -d $dir/$httplib_dir ]]; then
        sudo chmod +r $dir/$httplib_dir/*
    fi

done
