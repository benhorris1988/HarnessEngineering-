# Harness Engineering

An agentic DevOps assistant. Users file bugs/incidents through an
Azure-DevOps-style UI; the backend plans the work, drives an
on-premise Ollama LLM through a tool-using agent loop, and persists
every step to Microsoft SQL Server.

```
+-----------------------------+
|  Flutter app (web + Android)|
|  - Simulated ADO UI         |
|  - Plan + run viewer        |
+--------------|--------------+
               | REST
+--------------v--------------+
|  FastAPI + uvicorn (Python) |
|  - Work item CRUD           |
|  - Agent orchestrator       |
|  - Tool registry            |
+------|------|------|--------+
       |      |      |
       v      v      v
   MSSQL   Ollama   (tools)
```

## Layout

```
app/        Flutter app (web + Android share lib/)
server/     Python backend (FastAPI + uvicorn + MSSQL + Ollama)
db/         SQL migrations + seed
infra/      docker-compose for MSSQL + Ollama
```

## Prerequisites

- Python 3.11+
- Flutter SDK 3.22+
- Docker (only for the MSSQL + Ollama compose stack)
- unixODBC + Microsoft `msodbcsql18` if you connect to real MSSQL

## Quick start (no MSSQL — UI shake-down)

```bash
# 1. Backend with the in-memory store
cd server
python -m venv .venv && source .venv/bin/activate
pip install -e .                    # or: pip install -r requirements.txt
HARNESS_DB=memory uvicorn app.main:app --reload --host 0.0.0.0 --port 8080

# 2. Flutter (another shell)
cd app
flutter create --platforms=web,android --org com.harness .
flutter pub get
flutter run -d chrome
```

The agent loop still calls Ollama, so for full end-to-end behaviour
also run an Ollama instance with a tool-capable model (see below).

## Full local stack

```bash
# 1. Start MSSQL + Ollama
cd infra && docker compose up -d

# 2. Apply schema + seed (run from the repo root)
docker exec -i harness-mssql /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P 'Harness!Pass1' -C -No \
  -i /db/migrations/001_init.sql
docker exec -i harness-mssql /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P 'Harness!Pass1' -C -No \
  -i /db/migrations/002_seed.sql

# 3. Pull an Ollama model with tool-call support
docker exec harness-ollama ollama pull llama3.1:8b

# 4. Install ODBC driver on your host (Debian/Ubuntu example):
#    https://learn.microsoft.com/sql/connect/odbc/linux-mac/install-microsoft-odbc-driver-sql-server-linux
#    Then:
cd ../server
python -m venv .venv && source .venv/bin/activate
pip install -e .
uvicorn app.main:app --host 0.0.0.0 --port 8080

# 5. Run Flutter (web + Android)
cd ../app
flutter create --platforms=web,android --org com.harness .
flutter pub get
flutter run -d chrome           # web
flutter run -d <android-device> # Android (emulator: --dart-define=API_BASE=http://10.0.2.2:8080)
```

## Configuration

The backend reads env vars (see `server/app/config.py`):

| Var                 | Default                  |
|---------------------|--------------------------|
| `HARNESS_PORT`      | `8080`                   |
| `HARNESS_DB`        | `mssql` (or `memory`)    |
| `MSSQL_HOST`        | `localhost`              |
| `MSSQL_PORT`        | `1433`                   |
| `MSSQL_DB`          | `Harness`                |
| `MSSQL_USER`        | `sa`                     |
| `MSSQL_PASSWORD`    | `Harness!Pass1`          |
| `OLLAMA_URL`        | `http://localhost:11434` |
| `OLLAMA_MODEL`      | `llama3.1:8b`            |
| `AGENT_MAX_STEPS`   | `12`                     |

The Flutter app reads `--dart-define=API_BASE=http://...` (defaults to
`http://localhost:8080`).

## Agent loop

1. **Planner** (`app/agent/planner.py`) — asks the LLM for an ordered
   plan (JSON list of steps with rationale).
2. **Executor** (`app/agent/executor.py`) — for each step, asks the LLM
   to either call a tool or produce a natural-language outcome. Tool
   calls are dispatched against the registry (`app/agent/tools/`).
3. **Reflector** (`app/agent/reflector.py`) — after each step, asks the
   LLM whether the plan still holds, needs amendment, or the work item
   is resolved.
4. Loop terminates on `done`, `blocked`, or `AGENT_MAX_STEPS`.

Every message, tool call, and tool result is appended to
`agent_messages` so the Flutter app can render the run as a thread.

## Simulated Azure DevOps

The **New Incident** screen mirrors the ADO bug form: title, repro
steps, system info, severity, priority, area path, iteration, tags.
On submit the server creates a `work_items` row and (by default)
immediately kicks off an agent run.

## API

Swagger UI is auto-published at `http://localhost:8080/docs` (FastAPI
default). Key endpoints:

| Method | Path                                  | Purpose                       |
|--------|---------------------------------------|-------------------------------|
| GET    | `/api/health`                         | liveness                      |
| GET    | `/api/work-items?state=Active`        | list                          |
| POST   | `/api/work-items`                     | create (+ optional autorun)   |
| GET    | `/api/work-items/{id}`                | fetch one                     |
| GET    | `/api/work-items/{id}/comments`       | list comments                 |
| POST   | `/api/work-items/{id}/comments`       | add a comment                 |
| POST   | `/api/work-items/{id}/runs`           | start an agent run            |
| GET    | `/api/runs/{id}`                      | run metadata                  |
| GET    | `/api/runs/{id}/steps`                | plan steps                    |
| GET    | `/api/runs/{id}/messages`             | full transcript               |
| GET    | `/api/runs/by-work-item/{id}`         | runs for a work item          |
