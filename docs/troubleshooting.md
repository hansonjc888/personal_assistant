# Troubleshooting Guide

Common issues and solutions for the AI Personal Assistant Phase 1 MVP.

---

## Quick Diagnostics

Run these checks first:

```bash
# 1. Check n8n status
systemctl status n8n
curl -I https://your-n8n-domain.com

# 2. Check database
sqlite3 $DATABASE_PATH "SELECT COUNT(*) FROM users;"

# 3. Check Telegram webhook
curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo"

# 4. Check recent commands
sqlite3 $DATABASE_PATH "SELECT * FROM commands ORDER BY created_at DESC LIMIT 5;"

# 5. Check n8n execution logs
# Via n8n UI: Executions tab
```

---

## 1. Bot Not Responding

### Symptom
Sending messages to Telegram bot → No response

### Possible Causes & Solutions

#### A. Webhook Not Configured

**Check**:
```bash
curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo"
```

**If webhook URL is empty or wrong**:
```bash
./scripts/set-telegram-webhook.sh
```

**Verify**:
- `url` field matches your n8n webhook
- `has_custom_certificate`: false (should use public CA)
- `pending_update_count`: 0

---

#### B. Workflow Inactive

**Check**: n8n UI → Workflows → Workflow A status

**Solution**: Activate Workflow A (Inbound Router)

---

#### C. n8n Not Running

**Check**:
```bash
systemctl status n8n
# or
ps aux | grep n8n
```

**Solution**:
```bash
systemctl restart n8n
```

---

#### D. Webhook URL Unreachable

**Check**:
```bash
curl -X POST https://your-n8n-domain.com/webhook/telegram-bot \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

**If fails**:
- Check firewall rules
- Verify HTTPS certificate valid
- Confirm n8n listening on correct port

---

#### E. Database Permissions

**Check**:
```bash
ls -la $DATABASE_PATH
```

**Should be**:
```
-rw-rw---- 1 n8n n8n ... task_assistant.db
```

**Fix**:
```bash
chown n8n:n8n $DATABASE_PATH
chmod 660 $DATABASE_PATH
```

---

## 2. Drafts Not Creating

### Symptom
Bot acknowledges message but no draft appears

### Diagnostics

```sql
-- Check if command was created
SELECT * FROM commands WHERE status='pending' OR status='processing';

-- Check for failed commands
SELECT * FROM commands WHERE status='failed' ORDER BY created_at DESC LIMIT 5;
```

### Solutions

#### A. Workflow B Not Running

**Check**: n8n UI → Workflow B (Command Executor) status

**Solution**: Ensure Workflow B is:
1. Active
2. Has correct cron schedule (every 10s)
3. Sub-workflow IDs configured

---

#### B. Gemini API Issues

**Check n8n execution logs** for Gemini API errors:

**Common errors**:

1. **"Invalid API key"**
   ```bash
   # Test API key
   curl -X POST \
     "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GEMINI_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"contents":[{"parts":[{"text":"test"}]}]}'
   ```

   **Solution**: Verify `GEMINI_API_KEY` in environment

2. **"429 Rate limit exceeded"**

   **Solution**: Wait or upgrade to paid tier

3. **"JSON parse error"**

   **Solution**: Check Gemini response format in execution logs

---

#### C. Workflow D Not Configured

**Check**: Workflow D (Task Drafting) exists and workflow ID matches

**Solution**:
1. Import Workflow D
2. Get workflow ID from URL: `https://n8n.example.com/workflow/<ID>`
3. Update `WORKFLOW_D_ID` environment variable
4. Restart n8n

---

## 3. Tasks Not Creating in Google Tasks

### Symptom
Draft confirmed but task doesn't appear in Google Tasks

### Diagnostics

```sql
-- Check execution records
SELECT * FROM executions ORDER BY executed_at DESC LIMIT 5;

-- Check for failures
SELECT
  e.*,
  d.draft_json
FROM executions e
JOIN drafts d ON e.draft_id = d.id
WHERE e.status = 'failed'
ORDER BY e.executed_at DESC;
```

### Solutions

#### A. OAuth Token Expired

**Error in execution log**: "401 Unauthorized"

**Solution**:
1. n8n UI → Credentials → Google Tasks OAuth2
2. Click **Reconnect**
3. Authorize again

---

#### B. Invalid Task Format

**Error**: "400 Bad Request"

**Common causes**:
- Due date not in RFC 3339 format
- Title empty or too long (> 1024 chars)

**Fix in Workflow E**:
Check "Build Google Tasks Request" node for proper formatting:
```json
{
  "title": "...",
  "due": "YYYY-MM-DDTHH:mm:ss.sssZ",
  "notes": "..."
}
```

---

#### C. Google Tasks API Not Enabled

**Solution**:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. APIs & Services → Library
4. Search "Google Tasks API"
5. Click Enable

---

#### D. Rate Limit Exceeded

**Error**: "429 Too Many Requests"

