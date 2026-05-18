from __future__ import annotations

from typing import Any

from ...db.repositories.work_items import WorkItemsRepository
from .base import AgentTool, ToolContext


class CommentOnWorkItemTool(AgentTool):
    name = "comment_on_work_item"
    description = (
        "Post a comment back to the work item. Use this to record findings "
        "or to communicate with the human owner."
    )
    parameters_schema: dict[str, Any] = {
        "type": "object",
        "properties": {
            "body": {
                "type": "string",
                "description": "Markdown body of the comment.",
            }
        },
        "required": ["body"],
    }

    def __init__(self, repo: WorkItemsRepository) -> None:
        self._repo = repo

    async def call(
        self, arguments: dict[str, Any], ctx: ToolContext
    ) -> dict[str, Any]:
        body = (arguments.get("body") or "").strip()
        if not body:
            return {"error": "body is required"}
        await self._repo.add_comment(
            work_item_id=ctx.work_item_id,
            author="agent",
            body=body,
        )
        return {"ok": True}
