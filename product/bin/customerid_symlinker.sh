#!/system/bin/sh

# Copyright (C) 2020 Sony Mobile Communications Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# NOTE: This file has been modified by Sony Mobile Communications Inc.
# Modifications are licensed under the License.

# Create Symbolic links to switch attribution files

device_provisioned="$(/system/bin/getprop persist.sys.device_provisioned)"
if [ $# -eq 1 ] && [ -z $device_provisioned ]; then
  partition=$1

  customer_id="$(/system/bin/getprop ro.somc.customerid2)"
  src_dir="/data/customization"
  default_cust_dir="${partition}/etc/customization/defaults/symlink"
  if [ -n "${customer_id}" ]; then
    cust_dir="${partition}/etc/customization/${customer_id}/symlink"
  else
    cust_dir="${default_cust_dir}"
  fi

  for filename in `find ${default_cust_dir} -maxdepth 1 -type f`; do
    # Create symbolic link
    basefile="$(basename $filename)"
    src_file="${src_dir}/${basefile}"
    dest_file="${cust_dir}/${basefile}"
    default_dest_file="${default_cust_dir}/${basefile}"
    if [ -e "${dest_file}" ]; then
        /system/bin/ln -s "${dest_file}" "${src_file}"
    else
        /system/bin/ln -s "${default_dest_file}" "${src_file}"
    fi
  done
fi
