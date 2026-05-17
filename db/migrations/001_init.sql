IF DB_ID('Harness') IS NULL
BEGIN
    CREATE DATABASE Harness;
END;
GO

USE Harness;
GO

IF OBJECT_ID('dbo.work_items', 'U') IS NOT NULL DROP TABLE dbo.work_items;
IF OBJECT_ID('dbo.work_item_comments', 'U') IS NOT NULL DROP TABLE dbo.work_item_comments;
IF OBJECT_ID('dbo.agent_runs', 'U') IS NOT NULL DROP TABLE dbo.agent_runs;
IF OBJECT_ID('dbo.plan_steps', 'U') IS NOT NULL DROP TABLE dbo.plan_steps;
IF OBJECT_ID('dbo.agent_messages', 'U') IS NOT NULL DROP TABLE dbo.agent_messages;
IF OBJECT_ID('dbo.tool_calls', 'U') IS NOT NULL DROP TABLE dbo.tool_calls;
GO

CREATE TABLE dbo.work_items (
    id              UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    type            NVARCHAR(32)     NOT NULL,             -- Bug | Incident | Task | UserStory
    title           NVARCHAR(400)    NOT NULL,
    description     NVARCHAR(MAX)    NULL,
    repro_steps     NVARCHAR(MAX)    NULL,
    system_info     NVARCHAR(MAX)    NULL,
    severity        NVARCHAR(16)     NOT NULL DEFAULT '3 - Medium',
    priority        INT              NOT NULL DEFAULT 2,
    state           NVARCHAR(32)     NOT NULL DEFAULT 'New',
    area_path       NVARCHAR(200)    NOT NULL DEFAULT 'Harness',
    iteration_path  NVARCHAR(200)    NOT NULL DEFAULT 'Harness\\Current',
    tags            NVARCHAR(400)    NULL,
    assigned_to     NVARCHAR(120)    NULL,
    created_by      NVARCHAR(120)    NOT NULL DEFAULT 'simulated-user',
    created_at      DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_work_items_state ON dbo.work_items(state);
CREATE INDEX IX_work_items_created_at ON dbo.work_items(created_at DESC);
GO

CREATE TABLE dbo.work_item_comments (
    id           UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    work_item_id UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.work_items(id),
    author       NVARCHAR(120)    NOT NULL,
    body         NVARCHAR(MAX)    NOT NULL,
    created_at   DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_comments_work_item ON dbo.work_item_comments(work_item_id, created_at);
GO

CREATE TABLE dbo.agent_runs (
    id              UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    work_item_id    UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.work_items(id),
    model           NVARCHAR(120)    NOT NULL,
    status          NVARCHAR(24)     NOT NULL DEFAULT 'pending',  -- pending|running|done|blocked|failed
    summary         NVARCHAR(MAX)    NULL,
    started_at      DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
    finished_at     DATETIME2(3)     NULL,
    max_steps       INT              NOT NULL DEFAULT 12,
    error           NVARCHAR(MAX)    NULL
);
GO

CREATE INDEX IX_runs_work_item ON dbo.agent_runs(work_item_id, started_at DESC);
GO

CREATE TABLE dbo.plan_steps (
    id            UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    run_id        UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.agent_runs(id),
    ordinal       INT              NOT NULL,
    title         NVARCHAR(400)    NOT NULL,
    rationale     NVARCHAR(MAX)    NULL,
    status        NVARCHAR(24)     NOT NULL DEFAULT 'pending', -- pending|running|done|skipped|failed
    result        NVARCHAR(MAX)    NULL,
    started_at    DATETIME2(3)     NULL,
    finished_at   DATETIME2(3)     NULL
);
GO

CREATE INDEX IX_steps_run ON dbo.plan_steps(run_id, ordinal);
GO

CREATE TABLE dbo.agent_messages (
    id           UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    run_id       UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.agent_runs(id),
    step_id      UNIQUEIDENTIFIER NULL     REFERENCES dbo.plan_steps(id),
    role         NVARCHAR(24)     NOT NULL,  -- system|user|assistant|tool
    content      NVARCHAR(MAX)    NOT NULL,
    tool_name    NVARCHAR(120)    NULL,
    tokens_in    INT              NULL,
    tokens_out   INT              NULL,
    created_at   DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_messages_run ON dbo.agent_messages(run_id, created_at);
GO

CREATE TABLE dbo.tool_calls (
    id          UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    run_id      UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.agent_runs(id),
    step_id     UNIQUEIDENTIFIER NULL     REFERENCES dbo.plan_steps(id),
    tool_name   NVARCHAR(120)    NOT NULL,
    arguments   NVARCHAR(MAX)    NOT NULL,
    result      NVARCHAR(MAX)    NULL,
    success     BIT              NULL,
    started_at  DATETIME2(3)     NOT NULL DEFAULT SYSUTCDATETIME(),
    finished_at DATETIME2(3)     NULL
);
GO

CREATE INDEX IX_tool_calls_run ON dbo.tool_calls(run_id, started_at);
GO
