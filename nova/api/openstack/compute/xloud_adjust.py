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
