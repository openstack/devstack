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

import re


class VarGraph(object):
    # This is based on the JobGraph from Zuul.

    def __init__(self, vars):
        self.vars = {}
        self._varnames = set()
        self._dependencies = {}  # dependent_var_name -> set(parent_var_names)
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
        self._dependencies.setdefault(key, set())
        try:
            for dependency in self.getDependencies(value):
                if dependency == key:
                    # A variable is allowed to reference itself; no
                    # dependency link needed in that case.
                    continue
                if dependency not in self._varnames:
                    # It's not necessary to create a link for an
                    # external variable.
                    continue
                # Make sure a circular dependency is never created
                ancestor_vars = self._getParentVarNamesRecursively(
                    dependency, soft=True)
                ancestor_vars.add(dependency)
                if any((key == anc_var) for anc_var in ancestor_vars):
                    raise Exception("Dependency cycle detected in var {}".
                                    format(key))
                self._dependencies[key].add(dependency)
        except Exception:
            del self.vars[key]
            del self._dependencies[key]
            raise

    def getVars(self):
        ret = []
        keys = sorted(self.vars.keys())
        seen = set()
        for key in keys:
            dependencies = self.getDependentVarsRecursively(key)
            for var in dependencies + [key]:
                if var not in seen:
                    ret.append((var, self.vars[var]))
                    seen.add(var)
        return ret

    def getDependentVarsRecursively(self, parent_var):
        dependent_vars = []

        current_dependent_vars = self._dependencies[parent_var]
        for current_var in current_dependent_vars:
            if current_var not in dependent_vars:
                dependent_vars.append(current_var)
            for dep in self.getDependentVarsRecursively(current_var):
                if dep not in dependent_vars:
                    dependent_vars.append(dep)
        return dependent_vars

    def _getParentVarNamesRecursively(self, dependent_var, soft=False):
        all_parent_vars = set()
        vars_to_iterate = set([dependent_var])
        while len(vars_to_iterate) > 0:
            current_var = vars_to_iterate.pop()
            current_parent_vars = self._dependencies.get(current_var)
            if current_parent_vars is None:
                if soft:
                    current_parent_vars = set()
                else:
                    raise Exception("Dependent var {} not found: ".format(
                                    dependent_var))
            new_parent_vars = current_parent_vars - all_parent_vars
            vars_to_iterate |= new_parent_vars
            all_parent_vars |= new_parent_vars
        return all_parent_vars


class LocalConf(object):

    def __init__(self, localrc, localconf, base_services, services, plugins):
        self.localrc = []
        self.meta_sections = {}
        if plugins:
            self.handle_plugins(plugins)
        if services or base_services:
            self.handle_services(base_services, services or {})
        if localrc:
            self.handle_localrc(localrc)
        if localconf:
            self.handle_localconf(localconf)

    def handle_plugins(self, plugins):
        for k, v in plugins.items():
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
        vg = VarGraph(localrc)
        for k, v in vg.getVars():
            self.localrc.append('{}={}'.format(k, v))

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
            path=dict(type='str'),
        )
    )

    p = module.params
    lc = LocalConf(p.get('localrc'),
                   p.get('local_conf'),
                   p.get('base_services'),
                   p.get('services'),
                   p.get('plugins'))
    lc.write(p['path'])

    module.exit_json()


from ansible.module_utils.basic import *  # noqa
from ansible.module_utils.basic import AnsibleModule

if __name__ == '__main__':
    main()
