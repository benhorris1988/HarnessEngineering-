from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request

from ..db.repositories.agent_runs import AgentRunsRepository


def make_router() -> APIRouter:
    r = APIRouter(prefix="/api/runs", tags=["runs"])

    def _runs(req: Request) -> AgentRunsRepository:
        return req.app.state.runs

    @r.get("/{id_}")
    async def get(req: Request, id_: str):
        runs = _runs(req)
        run = await runs.get(id_)
        if run is None:
            raise HTTPException(status_code=404, detail="not found")
        return run.model_dump(by_alias=True, mode="json")

    @r.get("/{id_}/steps")
    async def steps(req: Request, id_: str):
        runs = _runs(req)
        return [
            s.model_dump(by_alias=True, mode="json") for s in await runs.list_steps(id_)
        ]

    @r.get("/{id_}/messages")
    async def messages(req: Request, id_: str):
        runs = _runs(req)
        return [
            m.model_dump(by_alias=True, mode="json")
            for m in await runs.list_messages(id_)
        ]

    @r.get("/by-work-item/{work_item_id}")
    async def by_work_item(req: Request, work_item_id: str):
        runs = _runs(req)
        return [
            r.model_dump(by_alias=True, mode="json")
            for r in await runs.list_for_work_item(work_item_id)
        ]

    return r
