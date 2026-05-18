from __future__ import annotations

from typing import Any

from ...db.repositories.work_items import WorkItemsRepository
from .base import AgentTool, ToolContext


class ProposeFixTool(AgentTool):
    name = "propose_fix"
    description = (
        "Record a proposed code or process fix. Stored as a comment tagged "
        "[PROPOSED FIX] so a human reviewer can act on it. Use this once you "
        "have identified the root cause."
    )
    parameters_schema: dict[str, Any] = {
        "type": "object",
        "properties": {
            "rootCause": {
                "type": "string",
                "description": "One-paragraph root cause analysis.",
            },
            "fixSummary": {
                "type": "string",
                "description": "What to change, in plain English.",
            },
            "patch": {
                "type": "string",
                "description": "Optional unified-diff patch or pseudo-code.",
            },
            "riskNotes": {
                "type": "string",
                "description": "Risks, regressions to watch for, rollout notes.",
            },
        },
        "required": ["rootCause", "fixSummary"],
    }

    def __init__(self, repo: WorkItemsRepository) -> None:
        self._repo = repo

    async def call(
        self, arguments: dict[str, Any], ctx: ToolContext
    ) -> dict[str, Any]:
        root_cause = arguments.get("rootCause")
        fix_summary = arguments.get("fixSummary")
        if not root_cause or not fix_summary:
            return {"error": "rootCause and fixSummary are required"}
        patch = arguments.get("patch")
        risk = arguments.get("riskNotes")

        parts = [
            "[PROPOSED FIX]",
            "",
            "**Root cause**",
            "",
            root_cause,
            "",
            "**Fix**",
            "",
            fix_summary,
            "",
        ]
        if patch and patch.strip():
            parts += ["**Patch**", "", "```diff", patch, "```", ""]
        if risk and risk.strip():
            parts += ["**Risk notes**", "", risk]

        await self._repo.add_comment(
            work_item_id=ctx.work_item_id,
            author="agent",
            body="\n".join(parts),
        )
        return {"ok": True}
