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

[[ -f "/etc/xensource-inventory" ]] && source "/etc/xensource-inventory" || source "/etc/xcp/inventory"

NAME="XenServer OpenStack VPX"
DATA_VDI_SIZE="500MiB"
BRIDGE_M=
BRIDGE_P=
VPX_FILE=os-vpx.xva
AS_TEMPLATE=
FROM_TEMPLATE=
RAM=
WAIT_FOR_NETWORK=
BALLOONING=

usage()
{
cat << EOF

  Usage: $0 [-f FILE_PATH] [-d DISK_SIZE] [-v BRIDGE_NAME] [-m BRIDGE_NAME] [-p BRIDGE_NAME]
            [-r RAM] [-i|-c] [-w] [-b] [-l NAME_LABEL] [-t TEMPLATE_NW_INSTALL]

  Installs XenServer OpenStack VPX.

  OPTIONS:

     -h           Shows this message.
     -i           Install OpenStack VPX as template.
     -c           Clone from existing template.
     -w           Wait for the network settings to show up before exiting.
     -b           Enable memory ballooning. When set min_RAM=RAM/2 max_RAM=RAM.
     -f path      Specifies the path to the XVA.
                  Default to ./os-vpx.xva.
     -d disk-size Specifies the size in MiB for the data disk.
                  Defaults to 500 MiB.
     -m bridge    Specifies the bridge for the isolated management network.
                  Defaults to xenbr0.
     -v bridge    Specifies the bridge for the vm network
     -p bridge    Specifies the bridge for the externally facing network.
     -r MiB       Specifies RAM used by the VPX, in MiB.
                  By default it will take the value from the XVA.
     -l name      Specifies the name label for the VM.
     -t template  Network install an openstack domU from this template

  EXAMPLES:

     Create a VPX that connects to the isolated management network using the
     default bridge with a data disk of 1GiB:
            install-os-vpx.sh -f /root/os-vpx-devel.xva -d 1024

     Create a VPX that connects to the isolated management network using xenbr1
     as bridge:
            install-os-vpx.sh -m xenbr1

     Create a VPX that connects to both the management and public networks
     using xenbr1 and xapi4 as bridges:
            install-os-vpx.sh -m xenbr1 -p xapi4

     Create a VPX that connects to both the management and public networks
     using the default for management traffic:
            install-os-vpx.sh -m xapi4

EOF
}

get_params()
{
  while getopts "hicwbf:d:v:m:p:r:l:t:" OPTION;
  do
    case $OPTION in
      h) usage
         exit 1
         ;;
      i)
         AS_TEMPLATE=1
         ;;
      c)
         FROM_TEMPLATE=1
         ;;
      w)
         WAIT_FOR_NETWORK=1
         ;;
      b)
         BALLOONING=1
         ;;
      f)
         VPX_FILE=$OPTARG
         ;;
      d)
         DATA_VDI_SIZE="${OPTARG}MiB"
         ;;
      m)
         BRIDGE_M=$OPTARG
         ;;
      p)
         BRIDGE_P=$OPTARG
         ;;
      r)
         RAM=$OPTARG
         ;;
      v)
         BRIDGE_V=$OPTARG
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
  if [[ -z $BRIDGE_M ]]
  then
     BRIDGE_M=xenbr0
  fi
}


xe_min()
{
  local cmd="$1"
  shift
  xe "$cmd" --minimal "$@"
}


