from __future__ import annotations

from typing import Any, Protocol


class Database(Protocol):
    """Thin async DB interface so the agent code never touches drivers.

    Implementations live in ``mssql.py`` (pyodbc) and ``memory.py``
    (zero-dep fallback). Both honour the same ``?`` positional parameter
    style; repository SQL strings are reused between them.
    """

    async def connect(self) -> None: ...

    async def close(self) -> None: ...

    async def execute(self, sql: str, params: tuple[Any, ...] = ()) -> int: ...

    async def query(
        self, sql: str, params: tuple[Any, ...] = ()
    ) -> list[dict[str, Any]]: ...

    async def query_one(
        self, sql: str, params: tuple[Any, ...] = ()
    ) -> dict[str, Any] | None: ...
