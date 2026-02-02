# Testing Guide

Comprehensive testing scenarios and validation procedures for the AI Personal Assistant Phase 1 MVP.

---

## Overview

This guide covers:
1. Manual testing scenarios
2. Database verification queries
3. Workflow testing
4. Integration testing
5. Error handling validation

---

## 1. Pre-Flight Checklist

Before testing, verify:

### 1.1 System Status

```bash
# Check n8n is running
systemctl status n8n
# or
curl https://your-n8n-domain.com

# Check database exists and is accessible
ls -la $DATABASE_PATH
sqlite3 $DATABASE_PATH "SELECT COUNT(*) FROM users;"

# Check webhook is set
curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo"

# Check workflows are active in n8n UI
```

### 1.2 Required Credentials

- [ ] Gemini API key working
- [ ] Telegram bot token valid
- [ ] Google Tasks OAuth connected
- [ ] SQLite database accessible
- [ ] Default user record exists

---

## 2. Manual Test Scenarios

### Test 1: Simple Task Creation

**Objective**: Verify basic end-to-end flow

**Steps**:
1. Send to bot: `Buy milk`
2. Wait for acknowledgment: "Got it! Working on it... ⚙️"
3. Verify draft message appears with confirmation buttons
4. Click **✅ Confirm**
5. Verify success message: "✅ Task created successfully!"
6. Check Google Tasks app for task

**Expected Result**:
- Task appears in Google Tasks
- Title: "Buy milk"
- Status: needsAction
- No subtasks (too simple)

**Database Verification**:
```sql
-- Command created
SELECT * FROM commands WHERE type='draft_task_from_text' ORDER BY created_at DESC LIMIT 1;

-- Draft created
SELECT * FROM drafts WHERE draft_type='task' ORDER BY created_at DESC LIMIT 1;

-- Execution successful
SELECT * FROM executions WHERE status='success' ORDER BY executed_at DESC LIMIT 1;

-- Audit trail complete
SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 5;
```

---

### Test 2: Task with Due Date

**Objective**: Verify date parsing and Google Tasks due date format

**Steps**:
1. Send: `Submit report by Friday`
2. Verify draft shows correct future date
3. Confirm task
4. Check Google Tasks shows due date

**Expected Result**:
- Due date correctly calculated (next Friday from today)
- RFC 3339 format stored: `YYYY-MM-DDT00:00:00.000Z`
- Visible in Google Tasks

**Validation Query**:
```sql
SELECT
  json_extract(draft_json, '$.title') as title,
  json_extract(draft_json, '$.due_date') as due_date,
  json_extract(draft_json, '$.due_date_reasoning') as reasoning
FROM drafts
WHERE id = (SELECT MAX(id) FROM drafts);
```

---

### Test 3: Complex Task with Subtasks

**Objective**: Verify subtask suggestion and creation

**Steps**:
1. Send: `Plan birthday party next week`
2. Verify draft includes 3-5 suggested subtasks
3. Confirm task
4. Check Google Tasks shows main task + subtasks

**Expected Result**:
- Main task created
- 3-5 subtasks created with `parent` field set
- Effort estimates in subtask titles: `[S]`, `[M]`, `[L]`

**Validation**:
```sql
-- Check draft has subtasks
SELECT
  json_extract(draft_json, '$.title') as title,
  json_array_length(json_extract(draft_json, '$.suggested_subtasks')) as subtask_count
FROM drafts
WHERE id = (SELECT MAX(id) FROM drafts);
```

**Google Tasks API Check**:
```bash
# Get main task
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks"

# Verify subtasks have parent field
```

---

### Test 4: Clarification Request

**Objective**: Verify bot asks for clarification when needed

**Steps**:
1. Send: `Call about the thing`
2. Verify bot responds with question (not draft)
3. Send clarification: `Call dentist to schedule cleaning`
4. Verify draft appears

**Expected Result**:
- No draft created on first message
- Clarification question sent
- Second message triggers draft

**Database Check**:
```sql
-- First command should complete without draft
SELECT c.id, c.type, d.id as draft_id
FROM commands c
LEFT JOIN drafts d ON json_extract(c.payload_json, '$.telegram_message_id') = d.source_message_id
WHERE c.type = 'draft_task_from_text'
ORDER BY c.created_at DESC
LIMIT 2;
```

---

### Test 5: Cancel Draft

**Objective**: Verify cancellation flow

**Steps**:
1. Send: `Buy bread`
2. Wait for draft
3. Click **❌ Cancel**
4. Verify cancellation message
5. Check Google Tasks (should not contain task)

**Expected Result**:
- Draft status changed to 'cancelled'
- No execution record created
- Task not in Google Tasks

