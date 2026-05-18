from __future__ import annotations

from typing import Any

from .base import AgentTool, ToolContext


class RunTestsTool(AgentTool):
    """Stub test runner.

    Real deployments would shell out to the actual repo under test. Here
    we return a deterministic envelope so the agent loop can be exercised
    end-to-end without external dependencies.
    """

    name = "run_tests"
    description = (
        "Run the relevant test suite. Returns pass/fail counts and the "
        "first failing test name if any. (Simulated in this build.)"
    )
    parameters_schema: dict[str, Any] = {
        "type": "object",
        "properties": {
            "suite": {
                "type": "string",
                "description": 'Suite or path filter, e.g. "auth", "etl".',
            }
        },
        "required": ["suite"],
    }

    async def call(
        self, arguments: dict[str, Any], ctx: ToolContext
    ) -> dict[str, Any]:
        suite = (arguments.get("suite") or "").lower()
        if "auth" in suite:
            return {
                "passed": 142,
                "failed": 1,
                "firstFailure": "auth/login_email_with_plus_test",
                "durationMs": 8421,
            }
        if "etl" in suite:
            return {
                "passed": 38,
                "failed": 0,
                "durationMs": 12044,
                "note": "job duration exceeded SLA by 2h42m",
            }
        return {"passed": 0, "failed": 0, "note": f'no suite matched "{suite}"'}
