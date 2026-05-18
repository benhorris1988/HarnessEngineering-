from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class CreateWorkItem(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    type: str = "Bug"
    title: str
    description: str | None = None
    repro_steps: str | None = Field(default=None, alias="reproSteps")
    system_info: str | None = Field(default=None, alias="systemInfo")
    severity: str = "3 - Medium"
    priority: int = 2
    area_path: str = Field(default="Harness", alias="areaPath")
    iteration_path: str = Field(default="Harness\\Current", alias="iterationPath")
    tags: str | None = None
    created_by: str = Field(default="simulated-user", alias="createdBy")
    autorun: bool = True


class CreateComment(BaseModel):
    author: str = "simulated-user"
    body: str
