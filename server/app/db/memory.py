from __future__ import annotations

import asyncio
import re
import uuid
from datetime import UTC, datetime
from typing import Any

_WS = re.compile(r"\s+")


def _normalise(sql: str) -> str:
    """Lower-case and collapse all whitespace so substring matchers work
    regardless of how the repository SQL is formatted."""
    return _WS.sub(" ", sql.lower()).strip()


class MemoryDatabase:
    """In-memory store used when ``HARNESS_DB=memory``.

    Understands only the small SQL dialect this app actually issues —
    not a real SQL engine. Useful for demos, tests, and getting the
    UI running without installing ODBC drivers.
    """

    def __init__(self) -> None:
        self._lock = asyncio.Lock()
        self._work_items: list[dict[str, Any]] = []
        self._comments: list[dict[str, Any]] = []
        self._runs: list[dict[str, Any]] = []
        self._steps: list[dict[str, Any]] = []
        self._messages: list[dict[str, Any]] = []
        self._tool_calls: list[dict[str, Any]] = []

    async def connect(self) -> None:  # noqa: D401
        return None

    async def close(self) -> None:
        return None

    @staticmethod
    def _now() -> datetime:
        return datetime.now(tz=UTC)

    async def execute(self, sql: str, params: tuple[Any, ...] = ()) -> int:
        async with self._lock:
            return self._execute(_normalise(sql), params)

    def _execute(self, lower: str, params: tuple[Any, ...]) -> int:
        if "insert into dbo.work_items" in lower:
            self._work_items.append(self._work_item_row(params))
            return 1
        if "update dbo.work_items" in lower:
            row = self._find(self._work_items, params[-1])
            row["state"] = params[0]
            row["updated_at"] = self._now()
            return 1
        if "insert into dbo.work_item_comments" in lower:
            self._comments.append(
                {
                    "id": str(uuid.uuid4()),
                    "work_item_id": params[0],
                    "author": params[1],
                    "body": params[2],
                    "created_at": self._now(),
                }
            )
            return 1
        if "insert into dbo.agent_runs" in lower:
            self._runs.append(
                {
                    "id": params[0],
                    "work_item_id": params[1],
                    "model": params[2],
                    "status": "pending",
                    "summary": None,
                    "started_at": self._now(),
                    "finished_at": None,
                    "max_steps": params[3],
                    "error": None,
                }
            )
            return 1
        if "update dbo.agent_runs set status" in lower:
            row = self._find(self._runs, params[-1])
            row["status"] = params[0]
            row["error"] = params[1]
            if params[0] in {"done", "failed", "blocked"}:
                row["finished_at"] = self._now()
            return 1
        if "update dbo.agent_runs set summary" in lower:
            row = self._find(self._runs, params[-1])
            row["summary"] = params[0]
            return 1
        if "insert into dbo.plan_steps" in lower:
            self._steps.append(
                {
                    "id": params[0],
                    "run_id": params[1],
                    "ordinal": params[2],
                    "title": params[3],
                    "rationale": params[4],
                    "status": "pending",
                    "result": None,
                    "started_at": None,
                    "finished_at": None,
                }
            )
            return 1
        if "update dbo.plan_steps" in lower:
            row = self._find(self._steps, params[-1])
            pi = 0
            if "status = ?" in lower:
                row["status"] = params[pi]
                pi += 1
            if "result = ?" in lower:
                row["result"] = params[pi]
                pi += 1
            if "started_at = sysutcdatetime()" in lower:
                row["started_at"] = self._now()
            if "finished_at = sysutcdatetime()" in lower:
                row["finished_at"] = self._now()
            return 1
        if "insert into dbo.agent_messages" in lower:
            self._messages.append(
                {
                    "id": params[0],
                    "run_id": params[1],
                    "step_id": params[2],
                    "role": params[3],
                    "content": params[4],
                    "tool_name": params[5],
                    "created_at": self._now(),
                }
            )
            return 1
        if "insert into dbo.tool_calls" in lower:
            self._tool_calls.append(
                {
                    "id": params[0],
                    "run_id": params[1],
                    "step_id": params[2],
                    "tool_name": params[3],
                    "arguments": params[4],
                    "result": params[5],
                    "success": params[6],
                    "started_at": self._now(),
                    "finished_at": self._now(),
                }
            )
            return 1
        raise NotImplementedError(f"MemoryDatabase.execute: {lower}")

    def _work_item_row(self, params: tuple[Any, ...]) -> dict[str, Any]:
        now = self._now()
        return {
            "id": params[0],
            "type": params[1],
            "title": params[2],
            "description": params[3],
            "repro_steps": params[4],
            "system_info": params[5],
            "severity": params[6],
            "priority": params[7],
            "state": "New",
            "area_path": params[8],
            "iteration_path": params[9],
            "tags": params[10],
            "assigned_to": None,
            "created_by": params[11],
            "created_at": now,
            "updated_at": now,
        }

    @staticmethod
    def _find(rows: list[dict[str, Any]], id_: Any) -> dict[str, Any]:
        for r in rows:
            if r["id"] == id_:
                return r
        raise KeyError(id_)

    async def query(
        self, sql: str, params: tuple[Any, ...] = ()
    ) -> list[dict[str, Any]]:
        async with self._lock:
            return self._query(_normalise(sql), params)

    def _query(self, lower: str, params: tuple[Any, ...]) -> list[dict[str, Any]]:
        if "from dbo.work_items where id = ?" in lower:
            return [r for r in self._work_items if r["id"] == params[0]]
        if "from dbo.work_items" in lower:
            items = list(self._work_items)
            if "where state = ?" in lower:
                items = [r for r in items if r["state"] == params[0]]
            items.sort(key=lambda r: r["created_at"], reverse=True)
            return items
        if "from dbo.work_item_comments" in lower:
            items = [r for r in self._comments if r["work_item_id"] == params[0]]
            items.sort(key=lambda r: r["created_at"])
            return items
        if "from dbo.agent_runs where id = ?" in lower:
            return [r for r in self._runs if r["id"] == params[0]]
        if "from dbo.agent_runs" in lower:
            items = [r for r in self._runs if r["work_item_id"] == params[0]]
            items.sort(key=lambda r: r["started_at"], reverse=True)
            return items
        if "from dbo.plan_steps where id = ?" in lower:
            return [r for r in self._steps if r["id"] == params[0]]
        if "from dbo.plan_steps" in lower:
            items = [r for r in self._steps if r["run_id"] == params[0]]
            items.sort(key=lambda r: r["ordinal"])
            return items
        if "from dbo.agent_messages" in lower:
            items = [r for r in self._messages if r["run_id"] == params[0]]
            items.sort(key=lambda r: r["created_at"])
            return items
        raise NotImplementedError(f"MemoryDatabase.query: {lower}")

    async def query_one(
        self, sql: str, params: tuple[Any, ...] = ()
    ) -> dict[str, Any] | None:
        rows = await self.query(sql, params)
        return rows[0] if rows else None
