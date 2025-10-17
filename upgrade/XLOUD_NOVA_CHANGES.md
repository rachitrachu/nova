# XLoud Nova Changes - Implementation Guide

This document provides exact code changes required to implement XLoud's minimum CPU and dynamic vCPU/memory adjustment features in a new version of Nova. All changes are based on the diff between `origin/original` and `stable/2024.1` branch.

## Overview of Features

1. **Minimum CPU/Memory Extra Specs**: Allow flavors to specify minimum resources while preserving max limits
2. **Dynamic vCPU/Memory Adjustment**: API endpoint for live adjustment of instance resources
3. **Libvirt Integration**: Support for current vCPU and memory balloon features

## File Changes Required

### 1. Documentation Changes

#### File: `/root/xloud-nova/doc/source/configuration/extra-specs.rst`

Add the following section after line 49 (after the `trait` section):

```rst
########### xloud code
``minimum``
~~~~~~~~~~~

The following extra specs are used to request a smaller "current" amount of
VCPU or memory while preserving the flavor's ``vcpus`` and ``ram`` as the
maximum values. When used with the libvirt driver, the ``minimum_cpu`` extra
spec controls the ``current`` attribute of the ``<vcpu>`` element in the guest
XML.

.. extra-specs:: minimum
   :summary:
########### xloud code
```

### 2. API Route Configuration

#### File: `/root/xloud-nova/nova/api/openstack/compute/routes.py`

Add imports after existing imports:
```python
from nova.api.openstack.compute import xloud_adjust
from nova.api.openstack.compute import xloud_adjust as xloud_adjust_mod
```

Add controller factory after line 353:
```python
# controller factory (pattern used throughout this file)
xloud_adjust_controller = functools.partial(
    _create_controller, xloud_adjust_mod.XloudAdjustController, []
)
```

Add route in ROUTE_LIST tuple before the closing parenthesis:
```python
('/os-xloud-adjust/{server_id}', {
    'POST': [xloud_adjust_controller, 'update']
}),
```

### 3. New API Controller

#### File: `/root/xloud-nova/nova/api/openstack/compute/xloud_adjust.py` (NEW FILE)

Create complete file:
```python
from http import HTTPStatus
from oslo_log import log as logging
from oslo_utils import strutils

from nova.api.openstack import wsgi, common
from nova import exception
from nova.compute import api as compute_api
from nova.compute import rpcapi as compute_rpcapi
from nova.policies import xloud_adjust as xloud_policy

from nova import objects
from nova.compute import rpcapi as compute_rpcapi

LOG = logging.getLogger(__name__)

class XloudAdjustController(wsgi.Controller):
    """Adjust current vCPUs and/or currentMemory (balloon) via RPC."""

    def __init__(self):
        super().__init__()
        self._compute_api = None               # lazy, avoids mod_wsgi import-time side effects
        self.compute_rpcapi = compute_rpcapi.ComputeAPI()

    @wsgi.response(HTTPStatus.ACCEPTED)
    def update(self, req, server_id, body=None):
        ctx = req.environ['nova.context']
        ctx.can(xloud_policy.POLICY_ROOT % 'adjust')

        if not isinstance(body, dict):
            raise exception.ValidationError(detail="Body must be JSON object")

        current_vcpus = body.get('current_vcpus')
        current_memory_mb = body.get('current_memory_mb')
        persist = bool(body.get('persist', True))

        if current_vcpus is None and current_memory_mb is None:
            raise exception.ValidationError(
                detail="Provide current_vcpus and/or current_memory_mb"
            )

        def _as_int(val, name):
            # Reject booleans explicitly (True/False are instances of int in Python)
            if isinstance(val, bool):
                raise exception.ValidationError(detail=f"{name} must be int")

            # If it's already an int, accept
            if isinstance(val, int):
                return val

            # If it's a string like "12", accept
            if isinstance(val, str):
                v = val.strip()
                if v.isdigit() or (v.startswith('-') and v[1:].isdigit()):
                    return int(v)

            # Last-chance: plain int() (covers Decimal, numpy ints, etc.)
            try:
                return int(val)
            except Exception:
                raise exception.ValidationError(detail=f"{name} must be int")

        if current_vcpus is not None:
            current_vcpus = _as_int(current_vcpus, "current_vcpus")
            if current_vcpus < 1:
                raise exception.ValidationError(detail="current_vcpus must be >= 1")

        if current_memory_mb is not None:
            current_memory_mb = _as_int(current_memory_mb, "current_memory_mb")
            if current_memory_mb < 1:
                raise exception.ValidationError(detail="current_memory_mb must be >= 1")

        # Load instance (does policy/visibility checks and sets cell mapping, etc.)
        inst = common.get_instance(self.compute_api, ctx, server_id)

        # Fire-and-forget RPC(s) to nova-compute on the instance's host
        if current_vcpus is not None:
            LOG.debug("xloud: casting xloud_adjust_vcpus uuid=%s target=%s persist=%s",
                      inst.uuid, current_vcpus, persist)
            self.compute_rpcapi.xloud_adjust_vcpus(ctx, inst, int(current_vcpus), persist=persist)

## self.compute_rpcapi.xloud_adjust_vcpus(ctx, inst, int(current_vcpus), persist=persist)

        if current_memory_mb is not None:
            LOG.debug("xloud: casting xloud_adjust_memory uuid=%s target_mb=%s persist=%s",
                      inst.uuid, current_memory_mb, persist)
            self.compute_rpcapi.xloud_adjust_memory(ctx, inst, int(current_memory_mb), persist=persist)


        # 202 Accepted with empty body (operation happens asynchronously on compute)
        return {}

    @property
    def compute_api(self):
        if self._compute_api is None:
            self._compute_api = compute_api.API()
        return self._compute_api
```

