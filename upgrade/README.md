# XLoud Nova Upgrade Documentation

This directory contains complete documentation for deploying XLoud Nova changes to a new Nova installation using rsync.

## Documentation Files

### 1. **RSYNC_DEPLOYMENT_GUIDE.md** - Primary Deployment Guide
- Complete rsync deployment procedures
- Docker container deployment methods
- Pre/post deployment steps
- Verification and validation
- Troubleshooting guide
- Multi-node deployment strategies

**Use this for**: Step-by-step deployment instructions

### 2. **EXACT_CODE_REFERENCE.md** - Complete Code Listing
- Full source code for all 5 new files
- Exact code sections to add/modify in 18 existing files
- Line numbers and context for each change
- Quick verification commands
- All code includes `#xloud` markers for easy identification

**Use this for**: Understanding what code changes were made

### 3. **FILE_MAPPING.md** - File-by-File Reference
- Exact source-to-destination file mappings
- Individual rsync commands for each file
- Deployment commands by category (new files, core, libvirt, tests)
- Single-command bulk deployment
- File size and deployment time estimates
- Verification and rollback scripts

**Use this for**: Rsync command reference and file organization

### 4. **XLOUD_NOVA_CHANGES.md** - Detailed Implementation Guide
- Feature overview and architecture
- Detailed explanation of each file change
- Integration points and dependencies
- API usage examples
- Implementation order recommendations

**Use this for**: Understanding the feature implementation

### 5. **CHANGE_SUMMARY.md** - High-Level Overview
- Statistics: 23 files (5 new, 18 modified)
- Feature area breakdown
- Implementation dependencies
- Change categorization

**Use this for**: Quick overview of scope

### 6. **GIT_COMMANDS.md** - Git Operations
- Git diff and patch generation commands
- Cherry-pick strategies
- Conflict resolution approaches
- Testing procedures
- Version-specific considerations

**Use this for**: Git-based deployment or understanding commit history

## Quick Start Guide

### For Rsync Deployment (Recommended)

1. **Read**: `RSYNC_DEPLOYMENT_GUIDE.md` (sections 1-3)
2. **Review**: `FILE_MAPPING.md` to understand file locations
3. **Execute**: Use deployment script from `RSYNC_DEPLOYMENT_GUIDE.md`
4. **Verify**: Follow verification steps in `RSYNC_DEPLOYMENT_GUIDE.md`

### For Manual Code Review

1. **Read**: `EXACT_CODE_REFERENCE.md` 
2. **Copy**: Code sections to target Nova installation
3. **Test**: Use verification commands from `EXACT_CODE_REFERENCE.md`

### For Understanding Changes

1. **Start**: `CHANGE_SUMMARY.md` for overview
2. **Deep Dive**: `XLOUD_NOVA_CHANGES.md` for details
3. **Reference**: `EXACT_CODE_REFERENCE.md` for actual code

## Features Implemented

### 1. Minimum Resource Extra Specs
- **Extra specs**: `minimum_cpu`, `minimum_memory`
- **Purpose**: Start instances with fewer resources than flavor max
- **Files affected**: 8 files (validation, scheduler, compute, objects)

### 2. Dynamic Resource Adjustment API
- **Endpoint**: `POST /os-xloud-adjust/{server_id}`
- **Purpose**: Live vCPU/memory adjustment via REST API
- **Files affected**: 6 files (API, RPC, compute manager)

### 3. Libvirt Integration
- **Features**: vCPU current attribute, memory balloon
- **Purpose**: Support for libvirt live resource management
- **Files affected**: 4 files (config, driver, guest)

## File Statistics

```
Total Files Changed: 23
├── New Files: 5
│   ├── nova/api/openstack/compute/xloud_adjust.py
│   ├── nova/api/validation/extra_specs/minimum.py
│   ├── nova/policies/xloud_adjust.py
│   ├── nova/tests/functional/libvirt/test_vcpu_current.py
│   └── releasenotes/notes/minimum-cpu-current-vcpu-attr.yaml
│
└── Modified Files: 18
    ├── API Layer (1)
    │   └── nova/api/openstack/compute/routes.py
    ├── Compute Layer (4)
    │   ├── nova/compute/api.py
    │   ├── nova/compute/instance_actions.py
    │   ├── nova/compute/manager.py
    │   └── nova/compute/rpcapi.py
    ├── Objects & Scheduling (3)
    │   ├── nova/objects/request_spec.py
    │   ├── nova/scheduler/utils.py
    │   └── nova/policies/__init__.py
    ├── Virtualization (4)
    │   ├── nova/virt/driver.py
    │   ├── nova/virt/libvirt/config.py
    │   ├── nova/virt/libvirt/driver.py
    │   └── nova/virt/libvirt/guest.py
    ├── Tests (4)
    │   ├── nova/tests/functional/test_flavor_extraspecs.py
    │   ├── nova/tests/functional/test_servers.py
    │   ├── nova/tests/unit/compute/test_compute.py
    │   └── nova/tests/unit/scheduler/test_utils.py
    ├── Configuration (1)
    │   └── setup.cfg
    └── Documentation (1)
        └── doc/source/configuration/extra-specs.rst
```

