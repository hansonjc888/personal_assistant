# n8n Database Setup Guide

This guide covers setting up the SQLite database connection in n8n for the AI Personal Assistant.

---

## Prerequisites

- n8n instance running (self-hosted on AWS Lightsail)
- SQLite3 installed on the server
- Database file created and accessible

---

## Step 1: Create Database File

### 1.1 Choose Database Location

Recommended path:
```bash
/home/n8n/data/task_assistant.db
```

### 1.2 Initialize Database

```bash
# Navigate to database directory
cd /home/n8n/data

# Create database and run schema
sqlite3 task_assistant.db < /path/to/schema.sql

# Verify tables created
sqlite3 task_assistant.db "SELECT name FROM sqlite_master WHERE type='table';"
```

Expected output:
```
users
commands
drafts
executions
audit_log
```

### 1.3 Initialize Default User

```bash
sqlite3 task_assistant.db < /path/to/init_user.sql
```

### 1.4 Set Permissions

```bash
# Ensure n8n process can read/write
chown n8n:n8n task_assistant.db
chmod 660 task_assistant.db
```

---

## Step 2: Configure n8n Credentials

### 2.1 Access n8n UI

Navigate to: `https://your-n8n-domain.com`

### 2.2 Add SQLite Credential

1. Click **Settings** → **Credentials**
2. Click **+ Add Credential**
3. Select **SQLite**
4. Fill in details:

   - **Name**: `Task Assistant DB`
   - **Database File Path**: `/home/n8n/data/task_assistant.db`

5. Click **Save**

### 2.3 Test Connection

Create a test workflow:

```json
{
  "nodes": [
    {
      "name": "Test SQLite Connection",
      "type": "n8n-nodes-base.sqlite",
      "parameters": {
        "operation": "executeQuery",
        "query": "SELECT * FROM users;"
      },
      "credentials": {
        "sqlite": {
          "name": "Task Assistant DB"
        }
      }
    }
  ]
}
```

Expected result: Returns the default user record.

---

## Step 3: Verify Database Structure

### 3.1 Check Tables

```bash
sqlite3 task_assistant.db
```

```sql
-- List all tables
.tables

-- Show schema for each table
.schema users
.schema commands
.schema drafts
.schema executions
.schema audit_log
```

### 3.2 Check Views

```sql
-- Verify views exist
SELECT name FROM sqlite_master WHERE type='view';
```

Expected views:
- `v_pending_commands`
- `v_active_drafts`
- `v_execution_history`

### 3.3 Check Indexes

```sql
-- Show all indexes
SELECT name, tbl_name FROM sqlite_master WHERE type='index';
```

---

## Step 4: Database Backup Strategy

### 4.1 Manual Backup

```bash
# Create backup
sqlite3 task_assistant.db ".backup '/home/n8n/backups/task_assistant_$(date +%Y%m%d_%H%M%S).db'"
```

### 4.2 Automated Daily Backup (Cron)

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * sqlite3 /home/n8n/data/task_assistant.db ".backup '/home/n8n/backups/task_assistant_$(date +\%Y\%m\%d).db'" && find /home/n8n/backups -name "task_assistant_*.db" -mtime +30 -delete
```

This keeps 30 days of backups.

### 4.3 Restore from Backup

```bash
# Stop n8n
systemctl stop n8n

# Restore database
cp /home/n8n/backups/task_assistant_20260202.db /home/n8n/data/task_assistant.db

# Start n8n
systemctl start n8n
```

---

## Step 5: Troubleshooting

### Issue: "Database is locked"

**Cause**: Multiple processes accessing database simultaneously.

**Solution**:
```bash
# Check for active connections
lsof | grep task_assistant.db

# If stuck, restart n8n
systemctl restart n8n
```

### Issue: "Unable to open database file"

**Cause**: Permissions or path issue.

**Solution**:
```bash
# Verify file exists
ls -la /home/n8n/data/task_assistant.db

# Fix permissions
chown n8n:n8n /home/n8n/data/task_assistant.db
chmod 660 /home/n8n/data/task_assistant.db
```

### Issue: "Table not found"

**Cause**: Schema not initialized.

**Solution**:
```bash
# Re-run schema
sqlite3 /home/n8n/data/task_assistant.db < schema.sql
```

### Issue: "Foreign key constraint failed"

**Cause**: Referenced record doesn't exist (e.g., draft without user).

**Solution**:
```sql
-- Verify user exists
SELECT * FROM users;

