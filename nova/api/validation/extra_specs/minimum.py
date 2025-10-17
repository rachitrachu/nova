# Copyright 2024 Xloud Technologies

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

"""Validators for minimum resource extra specs."""

from nova.api.validation.extra_specs import base


EXTRA_SPEC_VALIDATORS = [
    base.ExtraSpecValidator(
        name='minimum_cpu',
        description='Minimum number of vCPUs to allocate for the instance.',
        value={'type': int, 'min': 1},
    ),
    base.ExtraSpecValidator(
        name='minimum_memory',
        description='Minimum amount of memory (in MB) to allocate for the instance.',
        value={'type': int, 'min': 1},
    ),
]


def register():
    return EXTRA_SPEC_VALIDATORS
