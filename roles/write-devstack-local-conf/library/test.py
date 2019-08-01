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

    @staticmethod
    def _init_localconf(p):
        lc = LocalConf(p.get('localrc'),
                       p.get('local_conf'),
                       p.get('base_services'),
                       p.get('services'),
                       p.get('plugins'),
                       p.get('base_dir'),
                       p.get('projects'),
                       p.get('project'),
                       p.get('tempest_plugins'))
        return lc

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
            ('bar', 'https://git.openstack.org/openstack/bar-plugin'),
            ('foo', 'https://git.openstack.org/openstack/foo-plugin'),
            ('baz', 'https://git.openstack.org/openstack/baz-plugin'),
            ])
        p = dict(localrc=localrc,
                 local_conf=local_conf,
                 base_services=[],
                 services=services,
                 plugins=plugins,
                 base_dir='./test',
                 path=os.path.join(self.tmpdir, 'test.local.conf'))
        lc = self._init_localconf(p)
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
            f.write('define_plugin foo-plugin\n')
        with open(os.path.join(
                self.tmpdir,
                'bar-plugin', 'devstack', 'settings'), 'w') as f:
            f.write('define_plugin bar-plugin\n')
            f.write('plugin_requires bar-plugin foo-plugin\n')

        localrc = {'test_localrc': '1'}
        local_conf = {'install':
                      {'nova.conf':
                       {'main':
                        {'test_conf': '2'}}}}
        services = {'cinder': True}
        # We use ordereddict here to make sure the plugins are in the
        # *wrong* order for testing.
        plugins = OrderedDict([
            ('bar-plugin', 'https://git.openstack.org/openstack/bar-plugin'),
            ('foo-plugin', 'https://git.openstack.org/openstack/foo-plugin'),
            ])
        p = dict(localrc=localrc,
                 local_conf=local_conf,
                 base_services=[],
                 services=services,
                 plugins=plugins,
                 base_dir=self.tmpdir,
                 path=os.path.join(self.tmpdir, 'test.local.conf'))
        lc = self._init_localconf(p)
        lc.write(p['path'])

        plugins = []
        with open(p['path']) as f:
            for line in f:
                if line.startswith('enable_plugin'):
                    plugins.append(line.split()[1])
        self.assertEqual(['foo-plugin', 'bar-plugin'], plugins)

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
        lc = self._init_localconf(p)
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
        lc = self._init_localconf(p)
        lc.write(p['path'])

        lfg = None
        with open(p['path']) as f:
            for line in f:
                if line.startswith('LIBS_FROM_GIT'):
                    lfg = line.strip().split('=')[1]
        self.assertEqual('"oslo.db"', lfg)

    def test_avoid_double_quote(self):
        "Test that there a no duplicated quotes"
        localrc = {'TESTVAR': '"quoted value"'}
        p = dict(localrc=localrc,
                 base_services=[],
                 base_dir='./test',
                 path=os.path.join(self.tmpdir, 'test.local.conf'),
                 projects={})
        lc = self._init_localconf(p)
        lc.write(p['path'])

        testvar = None
        with open(p['path']) as f:
            for line in f:
                if line.startswith('TESTVAR'):
                    testvar = line.strip().split('=')[1]
        self.assertEqual('"quoted value"', testvar)

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
            ('bar', 'https://git.openstack.org/openstack/bar-plugin'),
            ('foo', 'https://git.openstack.org/openstack/foo-plugin'),
            ])
        p = dict(localrc=localrc,
                 local_conf=local_conf,
                 base_services=[],
                 services=services,
                 plugins=plugins,
                 base_dir=self.tmpdir,
                 path=os.path.join(self.tmpdir, 'test.local.conf'))
        with self.assertRaises(Exception):
            lc = self._init_localconf(p)
            lc.write(p['path'])

    def _find_tempest_plugins_value(self, file_path):
        tp = None
        with open(file_path) as f:
            for line in f:
                if line.startswith('TEMPEST_PLUGINS'):
                    found = line.strip().split('=')[1]
                    self.assertIsNone(tp,
                        "TEMPEST_PLUGIN ({}) found again ({})".format(
                            tp, found))
                    tp = found
        return tp

    def test_tempest_plugins(self):
        "Test that TEMPEST_PLUGINS is correctly populated."
        p = dict(base_services=[],
                 base_dir='./test',
                 path=os.path.join(self.tmpdir, 'test.local.conf'),
                 tempest_plugins=['heat-tempest-plugin', 'sahara-tests'])
        lc = self._init_localconf(p)
        lc.write(p['path'])

        tp = self._find_tempest_plugins_value(p['path'])
        self.assertEqual('"./test/heat-tempest-plugin ./test/sahara-tests"', tp)
        self.assertEqual(len(lc.warnings), 0)

    def test_tempest_plugins_not_overridden(self):
        """Test that the existing value of TEMPEST_PLUGINS is not overridden
        by the user-provided value, but a warning is emitted."""
        localrc = {'TEMPEST_PLUGINS': 'someplugin'}
        p = dict(localrc=localrc,
                 base_services=[],
                 base_dir='./test',
                 path=os.path.join(self.tmpdir, 'test.local.conf'),
                 tempest_plugins=['heat-tempest-plugin', 'sahara-tests'])
        lc = self._init_localconf(p)
        lc.write(p['path'])

        tp = self._find_tempest_plugins_value(p['path'])
        self.assertEqual('"someplugin"', tp)
        self.assertEqual(len(lc.warnings), 1)


if __name__ == '__main__':
    unittest.main()