-- If missing, run init_user.sql
.read init_user.sql
```

---

## Step 6: Database Maintenance

### 6.1 Vacuum Database (Monthly)

Reclaim unused space:

```bash
sqlite3 task_assistant.db "VACUUM;"
```

### 6.2 Analyze Query Performance

```sql
-- Enable query analyzer
EXPLAIN QUERY PLAN SELECT * FROM v_pending_commands;

-- Check index usage
.eqp on
SELECT * FROM commands WHERE status='pending';
```

### 6.3 Monitor Database Size

```bash
# Check database file size
du -h /home/n8n/data/task_assistant.db

# Get table sizes
sqlite3 task_assistant.db "SELECT name, COUNT(*) FROM sqlite_master sm JOIN pragma_table_info(sm.name) pti GROUP BY name;"
```

---

## Step 7: Security Considerations

### 7.1 File Permissions

Ensure only n8n process can access:

```bash
# Directory permissions
chmod 750 /home/n8n/data
chown n8n:n8n /home/n8n/data

# Database file permissions
chmod 660 /home/n8n/data/task_assistant.db
chown n8n:n8n /home/n8n/data/task_assistant.db
```

### 7.2 No Network Access

SQLite is file-based; ensure it's not exposed:

```bash
# Verify no network bindings
netstat -tulpn | grep sqlite
# Should return nothing
```

### 7.3 Backup Encryption (Optional)

```bash
# Install SQLCipher for encrypted backups
apt-get install sqlcipher

# Create encrypted backup
sqlcipher /home/n8n/data/task_assistant.db "ATTACH DATABASE '/home/n8n/backups/encrypted_backup.db' AS encrypted KEY 'your-secret-key'; SELECT sqlcipher_export('encrypted'); DETACH DATABASE encrypted;"
```

---

## Step 8: Migration to PostgreSQL (Future)

When scaling beyond MVP:

### 8.1 Export Data

```bash
# Dump to SQL
sqlite3 task_assistant.db .dump > task_assistant_export.sql
```

### 8.2 Convert Schema

SQLite → PostgreSQL differences:
- `AUTOINCREMENT` → `SERIAL`
- `TEXT` → `VARCHAR` or `TEXT`
- `TIMESTAMP` → `TIMESTAMPTZ`

### 8.3 Import to PostgreSQL

```bash
# Create PostgreSQL database
createdb task_assistant

# Import (after schema conversion)
psql task_assistant < task_assistant_postgres.sql
```

### 8.4 Update n8n Credentials

Switch from SQLite to PostgreSQL credentials in n8n.

---

## Reference Queries

### Useful Management Queries

```sql
-- Count records per table
SELECT 'users' as table_name, COUNT(*) as count FROM users
UNION ALL
SELECT 'commands', COUNT(*) FROM commands
UNION ALL
SELECT 'drafts', COUNT(*) FROM drafts
UNION ALL
SELECT 'executions', COUNT(*) FROM executions
UNION ALL
SELECT 'audit_log', COUNT(*) FROM audit_log;

-- Recent activity
SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 10;

-- Pending work
SELECT * FROM v_pending_commands;

-- Success rate
SELECT
  status,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM executions), 2) as percentage
FROM executions
GROUP BY status;
```

---

## Appendix: Database Schema Summary

| Table | Purpose | Key Indexes |
|-------|---------|-------------|
| `users` | User profiles | PRIMARY KEY (user_id) |
| `commands` | Command queue | status, created_at, payload_json |
| `drafts` | Task/event drafts | user_id+status, source_message_id |
| `executions` | Execution audit | draft_id, status+executed_at |
| `audit_log` | Full history | timestamp, entity_type+entity_id |

**Views**:
- `v_pending_commands` - Pending commands with user info
- `v_active_drafts` - Drafts awaiting confirmation
- `v_execution_history` - Execution results with draft details

---

## Support

For issues or questions:
1. Check n8n execution logs: `/var/log/n8n/`
2. Review SQLite logs: `sqlite3 task_assistant.db ".log stderr"`
3. Test queries in `database/test-queries.sql`
