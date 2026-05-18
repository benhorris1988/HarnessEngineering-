from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any

import httpx


@dataclass
class OllamaMessage:
    role: str  # system | user | assistant | tool
    content: str
    tool_name: str | None = None
    tool_calls: list[OllamaToolCall] | None = None

    def to_json(self) -> dict[str, Any]:
        out: dict[str, Any] = {"role": self.role, "content": self.content}
        if self.tool_name is not None:
            out["name"] = self.tool_name
        if self.tool_calls is not None:
            out["tool_calls"] = [c.to_json() for c in self.tool_calls]
        return out


@dataclass
class OllamaToolCall:
    name: str
    arguments: dict[str, Any] = field(default_factory=dict)

    def to_json(self) -> dict[str, Any]:
        return {"function": {"name": self.name, "arguments": self.arguments}}

    @classmethod
    def from_json(cls, raw: dict[str, Any]) -> OllamaToolCall:
        fn = raw.get("function") or {}
        args_raw = fn.get("arguments")
        if isinstance(args_raw, dict):
            args = args_raw
        elif isinstance(args_raw, str) and args_raw.strip():
            try:
                args = json.loads(args_raw)
            except json.JSONDecodeError:
                args = {}
        else:
            args = {}
        return cls(name=fn.get("name", ""), arguments=args)


@dataclass
class OllamaChatResponse:
    content: str
    tool_calls: list[OllamaToolCall]
    done: bool

    @classmethod
    def from_json(cls, raw: dict[str, Any]) -> OllamaChatResponse:
        msg = raw.get("message") or {}
        tool_calls_raw = msg.get("tool_calls") or []
        return cls(
            content=msg.get("content", ""),
            tool_calls=[OllamaToolCall.from_json(c) for c in tool_calls_raw],
            done=raw.get("done", True),
        )


class OllamaError(RuntimeError):
    def __init__(self, message: str, status_code: int | None = None) -> None:
        super().__init__(message)
        self.status_code = status_code


class OllamaClient:
    """Minimal Ollama HTTP client targeting ``/api/chat``."""

    def __init__(self, base_url: str, model: str, timeout: float = 300.0) -> None:
        self.base_url = base_url.rstrip("/")
        self.model = model
        self._client = httpx.AsyncClient(timeout=timeout)

    async def close(self) -> None:
        await self._client.aclose()

    async def chat(
        self,
        *,
        messages: list[OllamaMessage],
        tools: list[dict[str, Any]] | None = None,
        response_format: dict[str, Any] | None = None,
        temperature: float = 0.2,
    ) -> OllamaChatResponse:
        body: dict[str, Any] = {
            "model": self.model,
            "stream": False,
            "messages": [m.to_json() for m in messages],
            "options": {"temperature": temperature},
        }
        if tools is not None:
            body["tools"] = tools
        if response_format is not None:
            body["format"] = response_format

        resp = await self._client.post(f"{self.base_url}/api/chat", json=body)
        if resp.status_code >= 400:
            raise OllamaError(
                f"Ollama {resp.status_code}: {resp.text}",
                status_code=resp.status_code,
            )
        return OllamaChatResponse.from_json(resp.json())