### 4. Extra Specs Validation

#### File: `/root/xloud-nova/nova/api/validation/extra_specs/minimum.py` (NEW FILE)

Create complete file:
```python
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
```

### 5. Compute API Changes

#### File: `/root/xloud-nova/nova/compute/api.py`

Add method after line 5417:
```python
@check_instance_lock
@check_instance_state(
    vm_state=[vm_states.ACTIVE, vm_states.PAUSED, vm_states.STOPPED],
    task_state=[None],
)
######## Xloud Code
def hotplug_vcpus(self, context, instance, new_count):
    """Hotplug vCPUs to a running instance."""
    self._record_action_start(
        context, instance, instance_actions.HOTPLUG_VCPUS)
    return self.compute_rpcapi.hotplug_vcpus(
        context, instance=instance, new_count=new_count)
@check_instance_lock

################
```

### 6. Instance Actions

#### File: `/root/xloud-nova/nova/compute/instance_actions.py`

Add after line 68:
```python
HOTPLUG_VCPUS = 'hotplug_vcpus' ### xloud code
```

### 7. Compute Manager Changes

#### File: `/root/xloud-nova/nova/compute/manager.py`

Add methods after line 684:
```python
###############xloud code

def xloud_adjust_vcpus(self, context, instance, target, persist=True):
    LOG.info("xloud_adjust_vcpus: uuid=%s target=%s persist=%s",
             instance.uuid, target, persist)
    self.driver.xloud_adjust_vcpus(instance, int(target), persist)

def xloud_adjust_memory(self, context, instance, target_mb, persist=True):
    LOG.info("xloud_adjust_memory: uuid=%s target_mb=%s persist=%s",
             instance.uuid, target_mb, persist)
    self.driver.xloud_adjust_memory(instance, int(target_mb), persist)

######################
```

Add in `_set_instance_info` method after line 6212:
```python
##########xloud code
extra_specs = flavor.extra_specs or {}
instance.metadata = instance.metadata or {}
if 'minimum_cpu' in extra_specs:
    vcpus = int(extra_specs['minimum_cpu'])
    if vcpus > flavor.vcpus:
        raise exception.InvalidInput(
            reason='minimum_cpu exceeds flavor vcpus')
    instance.metadata['minimum_cpu'] = str(vcpus) 
else:
    instance.metadata.pop('minimum_cpu', None) 
if 'minimum_memory' in extra_specs:
    memory = int(extra_specs['minimum_memory'])
    if memory > flavor.memory_mb:
        raise exception.InvalidInput(
            reason='minimum_memory exceeds flavor memory')
    instance.memory_mb = memory
############
```

Add method after line 8246:
```python
#########Xloud Code
@wrap_exception()
@wrap_instance_event(prefix='compute')
@wrap_instance_fault
def hotplug_vcpus(self, context, instance, new_count):
    return self._hotplug_vcpus(context, instance, new_count)

def _hotplug_vcpus(self, context, instance, new_count):
    flavor_vcpus = instance.flavor.vcpus
    if new_count > flavor_vcpus:
        raise exception.InvalidRequest(
            _("Requested vCPU count %d exceeds flavor limit %d") %
            (new_count, flavor_vcpus))
    self.driver.hotplug_vcpus(instance, new_count)
#######################
```

