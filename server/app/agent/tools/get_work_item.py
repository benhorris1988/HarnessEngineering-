from __future__ import annotations

from typing import Any

from ...db.repositories.work_items import WorkItemsRepository
from .base import AgentTool, ToolContext


class GetWorkItemTool(AgentTool):
    name = "get_work_item"
    description = "Fetch the current work item, its fields, and recent comments."
    parameters_schema: dict[str, Any] = {
        "type": "object",
        "properties": {},
        "required": [],
    }

    def __init__(self, repo: WorkItemsRepository) -> None:
        self._repo = repo

    async def call(
        self, arguments: dict[str, Any], ctx: ToolContext
    ) -> dict[str, Any]:
        item = await self._repo.get(ctx.work_item_id)
        if item is None:
            return {"error": f"work item {ctx.work_item_id} not found"}
        comments = await self._repo.list_comments(ctx.work_item_id)
        return {
            "workItem": item.to_api(),
            "comments": [
                {
                    "author": c.author,
                    "body": c.body,
                    "createdAt": c.created_at.isoformat(),
                }
                for c in comments
            ],
        }
