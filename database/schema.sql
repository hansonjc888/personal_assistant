-- AI Personal Assistant Chatbot - Phase 1 MVP Database Schema
-- SQLite Database Schema
-- Created: 2026-02-02

-- ============================================
-- Users Table
-- ============================================
-- Stores user profile with timezone and channel info
CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    channel TEXT NOT NULL CHECK(channel IN ('telegram', 'whatsapp')),
    timezone TEXT NOT NULL DEFAULT 'UTC',
    telegram_chat_id TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- Commands Table
-- ============================================
-- Command queue for all pending/processing operations
CREATE TABLE IF NOT EXISTS commands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    type TEXT NOT NULL CHECK(type IN (
        'draft_task_from_text',
        'draft_event_from_text',
        'draft_event_from_url',
        'draft_event_from_image',
        'edit_draft',
        'confirm_draft',
        'cancel_draft',
        'daily_brief'
    )),
    payload_json TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'processing', 'completed', 'failed')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Index for efficient queue polling
CREATE INDEX IF NOT EXISTS idx_commands_status_created
ON commands(status, created_at);

-- Index for idempotency checks
CREATE INDEX IF NOT EXISTS idx_commands_payload
ON commands(payload_json);

-- ============================================
-- Drafts Table
-- ============================================
-- Task/event drafts awaiting user confirmation
CREATE TABLE IF NOT EXISTS drafts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    draft_type TEXT NOT NULL CHECK(draft_type IN ('task', 'event')),
    draft_json TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'drafted' CHECK(status IN ('drafted', 'confirmed', 'executed', 'cancelled')),
    source_message_id TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Index for fetching active drafts
CREATE INDEX IF NOT EXISTS idx_drafts_status
ON drafts(user_id, status);

-- Index for source message lookup
CREATE INDEX IF NOT EXISTS idx_drafts_source_message
ON drafts(source_message_id);

-- ============================================
-- Executions Table
-- ============================================
-- Audit trail of executed drafts (tasks/events created)
CREATE TABLE IF NOT EXISTS executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    draft_id INTEGER NOT NULL,
    result_json TEXT,
    status TEXT NOT NULL CHECK(status IN ('success', 'failed')),
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    error_message TEXT,
    FOREIGN KEY (draft_id) REFERENCES drafts(id)
);

-- Index for draft execution lookup
CREATE INDEX IF NOT EXISTS idx_executions_draft
ON executions(draft_id);

-- Index for execution status monitoring
CREATE INDEX IF NOT EXISTS idx_executions_status
ON executions(status, executed_at);

-- ============================================
-- Audit Log Table
-- ============================================
-- Full action history for debugging and compliance
CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL CHECK(entity_type IN ('command', 'draft', 'execution', 'user')),
    entity_id TEXT NOT NULL,
    source_message_id TEXT,
    details_json TEXT
);

-- Index for timeline queries
CREATE INDEX IF NOT EXISTS idx_audit_timestamp
ON audit_log(timestamp DESC);

-- Index for entity lookup
CREATE INDEX IF NOT EXISTS idx_audit_entity
ON audit_log(entity_type, entity_id);

-- ============================================
-- Triggers for automatic timestamp updates
-- ============================================
CREATE TRIGGER IF NOT EXISTS update_commands_timestamp
AFTER UPDATE ON commands
FOR EACH ROW
BEGIN
    UPDATE commands SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- ============================================
-- Views for common queries
-- ============================================
-- View for pending commands with user info
CREATE VIEW IF NOT EXISTS v_pending_commands AS
SELECT
    c.id,
    c.user_id,
    c.type,
    c.payload_json,
    c.status,
    c.created_at,
    u.timezone,
    u.telegram_chat_id
FROM commands c
JOIN users u ON c.user_id = u.user_id
WHERE c.status = 'pending'
ORDER BY c.created_at ASC;

-- View for active drafts awaiting confirmation
CREATE VIEW IF NOT EXISTS v_active_drafts AS
SELECT
    d.id,
    d.user_id,
    d.draft_type,
    d.draft_json,
    d.status,
    d.source_message_id,
    d.created_at,
    u.telegram_chat_id
FROM drafts d
JOIN users u ON d.user_id = u.user_id
WHERE d.status IN ('drafted', 'confirmed')
ORDER BY d.created_at DESC;

-- View for execution history with draft details
CREATE VIEW IF NOT EXISTS v_execution_history AS
SELECT
    e.id as execution_id,
    e.draft_id,
    e.status as execution_status,
    e.executed_at,
    e.error_message,
    d.draft_type,
    d.draft_json,
    d.user_id
FROM executions e
JOIN drafts d ON e.draft_id = d.id
ORDER BY e.executed_at DESC;
