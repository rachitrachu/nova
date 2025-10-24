# XLoud Nova - File Mapping for Rsync

This file provides exact source-to-destination mappings for rsync deployment.

## Environment Setup

```bash
# Set these variables for your environment
export SOURCE_REPO="/root/xloud-nova"
export TARGET_HOST="103.240.25.209"
export CONTAINER_NAME="nova_api"
export NOVA_SITE_PACKAGES="/usr/local/lib/python3.10/site-packages/nova"
```

## File Mapping Table

### New Files (Must Create)

| Source File (Local) | Destination File (Target) | Type |
|---------------------|---------------------------|------|
| `nova/api/openstack/compute/xloud_adjust.py` | `${NOVA_SITE_PACKAGES}/api/openstack/compute/xloud_adjust.py` | New |
| `nova/api/validation/extra_specs/minimum.py` | `${NOVA_SITE_PACKAGES}/api/validation/extra_specs/minimum.py` | New |
| `nova/policies/xloud_adjust.py` | `${NOVA_SITE_PACKAGES}/policies/xloud_adjust.py` | New |
| `nova/tests/functional/libvirt/test_vcpu_current.py` | `${NOVA_SITE_PACKAGES}/tests/functional/libvirt/test_vcpu_current.py` | New |
| `releasenotes/notes/minimum-cpu-current-vcpu-attr.yaml` | `/opt/nova/releasenotes/notes/minimum-cpu-current-vcpu-attr.yaml` | New |

### Modified Files (Must Replace)

| Source File (Local) | Destination File (Target) | Changes |
|---------------------|---------------------------|---------|
| `nova/api/openstack/compute/routes.py` | `${NOVA_SITE_PACKAGES}/api/openstack/compute/routes.py` | +imports, +controller, +route |
| `nova/compute/api.py` | `${NOVA_SITE_PACKAGES}/compute/api.py` | +hotplug_vcpus method |
| `nova/compute/instance_actions.py` | `${NOVA_SITE_PACKAGES}/compute/instance_actions.py` | +HOTPLUG_VCPUS constant |
| `nova/compute/manager.py` | `${NOVA_SITE_PACKAGES}/compute/manager.py` | +xloud methods, +minimum logic |
| `nova/compute/rpcapi.py` | `${NOVA_SITE_PACKAGES}/compute/rpcapi.py` | +xloud RPC methods |
| `nova/objects/request_spec.py` | `${NOVA_SITE_PACKAGES}/objects/request_spec.py` | Modified vcpus/memory_mb properties |
| `nova/scheduler/utils.py` | `${NOVA_SITE_PACKAGES}/scheduler/utils.py` | Modified pinning policies |
| `nova/policies/__init__.py` | `${NOVA_SITE_PACKAGES}/policies/__init__.py` | +xloud_adjust import |
| `nova/virt/driver.py` | `${NOVA_SITE_PACKAGES}/virt/driver.py` | +set_current_vcpus/memory methods |
| `nova/virt/libvirt/config.py` | `${NOVA_SITE_PACKAGES}/virt/libvirt/config.py` | +vcpus_current, +current_memory |
| `nova/virt/libvirt/driver.py` | `${NOVA_SITE_PACKAGES}/virt/libvirt/driver.py` | +xloud methods, +minimum handling |
| `nova/virt/libvirt/guest.py` | `${NOVA_SITE_PACKAGES}/virt/libvirt/guest.py` | +set_vcpus method |
| `setup.cfg` | `/opt/nova/setup.cfg` | +minimum validator entry |

### Test Files (Optional but Recommended)

| Source File (Local) | Destination File (Target) | Purpose |
|---------------------|---------------------------|---------|
| `nova/tests/functional/test_flavor_extraspecs.py` | `${NOVA_SITE_PACKAGES}/tests/functional/test_flavor_extraspecs.py` | Tests minimum spec validation |
| `nova/tests/functional/test_servers.py` | `${NOVA_SITE_PACKAGES}/tests/functional/test_servers.py` | Tests minimum resource allocation |
| `nova/tests/unit/compute/test_compute.py` | `${NOVA_SITE_PACKAGES}/tests/unit/compute/test_compute.py` | Unit tests for minimum specs |
| `nova/tests/unit/scheduler/test_utils.py` | `${NOVA_SITE_PACKAGES}/tests/unit/scheduler/test_utils.py` | Scheduler tests |