get_dest_sr()
{
  IFS=,
  sr_uuids=$(xe sr-list --minimal other-config:i18n-key=local-storage)
  dest_sr=""
  for sr_uuid in $sr_uuids
  do
    pbd=$(xe pbd-list --minimal sr-uuid=$sr_uuid host-uuid=$INSTALLATION_UUID)
    if [ "$pbd" ]
    then
      echo "$sr_uuid"
      unset IFS
      return
    fi
  done
  unset IFS

  dest_sr=$(xe_min sr-list uuid=$(xe_min pool-list params=default-SR))
  if [ "$dest_sr" = "" ]
  then
    echo "No local storage and no default storage; cannot import VPX." >&2
    exit 1
  else
    echo "$dest_sr"
  fi
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


find_template()
{
  xe_min template-list other-config:os-vpx=true
}


renumber_system_disk()
{
  local v="$1"
  local vdi_uuid=$(xe_min vbd-list vm-uuid="$v" type=Disk userdevice=xvda \
                                   params=vdi-uuid)
  if [ "$vdi_uuid" ]
  then
    local vbd_uuid=$(xe_min vbd-list vm-uuid="$v" vdi-uuid="$vdi_uuid")
    xe vbd-destroy uuid="$vbd_uuid"
    local new_vbd_uuid=$(xe vbd-create vm-uuid="$v" vdi-uuid="$vdi_uuid" \
                         device=0 bootable=true type=Disk)
    xe vbd-param-set other-config:owner uuid="$new_vbd_uuid"
  fi
}


create_vif()
{
  xe vif-create vm-uuid="$1" network-uuid="$2" device="$3"
}

create_gi_vif()
{
  local v="$1"
  # Note that we've made the outbound device eth1, so that it comes up after
  # the guest installer VIF, which means that the outbound one wins in terms
  # of gateway.
  local gi_network_uuid=$(xe_min network-list \
                                 other-config:is_guest_installer_network=true)
  create_vif "$v" "$gi_network_uuid" "0" >/dev/null
}

create_vm_vif()
{
  local v="$1"
  echo "Installing VM interface on $BRIDGE_V."
  local out_network_uuid=$(find_network "$BRIDGE_V")
  create_vif "$v" "$out_network_uuid" "1" >/dev/null
}

create_management_vif()
{
  local v="$1"
  echo "Installing management interface on $BRIDGE_M."
  local out_network_uuid=$(find_network "$BRIDGE_M")
  create_vif "$v" "$out_network_uuid" "2" >/dev/null
}


# This installs the interface for public traffic, only if a bridge is specified
# The interface is not configured at this stage, but it will be, once the admin
# tasks are complete for the services of this VPX
create_public_vif()
{
  local v="$1"
  if [[ -z $BRIDGE_P ]]
  then
    echo "Skipping installation of interface for public traffic."
  else
    echo "Installing public interface on $BRIDGE_P."
    pub_network_uuid=$(find_network "$BRIDGE_P")
    create_vif "$v" "$pub_network_uuid" "3" >/dev/null
  fi
}


label_system_disk()
{
  local v="$1"
  local vdi_uuid=$(xe_min vbd-list vm-uuid="$v" type=Disk userdevice=0 \
                                   params=vdi-uuid)
  xe vdi-param-set \
     name-label="$NAME system disk" \
     other-config:os-vpx=true \
     uuid=$vdi_uuid
}


create_data_disk()
{
  local v="$1"

  local sys_vdi_uuid=$(xe_min vbd-list vm-uuid="$v" type=Disk params=vdi-uuid)
  local data_vdi_uuid=$(xe_min vdi-list other-config:os-vpx-data=true)

  if echo "$data_vdi_uuid" | grep -q ,
  then
    echo "Multiple data disks found -- assuming that you want a new one."
    data_vdi_uuid=""
  else
    data_in_use=$(xe_min vbd-list vdi-uuid="$data_vdi_uuid")
    if [ "$data_in_use" != "" ]
    then
      echo "Data disk already in use -- will create another one."
      data_vdi_uuid=""
    fi
  fi

  if [ "$data_vdi_uuid" = "" ]
  then
    echo -n "Creating new data disk ($DATA_VDI_SIZE)... "
    sr_uuid=$(xe_min vdi-list params=sr-uuid uuid="$sys_vdi_uuid")
    data_vdi_uuid=$(xe vdi-create name-label="$NAME data disk" \
                                  sr-uuid="$sr_uuid" \
                                  type=user \
                                  virtual-size="$DATA_VDI_SIZE")
    xe vdi-param-set \
       other-config:os-vpx-data=true \
       uuid="$data_vdi_uuid"
    dom0_uuid=$(xe_min vm-list is-control-domain=true)
    vbd_uuid=$(xe vbd-create device=autodetect type=Disk \
                             vdi-uuid="$data_vdi_uuid" vm-uuid="$dom0_uuid")
    xe vbd-plug uuid=$vbd_uuid
    dev=$(xe_min vbd-list params=device uuid=$vbd_uuid)
    mke2fs -q -j -m0 /dev/$dev
    e2label /dev/$dev vpxstate
    xe vbd-unplug uuid=$vbd_uuid
    xe vbd-destroy uuid=$vbd_uuid
  else
    echo -n "Attaching old data disk... "
  fi
  vbd_uuid=$(xe vbd-create device=2 type=Disk \
                           vdi-uuid="$data_vdi_uuid" vm-uuid="$v")
  xe vbd-param-set other-config:os-vpx-data=true uuid=$vbd_uuid
  echo "done."
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


set_all()
{
  local v="$1"
  set_memory "$v"
  set_auto_start "$v"
  label_system_disk "$v"
  create_gi_vif "$v"
  create_vm_vif "$v"
  create_management_vif "$v"
  create_public_vif "$v"
}


log_vifs()
{
  local v="$1"

  (IFS=,
   for vif in $(xe_min vif-list vm-uuid="$v")
   do
    dev=$(xe_min vif-list uuid="$vif" params=device)
    mac=$(xe_min vif-list uuid="$vif" params=MAC | sed -e 's/:/-/g')
    echo "eth$dev has MAC $mac."
   done
   unset IFS) | sort
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

thisdir=$(dirname "$0")

if [ "$FROM_TEMPLATE" ]
then
  template_uuid=$(find_template)
  name=$(xe_min template-list params=name-label uuid="$template_uuid")
  echo -n "Cloning $name... "
  vm_uuid=$(xe vm-clone vm="$template_uuid" new-name-label="$name")
  xe vm-param-set is-a-template=false uuid="$vm_uuid"
  echo $vm_uuid.

  destroy_vifs "$vm_uuid"
  set_all "$vm_uuid"
elif [ "$TEMPLATE_NAME" ]
then
  echo $TEMPLATE_NAME
  vm_uuid=$(xe_min vm-install template="$TEMPLATE_NAME" new-name-label="$NAME_LABEL")
  destroy_vifs "$vm_uuid"
  set_auto_start "$vm_uuid"
  create_gi_vif "$vm_uuid"
  create_vm_vif "$vm_uuid"
  create_management_vif "$vm_uuid"
  create_public_vif "$vm_uuid"
  xe vm-param-set other-config:os-vpx=true uuid="$vm_uuid"
  xe vm-param-set actions-after-reboot=Destroy uuid="$vm_uuid"
  set_memory "$vm_uuid"
else
  if [ ! -f "$VPX_FILE" ]
  then
      # Search $thisdir/$VPX_FILE too.  In particular, this is used when
      # installing the VPX from the supp-pack, because we want to be able to
      # invoke this script from the RPM and the firstboot script.
      if [ -f "$thisdir/$VPX_FILE" ]
      then
          VPX_FILE="$thisdir/$VPX_FILE"
      else
          echo "$VPX_FILE does not exist." >&2
          exit 1
      fi
  fi

  echo "Found OS-VPX File: $VPX_FILE. "

  dest_sr=$(get_dest_sr)

  echo -n "Installing $NAME... "
  vm_uuid=$(xe vm-import filename=$VPX_FILE sr-uuid="$dest_sr")
  echo $vm_uuid.

  renumber_system_disk "$vm_uuid"

  nl=${NAME_LABEL:-$(xe_min vm-list params=name-label uuid=$vm_uuid)}
  xe vm-param-set \
    "name-label=${nl/ import/}" \
    other-config:os-vpx=true \
    uuid=$vm_uuid

  set_all "$vm_uuid"
  create_data_disk "$vm_uuid"

  if [ "$AS_TEMPLATE" ]
  then
    xe vm-param-set uuid="$vm_uuid" is-a-template=true \
                                    other-config:instant=true
    echo -n "Installing VPX from template... "
    vm_uuid=$(xe vm-clone vm="$vm_uuid" new-name-label="${nl/ import/}")
    xe vm-param-set is-a-template=false uuid="$vm_uuid"
    echo "$vm_uuid."
  fi
fi


log_vifs "$vm_uuid"

echo -n "Starting VM... "
xe vm-start uuid=$vm_uuid
echo "done."


show_ip()
{
  ip_addr=$(echo "$1" | sed -n "s,^.*"$2"/ip: \([^;]*\).*$,\1,p")
  echo -n "IP address for $3: "
  if [ "$ip_addr" = "" ]
  then
    echo "did not appear."
  else
    echo "$ip_addr."
  fi
}


if [ "$WAIT_FOR_NETWORK" ]
then
  echo "Waiting for network configuration... "
  i=0
  while [ $i -lt 600 ]
  do
    ip=$(xe_min vm-list params=networks uuid=$vm_uuid)
    if [ "$ip" != "<not in database>" ]
    then
      show_ip "$ip" "1" "$BRIDGE_M"
      if [[ $BRIDGE_P ]]
      then
        show_ip "$ip" "2" "$BRIDGE_P"
      fi
      echo "Installation complete."
      exit 0
    fi
    sleep 10
    let i=i+1
  done
fi
