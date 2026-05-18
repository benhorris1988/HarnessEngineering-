from __future__ import annotations

import asyncio
import json
import logging
import uuid

from ..db.repositories.agent_runs import AgentRunsRepository
from ..db.repositories.work_items import WorkItemsRepository
from .executor import Executor, StepOutcome
from .ollama_client import OllamaClient, OllamaMessage
from .planner import PlannedStep, Planner
from .reflector import Reflection, ReflectionDecision, Reflector
from .tools.base import ToolContext, ToolRegistry

log = logging.getLogger(__name__)


class Orchestrator:
    def __init__(
        self,
        *,
        work_items: WorkItemsRepository,
        runs: AgentRunsRepository,
        tools: ToolRegistry,
        ollama: OllamaClient,
        max_steps: int,
    ) -> None:
        self.work_items = work_items
        self.runs = runs
        self.tools = tools
        self.ollama = ollama
        self.max_steps = max_steps
        self._planner = Planner(ollama)
        self._executor = Executor(ollama, tools)
        self._reflector = Reflector(ollama)

    async def start_run(self, work_item_id: str) -> str:
        item = await self.work_items.get(work_item_id)
        if item is None:
            raise ValueError(f"work item {work_item_id} not found")
        run_id = str(uuid.uuid4())
        await self.runs.create(
            id_=run_id,
            work_item_id=work_item_id,
            model=self.ollama.model,
            max_steps=self.max_steps,
        )
        # Fire and forget; failures surface via the run record.
        task = asyncio.create_task(self._drive(run_id, work_item_id))
        task.add_done_callback(lambda t: t.exception() and log.exception(
            "run task crashed", exc_info=t.exception()
        ))
        return run_id

    async def _drive(self, run_id: str, work_item_id: str) -> None:
        try:
            await self.runs.set_status(run_id, "running")
            item = await self.work_items.get(work_item_id)
            assert item is not None

            history: list[OllamaMessage] = []

            plan = await self._planner.plan(item)
            await self._persist_plan(run_id, plan, replan=False)
            log.info("run %s planned %d steps", run_id, len(plan))

            executed = 0
            ordinal = 0
            while executed < self.max_steps and ordinal < len(plan):
                stored = await self.runs.list_steps(run_id)
                pending = next(
                    (s for s in stored if s.status == "pending"),
                    stored[-1] if stored else None,
                )
                if pending is None:
                    break

                await self.runs.update_step(
                    id_=pending.id, status="running", mark_started=True
                )

                ctx = ToolContext(work_item_id=work_item_id, run_id=run_id)
                outcome = await self._executor.execute(
                    item=item,
                    step_title=pending.title,
                    step_rationale=pending.rationale,
                    history=history,
                    ctx=ctx,
                )

                await self._record_outcome(run_id, pending.id, outcome, history)
                await self.runs.update_step(
                    id_=pending.id,
                    status="done",
                    result=self._summarise_outcome(outcome),
                    mark_finished=True,
                )

                executed += 1
                ordinal += 1

                reflection = await self._reflector.reflect(
                    history=history,
                    latest_step_title=pending.title,
                    latest_step_outcome=self._summarise_outcome(outcome),
                )
                await self.runs.add_message(
                    id_=str(uuid.uuid4()),
                    run_id=run_id,
                    step_id=pending.id,
                    role="system",
                    content=f"reflection: {reflection.decision.value} — {reflection.note}",
                )

                if reflection.decision is ReflectionDecision.DONE:
                    await self.runs.set_summary(
                        run_id, reflection.summary or reflection.note
                    )
                    await self.work_items.update_state(work_item_id, "Resolved")
                    await self.runs.set_status(run_id, "done")
                    return
                if reflection.decision is ReflectionDecision.BLOCKED:
                    await self.runs.set_summary(run_id, f"Blocked: {reflection.note}")
                    await self.runs.set_status(run_id, "blocked")
                    return
                if reflection.decision is ReflectionDecision.REPLAN:
                    item = await self.work_items.get(work_item_id)
                    assert item is not None
                    plan = await self._planner.plan(item)
                    await self._persist_plan(run_id, plan, replan=True)
                    ordinal = 0

            await self.runs.set_summary(
                run_id, f"Reached max steps ({self.max_steps}) without converging."
            )
            await self.runs.set_status(run_id, "blocked")
        except Exception as e:  # noqa: BLE001
            log.exception("run %s failed", run_id)
            await self.runs.set_status(run_id, "failed", error=repr(e))

    async def _persist_plan(
        self, run_id: str, plan: list[PlannedStep], *, replan: bool
    ) -> None:
        if replan:
            existing = await self.runs.list_steps(run_id)
            base = existing[-1].ordinal + 1 if existing else 0
        else:
            base = 0
        for i, step in enumerate(plan):
            await self.runs.add_step(
                id_=str(uuid.uuid4()),
                run_id=run_id,
                ordinal=base + i,
                title=step.title,
                rationale=step.rationale,
            )

    async def _record_outcome(
        self,
        run_id: str,
        step_id: str,
        outcome: StepOutcome,
        history: list[OllamaMessage],
    ) -> None:
        if outcome.assistant_content:
            await self.runs.add_message(
                id_=str(uuid.uuid4()),
                run_id=run_id,
                step_id=step_id,
                role="assistant",
                content=outcome.assistant_content,
            )
            history.append(
                OllamaMessage(role="assistant", content=outcome.assistant_content)
            )
        for call, res in zip(outcome.tool_calls, outcome.tool_results, strict=False):
            args_json = json.dumps(call.arguments, default=str)
            res_json = json.dumps(res.result, default=str)
            await self.runs.add_message(
                id_=str(uuid.uuid4()),
                run_id=run_id,
                step_id=step_id,
                role="tool",
                content=f"call {call.name}({args_json}) -> {res_json}",
                tool_name=call.name,
            )
            await self.runs.record_tool_call(
                id_=str(uuid.uuid4()),
                run_id=run_id,
                step_id=step_id,
                tool_name=call.name,
                arguments_json=args_json,
                result_json=res_json,
                success=res.success,
            )
            history.append(
                OllamaMessage(role="tool", tool_name=call.name, content=res_json)
            )

    @staticmethod
    def _summarise_outcome(o: StepOutcome) -> str:
        if not o.tool_results:
            return o.assistant_content
        parts: list[str] = []
        if o.assistant_content:
            parts.append(o.assistant_content)
        for r in o.tool_results:
            status = "ok" if r.success else "error"
            parts.append(f"tool {r.name}: {status} {json.dumps(r.result, default=str)}")
        return "\n".join(parts)


# Local re-export for readability
Reflection = Reflection