**Solution**:
- Wait before retrying
- Check quota: [API Console](https://console.cloud.google.com/apis/api/tasks.googleapis.com/quotas)
- Implement exponential backoff in workflow

---

## 4. Duplicate Messages

### Symptom
Same message processed multiple times

### Diagnostics

```sql
-- Find duplicates
SELECT
  json_extract(payload_json, '$.telegram_message_id') as msg_id,
  COUNT(*) as count
FROM commands
GROUP BY msg_id
HAVING count > 1;
```

### Solutions

#### A. Idempotency Check Not Working

**Check Workflow A**: "Idempotency Check" node query:
```sql
SELECT id FROM commands
WHERE json_extract(payload_json, '$.telegram_message_id') = :message_id
LIMIT 1
```

**Verify**: Returns existing command for duplicate

---

#### B. Telegram Pending Updates

**Solution**:
```bash
# Clear pending updates
curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getUpdates?offset=-1"

# Re-set webhook with drop_pending_updates
curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://your-n8n-domain.com/webhook/telegram-bot",
    "drop_pending_updates": true
  }'
```

---

## 5. Database Issues

### Issue: "Database is locked"

**Cause**: Multiple processes accessing database

**Immediate fix**:
```bash
# Check what's accessing
lsof | grep task_assistant.db

# Restart n8n
systemctl restart n8n
```

**Long-term solution**: Migrate to PostgreSQL (future)

---

### Issue: "Table not found"

**Cause**: Schema not initialized

**Solution**:
```bash
sqlite3 $DATABASE_PATH < database/schema.sql
sqlite3 $DATABASE_PATH < database/init_user.sql
```

---

### Issue: "Foreign key constraint failed"

**Cause**: Referenced record missing (e.g., user doesn't exist)

**Solution**:
```sql
-- Check users table
SELECT * FROM users;

-- If empty, initialize
.read database/init_user.sql
```

---

## 6. Intent Classification Issues

### Symptom
Bot doesn't understand messages or misclassifies intent

### Diagnostics

```sql
-- Check recent intents and confidence
SELECT
  json_extract(payload_json, '$.intent') as intent,
  json_extract(payload_json, '$.confidence') as confidence,
  json_extract(payload_json, '$.original_text') as text
FROM commands
WHERE type = 'draft_task_from_text'
ORDER BY created_at DESC
LIMIT 10;
```

### Solutions

#### A. Low Confidence Scores

**If confidence < 0.7 consistently**:
- Review Gemini prompt in Workflow A
- Adjust temperature (currently 0.1)
- Add more examples to prompt

---

#### B. Always Returns "unknown"

**Check**:
1. Gemini API responding correctly
2. JSON parsing in "Parse Intent" node
3. Intent mapping in command type switch

---

## 7. Subtasks Not Appearing

### Symptom
Main task created but subtasks missing

### Diagnostics

```sql
-- Check draft has subtasks
SELECT
  id,
  json_extract(draft_json, '$.title') as title,
  json_array_length(json_extract(draft_json, '$.suggested_subtasks')) as subtask_count,
  json_extract(draft_json, '$.suggested_subtasks') as subtasks
FROM drafts
WHERE id = (SELECT MAX(id) FROM drafts);
```

### Solutions

#### A. Subtask Loop Not Executing

**Check Workflow E**: "Split Subtasks" node

**Verify**:
- Batch size: 1
- Loop continues until all subtasks processed

---

#### B. Parent ID Not Set

**Check**: Subtask creation includes `parent` field:
```json
{
  "title": "Subtask title [S]",
  "parent": "main_task_id"
}
```

---

## 8. Performance Issues

### Symptom
Slow response times (> 30 seconds)

### Diagnostics

```sql
-- Check processing time
SELECT
  id,
  type,
  created_at,
  updated_at,
  (julianday(updated_at) - julianday(created_at)) * 86400 as processing_seconds
FROM commands
WHERE status = 'completed'
ORDER BY created_at DESC
LIMIT 10;
```

### Solutions

#### A. Workflow B Polling Interval Too Long

**Current**: Every 10 seconds

**Adjust**: Change cron schedule to 5 seconds (not recommended below that)

---

#### B. Gemini API Slow

**Check**: Execution logs for Gemini response time

**Solution**:
- Use Gemini 2.0 Flash (faster than Pro)
- Reduce prompt length
- Consider caching frequent patterns

---

#### C. Database Query Slow

**Check**: Enable query profiling:
```sql
.timer on
SELECT * FROM v_pending_commands;
```

**Solution**: Verify indexes exist:
```sql
.indexes commands
-- Should show: idx_commands_status_created, idx_commands_payload
```

---

## 9. Workflow Execution Errors

### General Debugging Process

1. **Check n8n Executions tab**
   - Find failed execution
   - Click to view details
   - Identify failing node

2. **Common node failures**:

   **Code nodes**:
   - Check syntax errors
   - Verify all variables defined
   - Test with sample data

   **HTTP Request nodes**:
   - Verify URL correct
   - Check credentials
   - Review request/response in logs

   **SQLite nodes**:
   - Check query syntax
   - Verify parameters bound correctly
   - Test query in sqlite3 CLI

3. **Manual re-run**:
   - Fix issue
   - Click "Execute Workflow" with test data

---

## 10. Telegram-Specific Issues

### Issue: Buttons Not Working

**Symptom**: Clicking inline buttons does nothing

**Check**:
1. Webhook `allowed_updates` includes "callback_query"
2. Intent classifier handles callback_data format
3. Workflow B routes "confirm_draft" command

**Solution**:
```bash
# Re-set webhook with callback_query
curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://your-n8n-domain.com/webhook/telegram-bot",
    "allowed_updates": ["message", "callback_query"]
  }'
```

---

### Issue: Messages Truncated

**Symptom**: Long drafts cut off

**Cause**: Telegram 4096 character limit

**Solution**: In Workflow D "Format Confirmation Message" node:
```javascript
// Truncate if needed
if (message.length > 4000) {
  message = message.substring(0, 3900) + "\n\n... (truncated)";
}
```

---

## 11. Logging and Debugging

### Enable Verbose Logging

**n8n**:
```bash
# Set log level
export N8N_LOG_LEVEL=debug

# Restart n8n
systemctl restart n8n

# View logs
journalctl -u n8n -f
```

---

### Useful Debug Queries

```sql
-- Full message flow
SELECT
  'Command' as stage,
  c.id,
  c.type,
  c.status,
  c.created_at
FROM commands c
WHERE json_extract(c.payload_json, '$.telegram_message_id') = '<MESSAGE_ID>'

UNION ALL

SELECT
  'Draft' as stage,
  d.id,
  d.draft_type,
  d.status,
  d.created_at
FROM drafts d
WHERE d.source_message_id = '<MESSAGE_ID>'

UNION ALL

SELECT
  'Execution' as stage,
  e.id,
  e.status,
  e.status,
  e.executed_at
FROM executions e
JOIN drafts d ON e.draft_id = d.id
WHERE d.source_message_id = '<MESSAGE_ID>'

ORDER BY created_at ASC;
```

---

## 12. Emergency Procedures

### Stop All Processing

```sql
-- Mark all pending commands as failed
UPDATE commands SET status='failed' WHERE status='pending';
```

---

### Reset System State

```bash
# 1. Stop n8n
systemctl stop n8n

# 2. Clear pending commands
sqlite3 $DATABASE_PATH "DELETE FROM commands WHERE status='pending';"

# 3. Clear Telegram pending updates
curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getUpdates?offset=-1"

# 4. Start n8n
systemctl start n8n
```

---

### Rollback Database

```bash
# Restore from backup
systemctl stop n8n
cp /home/n8n/backups/task_assistant_20260201.db $DATABASE_PATH
systemctl start n8n
```

---

## 13. Getting Help

### Information to Collect

When reporting issues:

1. **Error message**: Exact text from n8n execution logs
2. **Workflow execution ID**: From n8n UI
3. **Database state**:
   ```sql
   SELECT * FROM commands ORDER BY created_at DESC LIMIT 5;
   SELECT * FROM drafts ORDER BY created_at DESC LIMIT 5;
   SELECT * FROM executions ORDER BY executed_at DESC LIMIT 5;
   ```
4. **Telegram message**: Original text sent
5. **System info**:
   ```bash
   n8n --version
   sqlite3 --version
   ```

---

## 14. Preventive Maintenance

### Daily Checks

```bash
#!/bin/bash
# daily-health-check.sh

# Check command queue not backed up
PENDING=$(sqlite3 $DATABASE_PATH "SELECT COUNT(*) FROM commands WHERE status='pending';")
if [ $PENDING -gt 10 ]; then
  echo "WARNING: $PENDING pending commands"
fi

# Check success rate
sqlite3 $DATABASE_PATH "
SELECT
  status,
  COUNT(*) as count
FROM executions
WHERE DATE(executed_at) = DATE('now')
GROUP BY status;
"

# Check disk space
df -h $DATABASE_PATH
```

---

### Weekly Maintenance

```bash
# 1. Vacuum database
sqlite3 $DATABASE_PATH "VACUUM;"

# 2. Backup
sqlite3 $DATABASE_PATH ".backup '/home/n8n/backups/task_assistant_$(date +%Y%m%d).db'"

# 3. Clear old audit logs (> 30 days)
sqlite3 $DATABASE_PATH "DELETE FROM audit_log WHERE timestamp < datetime('now', '-30 days');"
```

---

## 15. Known Limitations

### Phase 1 MVP Constraints

1. **Single user only**: Multi-user not supported
2. **SQLite limitations**: No concurrent writes
3. **No task editing**: Can only cancel and recreate
4. **Limited error recovery**: Manual intervention needed for some failures
5. **No notification system**: User must check Google Tasks

**Workarounds**: Documented in CLAUDE.md

---

## Contact & Support

- **Documentation**: See `docs/` directory
- **Database queries**: `database/test-queries.sql`
- **Issues**: GitHub Issues (if applicable)
