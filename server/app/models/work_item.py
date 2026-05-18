from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


def _parse_dt(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value
    return datetime.fromisoformat(str(value))


class WorkItem(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    type: str
    title: str
    description: str | None = None
    repro_steps: str | None = Field(default=None, alias="reproSteps")
    system_info: str | None = Field(default=None, alias="systemInfo")
    severity: str
    priority: int
    state: str
    area_path: str = Field(alias="areaPath")
    iteration_path: str = Field(alias="iterationPath")
    tags: str | None = None
    assigned_to: str | None = Field(default=None, alias="assignedTo")
    created_by: str = Field(alias="createdBy")
    created_at: datetime = Field(alias="createdAt")
    updated_at: datetime = Field(alias="updatedAt")

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> WorkItem:
        return cls(
            id=str(row["id"]),
            type=row["type"],
            title=row["title"],
            description=row.get("description"),
            reproSteps=row.get("repro_steps"),
            systemInfo=row.get("system_info"),
            severity=row["severity"],
            priority=int(row["priority"]),
            state=row["state"],
            areaPath=row["area_path"],
            iterationPath=row["iteration_path"],
            tags=row.get("tags"),
            assignedTo=row.get("assigned_to"),
            createdBy=row["created_by"],
            createdAt=_parse_dt(row["created_at"]),
            updatedAt=_parse_dt(row["updated_at"]),
        )

    def to_api(self) -> dict[str, Any]:
        return self.model_dump(by_alias=True, mode="json")


class WorkItemComment(BaseModel):
    id: str
    work_item_id: str = Field(alias="workItemId")
    author: str
    body: str
    created_at: datetime = Field(alias="createdAt")

    model_config = ConfigDict(populate_by_name=True)

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> WorkItemComment:
        return cls(
            id=str(row["id"]),
            workItemId=str(row["work_item_id"]),
            author=row["author"],
            body=row["body"],
            createdAt=_parse_dt(row["created_at"]),
        )
