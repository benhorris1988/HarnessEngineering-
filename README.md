# Harness Engineering

An agentic DevOps assistant. Users file bugs/incidents through an
Azure-DevOps-style UI; the application plans the work, drives an
on-premise Ollama LLM through a tool-using agent loop, and persists
every step to Microsoft SQL Server.

```
+-----------------------------+
|  Flutter app (web + Android)|
|  - Simulated ADO UI         |
|  - Plan + run viewer        |
+--------------|--------------+
               | REST + SSE
+--------------v--------------+
|  Dart server (shelf)        |
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
server/     Dart backend (shelf, MSSQL, Ollama)
db/         SQL migrations + seed
infra/      docker-compose for MSSQL + Ollama
```

## Prerequisites

- Flutter SDK 3.22+
- Dart SDK 3.4+
- Docker (only needed for the MSSQL + Ollama compose stack)

## Quick start (no MSSQL, no Ollama — UI shake-down)

```bash
cd server
dart pub get
HARNESS_DB=memory OLLAMA_URL=http://localhost:11434 dart run bin/server.dart

# in another shell
cd app
flutter create --platforms=web,android --org com.harness .
flutter pub get
flutter run -d chrome
```

The in-memory DB lets you exercise the UI immediately; the agent loop
will still try to call Ollama, so for end-to-end behaviour also start
Ollama (see below).

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

# 4. Wire your preferred MSSQL Dart driver into
#    server/lib/db/mssql_database.dart (see notes below), then:
cd ../server
dart pub get
dart run bin/server.dart

# 5. Run Flutter (web + Android)
cd ../app
flutter create --platforms=web,android --org com.harness .
flutter pub get
flutter run -d chrome           # web
flutter run -d <android-device> # Android
```

## MSSQL driver wiring

`server/lib/db/mssql_database.dart` is a scaffold. The repositories
never touch the driver directly — they go through the `Database`
interface — so plugging one in is a small, contained change. Common
choices:

| Package          | Notes                                                  |
|------------------|--------------------------------------------------------|
| `odbc`           | FFI over unixODBC + Microsoft `msodbcsql18`. Robust.   |
| `tedious_dart`   | Pure-Dart TDS implementation, no system deps.          |
| `Process.run`    | Shell out to `sqlcmd`. Fine for very small workloads.  |

Implement `connect`, `execute(sql, params)`, and `query(sql, params)`
using `?` positional parameters in the order they appear in the SQL.

## Configuration

Server reads env vars (see `server/lib/config.dart`):

| Var                 | Default                              |
|---------------------|--------------------------------------|
| `HARNESS_PORT`      | `8080`                               |
| `HARNESS_DB`        | `mssql` (or `memory`)                |
| `MSSQL_HOST`        | `localhost`                          |
| `MSSQL_PORT`        | `1433`                               |
| `MSSQL_DB`          | `Harness`                            |
| `MSSQL_USER`        | `sa`                                 |
| `MSSQL_PASSWORD`    | `Harness!Pass1`                      |
| `OLLAMA_URL`        | `http://localhost:11434`             |
| `OLLAMA_MODEL`      | `llama3.1:8b`                        |
| `AGENT_MAX_STEPS`   | `12`                                 |

Flutter reads `--dart-define=API_BASE=http://...` (defaults to
`http://localhost:8080`).

## Agent loop

1. **Planner** — given a work item, asks the LLM for an ordered plan
   (JSON list of steps with rationale).
2. **Executor** — for each step, asks the LLM to either call a tool
   or produce a natural-language outcome. Tool calls are dispatched
   against the registry (`server/lib/agent/tools/`).
3. **Reflector** — after each step, asks the LLM whether the plan
   still holds, needs amendment, or the work item is resolved.
4. Loop terminates on `done`, `blocked`, or `AGENT_MAX_STEPS`.

Every message, tool call, and tool result is appended to
`agent_messages` so the Flutter app can render the run as a thread.

## Simulated Azure DevOps

The `New Incident` screen mirrors the ADO bug form: title, repro
steps, system info, severity, priority, area path, iteration, tags.
On submit the server creates a `work_items` row and immediately kicks
off an agent run.