### 8. RPC API Changes

#### File: `/root/xloud-nova/nova/compute/rpcapi.py`

Add imports after existing imports:
```python
from oslo_messaging import Target
```

Add methods after line 580:
```python
############Xloud Code
def hotplug_vcpus(self, ctxt, instance, new_count):
    kw = {'instance': instance, 'new_count': new_count}
    version = self._ver(ctxt, '5.0')
    client = self.router.client(ctxt)
    cctxt = client.prepare(server=_compute_host(None, instance),
                           version=version)
    return cctxt.call(ctxt, 'hotplug_vcpus', **kw)

   ################
    
def xloud_adjust_vcpus(self, ctxt, instance, target, persist=False):
    """Adjust current vCPUs live (and optionally persist)."""
    version = self._ver(ctxt, '6.0')  # match your file's baseline (router Target uses 6.0)
    client = self.router.client(ctxt)
    cctxt = client.prepare(server=_compute_host(None, instance), version=version)
    cctxt.cast(ctxt, 'xloud_adjust_vcpus',
            instance=instance, target=int(target), persist=bool(persist))

def xloud_adjust_memory(self, ctxt, instance, target_mb, persist=False):
    """Adjust current balloon memory (MiB) live (and optionally persist)."""
    version = self._ver(ctxt, '6.0')
    client = self.router.client(ctxt)
    cctxt = client.prepare(server=_compute_host(None, instance), version=version)
    cctxt.cast(ctxt, 'xloud_adjust_memory',
           instance=instance, target_mb=int(target_mb), persist=bool(persist))
def __init__(self):
    super().__init__()
    target = Target(topic='compute', version='6.3')   # keep your release's values
    serializer = objects.base.NovaObjectSerializer()
    self.client = rpc.get_client(target, version_cap='auto',
                                 serializer=serializer)

####################
```

### 9. Request Spec Changes

#### File: `/root/xloud-nova/nova/objects/request_spec.py`

Replace the `vcpus` and `memory_mb` properties (around lines 176-182):
```python
############Xloud Code
@property
def vcpus(self):
    extra = self.flavor.extra_specs or {}
    if 'minimum_cpu' in extra:
        try:
            vcpus = int(extra['minimum_cpu'])
        except (ValueError, TypeError):
            vcpus = self.flavor.vcpus
        else:
            if vcpus <= self.flavor.vcpus:
                return vcpus
    return self.flavor.vcpus

@property
def memory_mb(self):
    extra = self.flavor.extra_specs or {}
    if 'minimum_memory' in extra:
        try:
            memory = int(extra['minimum_memory'])
        except (ValueError, TypeError):
            memory = self.flavor.memory_mb
        else:
            if memory <= self.flavor.memory_mb:
                return memory
    return self.flavor.memory_mb
########################
```

### 10. Policy Changes

#### File: `/root/xloud-nova/nova/policies/__init__.py`

Add import:
```python
from nova.policies import xloud_adjust
```

Add to the list_rules() return tuple:
```python
xloud_adjust.list_rules(),
```

#### File: `/root/xloud-nova/nova/policies/xloud_adjust.py` (NEW FILE)

Create complete file:
```python
from oslo_policy import policy
from nova.policies import base

POLICY_ROOT = 'os_compute_api:xloud:%s'

rules = [
    policy.DocumentedRuleDefault(
        name=POLICY_ROOT % 'adjust',
        check_str=base.ADMIN,
        description='Adjust current vCPUs and current memory (balloon target)',
        operations=[{'path': '/os-xloud-adjust/{server_id}', 'method': 'POST'}],
        scope_types=['project'],
    ),
]

def list_rules():
    return rules
```

### 11. Scheduler Utils Changes

#### File: `/root/xloud-nova/nova/scheduler/utils.py`

Change method signature on line 342:
```python
def _translate_pinning_policies(self, request_spec, image): ##xloud    
```

Add line after 350:
```python
flavor = request_spec.flavor
```

Change line around 365:
```python
pcpus = request_spec.vcpus
```

Change line around 382:
```python
vcpus = request_spec.vcpus - pcpus  #xloud
```

### 12. Virt Driver Base Changes

#### File: `/root/xloud-nova/nova/virt/driver.py`

