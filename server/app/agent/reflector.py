from __future__ import annotations

import json
from dataclasses import dataclass
from enum import Enum

from .ollama_client import OllamaClient, OllamaMessage
from .planner import _strip_fences


class ReflectionDecision(str, Enum):
    CONTINUE = "continue"
    REPLAN = "replan"
    DONE = "done"
    BLOCKED = "blocked"


@dataclass
class Reflection:
    decision: ReflectionDecision
    note: str
    summary: str | None


_SYSTEM = """You are the reflection module of an agentic DevOps assistant. Given the
plan so far and the latest step result, decide what to do next.

Choose exactly one decision:
  - "continue" - move on to the next planned step
  - "replan"   - the situation changed; the orchestrator should regenerate the plan
  - "done"     - the work item is resolved or sufficiently triaged; provide a summary
  - "blocked"  - human input is required to proceed

Respond with STRICT JSON:
{
  "decision": "continue" | "replan" | "done" | "blocked",
  "note": "<one sentence justification>",
  "summary": "<final summary if decision is done, else null>"
}
No prose outside the JSON.
"""


class Reflector:
    def __init__(self, ollama: OllamaClient) -> None:
        self._ollama = ollama

    async def reflect(
        self,
        *,
        history: list[OllamaMessage],
        latest_step_title: str,
        latest_step_outcome: str,
    ) -> Reflection:
        response = await self._ollama.chat(
            messages=[
                OllamaMessage(role="system", content=_SYSTEM),
                *history,
                OllamaMessage(
                    role="user",
                    content=(
                        f"Latest step: {latest_step_title}\n"
                        f"Latest outcome: {latest_step_outcome}"
                    ),
                ),
            ],
            response_format={"type": "object"},
            temperature=0.1,
        )
        return self._parse(response.content)

    def _parse(self, raw: str) -> Reflection:
        cleaned = _strip_fences(raw)
        decoded = json.loads(cleaned)
        if not isinstance(decoded, dict):
            raise ValueError(f"reflector returned non-object: {raw!r}")
        decision_raw = decoded.get("decision")
        try:
            decision = ReflectionDecision(decision_raw)
        except ValueError:
            decision = ReflectionDecision.CONTINUE
        return Reflection(
            decision=decision,
            note=decoded.get("note") or "",
            summary=decoded.get("summary"),
        )
