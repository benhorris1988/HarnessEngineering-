from __future__ import annotations

import asyncio
import logging
from typing import Any

import pyodbc

log = logging.getLogger(__name__)


class MssqlDatabase:
    """MSSQL implementation backed by pyodbc.

    pyodbc is synchronous, so all calls are dispatched to a thread via
    ``asyncio.to_thread`` to keep the FastAPI event loop responsive.

    Requires unixODBC + Microsoft's ``msodbcsql18`` driver on the host.
    """

    def __init__(self, connection_string: str) -> None:
        self._connection_string = connection_string
        self._conn: pyodbc.Connection | None = None
        self._lock = asyncio.Lock()  # pyodbc connections are not thread-safe

    async def connect(self) -> None:
        def _open() -> pyodbc.Connection:
            conn = pyodbc.connect(self._connection_string, autocommit=True)
            conn.timeout = 30
            return conn

        self._conn = await asyncio.to_thread(_open)
        log.info("connected to MSSQL")

    async def close(self) -> None:
        if self._conn is None:
            return
        await asyncio.to_thread(self._conn.close)
        self._conn = None

    def _required(self) -> pyodbc.Connection:
        if self._conn is None:
            raise RuntimeError("MssqlDatabase not connected")
        return self._conn

    async def execute(self, sql: str, params: tuple[Any, ...] = ()) -> int:
        async with self._lock:
            return await asyncio.to_thread(self._execute_sync, sql, params)

    def _execute_sync(self, sql: str, params: tuple[Any, ...]) -> int:
        cur = self._required().cursor()
        try:
            cur.execute(sql, params)
            return cur.rowcount
        finally:
            cur.close()

    async def query(
        self, sql: str, params: tuple[Any, ...] = ()
    ) -> list[dict[str, Any]]:
        async with self._lock:
            return await asyncio.to_thread(self._query_sync, sql, params)

    def _query_sync(self, sql: str, params: tuple[Any, ...]) -> list[dict[str, Any]]:
        cur = self._required().cursor()
        try:
            cur.execute(sql, params)
            cols = [c[0] for c in cur.description] if cur.description else []
            return [dict(zip(cols, row, strict=False)) for row in cur.fetchall()]
        finally:
            cur.close()

    async def query_one(
        self, sql: str, params: tuple[Any, ...] = ()
    ) -> dict[str, Any] | None:
        rows = await self.query(sql, params)
        return rows[0] if rows else None
