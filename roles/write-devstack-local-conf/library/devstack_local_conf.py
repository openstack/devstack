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
import re


class DependencyGraph(object):
    # This is based on the JobGraph from Zuul.

    def __init__(self):
        self._names = set()
        self._dependencies = {}  # dependent_name -> set(parent_names)

    def add(self, name, dependencies):
        # Append the dependency information
        self._dependencies.setdefault(name, set())
        try:
            for dependency in dependencies:
                # Make sure a circular dependency is never created
                ancestors = self._getParentNamesRecursively(
                    dependency, soft=True)
                ancestors.add(dependency)
                if name in ancestors:
                    raise Exception("Dependency cycle detected in {}".
                                    format(name))
                self._dependencies[name].add(dependency)
        except Exception:
            del self._dependencies[name]
            raise

    def getDependenciesRecursively(self, parent):
        dependencies = []

        current_dependencies = self._dependencies[parent]
        for current in current_dependencies:
            if current not in dependencies:
                dependencies.append(current)
            for dep in self.getDependenciesRecursively(current):
                if dep not in dependencies:
                    dependencies.append(dep)
        return dependencies

    def _getParentNamesRecursively(self, dependent, soft=False):
        all_parent_items = set()
        items_to_iterate = set([dependent])
        while len(items_to_iterate) > 0:
            current_item = items_to_iterate.pop()
            current_parent_items = self._dependencies.get(current_item)
            if current_parent_items is None:
                if soft:
                    current_parent_items = set()
                else:
                    raise Exception("Dependent item {} not found: ".format(
                                    dependent))
            new_parent_items = current_parent_items - all_parent_items
            items_to_iterate |= new_parent_items
            all_parent_items |= new_parent_items
        return all_parent_items


class VarGraph(DependencyGraph):
    def __init__(self, vars):
        super(VarGraph, self).__init__()
        self.vars = {}
        self._varnames = set()
        for k, v in vars.items():
            self._varnames.add(k)
        for k, v in vars.items():
            self._addVar(k, str(v))

    bash_var_re = re.compile(r'\$\{?(\w+)')
    def getDependencies(self, value):
        return self.bash_var_re.findall(value)

    def _addVar(self, key, value):
        if key in self.vars:
            raise Exception("Variable {} already added".format(key))
        self.vars[key] = value
        # Append the dependency information
        dependencies = set()
        for dependency in self.getDependencies(value):
            if dependency == key:
                # A variable is allowed to reference itself; no
                # dependency link needed in that case.
                continue
            if dependency not in self._varnames:
                # It's not necessary to create a link for an
                # external variable.
                continue
            dependencies.add(dependency)
        try:
            self.add(key, dependencies)
        except Exception:
            del self.vars[key]
            raise

    def getVars(self):
        ret = []
        keys = sorted(self.vars.keys())
        seen = set()
        for key in keys:
            dependencies = self.getDependenciesRecursively(key)
            for var in dependencies + [key]:
                if var not in seen:
                    ret.append((var, self.vars[var]))
                    seen.add(var)
        return ret


class PluginGraph(DependencyGraph):
    def __init__(self, base_dir, plugins):
        super(PluginGraph, self).__init__()
        # The dependency trees expressed by all the plugins we found
        # (which may be more than those the job is using).
        self._plugin_dependencies = {}
        self.loadPluginNames(base_dir)

        self.plugins = {}
        self._pluginnames = set()
        for k, v in plugins.items():
            self._pluginnames.add(k)
        for k, v in plugins.items():
            self._addPlugin(k, str(v))

    def loadPluginNames(self, base_dir):
        if base_dir is None:
            return
        git_roots = []
        for root, dirs, files in os.walk(base_dir):
            if '.git' not in dirs:
                continue
            # Don't go deeper than git roots
            dirs[:] = []
            git_roots.append(root)
        for root in git_roots:
            devstack = os.path.join(root, 'devstack')
            if not (os.path.exists(devstack) and os.path.isdir(devstack)):
                continue
            settings = os.path.join(devstack, 'settings')
            if not (os.path.exists(settings) and os.path.isfile(settings)):
                continue
            self.loadDevstackPluginInfo(settings)

    define_re = re.compile(r'^define_plugin\s+(\w+).*')
    require_re = re.compile(r'^plugin_requires\s+(\w+)\s+(\w+).*')
    def loadDevstackPluginInfo(self, fn):
        name = None
        reqs = set()
        with open(fn) as f:
            for line in f:
                m = self.define_re.match(line)
                if m:
                    name = m.group(1)
                m = self.require_re.match(line)
                if m:
                    if name == m.group(1):
                        reqs.add(m.group(2))
        if name and reqs:
            self._plugin_dependencies[name] = reqs

    def getDependencies(self, value):
        return self._plugin_dependencies.get(value, [])

    def _addPlugin(self, key, value):
        if key in self.plugins:
            raise Exception("Plugin {} already added".format(key))
        self.plugins[key] = value
        # Append the dependency information
        dependencies = set()
        for dependency in self.getDependencies(key):
            if dependency == key:
                continue
            dependencies.add(dependency)
        try:
            self.add(key, dependencies)
        except Exception:
            del self.plugins[key]
            raise

    def getPlugins(self):
        ret = []
        keys = sorted(self.plugins.keys())
        seen = set()
        for key in keys:
            dependencies = self.getDependenciesRecursively(key)
            for plugin in dependencies + [key]:
                if plugin not in seen:
                    ret.append((plugin, self.plugins[plugin]))
                    seen.add(plugin)
        return ret


