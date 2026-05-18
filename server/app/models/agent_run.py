from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from .work_item import _parse_dt


class AgentRun(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    work_item_id: str = Field(alias="workItemId")
    model: str
    status: str
    summary: str | None = None
    started_at: datetime = Field(alias="startedAt")
    finished_at: datetime | None = Field(default=None, alias="finishedAt")
    max_steps: int = Field(alias="maxSteps")
    error: str | None = None

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> AgentRun:
        return cls(
            id=str(row["id"]),
            workItemId=str(row["work_item_id"]),
            model=row["model"],
            status=row["status"],
            summary=row.get("summary"),
            startedAt=_parse_dt(row["started_at"]),
            finishedAt=_parse_dt(row["finished_at"]) if row.get("finished_at") else None,
            maxSteps=int(row["max_steps"]),
            error=row.get("error"),
        )


class PlanStep(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    run_id: str = Field(alias="runId")
    ordinal: int
    title: str
    rationale: str | None = None
    status: str
    result: str | None = None
    started_at: datetime | None = Field(default=None, alias="startedAt")
    finished_at: datetime | None = Field(default=None, alias="finishedAt")

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> PlanStep:
        return cls(
            id=str(row["id"]),
            runId=str(row["run_id"]),
            ordinal=int(row["ordinal"]),
            title=row["title"],
            rationale=row.get("rationale"),
            status=row["status"],
            result=row.get("result"),
            startedAt=_parse_dt(row["started_at"]) if row.get("started_at") else None,
            finishedAt=_parse_dt(row["finished_at"]) if row.get("finished_at") else None,
        )


class AgentMessage(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    run_id: str = Field(alias="runId")
    step_id: str | None = Field(default=None, alias="stepId")
    role: str
    content: str
    tool_name: str | None = Field(default=None, alias="toolName")
    created_at: datetime = Field(alias="createdAt")

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> AgentMessage:
        return cls(
            id=str(row["id"]),
            runId=str(row["run_id"]),
            stepId=str(row["step_id"]) if row.get("step_id") else None,
            role=row["role"],
            content=row["content"],
            toolName=row.get("tool_name"),
            createdAt=_parse_dt(row["created_at"]),
        )
