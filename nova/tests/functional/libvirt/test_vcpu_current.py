# Copyright 2024 OpenStack Foundation
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

"""Tests for libvirt vCPU current handling."""

from nova.tests.functional.libvirt import base


class VCPUCurrentTest(base.ServersTestBase):
    def setUp(self):
        super().setUp()
        self.compute_hostname = self.start_compute()

    def test_vcpu_current_in_domain_xml(self):
        flavor_id = self._create_flavor(
            vcpu=4, extra_spec={'minimum_cpu': '2'})
        server = self._create_server(flavor_id=flavor_id, networks='none')
        conn = self.computes[self.compute_hostname].driver._host.get_connection()
        dom = conn.lookupByUUIDString(server['id'])
        xml = dom.XMLDesc(0)
        self.assertIn("<vcpu current='2'>4</vcpu>", xml)
