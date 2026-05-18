from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .agent.ollama_client import OllamaClient
from .agent.orchestrator import Orchestrator
from .agent.tools.base import ToolRegistry
from .agent.tools.comment import CommentOnWorkItemTool
from .agent.tools.get_work_item import GetWorkItemTool
from .agent.tools.propose_fix import ProposeFixTool
from .agent.tools.run_tests import RunTestsTool
from .api.agent_runs import make_router as make_agent_runs_router
from .api.work_items import make_router as make_work_items_router
from .config import Settings, get_settings
from .db.base import Database
from .db.memory import MemoryDatabase
from .db.mssql import MssqlDatabase
from .db.repositories.agent_runs import AgentRunsRepository
from .db.repositories.work_items import WorkItemsRepository

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
log = logging.getLogger("harness")


def _build_database(settings: Settings) -> Database:
    if settings.harness_db == "memory":
        return MemoryDatabase()
    return MssqlDatabase(settings.odbc_connection_string)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    db = _build_database(settings)
    await db.connect()
    log.info(
        "DB ready (%s)",
        "in-memory" if settings.harness_db == "memory"
        else f"MSSQL {settings.mssql_host}:{settings.mssql_port}/{settings.mssql_db}",
    )

    work_items = WorkItemsRepository(db)
    runs = AgentRunsRepository(db)
    ollama = OllamaClient(base_url=settings.ollama_url, model=settings.ollama_model)
    tools = ToolRegistry(
        [
            GetWorkItemTool(work_items),
            CommentOnWorkItemTool(work_items),
            ProposeFixTool(work_items),
            RunTestsTool(),
        ]
    )
    orchestrator = Orchestrator(
        work_items=work_items,
        runs=runs,
        tools=tools,
        ollama=ollama,
        max_steps=settings.agent_max_steps,
    )

    app.state.settings = settings
    app.state.db = db
    app.state.work_items = work_items
    app.state.runs = runs
    app.state.ollama = ollama
    app.state.orchestrator = orchestrator
    log.info("Harness ready on port %s", settings.harness_port)

    try:
        yield
    finally:
        await ollama.close()
        await db.close()
        log.info("Harness shutdown complete")


def create_app() -> FastAPI:
    app = FastAPI(
        title="Harness Engineering",
        description="Agentic DevOps assistant — backend API.",
        version="0.1.0",
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/api/health", tags=["meta"])
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    app.include_router(make_work_items_router())
    app.include_router(make_agent_runs_router())
    return app


app = create_app()
