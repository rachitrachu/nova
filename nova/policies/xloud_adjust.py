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
