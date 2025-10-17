# Git Commands and Patch Application Guide

This document provides git commands and patch information for applying XLoud Nova changes to a new version.

## Git Information

### Original Branch Comparison
```bash
# View the changes made in current branch vs original
git diff origin/original..stable/2024.1

# View only the file names that were changed  
git diff origin/original..stable/2024.1 --name-only

# View commit history of changes
git log --oneline origin/original..stable/2024.1
```

### Commits in Feature Branch
The following commits were made on the stable/2024.1 branch:

```
d70f4575e5 Update minimum.py
e82c3ceeae Added initial modules and environment files
263f003302 Added initial modules and environment files
... (multiple commits adding modules)
bb7f1bc741 Merge pull request #2 from rachitrachu/codex/implement-minimum_cpu-and-current-vcpu-support
99bc462b7d tests: add vcpu current functional test
e304f231d3 Merge pull request #1 from rachitrachu/codex/override-instance-vcpus-and-memory-from-flavor
230c9fe370 Support minimum CPU and memory extra specs
```

### Key Feature Commits
1. **230c9fe370**: Support minimum CPU and memory extra specs
2. **99bc462b7d**: tests: add vcpu current functional test  
3. **d70f4575e5**: Update minimum.py

## Applying Changes to New Nova Version

### Method 1: Cherry-pick Individual Commits
```bash
# For each feature commit, cherry-pick to new branch
git cherry-pick 230c9fe370  # minimum CPU/memory support
git cherry-pick 99bc462b7d  # vCPU current tests
git cherry-pick d70f4575e5  # minimum.py updates
```

### Method 2: Generate and Apply Patches
```bash
# Generate patch files for all changes
git format-patch origin/original..stable/2024.1 -o patches/

# Apply patches to new branch (in order)
git am patches/*.patch
```

### Method 3: Create Single Comprehensive Patch
```bash
# Generate single patch file with all changes
git diff origin/original stable/2024.1 > xloud-nova-complete.patch

# Apply to new codebase
git apply xloud-nova-complete.patch
```

### Method 4: Manual File-by-File Application

Using the detailed file changes in `XLOUD_NOVA_CHANGES.md`, manually apply each code block to the corresponding files in the new Nova version.

## Conflict Resolution Strategy

When applying to a newer Nova version, conflicts may occur. Use this resolution strategy:

### 1. API/Route Changes
- **File**: `nova/api/openstack/compute/routes.py`
- **Strategy**: Add xloud_adjust imports and route entry, preserving existing route structure
- **Potential Conflicts**: New routes added in newer Nova versions

### 2. Compute Manager Changes  
- **File**: `nova/compute/manager.py`
- **Strategy**: Add xloud methods as new methods, integrate minimum resource logic in `_set_instance_info`
- **Potential Conflicts**: Changes to `_set_instance_info` method signature or logic

### 3. RPC API Changes
- **File**: `nova/compute/rpcapi.py` 
- **Strategy**: Add new RPC methods, may need to update version numbers
- **Potential Conflicts**: RPC API version changes, new methods added

### 4. Libvirt Driver Changes
- **File**: `nova/virt/libvirt/driver.py`
- **Strategy**: Add xloud methods and integrate minimum resource handling in guest config
- **Potential Conflicts**: Changes to `_get_guest_config` method

### 5. Scheduler Changes
- **File**: `nova/scheduler/utils.py`
- **Strategy**: Update pinning policy method to accept request_spec instead of flavor
- **Potential Conflicts**: Scheduler refactoring in newer versions

## Testing After Application

### 1. Unit Tests
```bash
# Run tests for modified modules
tox -e py3 -- nova.tests.unit.compute.test_compute
tox -e py3 -- nova.tests.unit.scheduler.test_utils
```

### 2. Functional Tests  
```bash
# Run functional tests for new features
tox -e functional -- nova.tests.functional.test_servers.ServerMinimumExtraSpecsTest
tox -e functional -- nova.tests.functional.libvirt.test_vcpu_current
```

### 3. API Tests
```bash
# Test new API endpoints
tox -e functional -- nova.tests.functional.test_flavor_extraspecs
```

### 4. Integration Testing
```bash
# Full test suite
tox

# Fast targeted testing  
tools/run-tests-for-diff.sh
```

## Version-Specific Considerations

### Nova 2024.2 (Dalmatian)
- Check for changes to RPC API versioning
- Verify compute manager method signatures
- Update policy format if changed

### Nova 2025.1 (Future Release)
- Review scheduler refactoring
- Check for libvirt driver architectural changes
- Verify extra spec validation framework changes

### General Upgrade Path
1. Apply core object changes first (request_spec.py)
2. Apply scheduler changes
3. Apply compute manager changes  
4. Apply RPC API changes
5. Apply libvirt driver changes
6. Apply API layer changes
7. Apply tests and validation

## Rollback Strategy

### Save Original State
```bash
# Before applying changes, create backup branch
git checkout -b backup-before-xloud-changes
```

### Rollback Commands
```bash
# If using cherry-pick, reset to before first commit
git reset --hard <commit-before-xloud-changes>

# If using patch, reverse apply
git apply -R xloud-nova-complete.patch

# If manual changes, restore from backup
git checkout backup-before-xloud-changes
```

## Validation Checklist

After applying changes, verify:

- [ ] All new files are created in correct locations
- [ ] Import statements are correctly added
- [ ] Policy registration includes xloud_adjust
- [ ] Setup.cfg includes minimum validator
- [ ] RPC version numbers are compatible
- [ ] Libvirt config attributes are properly initialized
- [ ] Tests pass without errors
- [ ] API endpoints are accessible
- [ ] Minimum resource extra specs validate correctly
- [ ] Dynamic adjustment API functions properly

## Support Commands

```bash
# Check current branch and status
git status
git branch -v

# View specific file changes
git show HEAD:nova/compute/manager.py
git diff HEAD~1 nova/compute/manager.py

# Validate Python syntax
python -m py_compile nova/api/openstack/compute/xloud_adjust.py

# Check import issues
python -c "from nova.api.openstack.compute import xloud_adjust"
```