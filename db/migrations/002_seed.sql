USE Harness;
GO

DECLARE @id1 UNIQUEIDENTIFIER = NEWID();
DECLARE @id2 UNIQUEIDENTIFIER = NEWID();
DECLARE @id3 UNIQUEIDENTIFIER = NEWID();

INSERT INTO dbo.work_items
    (id, type, title, description, repro_steps, severity, priority, state, tags, created_by)
VALUES
    (@id1, 'Bug',
     'Login fails with 500 when email contains a plus sign',
     'Users with addresses like user+tag@example.com cannot sign in. Started after the 2026-05-12 release.',
     '1. Enter user+tag@example.com\n2. Enter any password\n3. Submit\nExpected: validation or successful auth\nActual: 500 from /api/auth/login',
     '2 - High', 1, 'Active', 'auth;regression', 'simulated-user'),

    (@id2, 'Incident',
     'Nightly ETL job missed SLA on 2026-05-16',
     'Batch finished at 06:42 instead of 04:00. No alert fired. Need RCA and a guardrail.',
     NULL, '1 - Critical', 1, 'New', 'etl;sla', 'simulated-user'),

    (@id3, 'Bug',
     'Dark mode toggle reverts on page reload',
     'Theme preference is not persisted; defaults back to system on refresh.',
     '1. Toggle dark mode\n2. Reload page\nExpected: dark mode stays\nActual: reverts to light',
     '3 - Medium', 3, 'New', 'ui;preferences', 'simulated-user');
GO
