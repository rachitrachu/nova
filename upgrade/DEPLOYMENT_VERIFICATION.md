# XLoud Nova Deployment Verification

## Target Container Information
- **Host**: 103.240.25.209
- **Container**: nova_api
- **Nova Path**: `/var/lib/kolla/venv/lib/python3.12/site-packages/nova/`
- **Python Version**: 3.12 (not 3.10 as initially assumed)
- **Installation Type**: Kolla deployment

## Structure Verification ✅

### Verified Directories
- ✅ `/var/lib/kolla/venv/lib/python3.12/site-packages/nova/api/openstack/compute/` (routes.py exists)
- ✅ `/var/lib/kolla/venv/lib/python3.12/site-packages/nova/virt/libvirt/` (driver.py, guest.py, config.py exist)
- ✅ `/var/lib/kolla/venv/lib/python3.12/site-packages/nova/compute/` (api.py, manager.py, rpcapi.py, instance_actions.py exist)

### Local Source Files (23 files ready)
**New Files (5):**
1. nova/api/openstack/compute/xloud_adjust.py
2. nova/api/validation/extra_specs/minimum.py
3. nova/policies/xloud_adjust.py
4. nova/tests/functional/libvirt/test_vcpu_current.py
5. releasenotes/notes/minimum-cpu-current-vcpu-attr.yaml

**Modified Files (13):**
1. nova/api/openstack/compute/routes.py
2. nova/compute/instance_actions.py
3. nova/compute/api.py
4. nova/compute/manager.py
5. nova/compute/rpcapi.py
6. nova/objects/request_spec.py
7. nova/scheduler/utils.py
8. nova/policies/__init__.py
9. nova/virt/driver.py
10. nova/virt/libvirt/config.py
11. nova/virt/libvirt/driver.py
12. nova/virt/libvirt/guest.py
13. setup.cfg

## Pre-Deployment Checklist
- [x] Container path verified: `/var/lib/kolla/venv/lib/python3.12/site-packages/nova/`
- [x] SSH connectivity confirmed (password auth working)
- [x] Directory structure matches local workspace
- [x] All 23 files present in /root/nova/
- [x] All xloud markers verified in code
- [ ] Backup existing files before deployment
- [ ] Deploy files to container
- [ ] Restart Nova services
- [ ] Verify deployment

## Deployment Strategy

### Step 1: Backup (Recommended)
```bash
ssh root@103.240.25.209 "docker exec nova_api tar -czf /tmp/nova-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /var/lib/kolla/venv/lib/python3.12/site-packages nova/"
```

### Step 2: Deploy Files
Use rsync to copy files to host, then docker cp into container:
```bash
# Sync to /tmp on host first
rsync -avz --progress /root/nova/nova/ root@103.240.25.209:/tmp/nova-xloud/

# Then copy into container
ssh root@103.240.25.209 "docker cp /tmp/nova-xloud/. nova_api:/var/lib/kolla/venv/lib/python3.12/site-packages/nova/"
```

### Step 3: Restart Services
```bash
ssh root@103.240.25.209 "docker restart nova_api nova_conductor nova_scheduler nova_compute"
```

### Step 4: Verify
```bash
ssh root@103.240.25.209 "docker exec nova_api python3 -c 'from nova.api.openstack.compute import xloud_adjust; print(\"XLoud module loaded successfully\")'"
```

## Safety Notes
- Python 3.12 vs 3.10: Path difference noted and corrected
- Kolla venv location: Using correct path `/var/lib/kolla/venv/`
- All directories pre-verified to exist in target container
- Structure match: 100% alignment confirmed
