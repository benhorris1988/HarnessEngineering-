from __future__ import annotations

from typing import Any

from ...models.work_item import WorkItem, WorkItemComment
from ..base import Database

_SELECT_ALL = """
    SELECT id, type, title, description, repro_steps, system_info,
           severity, priority, state, area_path, iteration_path,
           tags, assigned_to, created_by, created_at, updated_at
    FROM dbo.work_items
"""


class WorkItemsRepository:
    def __init__(self, db: Database) -> None:
        self._db = db

    async def list(self, state: str | None = None, limit: int = 100) -> list[WorkItem]:
        where = "WHERE state = ?" if state else ""
        params: tuple[Any, ...] = (state,) if state else ()
        rows = await self._db.query(
            f"{_SELECT_ALL} {where} ORDER BY created_at DESC "
            f"OFFSET 0 ROWS FETCH NEXT {limit} ROWS ONLY",
            params,
        )
        return [WorkItem.from_row(r) for r in rows]

    async def get(self, id_: str) -> WorkItem | None:
        row = await self._db.query_one(f"{_SELECT_ALL} WHERE id = ?", (id_,))
        return WorkItem.from_row(row) if row else None

    async def create(
        self,
        *,
        id_: str,
        type_: str,
        title: str,
        description: str | None = None,
        repro_steps: str | None = None,
        system_info: str | None = None,
        severity: str = "3 - Medium",
        priority: int = 2,
        area_path: str = "Harness",
        iteration_path: str = "Harness\\Current",
        tags: str | None = None,
        created_by: str = "simulated-user",
    ) -> WorkItem:
        await self._db.execute(
            """
            INSERT INTO dbo.work_items
              (id, type, title, description, repro_steps, system_info,
               severity, priority, state, area_path, iteration_path, tags, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'New', ?, ?, ?, ?)
            """,
            (
                id_,
                type_,
                title,
                description,
                repro_steps,
                system_info,
                severity,
                priority,
                area_path,
                iteration_path,
                tags,
                created_by,
            ),
        )
        created = await self.get(id_)
        if created is None:
            raise RuntimeError(f"insert succeeded but row {id_} not found")
        return created

    async def update_state(self, id_: str, state: str) -> None:
        await self._db.execute(
            "UPDATE dbo.work_items SET state = ?, updated_at = SYSUTCDATETIME() "
            "WHERE id = ?",
            (state, id_),
        )

    async def add_comment(self, *, work_item_id: str, author: str, body: str) -> None:
        await self._db.execute(
            "INSERT INTO dbo.work_item_comments (work_item_id, author, body) "
            "VALUES (?, ?, ?)",
            (work_item_id, author, body),
        )

    async def list_comments(self, work_item_id: str) -> list[WorkItemComment]:
        rows = await self._db.query(
            "SELECT id, work_item_id, author, body, created_at "
            "FROM dbo.work_item_comments WHERE work_item_id = ? "
            "ORDER BY created_at ASC",
            (work_item_id,),
        )
        return [WorkItemComment.from_row(r) for r in rows]
