-- Useful debugging queries for Phase 1 MVP testing

-- ============================================
-- Command Queue Monitoring
-- ============================================

-- Recent commands with status
SELECT
    id,
    user_id,
    type,
    status,
    created_at,
    updated_at,
    substr(payload_json, 1, 100) as payload_preview
FROM commands
ORDER BY created_at DESC
LIMIT 10;

-- Pending commands (what's in queue)
SELECT * FROM v_pending_commands;

-- Failed commands (needs attention)
SELECT
    id,
    type,
    created_at,
    payload_json
FROM commands
WHERE status = 'failed'
ORDER BY created_at DESC;

-- Command status distribution
SELECT status, COUNT(*) as count
FROM commands
GROUP BY status;

-- ============================================
-- Draft Monitoring
-- ============================================

-- Recent drafts
SELECT
    id,
    draft_type,
    status,
    created_at,
    substr(draft_json, 1, 100) as draft_preview
FROM drafts
ORDER BY created_at DESC
LIMIT 10;

-- Active drafts awaiting confirmation
SELECT * FROM v_active_drafts;

-- Draft status distribution
SELECT status, COUNT(*) as count
FROM drafts
GROUP BY status;

-- Orphaned drafts (no execution record)
SELECT d.*
FROM drafts d
LEFT JOIN executions e ON d.id = e.draft_id
WHERE d.status = 'confirmed'
  AND e.id IS NULL;

-- ============================================
-- Execution History
-- ============================================

-- Recent executions
SELECT * FROM v_execution_history LIMIT 10;

-- Failed executions with errors
SELECT
    e.id,
    e.draft_id,
    e.executed_at,
    e.error_message,
    d.draft_json
FROM executions e
JOIN drafts d ON e.draft_id = d.id
WHERE e.status = 'failed'
ORDER BY e.executed_at DESC;

-- Success rate
SELECT
    status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM executions), 2) as percentage
FROM executions
GROUP BY status;

-- ============================================
-- Audit Trail
-- ============================================

-- Recent audit logs
SELECT
    timestamp,
    action,
    entity_type,
    entity_id,
    substr(details_json, 1, 100) as details_preview
FROM audit_log
ORDER BY timestamp DESC
LIMIT 20;

-- Audit logs for specific entity
-- Replace <entity_type> and <entity_id> with actual values
SELECT *
FROM audit_log
WHERE entity_type = '<entity_type>'
  AND entity_id = '<entity_id>'
ORDER BY timestamp DESC;

-- Actions by type
SELECT action, COUNT(*) as count
FROM audit_log
GROUP BY action
ORDER BY count DESC;

-- ============================================
-- End-to-End Flow Tracking
-- ============================================

-- Track a message through the entire flow
-- Replace <message_id> with actual Telegram message ID
SELECT
    'Command' as stage,
    id as entity_id,
    type as detail,
    status,
    created_at as timestamp
FROM commands
WHERE json_extract(payload_json, '$.telegram_message_id') = '<message_id>'

UNION ALL

SELECT
    'Draft' as stage,
    id as entity_id,
    draft_type as detail,
    status,
    created_at as timestamp
FROM drafts
WHERE source_message_id = '<message_id>'

UNION ALL

SELECT
    'Execution' as stage,
    e.id as entity_id,
    e.status as detail,
    e.status,
    e.executed_at as timestamp
FROM executions e
JOIN drafts d ON e.draft_id = d.id
WHERE d.source_message_id = '<message_id>'

ORDER BY timestamp ASC;

-- ============================================
-- Performance Monitoring
-- ============================================

-- Average processing time (command creation to execution)
SELECT
    AVG(
        (julianday(e.executed_at) - julianday(c.created_at)) * 86400
    ) as avg_seconds
FROM executions e
JOIN drafts d ON e.draft_id = d.id
JOIN commands c ON json_extract(c.payload_json, '$.telegram_message_id') = d.source_message_id
WHERE e.status = 'success'
  AND c.type = 'draft_task_from_text';

-- ============================================
-- Cleanup Queries
-- ============================================

-- Delete old completed commands (older than 7 days)
-- CAUTION: Only run if you don't need historical data
-- DELETE FROM commands
-- WHERE status = 'completed'
--   AND created_at < datetime('now', '-7 days');

-- Delete old executed drafts (older than 30 days)
-- DELETE FROM drafts
-- WHERE status = 'executed'
--   AND created_at < datetime('now', '-30 days');

-- Delete old audit logs (older than 90 days)
-- DELETE FROM audit_log
-- WHERE timestamp < datetime('now', '-90 days');

-- ============================================
-- Idempotency Check
-- ============================================

-- Find duplicate commands (same message processed multiple times)
SELECT
    json_extract(payload_json, '$.telegram_message_id') as message_id,
    COUNT(*) as duplicate_count
FROM commands
GROUP BY message_id
HAVING duplicate_count > 1;
