from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from ..models.work_item import WorkItem
from .ollama_client import OllamaClient, OllamaMessage
from .tools.base import ToolContext, ToolRegistry

_SYSTEM = """You are the execution module of an agentic DevOps assistant. You are
working on ONE step of a plan to resolve a work item. You may either:
  - call exactly one tool (preferred when the step needs evidence or an
    action), or
  - reply in natural language summarising what was learned for this step.

Be concise. Do not invent facts. If you do not have enough information,
say so plainly so the reflector can decide what to do next.
"""


@dataclass
class ToolInvocation:
    name: str
    arguments: dict[str, Any]


@dataclass
class ToolResult:
    name: str
    result: dict[str, Any]
    success: bool


@dataclass
class StepOutcome:
    assistant_content: str
    tool_calls: list[ToolInvocation]
    tool_results: list[ToolResult]


class Executor:
    def __init__(self, ollama: OllamaClient, tools: ToolRegistry) -> None:
        self._ollama = ollama
        self._tools = tools

    async def execute(
        self,
        *,
        item: WorkItem,
        step_title: str,
        step_rationale: str | None,
        history: list[OllamaMessage],
        ctx: ToolContext,
    ) -> StepOutcome:
        messages: list[OllamaMessage] = [
            OllamaMessage(role="system", content=_SYSTEM),
            OllamaMessage(role="user", content=self._render_item(item)),
            *history,
            OllamaMessage(role="user", content=self._render_step(step_title, step_rationale)),
        ]
        response = await self._ollama.chat(
            messages=messages,
            tools=self._tools.ollama_specs(),
            temperature=0.2,
        )

        results: list[ToolResult] = []
        for call in response.tool_calls:
            tool = self._tools.get(call.name)
            if tool is None:
                results.append(
                    ToolResult(
                        name=call.name,
                        result={"error": f"unknown tool {call.name}"},
                        success=False,
                    )
                )
                continue
            try:
                r = await tool.call(call.arguments, ctx)
                results.append(
                    ToolResult(
                        name=call.name,
                        result=r,
                        success="error" not in r,
                    )
                )
            except Exception as e:  # noqa: BLE001
                results.append(
                    ToolResult(
                        name=call.name,
                        result={"error": str(e)},
                        success=False,
                    )
                )

        return StepOutcome(
            assistant_content=response.content,
            tool_calls=[
                ToolInvocation(name=c.name, arguments=c.arguments)
                for c in response.tool_calls
            ],
            tool_results=results,
        )

    def _render_item(self, i: WorkItem) -> str:
        return (
            f"Work item {i.id} — {i.type}: {i.title}\n"
            f"Severity {i.severity}, priority {i.priority}, state {i.state}."
        )

    def _render_step(self, title: str, rationale: str | None) -> str:
        if rationale:
            return f"Current step: {title}\nRationale: {rationale}"
        return f"Current step: {title}"

    @staticmethod
    def encode_tool_result(result: dict[str, Any]) -> str:
        return json.dumps(result, default=str)