class LocalConf(object):

    def __init__(self, localrc, localconf, base_services, services, plugins,
                 base_dir, projects, project):
        self.localrc = []
        self.meta_sections = {}
        self.plugin_deps = {}
        self.base_dir = base_dir
        self.projects = projects
        self.project = project
        if plugins:
            self.handle_plugins(plugins)
        if services or base_services:
            self.handle_services(base_services, services or {})
        self.handle_localrc(localrc)
        if localconf:
            self.handle_localconf(localconf)

    def handle_plugins(self, plugins):
        pg = PluginGraph(self.base_dir, plugins)
        for k, v in pg.getPlugins():
            if v:
                self.localrc.append('enable_plugin {} {}'.format(k, v))

    def handle_services(self, base_services, services):
        enable_base_services = services.pop('base', True)
        if enable_base_services and base_services:
            self.localrc.append('ENABLED_SERVICES={}'.format(
                ",".join(base_services)))
        else:
            self.localrc.append('disable_all_services')
        for k, v in services.items():
            if v is False:
                self.localrc.append('disable_service {}'.format(k))
            elif v is True:
                self.localrc.append('enable_service {}'.format(k))

    def handle_localrc(self, localrc):
        lfg = False
        if localrc:
            vg = VarGraph(localrc)
            for k, v in vg.getVars():
                self.localrc.append('{}={}'.format(k, v))
                if k == 'LIBS_FROM_GIT':
                    lfg = True

        if not lfg and (self.projects or self.project):
            required_projects = []
            if self.projects:
                for project_name, project_info in self.projects.items():
                    if project_info.get('required'):
                        required_projects.append(project_info['short_name'])
            if self.project:
                if self.project['short_name'] not in required_projects:
                    required_projects.append(self.project['short_name'])
            if required_projects:
                self.localrc.append('LIBS_FROM_GIT={}'.format(
                    ','.join(required_projects)))

    def handle_localconf(self, localconf):
        for phase, phase_data in localconf.items():
            for fn, fn_data in phase_data.items():
                ms_name = '[[{}|{}]]'.format(phase, fn)
                ms_data = []
                for section, section_data in fn_data.items():
                    ms_data.append('[{}]'.format(section))
                    for k, v in section_data.items():
                        ms_data.append('{} = {}'.format(k, v))
                    ms_data.append('')
                self.meta_sections[ms_name] = ms_data

    def write(self, path):
        with open(path, 'w') as f:
            f.write('[[local|localrc]]\n')
            f.write('\n'.join(self.localrc))
            f.write('\n\n')
            for section, lines in self.meta_sections.items():
                f.write('{}\n'.format(section))
                f.write('\n'.join(lines))


def main():
    module = AnsibleModule(
        argument_spec=dict(
            plugins=dict(type='dict'),
            base_services=dict(type='list'),
            services=dict(type='dict'),
            localrc=dict(type='dict'),
            local_conf=dict(type='dict'),
            base_dir=dict(type='path'),
            path=dict(type='str'),
            projects=dict(type='dict'),
            project=dict(type='dict'),
        )
    )

    p = module.params
    lc = LocalConf(p.get('localrc'),
                   p.get('local_conf'),
                   p.get('base_services'),
                   p.get('services'),
                   p.get('plugins'),
                   p.get('base_dir'),
                   p.get('projects'),
                   p.get('project'))
    lc.write(p['path'])

    module.exit_json()


try:
    from ansible.module_utils.basic import *  # noqa
    from ansible.module_utils.basic import AnsibleModule
except ImportError:
    pass

if __name__ == '__main__':
    main()