Add methods after line 264:
```python
################ xloud code

def set_current_vcpus(self, instance, count, persist=True):
    """Set the current (live) vCPU count for an instance.
    :param instance: nova.objects.Instance
    :param count: int >=1
    :param persist: also write to config XML if possible
    """
    raise NotImplementedError()

def set_current_memory_mb(self, instance, memory_mb, persist=True):
    """Set the current (balloon) memory target in MiB.
    :param instance: nova.objects.Instance
    :param memory_mb: int >=1
    :param persist: also write to config XML if possible
    """
    raise NotImplementedError()

#######################
```

### 13. Libvirt Config Changes

#### File: `/root/xloud-nova/nova/virt/libvirt/config.py`

Add attributes to `LibvirtConfigGuest.__init__` after line 3015:
```python
self.vcpus_current = None  #xloud code
self.current_memory = None   #xloud code
```

Add in `format_dom` method after line 3051:
```python
if self.current_memory is not None:
    root.append(self._text_node("currentMemory", self.current_memory))
```

Replace the vcpu handling section around line 3061:
```python
if self.cpuset is not None:
    vcpu = self._text_node("vcpu", self.vcpus)
    vcpu.set("cpuset", hardware.format_cpu_spec(self.cpuset))
    if self.vcpus_current is not None: #xloud code
        vcpu.set("current", str(self.vcpus_current))   
    root.append(vcpu)
else:
    vcpu = self._text_node("vcpu", self.vcpus)
    if self.vcpus_current is not None:
        vcpu.set("current", str(self.vcpus_current))
    root.append(vcpu)
#########
```

Add in `_parse_vcpu` method after line 3223:
```python
if xmldoc.get('current') is not None:
    self.vcpus_current = int(xmldoc.get('current'))  #xloud code
```

### 14. Libvirt Driver Changes

#### File: `/root/xloud-nova/nova/virt/libvirt/driver.py`

Add methods after class definition:
```python
######### xloud code #########

def xloud_adjust_vcpus(self, instance, count, persist=True):
    if count < 1:
        raise exception.InvalidInput(reason="current vcpus must be >= 1")

    # Get the running guest/domain via the Host wrapper
    guest = self._host.get_guest(instance)
    dom = guest._domain  # libvirt.virDomain

    try:
        maxv = dom.maxVcpus()
    except libvirt.libvirtError:
        maxv = count
    if count > maxv:
        count = maxv

    flags = libvirt.VIR_DOMAIN_VCPU_LIVE
    if persist:
        flags |= libvirt.VIR_DOMAIN_VCPU_CONFIG

    try:
        dom.setVcpusFlags(int(count), flags)
    except libvirt.libvirtError as e:
        raise exception.InvalidInput(reason=f"libvirt vcpu change failed: {e}")


def xloud_adjust_memory(self, instance, memory_mb, persist=True):
    if memory_mb < 1:
        raise exception.InvalidInput(reason="current memory must be >= 1 MiB")

    target_kib = int(memory_mb) * units.Ki

    guest = self._host.get_guest(instance)
    dom = guest._domain

    flags = libvirt.VIR_DOMAIN_AFFECT_LIVE
    if persist:
        flags |= libvirt.VIR_DOMAIN_AFFECT_CONFIG

    try:
        dom.setMemoryFlags(target_kib, flags)
    except libvirt.libvirtError as e:
        raise exception.InvalidInput(reason=f"libvirt memory change failed: {e}")

        
###############################
```

Add method after line 4297:
```python
########################## xloud Code
def hotplug_vcpus(self, instance, new_count):
    """Hotplug vCPUs for a running guest."""
    guest = self._host.get_guest(instance)
    guest.set_vcpus(new_count)

###########################
```

