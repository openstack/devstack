#!/bin/bash
#
# Copyright (c) 2011 Citrix Systems, Inc.
# Copyright 2011 OpenStack LLC.
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#

set -eux

BRIDGE=
RAM=
BALLOONING=
NAME_LABEL=
TEMPLATE_NAME=

usage()
{
cat << EOF

  Usage: $0 -t TEMPLATE_NW_INSTALL -l NAME_LABEL [-n BRIDGE] [-r RAM] [-b] 

  Install a VM from a template

  OPTIONS:

     -h           Shows this message.
     -t template  VM template to use
     -b           Enable memory ballooning. When set min_RAM=RAM/2 max_RAM=RAM.
     -r MiB       Specifies RAM used by the VPX, in MiB.
                  By default it will take the value from the XVA.
     -l name      Specifies the name label for the VM.
     -n bridge    The bridge/network to use for eth0. Defaults to xenbr0
EOF
}

get_params()
{
  while getopts "hbn:r:l:t:" OPTION;
  do
    case $OPTION in
      h) usage
         exit 1
         ;;
      b)
         BALLOONING=1
         ;;
      r)
         RAM=$OPTARG
         ;;
      n)
         BRIDGE=$OPTARG
         ;;
      l)
         NAME_LABEL=$OPTARG
         ;;
      t)
         TEMPLATE_NAME=$OPTARG
         ;;
      ?)
         usage
         exit
         ;;
    esac
  done
  if [[ -z $BRIDGE ]]
  then
     BRIDGE=xenbr0
  fi

  if [[ -z $TEMPLATE_NAME ]]; then
    echo "Please specify a template name" >&2
    exit 1
  fi

  if [[ -z $NAME_LABEL ]]; then
    echo "Please specify a name-label for the new VM" >&2
    exit 1
  fi
}


xe_min()
{
  local cmd="$1"
  shift
  xe "$cmd" --minimal "$@"
}


find_network()
{
  result=$(xe_min network-list bridge="$1")
  if [ "$result" = "" ]
  then
    result=$(xe_min network-list name-label="$1")
  fi
  echo "$result"
}


create_vif()
{
  local v="$1"
  echo "Installing VM interface on [$BRIDGE]"
  local out_network_uuid=$(find_network "$BRIDGE")
  xe vif-create vm-uuid="$v" network-uuid="$out_network_uuid" device="0"
}


set_memory()
{
  local v="$1"
  if [ "$RAM" != "" ]
  then
    echo "Setting RAM to $RAM MiB."
    [ "$BALLOONING" == 1 ] && RAM_MIN=$(($RAM / 2)) || RAM_MIN=$RAM
    xe vm-memory-limits-set static-min=16MiB static-max=${RAM}MiB \
                            dynamic-min=${RAM_MIN}MiB dynamic-max=${RAM}MiB \
                            uuid="$v"
  fi
}


# Make the VM auto-start on server boot.
set_auto_start()
{
  local v="$1"
  xe vm-param-set uuid="$v" other-config:auto_poweron=true
}


destroy_vifs()
{
  local v="$1"
  IFS=,
  for vif in $(xe_min vif-list vm-uuid="$v")
  do
    xe vif-destroy uuid="$vif"
  done
  unset IFS
}


get_params "$@"

vm_uuid=$(xe_min vm-install template="$TEMPLATE_NAME" new-name-label="$NAME_LABEL")
destroy_vifs "$vm_uuid"
set_auto_start "$vm_uuid"
create_vif "$vm_uuid"
xe vm-param-set other-config:os-vpx=true uuid="$vm_uuid"
xe vm-param-set actions-after-reboot=Destroy uuid="$vm_uuid"
set_memory "$vm_uuid"
xe vm-start uuid=$vm_uuid