### Documentation Files (Optional)

| Source File (Local) | Destination File (Target) | Purpose |
|---------------------|---------------------------|---------|
| `doc/source/configuration/extra-specs.rst` | `/opt/nova/doc/source/configuration/extra-specs.rst` | Extra specs documentation |

## Rsync Commands by Category

### Deploy All New Files
```bash
cd $SOURCE_REPO

# New Python files
for file in \
  "nova/api/openstack/compute/xloud_adjust.py" \
  "nova/api/validation/extra_specs/minimum.py" \
  "nova/policies/xloud_adjust.py" \
  "nova/tests/functional/libvirt/test_vcpu_current.py"; do
  
  rsync -avz --progress "$file" root@${TARGET_HOST}:/tmp/
  filename=$(basename "$file")
  dirname=$(dirname "$file")
  ssh root@${TARGET_HOST} "docker cp /tmp/$filename ${CONTAINER_NAME}:${NOVA_SITE_PACKAGES}/${dirname#nova/}/"
  ssh root@${TARGET_HOST} "rm /tmp/$filename"
done
```

### Deploy Core Modified Files
```bash
cd $SOURCE_REPO

# Core functionality files
for file in \
  "nova/api/openstack/compute/routes.py" \
  "nova/compute/api.py" \
  "nova/compute/instance_actions.py" \
  "nova/compute/manager.py" \
  "nova/compute/rpcapi.py" \
  "nova/objects/request_spec.py" \
  "nova/scheduler/utils.py" \
  "nova/policies/__init__.py"; do
  
  rsync -avz --progress "$file" root@${TARGET_HOST}:/tmp/
  filename=$(basename "$file")
  dirname=$(dirname "$file")
  ssh root@${TARGET_HOST} "docker cp /tmp/$filename ${CONTAINER_NAME}:${NOVA_SITE_PACKAGES}/${dirname#nova/}/"
  ssh root@${TARGET_HOST} "rm /tmp/$filename"
done
```

### Deploy Libvirt Driver Files
```bash
cd $SOURCE_REPO

# Libvirt-specific files
for file in \
  "nova/virt/driver.py" \
  "nova/virt/libvirt/config.py" \
  "nova/virt/libvirt/driver.py" \
  "nova/virt/libvirt/guest.py"; do
  
  rsync -avz --progress "$file" root@${TARGET_HOST}:/tmp/
  filename=$(basename "$file")
  dirname=$(dirname "$file")
  ssh root@${TARGET_HOST} "docker cp /tmp/$filename ${CONTAINER_NAME}:${NOVA_SITE_PACKAGES}/${dirname#nova/}/"
  ssh root@${TARGET_HOST} "rm /tmp/$filename"
done
```

### Deploy Test Files
```bash
cd $SOURCE_REPO

# Test files
for file in \
  "nova/tests/functional/test_flavor_extraspecs.py" \
  "nova/tests/functional/test_servers.py" \
  "nova/tests/unit/compute/test_compute.py" \
  "nova/tests/unit/scheduler/test_utils.py"; do
  
  rsync -avz --progress "$file" root@${TARGET_HOST}:/tmp/
  filename=$(basename "$file")
  dirname=$(dirname "$file")
  ssh root@${TARGET_HOST} "docker cp /tmp/$filename ${CONTAINER_NAME}:${NOVA_SITE_PACKAGES}/${dirname#nova/}/"
  ssh root@${TARGET_HOST} "rm /tmp/$filename"
done
```

## Single Command Deployment

Deploy everything at once:
```bash
cd $SOURCE_REPO

# Create file list
cat > /tmp/xloud_files.txt << 'EOF'
nova/api/openstack/compute/xloud_adjust.py
nova/api/openstack/compute/routes.py
nova/api/validation/extra_specs/minimum.py
nova/compute/api.py
nova/compute/instance_actions.py
nova/compute/manager.py
nova/compute/rpcapi.py
nova/objects/request_spec.py
nova/scheduler/utils.py
nova/policies/__init__.py
nova/policies/xloud_adjust.py
nova/virt/driver.py
nova/virt/libvirt/config.py
nova/virt/libvirt/driver.py
nova/virt/libvirt/guest.py
nova/tests/functional/libvirt/test_vcpu_current.py
nova/tests/functional/test_flavor_extraspecs.py
nova/tests/functional/test_servers.py
nova/tests/unit/compute/test_compute.py
nova/tests/unit/scheduler/test_utils.py
EOF

# Create tarball
tar czf /tmp/xloud-nova.tar.gz -T /tmp/xloud_files.txt

# Deploy
rsync -avz --progress /tmp/xloud-nova.tar.gz root@${TARGET_HOST}:/tmp/
ssh root@${TARGET_HOST} "docker cp /tmp/xloud-nova.tar.gz ${CONTAINER_NAME}:/tmp/"
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} bash -c 'cd ${NOVA_SITE_PACKAGES}/../ && tar xzf /tmp/xloud-nova.tar.gz'"
```

