# XLoud Nova - Rsync Deployment Guide

This guide provides exact rsync commands and file mappings to deploy XLoud Nova changes to a new Nova installation.

## Deployment Overview

You will use rsync to copy modified and new files from this repository to the target Nova installation. The target Nova path is typically inside a Docker container or virtual environment.

## Prerequisites

1. Identify target Nova installation path:
```bash
# Example: Find Nova installation in Docker container
ssh root@<TARGET_HOST> "docker exec nova_api python3 -c 'import nova; print(nova.__file__)'"
# Output example: /usr/local/lib/python3.10/site-packages/nova/__init__.py
# Base path: /usr/local/lib/python3.10/site-packages/nova/
```

2. Set environment variables:
```bash
export TARGET_HOST="103.240.25.209"
export CONTAINER_NAME="nova_api"
export NOVA_BASE_PATH="/usr/local/lib/python3.10/site-packages/nova"
```

## File Deployment Structure

### New Files to Deploy (5 files)

These files must be created in the target Nova installation:

```bash
# 1. API Controller
LOCAL: nova/api/openstack/compute/xloud_adjust.py
TARGET: ${NOVA_BASE_PATH}/api/openstack/compute/xloud_adjust.py

# 2. Extra Spec Validator
LOCAL: nova/api/validation/extra_specs/minimum.py
TARGET: ${NOVA_BASE_PATH}/api/validation/extra_specs/minimum.py

# 3. Policy Definition
LOCAL: nova/policies/xloud_adjust.py
TARGET: ${NOVA_BASE_PATH}/policies/xloud_adjust.py

# 4. Functional Test
LOCAL: nova/tests/functional/libvirt/test_vcpu_current.py
TARGET: ${NOVA_BASE_PATH}/tests/functional/libvirt/test_vcpu_current.py

# 5. Release Notes
LOCAL: releasenotes/notes/minimum-cpu-current-vcpu-attr.yaml
TARGET: <NOVA_ROOT>/releasenotes/notes/minimum-cpu-current-vcpu-attr.yaml
```

### Modified Files to Deploy (18 files)

These files must be synced with modifications applied:

```bash
# Documentation
doc/source/configuration/extra-specs.rst

# API Layer
nova/api/openstack/compute/routes.py

# Compute Layer
nova/compute/api.py
nova/compute/instance_actions.py
nova/compute/manager.py
nova/compute/rpcapi.py

# Objects & Scheduling
nova/objects/request_spec.py
nova/scheduler/utils.py
nova/policies/__init__.py

# Virtualization Layer
nova/virt/driver.py
nova/virt/libvirt/config.py
nova/virt/libvirt/driver.py
nova/virt/libvirt/guest.py

# Tests
nova/tests/functional/test_flavor_extraspecs.py
nova/tests/functional/test_servers.py
nova/tests/unit/compute/test_compute.py
nova/tests/unit/scheduler/test_utils.py

# Configuration
setup.cfg
```

## Rsync Deployment Commands

### Method 1: Direct Container Rsync

Deploy new files only:
```bash
# Deploy new API controller
rsync -avz --progress \
  nova/api/openstack/compute/xloud_adjust.py \
  root@${TARGET_HOST}:/tmp/
ssh root@${TARGET_HOST} "docker cp /tmp/xloud_adjust.py ${CONTAINER_NAME}:${NOVA_BASE_PATH}/api/openstack/compute/"

# Deploy extra spec validator
rsync -avz --progress \
  nova/api/validation/extra_specs/minimum.py \
  root@${TARGET_HOST}:/tmp/
ssh root@${TARGET_HOST} "docker cp /tmp/minimum.py ${CONTAINER_NAME}:${NOVA_BASE_PATH}/api/validation/extra_specs/"

# Deploy policy
rsync -avz --progress \
  nova/policies/xloud_adjust.py \
  root@${TARGET_HOST}:/tmp/
ssh root@${TARGET_HOST} "docker cp /tmp/xloud_adjust.py ${CONTAINER_NAME}:${NOVA_BASE_PATH}/policies/"

# Deploy functional test
rsync -avz --progress \
  nova/tests/functional/libvirt/test_vcpu_current.py \
  root@${TARGET_HOST}:/tmp/
ssh root@${TARGET_HOST} "docker cp /tmp/test_vcpu_current.py ${CONTAINER_NAME}:${NOVA_BASE_PATH}/tests/functional/libvirt/"
```

### Method 2: Bulk Deployment Script

