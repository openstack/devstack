# Copyright (C) 2017 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import shutil
import tempfile
import unittest

from devstack_local_conf import LocalConf
from collections import OrderedDict

class TestDevstackLocalConf(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_plugins(self):
        "Test that plugins without dependencies work"
        localrc = {'test_localrc': '1'}
        local_conf = {'install':
                      {'nova.conf':
                       {'main':
                        {'test_conf': '2'}}}}
        services = {'cinder': True}
        # We use ordereddict here to make sure the plugins are in the
        # *wrong* order for testing.
        plugins = OrderedDict([
            ('bar', 'git://git.openstack.org/openstack/bar-plugin'),
            ('foo', 'git://git.openstack.org/openstack/foo-plugin'),
            ('baz', 'git://git.openstack.org/openstack/baz-plugin'),
            ])
        p = dict(localrc=localrc,
                 local_conf=local_conf,
                 base_services=[],
                 services=services,
                 plugins=plugins,
                 base_dir='./test',
                 path=os.path.join(self.tmpdir, 'test.local.conf'))
        lc = LocalConf(p.get('localrc'),
                       p.get('local_conf'),
                       p.get('base_services'),
                       p.get('services'),
                       p.get('plugins'),
                       p.get('base_dir'),
                       p.get('projects'),
                       p.get('project'))
        lc.write(p['path'])

        plugins = []
        with open(p['path']) as f:
            for line in f:
                if line.startswith('enable_plugin'):
                    plugins.append(line.split()[1])
        self.assertEqual(['bar', 'baz', 'foo'], plugins)


    def test_plugin_deps(self):
        "Test that plugins with dependencies work"
        os.makedirs(os.path.join(self.tmpdir, 'foo-plugin', 'devstack'))
        os.makedirs(os.path.join(self.tmpdir, 'foo-plugin', '.git'))
        os.makedirs(os.path.join(self.tmpdir, 'bar-plugin', 'devstack'))
        os.makedirs(os.path.join(self.tmpdir, 'bar-plugin', '.git'))
        with open(os.path.join(
                self.tmpdir,
                'foo-plugin', 'devstack', 'settings'), 'w') as f:
            f.write('define_plugin foo\n')
        with open(os.path.join(
                self.tmpdir,
                'bar-plugin', 'devstack', 'settings'), 'w') as f:
            f.write('define_plugin bar\n')
            f.write('plugin_requires bar foo\n')

        localrc = {'test_localrc': '1'}
        local_conf = {'install':
                      {'nova.conf':
                       {'main':
                        {'test_conf': '2'}}}}
        services = {'cinder': True}
        # We use ordereddict here to make sure the plugins are in the
        # *wrong* order for testing.
        plugins = OrderedDict([
            ('bar', 'git://git.openstack.org/openstack/bar-plugin'),
            ('foo', 'git://git.openstack.org/openstack/foo-plugin'),
            ])
        p = dict(localrc=localrc,
                 local_conf=local_conf,
                 base_services=[],
                 services=services,
                 plugins=plugins,
                 base_dir=self.tmpdir,
                 path=os.path.join(self.tmpdir, 'test.local.conf'))

    def test_libs_from_git(self):
        "Test that LIBS_FROM_GIT is auto-generated"
        projects = {
            'git.openstack.org/openstack/nova': {
                'required': True,
                'short_name': 'nova',
            },
            'git.openstack.org/openstack/oslo.messaging': {
                'required': True,
                'short_name': 'oslo.messaging',
            },
            'git.openstack.org/openstack/devstack-plugin': {
                'required': False,
                'short_name': 'devstack-plugin',
            },
        }
        project = {
            'short_name': 'glance',
        }
        p = dict(base_services=[],
                 base_dir='./test',
                 path=os.path.join(self.tmpdir, 'test.local.conf'),
                 projects=projects,
                 project=project)
        lc = LocalConf(p.get('localrc'),
                       p.get('local_conf'),
                       p.get('base_services'),
                       p.get('services'),
                       p.get('plugins'),
                       p.get('base_dir'),
                       p.get('projects'),
                       p.get('project'))
        lc.write(p['path'])

        lfg = None
        with open(p['path']) as f:
            for line in f:
                if line.startswith('LIBS_FROM_GIT'):
                    lfg = line.strip().split('=')[1]
        self.assertEqual('nova,oslo.messaging,glance', lfg)

    def test_overridelibs_from_git(self):
        "Test that LIBS_FROM_GIT can be overridden"
        localrc = {'LIBS_FROM_GIT': 'oslo.db'}
        projects = {
            'git.openstack.org/openstack/nova': {
                'required': True,
                'short_name': 'nova',
            },
            'git.openstack.org/openstack/oslo.messaging': {
                'required': True,
                'short_name': 'oslo.messaging',
            },
            'git.openstack.org/openstack/devstack-plugin': {
                'required': False,
                'short_name': 'devstack-plugin',
            },
        }
        p = dict(localrc=localrc,
                 base_services=[],
                 base_dir='./test',
                 path=os.path.join(self.tmpdir, 'test.local.conf'),
                 projects=projects)
        lc = LocalConf(p.get('localrc'),
                       p.get('local_conf'),
                       p.get('base_services'),
                       p.get('services'),
                       p.get('plugins'),
                       p.get('base_dir'),
                       p.get('projects'),
                       p.get('project'))
        lc.write(p['path'])

        lfg = None
        with open(p['path']) as f:
            for line in f:
                if line.startswith('LIBS_FROM_GIT'):
                    lfg = line.strip().split('=')[1]
        self.assertEqual('oslo.db', lfg)

    def test_plugin_circular_deps(self):
        "Test that plugins with circular dependencies fail"
        os.makedirs(os.path.join(self.tmpdir, 'foo-plugin', 'devstack'))
        os.makedirs(os.path.join(self.tmpdir, 'foo-plugin', '.git'))
        os.makedirs(os.path.join(self.tmpdir, 'bar-plugin', 'devstack'))
        os.makedirs(os.path.join(self.tmpdir, 'bar-plugin', '.git'))
        with open(os.path.join(
                self.tmpdir,
                'foo-plugin', 'devstack', 'settings'), 'w') as f:
            f.write('define_plugin foo\n')
            f.write('plugin_requires foo bar\n')
        with open(os.path.join(
                self.tmpdir,
                'bar-plugin', 'devstack', 'settings'), 'w') as f:
            f.write('define_plugin bar\n')
            f.write('plugin_requires bar foo\n')

        localrc = {'test_localrc': '1'}
        local_conf = {'install':
                      {'nova.conf':
                       {'main':
                        {'test_conf': '2'}}}}
        services = {'cinder': True}
        # We use ordereddict here to make sure the plugins are in the
        # *wrong* order for testing.
        plugins = OrderedDict([
            ('bar', 'git://git.openstack.org/openstack/bar-plugin'),
            ('foo', 'git://git.openstack.org/openstack/foo-plugin'),
            ])
        p = dict(localrc=localrc,
                 local_conf=local_conf,
                 base_services=[],
                 services=services,
                 plugins=plugins,
                 base_dir=self.tmpdir,
                 path=os.path.join(self.tmpdir, 'test.local.conf'))
        with self.assertRaises(Exception):
            lc = LocalConf(p.get('localrc'),
                           p.get('local_conf'),
                           p.get('base_services'),
                           p.get('services'),
                           p.get('plugins'),
                           p.get('base_dir'))
            lc.write(p['path'])


if __name__ == '__main__':
    unittest.main()