## Verification Script

Verify all files are in place:
```bash
#!/bin/bash
TARGET_HOST="103.240.25.209"
CONTAINER_NAME="nova_api"
NOVA_SITE_PACKAGES="/usr/local/lib/python3.10/site-packages/nova"

echo "=== Verifying XLoud Nova Deployment ==="

# Check new files
echo "Checking new files..."
for file in \
  "api/openstack/compute/xloud_adjust.py" \
  "api/validation/extra_specs/minimum.py" \
  "policies/xloud_adjust.py" \
  "tests/functional/libvirt/test_vcpu_current.py"; do
  
  if ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} test -f ${NOVA_SITE_PACKAGES}/$file"; then
    echo "✓ $file exists"
  else
    echo "✗ $file MISSING"
  fi
done

# Check modified files
echo "Checking modified files..."
for file in \
  "api/openstack/compute/routes.py" \
  "compute/manager.py" \
  "virt/libvirt/driver.py"; do
  
  if ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} grep -q 'xloud' ${NOVA_SITE_PACKAGES}/$file"; then
    echo "✓ $file contains xloud changes"
  else
    echo "✗ $file missing xloud changes"
  fi
done

echo "=== Verification Complete ==="
```

## Size Reference

Approximate file sizes for bandwidth planning:

| File | Size | Lines |
|------|------|-------|
| xloud_adjust.py | ~4 KB | ~100 |
| minimum.py | ~1 KB | ~35 |
| xloud_adjust.py (policy) | ~500 B | ~17 |
| routes.py | ~45 KB | ~860 |
| manager.py | ~320 KB | ~8,250 |
| driver.py (libvirt) | ~650 KB | ~15,000 |
| **Total new files** | ~6 KB | ~152 |
| **Total modified** | ~1.2 MB | ~25,000 |

## Deployment Time Estimates

| Connection Speed | Transfer Time | Total Time (with restarts) |
|-----------------|---------------|----------------------------|
| 1 Mbps | ~12 seconds | ~2 minutes |
| 10 Mbps | ~2 seconds | ~1 minute |
| 100 Mbps | <1 second | ~45 seconds |
| LAN/Local | <1 second | ~30 seconds |

## Backup Commands

Before deployment, backup existing files:
```bash
# Backup critical files
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} bash -c 'cd ${NOVA_SITE_PACKAGES} && \
  tar czf /tmp/nova-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  api/openstack/compute/routes.py \
  compute/manager.py \
  compute/rpcapi.py \
  virt/libvirt/driver.py \
  objects/request_spec.py \
  scheduler/utils.py'"

# Download backup
scp root@${TARGET_HOST}:/tmp/nova-backup-*.tar.gz ./backups/
```

## Post-Deployment Checklist

- [ ] All 5 new files created
- [ ] All 18 modified files updated
- [ ] setup.cfg updated with minimum validator
- [ ] File permissions correct (644 for .py files)
- [ ] Python imports work (no ImportError)
- [ ] Nova services restarted
- [ ] API endpoint accessible
- [ ] Flavor extra specs validate
- [ ] Backup created and saved

## Rollback Command

```bash
# Restore from backup if needed
BACKUP_FILE="nova-backup-YYYYMMDD-HHMMSS.tar.gz"
scp ./backups/$BACKUP_FILE root@${TARGET_HOST}:/tmp/
ssh root@${TARGET_HOST} "docker cp /tmp/$BACKUP_FILE ${CONTAINER_NAME}:/tmp/"
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} tar xzf /tmp/$BACKUP_FILE -C ${NOVA_SITE_PACKAGES}/../"
ssh root@${TARGET_HOST} "docker restart ${CONTAINER_NAME}"
```