**Validation**:
```sql
SELECT
  id,
  status,
  json_extract(draft_json, '$.title') as title
FROM drafts
WHERE status = 'cancelled'
ORDER BY created_at DESC
LIMIT 1;
```

---

### Test 6: Edit Draft (Future Feature)

**Objective**: Verify edit flow (if implemented)

**Steps**:
1. Send: `Write proposal`
2. Click **✏️ Edit**
3. Send modification: `Write project proposal with budget`
4. Verify updated draft

**Note**: Phase 1 MVP may show "Edit not implemented" message.

---

### Test 7: Priority Indicators

**Objective**: Verify priority detection

**Steps**:
1. Send: `URGENT: Fix production bug`
2. Verify priority captured in draft metadata

**Expected Result**:
```sql
SELECT json_extract(draft_json, '$.priority_indicators') as priority
FROM drafts ORDER BY created_at DESC LIMIT 1;
-- Should contain ["urgent"]
```

---

### Test 8: Idempotency

**Objective**: Prevent duplicate processing

**Steps**:
1. Send: `Test task`
2. Quickly send again: `Test task`
3. Verify only one command created

**Expected Result**:
- Second message returns: "This message is already being processed."
- Only one command in database

**Validation**:
```sql
SELECT
  json_extract(payload_json, '$.telegram_message_id') as msg_id,
  COUNT(*) as duplicate_count
FROM commands
GROUP BY msg_id
HAVING duplicate_count > 1;
-- Should return no rows
```

---

### Test 9: Very Long Task Description

**Objective**: Test length limits

**Steps**:
1. Send a very long task (> 1000 characters)
2. Verify truncation or handling

**Expected Result**:
- Task title truncated to 100 chars
- Full description in notes
- No errors

---

### Test 10: Special Characters

**Objective**: Test character escaping

**Steps**:
1. Send: `Buy "groceries" & supplies @ store`
2. Verify task created with special characters intact

**Expected Result**:
- Title: `Buy "groceries" & supplies @ store`
- No SQL injection or escaping errors

---

## 3. Error Handling Tests

### Test 11: Invalid Due Date

**Objective**: Handle past dates

**Steps**:
1. Send: `Submit report by last Monday`
2. Verify bot suggests future date or asks clarification

---

### Test 12: API Failures

**Objective**: Graceful failure handling

**Simulate**:
```bash
# Temporarily revoke Google OAuth token
# Then try to confirm a draft
```

**Expected Result**:
- Execution status: 'failed'
- Error message stored
- User notified via Telegram

**Validation**:
```sql
SELECT
  id,
  status,
  error_message,
  executed_at
FROM executions
WHERE status = 'failed'
ORDER BY executed_at DESC;
```

---

### Test 13: Database Lock

**Objective**: Handle concurrent access

**Simulate**:
```bash
# In one terminal
sqlite3 $DATABASE_PATH "BEGIN TRANSACTION; SELECT * FROM commands;"
# (don't commit, leave hanging)

# In another, trigger command via Telegram
```

**Expected Result**:
- Workflow retries or fails gracefully
- No data corruption

---

### Test 14: Malformed JSON

**Objective**: Handle Gemini returning invalid JSON

**Test**:
- Monitor execution logs for JSON parse errors
- Verify fallback handling

---

## 4. Performance Tests

### Test 15: Response Time

**Objective**: Measure end-to-end latency

**Metrics**:
```sql
-- Average time from command to execution
SELECT
  AVG(
    (julianday(e.executed_at) - julianday(c.created_at)) * 86400
  ) as avg_seconds
FROM executions e
JOIN drafts d ON e.draft_id = d.id
JOIN commands c ON json_extract(c.payload_json, '$.telegram_message_id') = d.source_message_id
WHERE e.status = 'success';
```

**Target**: < 15 seconds for draft creation

---

### Test 16: Concurrent Users

**Objective**: Simulate multiple messages

**Steps**:
1. Send 5 messages in quick succession
2. Verify all processed correctly

**Expected Result**:
- All commands queued
- Processed sequentially
- No race conditions

---

## 5. Integration Tests

### Test 17: Telegram Webhook

**Objective**: Verify webhook receives messages

**Manual Test**:
```bash
curl -X POST "https://your-n8n-domain.com/webhook/telegram-bot" \
  -H "Content-Type: application/json" \
  -d '{
    "update_id": 1,
    "message": {
      "message_id": 999,
      "from": {"id": 123, "first_name": "Test"},
      "chat": {"id": 123, "type": "private"},
      "text": "Test message"
    }
  }'
```

**Expected**: Command created in database

---

### Test 18: Gemini API

