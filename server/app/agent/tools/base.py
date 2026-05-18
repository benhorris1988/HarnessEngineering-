from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any


@dataclass
class ToolContext:
    work_item_id: str
    run_id: str


class AgentTool(ABC):
    """Contract every agent tool must satisfy.

    Tools are async callables from a JSON arguments dict to a JSON result
    dict; the orchestrator serialises both for storage and for the LLM.
    """

    name: str
    description: str
    parameters_schema: dict[str, Any]

    @abstractmethod
    async def call(
        self, arguments: dict[str, Any], ctx: ToolContext
    ) -> dict[str, Any]: ...

    def to_ollama_spec(self) -> dict[str, Any]:
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": self.parameters_schema,
            },
        }


class ToolRegistry:
    def __init__(self, tools: list[AgentTool]) -> None:
        self._tools: dict[str, AgentTool] = {t.name: t for t in tools}

    def __iter__(self):  # type: ignore[no-untyped-def]
        return iter(self._tools.values())

    def get(self, name: str) -> AgentTool | None:
        return self._tools.get(name)

    def ollama_specs(self) -> list[dict[str, Any]]:
        return [t.to_ollama_spec() for t in self._tools.values()]