Create deployment script `deploy_xloud_nova.sh`:
```bash
#!/bin/bash
set -e

TARGET_HOST="103.240.25.209"
CONTAINER_NAME="nova_api"
NOVA_BASE_PATH="/usr/local/lib/python3.10/site-packages/nova"

echo "=== XLoud Nova Deployment Script ==="

# Function to deploy a single file
deploy_file() {
    local src=$1
    local dst=$2
    echo "Deploying: $src -> $dst"
    rsync -avz --progress "$src" root@${TARGET_HOST}:/tmp/$(basename $src)
    ssh root@${TARGET_HOST} "docker cp /tmp/$(basename $src) ${CONTAINER_NAME}:$dst"
    ssh root@${TARGET_HOST} "rm /tmp/$(basename $src)"
}

# Deploy new files
echo "=== Deploying New Files ==="
deploy_file "nova/api/openstack/compute/xloud_adjust.py" "${NOVA_BASE_PATH}/api/openstack/compute/xloud_adjust.py"
deploy_file "nova/api/validation/extra_specs/minimum.py" "${NOVA_BASE_PATH}/api/validation/extra_specs/minimum.py"
deploy_file "nova/policies/xloud_adjust.py" "${NOVA_BASE_PATH}/policies/xloud_adjust.py"
deploy_file "nova/tests/functional/libvirt/test_vcpu_current.py" "${NOVA_BASE_PATH}/tests/functional/libvirt/test_vcpu_current.py"

# Deploy modified files
echo "=== Deploying Modified Files ==="
deploy_file "nova/api/openstack/compute/routes.py" "${NOVA_BASE_PATH}/api/openstack/compute/routes.py"
deploy_file "nova/compute/api.py" "${NOVA_BASE_PATH}/compute/api.py"
deploy_file "nova/compute/instance_actions.py" "${NOVA_BASE_PATH}/compute/instance_actions.py"
deploy_file "nova/compute/manager.py" "${NOVA_BASE_PATH}/compute/manager.py"
deploy_file "nova/compute/rpcapi.py" "${NOVA_BASE_PATH}/compute/rpcapi.py"
deploy_file "nova/objects/request_spec.py" "${NOVA_BASE_PATH}/objects/request_spec.py"
deploy_file "nova/scheduler/utils.py" "${NOVA_BASE_PATH}/scheduler/utils.py"
deploy_file "nova/policies/__init__.py" "${NOVA_BASE_PATH}/policies/__init__.py"
deploy_file "nova/virt/driver.py" "${NOVA_BASE_PATH}/virt/driver.py"
deploy_file "nova/virt/libvirt/config.py" "${NOVA_BASE_PATH}/virt/libvirt/config.py"
deploy_file "nova/virt/libvirt/driver.py" "${NOVA_BASE_PATH}/virt/libvirt/driver.py"
deploy_file "nova/virt/libvirt/guest.py" "${NOVA_BASE_PATH}/virt/libvirt/guest.py"

echo "=== Deployment Complete ==="
echo "Remember to restart Nova services!"
```

Make it executable and run:
```bash
chmod +x deploy_xloud_nova.sh
./deploy_xloud_nova.sh
```

### Method 3: Archive and Extract

Create a deployment archive:
```bash
# Create archive with all XLoud changes
tar czf xloud-nova-changes.tar.gz \
  nova/api/openstack/compute/xloud_adjust.py \
  nova/api/openstack/compute/routes.py \
  nova/api/validation/extra_specs/minimum.py \
  nova/compute/api.py \
  nova/compute/instance_actions.py \
  nova/compute/manager.py \
  nova/compute/rpcapi.py \
  nova/objects/request_spec.py \
  nova/scheduler/utils.py \
  nova/policies/__init__.py \
  nova/policies/xloud_adjust.py \
  nova/virt/driver.py \
  nova/virt/libvirt/config.py \
  nova/virt/libvirt/driver.py \
  nova/virt/libvirt/guest.py

# Deploy archive
rsync -avz --progress xloud-nova-changes.tar.gz root@${TARGET_HOST}:/tmp/
ssh root@${TARGET_HOST} "docker cp /tmp/xloud-nova-changes.tar.gz ${CONTAINER_NAME}:/tmp/"
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} tar xzf /tmp/xloud-nova-changes.tar.gz -C ${NOVA_BASE_PATH}/../"
```

## Pre-Deployment Backup

**CRITICAL**: Always backup before deployment:

```bash
# Backup entire Nova directory
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} tar czf /tmp/nova-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C ${NOVA_BASE_PATH}/../ nova/"

# Copy backup locally
scp root@${TARGET_HOST}:/tmp/nova-backup-*.tar.gz ./backups/
```

## Post-Deployment Steps

### 1. Verify File Deployment
```bash
# Check new files exist
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} ls -la ${NOVA_BASE_PATH}/api/openstack/compute/xloud_adjust.py"
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} ls -la ${NOVA_BASE_PATH}/api/validation/extra_specs/minimum.py"
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} ls -la ${NOVA_BASE_PATH}/policies/xloud_adjust.py"
```

### 2. Update setup.cfg
```bash
# Setup.cfg needs to be updated in the Nova root (not in site-packages)
# This is typically /opt/nova/setup.cfg or similar
# Add this line under [nova.api.extra_spec_validators] section:
# minimum = nova.api.validation.extra_specs.minimum
```

### 3. Restart Nova Services
```bash
# Restart all Nova services
ssh root@${TARGET_HOST} "docker restart nova_api nova_conductor nova_scheduler"

# Or if using systemctl
ssh root@${TARGET_HOST} "systemctl restart openstack-nova-api openstack-nova-conductor openstack-nova-scheduler"

# For compute nodes
ssh root@${COMPUTE_HOST} "systemctl restart openstack-nova-compute"
```

