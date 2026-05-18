from __future__ import annotations

from typing import Any

from ...models.agent_run import AgentMessage, AgentRun, PlanStep
from ..base import Database


class AgentRunsRepository:
    def __init__(self, db: Database) -> None:
        self._db = db

    async def create(
        self, *, id_: str, work_item_id: str, model: str, max_steps: int
    ) -> AgentRun:
        await self._db.execute(
            """
            INSERT INTO dbo.agent_runs (id, work_item_id, model, status, max_steps)
            VALUES (?, ?, ?, 'pending', ?)
            """,
            (id_, work_item_id, model, max_steps),
        )
        run = await self.get(id_)
        assert run is not None
        return run

    async def get(self, id_: str) -> AgentRun | None:
        row = await self._db.query_one(
            "SELECT id, work_item_id, model, status, summary, started_at, "
            "finished_at, max_steps, error FROM dbo.agent_runs WHERE id = ?",
            (id_,),
        )
        return AgentRun.from_row(row) if row else None

    async def list_for_work_item(self, work_item_id: str) -> list[AgentRun]:
        rows = await self._db.query(
            "SELECT id, work_item_id, model, status, summary, started_at, "
            "finished_at, max_steps, error FROM dbo.agent_runs "
            "WHERE work_item_id = ? ORDER BY started_at DESC",
            (work_item_id,),
        )
        return [AgentRun.from_row(r) for r in rows]

    async def set_status(self, id_: str, status: str, error: str | None = None) -> None:
        finished = status in {"done", "failed", "blocked"}
        ts = "SYSUTCDATETIME()" if finished else "finished_at"
        await self._db.execute(
            f"UPDATE dbo.agent_runs SET status = ?, error = ?, finished_at = {ts} "
            "WHERE id = ?",
            (status, error, id_),
        )

    async def set_summary(self, id_: str, summary: str) -> None:
        await self._db.execute(
            "UPDATE dbo.agent_runs SET summary = ? WHERE id = ?",
            (summary, id_),
        )

    async def add_step(
        self,
        *,
        id_: str,
        run_id: str,
        ordinal: int,
        title: str,
        rationale: str | None,
    ) -> PlanStep:
        await self._db.execute(
            "INSERT INTO dbo.plan_steps (id, run_id, ordinal, title, rationale, status) "
            "VALUES (?, ?, ?, ?, ?, 'pending')",
            (id_, run_id, ordinal, title, rationale),
        )
        step = await self.get_step(id_)
        assert step is not None
        return step

    async def get_step(self, id_: str) -> PlanStep | None:
        row = await self._db.query_one(
            "SELECT id, run_id, ordinal, title, rationale, status, result, "
            "started_at, finished_at FROM dbo.plan_steps WHERE id = ?",
            (id_,),
        )
        return PlanStep.from_row(row) if row else None

    async def list_steps(self, run_id: str) -> list[PlanStep]:
        rows = await self._db.query(
            "SELECT id, run_id, ordinal, title, rationale, status, result, "
            "started_at, finished_at FROM dbo.plan_steps "
            "WHERE run_id = ? ORDER BY ordinal ASC",
            (run_id,),
        )
        return [PlanStep.from_row(r) for r in rows]

    async def update_step(
        self,
        *,
        id_: str,
        status: str | None = None,
        result: str | None = None,
        mark_started: bool = False,
        mark_finished: bool = False,
    ) -> None:
        sets: list[str] = []
        params: list[Any] = []
        if status is not None:
            sets.append("status = ?")
            params.append(status)
        if result is not None:
            sets.append("result = ?")
            params.append(result)
        if mark_started:
            sets.append("started_at = SYSUTCDATETIME()")
        if mark_finished:
            sets.append("finished_at = SYSUTCDATETIME()")
        if not sets:
            return
        params.append(id_)
        await self._db.execute(
            f"UPDATE dbo.plan_steps SET {', '.join(sets)} WHERE id = ?",
            tuple(params),
        )

    async def add_message(
        self,
        *,
        id_: str,
        run_id: str,
        step_id: str | None,
        role: str,
        content: str,
        tool_name: str | None = None,
    ) -> None:
        await self._db.execute(
            "INSERT INTO dbo.agent_messages "
            "(id, run_id, step_id, role, content, tool_name) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (id_, run_id, step_id, role, content, tool_name),
        )

    async def list_messages(self, run_id: str) -> list[AgentMessage]:
        rows = await self._db.query(
            "SELECT id, run_id, step_id, role, content, tool_name, created_at "
            "FROM dbo.agent_messages WHERE run_id = ? ORDER BY created_at ASC",
            (run_id,),
        )
        return [AgentMessage.from_row(r) for r in rows]

    async def record_tool_call(
        self,
        *,
        id_: str,
        run_id: str,
        step_id: str | None,
        tool_name: str,
        arguments_json: str,
        result_json: str,
        success: bool,
    ) -> None:
        await self._db.execute(
            "INSERT INTO dbo.tool_calls "
            "(id, run_id, step_id, tool_name, arguments, result, success, finished_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, SYSUTCDATETIME())",
            (id_, run_id, step_id, tool_name, arguments_json, result_json, 1 if success else 0),
        )
