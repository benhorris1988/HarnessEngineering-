from __future__ import annotations

import uuid

from fastapi import APIRouter, HTTPException, Request, status

from ..agent.orchestrator import Orchestrator
from ..db.repositories.work_items import WorkItemsRepository
from .schemas import CreateComment, CreateWorkItem


def make_router() -> APIRouter:
    r = APIRouter(prefix="/api/work-items", tags=["work-items"])

    def _repo(req: Request) -> WorkItemsRepository:
        return req.app.state.work_items

    def _orchestrator(req: Request) -> Orchestrator:
        return req.app.state.orchestrator

    @r.get("")
    async def list_(req: Request, state: str | None = None):
        repo = _repo(req)
        items = await repo.list(state=state)
        return [i.to_api() for i in items]

    @r.post("", status_code=status.HTTP_201_CREATED)
    async def create(req: Request, body: CreateWorkItem):
        repo = _repo(req)
        orch = _orchestrator(req)
        item = await repo.create(
            id_=str(uuid.uuid4()),
            type_=body.type,
            title=body.title,
            description=body.description,
            repro_steps=body.repro_steps,
            system_info=body.system_info,
            severity=body.severity,
            priority=body.priority,
            area_path=body.area_path,
            iteration_path=body.iteration_path,
            tags=body.tags,
            created_by=body.created_by,
        )
        run_id: str | None = None
        if body.autorun:
            run_id = await orch.start_run(item.id)
        return {"workItem": item.to_api(), "runId": run_id}

    @r.get("/{id_}")
    async def get(req: Request, id_: str):
        repo = _repo(req)
        item = await repo.get(id_)
        if item is None:
            raise HTTPException(status_code=404, detail="not found")
        return item.to_api()

    @r.get("/{id_}/comments")
    async def comments(req: Request, id_: str):
        repo = _repo(req)
        return [
            c.model_dump(by_alias=True, mode="json")
            for c in await repo.list_comments(id_)
        ]

    @r.post("/{id_}/comments", status_code=status.HTTP_201_CREATED)
    async def add_comment(req: Request, id_: str, body: CreateComment):
        repo = _repo(req)
        text = body.body.strip()
        if not text:
            raise HTTPException(status_code=400, detail="body is required")
        await repo.add_comment(work_item_id=id_, author=body.author, body=text)
        return {"ok": True}

    @r.post("/{id_}/runs", status_code=status.HTTP_202_ACCEPTED)
    async def kickoff_run(req: Request, id_: str):
        orch = _orchestrator(req)
        run_id = await orch.start_run(id_)
        return {"runId": run_id}

    return r
