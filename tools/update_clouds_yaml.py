#!/usr/bin/env python3

# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# Update the clouds.yaml file.


import argparse
import os.path

import yaml


class UpdateCloudsYaml(object):
    def __init__(self, args):
        if args.file:
            self._clouds_path = args.file
            self._create_directory = False
        else:
            self._clouds_path = os.path.expanduser(
                '~/.config/openstack/clouds.yaml')
            self._create_directory = True
        self._clouds = {}

        self._cloud = args.os_cloud
        self._cloud_data = {
            'region_name': args.os_region_name,
            'identity_api_version': args.os_identity_api_version,
            'volume_api_version': args.os_volume_api_version,
            'auth': {
                'auth_url': args.os_auth_url,
                'username': args.os_username,
                'password': args.os_password,
            },
        }
        if args.os_project_name and args.os_system_scope:
            print(
                "WARNING: os_project_name and os_system_scope were both"
                " given. os_system_scope will take priority.")
        if args.os_project_name and not args.os_system_scope:
            self._cloud_data['auth']['project_name'] = args.os_project_name
        if args.os_identity_api_version == '3' and not args.os_system_scope:
            self._cloud_data['auth']['user_domain_id'] = 'default'
            self._cloud_data['auth']['project_domain_id'] = 'default'
        if args.os_system_scope:
            self._cloud_data['auth']['system_scope'] = args.os_system_scope
        if args.os_cacert:
            self._cloud_data['cacert'] = args.os_cacert

    def run(self):
        self._read_clouds()
        self._update_clouds()
        self._write_clouds()

    def _read_clouds(self):
        try:
            with open(self._clouds_path) as clouds_file:
                self._clouds = yaml.safe_load(clouds_file)
        except IOError:
            # The user doesn't have a clouds.yaml file.
            print("The user clouds.yaml file didn't exist.")
            self._clouds = {}

    def _update_clouds(self):
        self._clouds.setdefault('clouds', {})[self._cloud] = self._cloud_data

    def _write_clouds(self):

        if self._create_directory:
            clouds_dir = os.path.dirname(self._clouds_path)
            os.makedirs(clouds_dir)

        with open(self._clouds_path, 'w') as clouds_file:
            yaml.dump(self._clouds, clouds_file, default_flow_style=False)


def main():
    parser = argparse.ArgumentParser('Update clouds.yaml file.')
    parser.add_argument('--file')
    parser.add_argument('--os-cloud', required=True)
    parser.add_argument('--os-region-name', default='RegionOne')
    parser.add_argument('--os-identity-api-version', default='3')
    parser.add_argument('--os-volume-api-version', default='3')
    parser.add_argument('--os-cacert')
    parser.add_argument('--os-auth-url', required=True)
    parser.add_argument('--os-username', required=True)
    parser.add_argument('--os-password', required=True)
    parser.add_argument('--os-project-name')
    parser.add_argument('--os-system-scope')

    args = parser.parse_args()

    update_clouds_yaml = UpdateCloudsYaml(args)
    update_clouds_yaml.run()


if __name__ == "__main__":
    main()