**Objective**: Verify intent classification

**Manual Test**:
```bash
curl -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [{
        "text": "Classify this: Buy milk tomorrow"
      }]
    }],
    "generationConfig": {
      "temperature": 0.1,
      "responseMimeType": "application/json"
    }
  }'
```

---

### Test 19: Google Tasks API

**Objective**: Verify task creation

**Manual Test**:
```bash
curl -X POST \
  "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "API Test Task"
  }'
```

---

## 6. Regression Tests

After any changes, run full test suite:

```bash
#!/bin/bash
# regression-test.sh

echo "Running regression tests..."

# Test 1: Simple task
echo "Test 1: Simple task"
# Send message, verify in DB

# Test 2: Task with date
echo "Test 2: Task with due date"
# Send message, verify date parsing

# Test 3: Cancel
echo "Test 3: Cancel draft"
# Send, cancel, verify no task created

# Test 4: Idempotency
echo "Test 4: Idempotency"
# Send duplicate, verify single command

echo "All tests complete!"
```

---

## 7. Database Integrity Checks

### Orphaned Records

```sql
-- Drafts without commands
SELECT d.*
FROM drafts d
LEFT JOIN commands c ON d.source_message_id = json_extract(c.payload_json, '$.telegram_message_id')
WHERE c.id IS NULL;

-- Executions without drafts
SELECT e.*
FROM executions e
LEFT JOIN drafts d ON e.draft_id = d.id
WHERE d.id IS NULL;

-- Commands stuck in 'processing'
SELECT *
FROM commands
WHERE status = 'processing'
  AND updated_at < datetime('now', '-5 minutes');
```

---

## 8. Load Testing (Future)

### Sustained Load

```bash
# Send 100 messages over 1 hour
for i in {1..100}; do
  # Send Telegram message
  sleep 36  # Every 36 seconds
done
```

### Burst Load

```bash
# Send 10 messages in 10 seconds
for i in {1..10}; do
  # Send Telegram message
  sleep 1
done
```

---

## 9. User Acceptance Testing (UAT)

### Scenario 1: Daily Use

**Persona**: Busy professional

**Tasks**:
1. "Email client proposal by EOD"
2. "Call plumber about leak"
3. "Prepare presentation for Monday"

**Success Criteria**:
- All tasks created correctly
- Subtasks helpful
- Due dates accurate

---

### Scenario 2: Planning

**Persona**: Event organizer

**Task**: "Organize team retreat in June"

**Success Criteria**:
- Main task + comprehensive subtasks
- Due date in June
- Effort estimates reasonable

---

## 10. Monitoring Queries

### System Health

```sql
-- Commands processed today
SELECT COUNT(*) FROM commands WHERE DATE(created_at) = DATE('now');

-- Success rate today
SELECT
  status,
  COUNT(*) as count
FROM executions
WHERE DATE(executed_at) = DATE('now')
GROUP BY status;

-- Average processing time
SELECT AVG(
  (julianday(updated_at) - julianday(created_at)) * 86400
) as avg_seconds
FROM commands
WHERE status = 'completed'
  AND DATE(created_at) = DATE('now');
```

---

## 11. Cleanup After Testing

```sql
-- Delete test commands
DELETE FROM commands WHERE json_extract(payload_json, '$.original_text') LIKE 'Test%';

-- Delete test drafts
DELETE FROM drafts WHERE json_extract(draft_json, '$.title') LIKE 'Test%';

-- Clear audit log of tests
DELETE FROM audit_log WHERE details_json LIKE '%Test%';

-- Vacuum database
VACUUM;
```

---

## 12. Test Results Template

Create a test results document:

```markdown
# Test Results - Phase 1 MVP

**Date**: 2026-02-02
**Tester**: Your Name
**Environment**: Production/Staging

## Test Summary

| Test | Status | Notes |
|------|--------|-------|
| Simple task creation | ✅ Pass | |
| Task with due date | ✅ Pass | |
| Complex task + subtasks | ✅ Pass | 5 subtasks created |
| Clarification flow | ✅ Pass | |
| Cancel draft | ✅ Pass | |
| Idempotency | ✅ Pass | |
| Priority indicators | ⚠️ Warning | Priority not visible in Google Tasks |
| Error handling | ✅ Pass | Graceful failure on OAuth revoke |

## Issues Found

1. **Issue**: Priority not displayed
   **Severity**: Low
   **Workaround**: Add to notes field

## Overall Assessment

✅ System ready for production use
```

---

## Resources

- Database queries: `database/test-queries.sql`
- Workflow execution logs: n8n UI → Executions
- Telegram message history: Bot chat
- Google Tasks: https://tasks.google.com
