#!/bin/bash
#
# Copyright (c) 2011 Citrix Systems, Inc.
# Copyright 2011 OpenStack Foundation
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

set -ex

# By default, don't remove the templates
REMOVE_TEMPLATES=${REMOVE_TEMPLATES:-"false"}
if [ "$1" = "--remove-templates" ]; then
  REMOVE_TEMPLATES=true
fi

xe_min()
{
  local cmd="$1"
  shift
  xe "$cmd" --minimal "$@"
}

destroy_vdi()
{
  local vbd_uuid="$1"
  local type=$(xe_min vbd-list uuid=$vbd_uuid params=type)
  local dev=$(xe_min vbd-list uuid=$vbd_uuid params=userdevice)
  local vdi_uuid=$(xe_min vbd-list uuid=$vbd_uuid params=vdi-uuid)

  if [ "$type" == 'Disk' ] && [ "$dev" != 'xvda' ] && [ "$dev" != '0' ]; then
    xe vdi-destroy uuid=$vdi_uuid
  fi
}

uninstall()
{
  local vm_uuid="$1"
  local power_state=$(xe_min vm-list uuid=$vm_uuid params=power-state)

  if [ "$power_state" != "halted" ]; then
    xe vm-shutdown vm=$vm_uuid force=true
  fi

  for v in $(xe_min vbd-list vm-uuid=$vm_uuid | sed -e 's/,/ /g'); do
    destroy_vdi "$v"
  done

  xe vm-uninstall vm=$vm_uuid force=true >/dev/null
}

uninstall_template()
{
  local vm_uuid="$1"

  for v in $(xe_min vbd-list vm-uuid=$vm_uuid | sed -e 's/,/ /g'); do
    destroy_vdi "$v"
  done

  xe template-uninstall template-uuid=$vm_uuid force=true >/dev/null
}

# remove the VMs and their disks
for u in $(xe_min vm-list other-config:os-vpx=true | sed -e 's/,/ /g'); do
  uninstall "$u"
done

# remove the templates
if [ "$REMOVE_TEMPLATES" == "true" ]; then
  for u in $(xe_min template-list other-config:os-vpx=true | sed -e 's/,/ /g'); do
    uninstall_template "$u"
  done
fi
