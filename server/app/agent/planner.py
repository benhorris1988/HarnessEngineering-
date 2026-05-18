from __future__ import annotations

import json
from dataclasses import dataclass

from ..models.work_item import WorkItem
from .ollama_client import OllamaClient, OllamaMessage

_SYSTEM = """You are the planning module of an agentic DevOps assistant. Given a work
item, produce a SHORT ordered plan of investigative steps a software engineer
should take to triage and resolve it. Steps should be concrete and verifiable;
prefer 3-6 steps.

Respond with STRICT JSON in this shape:
{
  "steps": [
    {"title": "<short imperative title>", "rationale": "<why this step>"}
  ]
}
Do not include any prose outside the JSON object.
"""


@dataclass
class PlannedStep:
    title: str
    rationale: str | None


class Planner:
    def __init__(self, ollama: OllamaClient) -> None:
        self._ollama = ollama

    async def plan(self, item: WorkItem) -> list[PlannedStep]:
        response = await self._ollama.chat(
            messages=[
                OllamaMessage(role="system", content=_SYSTEM),
                OllamaMessage(role="user", content=self._render(item)),
            ],
            response_format={"type": "object"},
            temperature=0.1,
        )
        return self._parse(response.content)

    def _render(self, i: WorkItem) -> str:
        lines = [
            f"Work item type: {i.type}",
            f"Title: {i.title}",
            f"Severity: {i.severity}  Priority: {i.priority}",
            f"State: {i.state}",
            f"Area: {i.area_path}",
            f"Tags: {i.tags or '(none)'}",
        ]
        if i.description and i.description.strip():
            lines += ["", "Description:", i.description]
        if i.repro_steps and i.repro_steps.strip():
            lines += ["", "Repro steps:", i.repro_steps]
        if i.system_info and i.system_info.strip():
            lines += ["", "System info:", i.system_info]
        return "\n".join(lines)

    def _parse(self, raw: str) -> list[PlannedStep]:
        cleaned = _strip_fences(raw)
        decoded = json.loads(cleaned)
        if not isinstance(decoded, dict) or not isinstance(decoded.get("steps"), list):
            raise ValueError(f'planner response missing "steps" list: {raw!r}')
        out: list[PlannedStep] = []
        for s in decoded["steps"]:
            if not isinstance(s, dict):
                continue
            out.append(
                PlannedStep(
                    title=str(s.get("title", "untitled step")).strip(),
                    rationale=(s.get("rationale") or None),
                )
            )
        return out


def _strip_fences(raw: str) -> str:
    t = raw.strip()
    if not t.startswith("```"):
        return t
    first_nl = t.find("\n")
    body = t[first_nl + 1 :] if first_nl != -1 else t
    end = body.rfind("```")
    return (body[:end] if end != -1 else body).strip()
