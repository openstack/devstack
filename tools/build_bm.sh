#!/usr/bin/env bash

# **build_bm.sh**

# Build an OpenStack install on a bare metal machine.
set +x

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Import common functions
source $TOP_DIR/functions

# Source params
source ./stackrc

# Param string to pass to stack.sh.  Like "EC2_DMZ_HOST=192.168.1.1 MYSQL_USER=nova"
STACKSH_PARAMS=${STACKSH_PARAMS:-}

# Option to use the version of devstack on which we are currently working
USE_CURRENT_DEVSTACK=${USE_CURRENT_DEVSTACK:-1}

# Configure the runner
RUN_SH=`mktemp`
cat > $RUN_SH <<EOF
#!/usr/bin/env bash
# Install and run stack.sh
cd devstack
$STACKSH_PARAMS ./stack.sh
EOF

# Make the run.sh executable
chmod 755 $RUN_SH

scp -r . root@$CONTAINER_IP:devstack
scp $RUN_SH root@$CONTAINER_IP:$RUN_SH
ssh root@$CONTAINER_IP $RUN_SH