### 4. Verify Deployment
```bash
# Test import of new modules
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} python3 -c 'from nova.api.openstack.compute import xloud_adjust; print(\"OK\")'"
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} python3 -c 'from nova.api.validation.extra_specs import minimum; print(\"OK\")'"
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} python3 -c 'from nova.policies import xloud_adjust; print(\"OK\")'"

# Check API endpoint is registered
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} grep -r 'os-xloud-adjust' ${NOVA_BASE_PATH}/api/"
```

## Deployment Validation

### Test Minimum CPU Extra Spec
```bash
# Create flavor with minimum_cpu
openstack flavor create --vcpus 4 --ram 4096 --disk 20 test-xloud-flavor
openstack flavor set test-xloud-flavor --property minimum_cpu=2
openstack flavor set test-xloud-flavor --property minimum_memory=2048

# Verify extra specs
openstack flavor show test-xloud-flavor -f json | jq '.properties'
```

### Test Dynamic Adjustment API
```bash
# Create test instance
SERVER_ID=$(openstack server create --flavor test-xloud-flavor --image cirros --network private test-instance -f value -c id)

# Wait for ACTIVE state
openstack server show $SERVER_ID -f value -c status

# Test xloud-adjust API
curl -X POST http://nova-api:8774/v2.1/os-xloud-adjust/$SERVER_ID \
  -H "X-Auth-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"current_vcpus": 3, "current_memory_mb": 3072, "persist": true}'
```

## Rollback Procedure

If deployment fails:
```bash
# Restore from backup
BACKUP_FILE="nova-backup-YYYYMMDD-HHMMSS.tar.gz"
scp ./backups/$BACKUP_FILE root@${TARGET_HOST}:/tmp/
ssh root@${TARGET_HOST} "docker cp /tmp/$BACKUP_FILE ${CONTAINER_NAME}:/tmp/"
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} tar xzf /tmp/$BACKUP_FILE -C ${NOVA_BASE_PATH}/../ --overwrite"
ssh root@${TARGET_HOST} "docker restart nova_api nova_conductor nova_scheduler"
```

## Troubleshooting

### Import Errors
```bash
# Check Python path
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} python3 -c 'import sys; print(sys.path)'"

# Check file permissions
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} ls -la ${NOVA_BASE_PATH}/api/openstack/compute/xloud_adjust.py"

# Fix permissions if needed
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} chmod 644 ${NOVA_BASE_PATH}/api/openstack/compute/xloud_adjust.py"
```

### API Not Responding
```bash
# Check Nova API logs
ssh root@${TARGET_HOST} "docker logs nova_api --tail 100"

# Check for syntax errors
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} python3 -m py_compile ${NOVA_BASE_PATH}/api/openstack/compute/xloud_adjust.py"
```

### Service Won't Start
```bash
# Check for missing dependencies
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} pip list | grep oslo"

# Validate configuration
ssh root@${TARGET_HOST} "docker exec ${CONTAINER_NAME} nova-api --config-file /etc/nova/nova.conf --dry-run"
```

## Multi-Node Deployment

For distributed Nova deployments:

```bash
# Define all hosts
CONTROLLER_HOSTS="controller1 controller2 controller3"
COMPUTE_HOSTS="compute1 compute2 compute3 compute4"

# Deploy to controllers (API, Conductor, Scheduler)
for host in $CONTROLLER_HOSTS; do
  echo "Deploying to controller: $host"
  ./deploy_xloud_nova.sh $host
  ssh root@$host "systemctl restart openstack-nova-api openstack-nova-conductor openstack-nova-scheduler"
done

# Deploy to compute nodes
for host in $COMPUTE_HOSTS; do
  echo "Deploying to compute: $host"
  # Only deploy compute-related files
  rsync -avz --progress nova/compute/ root@$host:${NOVA_BASE_PATH}/compute/
  rsync -avz --progress nova/virt/ root@$host:${NOVA_BASE_PATH}/virt/
  ssh root@$host "systemctl restart openstack-nova-compute"
done
```

## Continuous Deployment

For automated deployments:
```bash
# Create cron job for rsync deployment
cat > /etc/cron.d/xloud-nova-sync << 'EOF'
# Sync XLoud Nova changes every hour
0 * * * * root /opt/xloud-nova/deploy_xloud_nova.sh >> /var/log/xloud-nova-deploy.log 2>&1
EOF
```

## Notes

1. **Python Bytecode**: After deployment, Python will automatically generate `.pyc` files
2. **SELinux**: May need to run `restorecon` on deployed files if SELinux is enabled
3. **Permissions**: Ensure deployed files have correct ownership (typically nova:nova)
4. **Configuration**: Remember to update setup.cfg for extra spec validators
5. **Database**: No database migrations required for these changes
6. **Version Compatibility**: Test thoroughly in staging before production deployment