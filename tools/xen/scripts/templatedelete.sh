#!/bin/bash

#Usage: ./templatedelete.sh <template-uuid>

templateuuid="$1"

xe template-param-set other-config:default_template=false uuid="$templateuuid"
xe template-param-set is-a-template=false uuid="$templateuuid"
xe vm-destroy uuid="$templateuuid"
