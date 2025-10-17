# OpenStack Nova Copilot Instructions

## Architecture Overview

Nova is a distributed system with multiple service types that communicate via RPC (oslo.messaging):

- **nova-api**: REST API service handling user requests (`nova/api/`)
- **nova-conductor**: Database proxy and workflow orchestrator (`nova/conductor/`)
- **nova-scheduler**: Resource allocation and host selection (`nova/scheduler/`)
- **nova-compute**: Hypervisor management on compute nodes (`nova/compute/`)

### Critical Communication Flow
1. API receives requests → Conductor via `ComputeTaskAPI`
2. Conductor coordinates workflow → Scheduler for placement decisions
3. Conductor sends tasks → Compute nodes for execution
4. All DB operations flow through Conductor (compute nodes are DB-less)

## Key Development Patterns

### RPC API Versioning
- Each service has versioned RPC APIs with backwards compatibility
- Use `@messaging.expected_exceptions()` for proper exception handling
- Version bumps require careful consideration of rolling upgrades
- Example: `nova/conductor/rpcapi.py` shows version evolution patterns

### Object Model (VersionedObjects)
- All data uses oslo.versionedobjects for serialization/RPC safety
- Objects in `nova/objects/` with fields, version management
- Use `context` parameter consistently across all methods
- Objects handle DB mapping and validation automatically

### Service Structure
- Services inherit from `nova.manager.Manager`
- Use `nova.service.Service.create()` for service bootstrapping
- Periodic tasks via `@periodic_task.periodic_task()` decorator
- Entry points defined in `setup.cfg` for service binaries

### Configuration Management
- Centralized config in `nova/conf/` using oslo.config
- Use `nova.conf.CONF` not raw config access
- Config options grouped by functional area (compute.py, api.py, etc.)

### Exception Handling
- Custom exceptions in `nova/exception.py`
- Use specific exceptions, avoid generic `Exception`
- RPC methods should declare expected exceptions for proper serialization

## Testing Conventions

### Test Structure
- Unit tests: `nova/tests/unit/` (mirrors source structure)
- Functional tests: `nova/tests/functional/`
- Use fixtures from `nova/tests/fixtures/` for common setups
- Mock external dependencies, test Nova logic

### Test Commands
```bash
tox -e py3              # Run unit tests
tox -e functional       # Run functional tests  
tox -e pep8             # Code style checks
tox -e cover            # Coverage report
```

### Common Test Patterns
- Use `nova.test.TestCase` base class
- Mock RPC calls with `mock.patch()`
- Use `self.flags()` for config overrides, never `CONF.set_override()`
- Test exception paths and edge cases

## Database & Migration Patterns

### Database Access
- Only Conductor touches the database directly
- Compute nodes are DB-less, use RPC to Conductor
- Use objects layer, avoid raw SQLAlchemy in most cases
- DB migrations in `nova/db/main/migrations/versions/`

### Object Relationships
- Use `obj_relationships` for lazy loading
- Handle object versioning in `obj_make_compatible()`
- Objects auto-backport for older RPC API consumers

## Common Workflows

### Instance Lifecycle
1. API validates request → `conductor.ComputeTaskAPI.schedule_and_build_instances()`
2. Conductor → Scheduler for resource claims
3. Conductor → Compute for build/spawn
4. Periodic updates via heartbeats and RPC calls

### Development Workflow
- Gerrit-based reviews (not GitHub PRs)
- Follow `HACKING.rst` style guidelines (Nova-specific rules N3xx)
- Add specs for significant features in `nova-specs` repository
- Use `nova-manage` CLI for administrative operations

## Key Files for Context
- `nova/compute/manager.py`: Core compute operations (12k+ lines)
- `nova/conductor/manager.py`: Workflow orchestration
- `nova/scheduler/manager.py`: Resource allocation logic
- `nova/api/openstack/compute/servers.py`: Instance API endpoints
- `nova/rpc.py`: RPC infrastructure setup
- `nova/service.py`: Base service framework

## Anti-patterns
- Never import `nova.db` in `nova/virt/` (enforced by N307)
- Don't use `datetime.datetime.utcnow()` directly (use `nova.utils.utcnow()`)
- Avoid cross-virt-driver imports (use common modules)
- Don't access config from other virt drivers
- Use versioned objects, not raw dicts for RPC data