Add in `_get_guest_config` method after line 7341:
```python
####################### Xloud Code
# --- XLOUD: combined min vCPU + min memory handling ---

def _as_int(val):
    try:
        return int(val)
    except (TypeError, ValueError):
        return None

# Prefer per-instance metadata; fall back to flavor extra_specs if present
min_cpu_raw = (instance.metadata or {}).get('minimum_cpu') or \
            (flavor.extra_specs or {}).get('minimum_cpu')
min_mem_raw = (instance.metadata or {}).get('minimum_memory') or \
            (flavor.extra_specs or {}).get('minimum_memory')

# ----- vCPUs -----
min_cpu = _as_int(min_cpu_raw)
if min_cpu is not None:
    if min_cpu < 1:
        LOG.warning("minimum_cpu < 1 for %s; clamping to 1", instance.uuid)
        min_cpu = 1
    if min_cpu > flavor.vcpus:
        LOG.warning("minimum_cpu > flavor.vcpus for %s; clamping to %d",
                    instance.uuid, flavor.vcpus)
        min_cpu = flavor.vcpus
    guest.vcpus_current = min_cpu
else:
    guest.vcpus_current = flavor.vcpus  # default current == max

# ----- Memory (MB → KiB) -----
min_mem_mb = _as_int(min_mem_raw)
if min_mem_mb is not None:
    if min_mem_mb < 1:
        LOG.warning("minimum_memory < 1MB for %s; clamping to 1MB", instance.uuid)
        min_mem_mb = 1
    if min_mem_mb > flavor.memory_mb:
        LOG.warning("minimum_memory > flavor.memory_mb for %s; clamping to %dMB",
                    instance.uuid, flavor.memory_mb)
        min_mem_mb = flavor.memory_mb
    guest.current_memory = min_mem_mb * units.Ki  # libvirt uses KiB
else:
    guest.current_memory = None  # omit → libvirt treats current==max

# Final guard: currentMemory must not exceed memory
if guest.current_memory is not None and guest.current_memory > guest.memory:
    LOG.warning("currentMemory > memory for %s; fixing to memory", instance.uuid)
    guest.current_memory = guest.memory
# --- end XLOUD block ---
################################################
```

### 15. Libvirt Guest Changes

#### File: `/root/xloud-nova/nova/virt/libvirt/guest.py`

Add method after line 296:
```python
########################### xloud code
def set_vcpus(self, count):
    """Set the number of active vCPUs for the guest.

    :param count: Total number of vCPUs the guest should have enabled.
    """
    flags = libvirt.VIR_DOMAIN_VCPU_LIVE | libvirt.VIR_DOMAIN_VCPU_CONFIG
    self._domain.setVcpusFlags(count, flags)
#########################
```

### 16. Setup Configuration

#### File: `/root/xloud-nova/setup.cfg`

Add entry in `nova.api.extra_spec_validators` section:
```ini
minimum = nova.api.validation.extra_specs.minimum
```

### 17. Release Notes

#### File: `/root/xloud-nova/releasenotes/notes/minimum-cpu-current-vcpu-attr.yaml` (NEW FILE)

Create complete file:
```yaml
---
features:
  - |
    The libvirt driver now honors the ``minimum_cpu`` flavor extra spec by
    setting the ``current`` attribute of the ``<vcpu>`` element in the domain
    XML. Nova preserves the flavor ``vcpus`` as the maximum and stores the
    ``minimum_cpu`` value in instance metadata, allowing guests to boot with
    fewer vCPUs and grow up to the flavor limit automatically.
```

### 18. Test Files

Several test files were modified to validate the new functionality:

- `/root/xloud-nova/nova/tests/functional/libvirt/test_vcpu_current.py` (NEW FILE)
- `/root/xloud-nova/nova/tests/functional/test_flavor_extraspecs.py`
- `/root/xloud-nova/nova/tests/functional/test_servers.py`
- `/root/xloud-nova/nova/tests/unit/compute/test_compute.py`
- `/root/xloud-nova/nova/tests/unit/scheduler/test_utils.py`

## Implementation Summary

The changes implement:

1. **Minimum Resource Extra Specs**: `minimum_cpu` and `minimum_memory` flavor extra specs
2. **Dynamic Adjustment API**: `/os-xloud-adjust/{server_id}` endpoint for live resource changes
3. **Libvirt Integration**: Support for `current` attribute in vCPU and currentMemory elements
4. **Request Spec Integration**: Proper resource calculation during scheduling
5. **Policy Controls**: Admin-only access to adjustment APIs

## Key Integration Points

- The scheduler now uses `request_spec.vcpus` instead of `flavor.vcpus` to properly handle minimum resources
- Instance metadata stores the minimum values for runtime access
- The libvirt driver handles both the initial configuration and live adjustments
- All changes maintain backward compatibility when extra specs are not present

## API Usage Example

```bash
# Adjust current vCPUs and memory
curl -X POST /os-xloud-adjust/{server_id} \
  -H "Content-Type: application/json" \
  -d '{"current_vcpus": 2, "current_memory_mb": 1024, "persist": true}'
```

This implementation allows instances to start with minimal resources and dynamically scale up to their flavor limits as needed.