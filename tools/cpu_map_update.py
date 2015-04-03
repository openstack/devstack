#!/usr/bin/env python
#
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

# This small script updates the libvirt CPU map to add a gate64 cpu model
# that can be used to enable a common 64bit capable feature set across
# devstack nodes so that features like nova live migration work.

import sys
import xml.etree.ElementTree as ET
from xml.dom import minidom


def update_cpu_map(tree):
    root = tree.getroot()
    cpus = root#.find("cpus")
    x86 = None
    for arch in cpus.findall("arch"):
        if arch.get("name") == "x86":
            x86 = arch
            break
    if x86 is not None:
        # Create a gate64 cpu model that is core2duo less monitor and pse36
        gate64 = ET.SubElement(x86, "model")
        gate64.set("name", "gate64")
        ET.SubElement(gate64, "vendor").set("name", "Intel")
        ET.SubElement(gate64, "feature").set("name", "fpu")
        ET.SubElement(gate64, "feature").set("name", "de")
        ET.SubElement(gate64, "feature").set("name", "pse")
        ET.SubElement(gate64, "feature").set("name", "tsc")
        ET.SubElement(gate64, "feature").set("name", "msr")
        ET.SubElement(gate64, "feature").set("name", "pae")
        ET.SubElement(gate64, "feature").set("name", "mce")
        ET.SubElement(gate64, "feature").set("name", "cx8")
        ET.SubElement(gate64, "feature").set("name", "apic")
        ET.SubElement(gate64, "feature").set("name", "sep")
        ET.SubElement(gate64, "feature").set("name", "pge")
        ET.SubElement(gate64, "feature").set("name", "cmov")
        ET.SubElement(gate64, "feature").set("name", "pat")
        ET.SubElement(gate64, "feature").set("name", "mmx")
        ET.SubElement(gate64, "feature").set("name", "fxsr")
        ET.SubElement(gate64, "feature").set("name", "sse")
        ET.SubElement(gate64, "feature").set("name", "sse2")
        ET.SubElement(gate64, "feature").set("name", "vme")
        ET.SubElement(gate64, "feature").set("name", "mtrr")
        ET.SubElement(gate64, "feature").set("name", "mca")
        ET.SubElement(gate64, "feature").set("name", "clflush")
        ET.SubElement(gate64, "feature").set("name", "pni")
        ET.SubElement(gate64, "feature").set("name", "nx")
        ET.SubElement(gate64, "feature").set("name", "ssse3")
        ET.SubElement(gate64, "feature").set("name", "syscall")
        ET.SubElement(gate64, "feature").set("name", "lm")


def format_xml(root):
    # Adapted from http://pymotw.com/2/xml/etree/ElementTree/create.html
    # thank you dhellmann
    rough_string = ET.tostring(root, encoding="UTF-8")
    dom_parsed = minidom.parseString(rough_string)
    return dom_parsed.toprettyxml("  ", encoding="UTF-8")


def main():
    if len(sys.argv) != 2:
        raise Exception("Must pass path to cpu_map.xml to update")
    cpu_map = sys.argv[1]
    tree = ET.parse(cpu_map)
    for model in tree.getroot().iter("model"):
        if model.get("name") == "gate64":
            # gate64 model is already present
            return
    update_cpu_map(tree)
    pretty_xml = format_xml(tree.getroot())
    with open(cpu_map, 'w') as f:
        f.write(pretty_xml)


if __name__ == "__main__":
    main()