## Deployment Checklist

### Pre-Deployment
- [ ] Read `RSYNC_DEPLOYMENT_GUIDE.md`
- [ ] Identify target Nova installation path
- [ ] Set environment variables (TARGET_HOST, CONTAINER_NAME, NOVA_BASE_PATH)
- [ ] Create backup of existing Nova installation
- [ ] Test SSH/Docker access to target host

### Deployment
- [ ] Deploy 5 new files
- [ ] Deploy 18 modified files
- [ ] Update setup.cfg with validator registration
- [ ] Verify file permissions (644 for .py files)
- [ ] Test Python imports

### Post-Deployment
- [ ] Restart Nova API service
- [ ] Restart Nova Conductor service
- [ ] Restart Nova Scheduler service
- [ ] Restart Nova Compute services (on compute nodes)
- [ ] Verify API endpoint is accessible
- [ ] Test flavor with minimum_cpu extra spec
- [ ] Test dynamic adjustment API

### Validation
- [ ] Create test flavor with minimum specs
- [ ] Launch test instance
- [ ] Verify vCPU current attribute in libvirt XML
- [ ] Test xloud-adjust API endpoint
- [ ] Run functional tests (optional)
- [ ] Check Nova logs for errors

## Environment Variables

Set these before deployment:

```bash
# Target deployment host
export TARGET_HOST="103.240.25.209"

# Docker container name (or blank if not using Docker)
export CONTAINER_NAME="nova_api"

# Nova installation path
export NOVA_SITE_PACKAGES="/usr/local/lib/python3.10/site-packages/nova"

# Nova source root (for setup.cfg, release notes)
export NOVA_ROOT="/opt/nova"

# Backup directory (local)
export BACKUP_DIR="./backups"
```

## Common Deployment Scenarios

### Scenario 1: Docker-based Nova API
```bash
# Single controller with Docker containers
cd /root/xloud-nova
source upgrade/env.sh  # Load environment variables
bash upgrade/deploy_docker.sh
```

### Scenario 2: Systemd-based Nova Services
```bash
# Traditional OpenStack installation
cd /root/xloud-nova
export NOVA_SITE_PACKAGES="/usr/lib/python3/dist-packages/nova"
bash upgrade/deploy_systemd.sh
```

### Scenario 3: Multi-Node OpenStack
```bash
# Deploy to controllers and compute nodes
cd /root/xloud-nova
bash upgrade/deploy_multinode.sh
```

### Scenario 4: Manual File-by-File
```bash
# For careful, controlled deployment
# Follow FILE_MAPPING.md step by step
cd /root/xloud-nova
# Copy each file individually using rsync commands
```

## Troubleshooting

### Import Errors
**Problem**: `ImportError: cannot import name 'xloud_adjust'`
**Solution**: Check file was deployed correctly and Python path
**Command**: `python3 -c "from nova.api.openstack.compute import xloud_adjust"`

### API Endpoint Not Found
**Problem**: `404 Not Found` when calling `/os-xloud-adjust/{server_id}`
**Solution**: Verify routes.py was updated and service restarted
**Command**: `grep xloud_adjust nova/api/openstack/compute/routes.py`

### Service Won't Start
**Problem**: Nova service fails to start after deployment
**Solution**: Check logs for syntax errors, restore from backup
**Command**: `docker logs nova_api --tail 50` or `journalctl -u openstack-nova-api -n 50`

### Permission Denied
**Problem**: Cannot read deployed files
**Solution**: Fix file permissions
**Command**: `chmod 644 /path/to/deployed/file.py`

## Support and Contact

For issues with XLoud Nova changes:
1. Check `RSYNC_DEPLOYMENT_GUIDE.md` troubleshooting section
2. Review Nova logs for error messages
3. Verify all files deployed correctly using verification script
4. Restore from backup if needed

## Version Compatibility

These changes are based on:
- **Source Branch**: `stable/2024.1`
- **Original Branch**: `origin/original`
- **Tested With**: OpenStack 2024.1 (Caracal)

For newer Nova versions:
1. Review `GIT_COMMANDS.md` for conflict resolution strategies
2. Check for API/RPC version changes
3. Test in staging environment first
4. Adjust line numbers in `EXACT_CODE_REFERENCE.md` as needed

## Additional Resources

- OpenStack Nova Documentation: https://docs.openstack.org/nova/
- Nova API Reference: https://docs.openstack.org/api-ref/compute/
- Libvirt Domain XML: https://libvirt.org/formatdomain.html
- Oslo.Policy Documentation: https://docs.openstack.org/oslo.policy/

## License

These changes are made to OpenStack Nova, which is licensed under Apache License 2.0.
See the LICENSE file in the Nova repository for details.