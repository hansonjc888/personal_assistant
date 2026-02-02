# Credentials Setup Guide

Complete guide for configuring all credentials and API keys for the AI Personal Assistant.

---

## Overview

The system requires credentials for:
1. **Gemini AI** - Intent classification and task structuring
2. **Telegram** - Chat interface
3. **Google Tasks** - Task management
4. **SQLite Database** - Data persistence

---

## 1. Gemini API Setup

### 1.1 Get API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click **Create API Key**
4. Select an existing Google Cloud project or create new one
5. Copy the API key

### 1.2 Configure in n8n

**Option A: Environment Variable (Recommended)**

```bash
# Add to n8n environment file or server env
export GEMINI_API_KEY="your_api_key_here"
```

**Option B: Direct in Workflow**

In HTTP Request nodes using Gemini API:
- Authentication: Generic Credential Type
- Generic Auth Type: Query Auth
- Query Parameters:
  - Name: `key`
  - Value: `{{ $env.GEMINI_API_KEY }}`

### 1.3 Test API Key

```bash
curl -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [{
        "text": "Hello, world!"
      }]
    }]
  }'
```

Expected: JSON response with generated content.

### 1.4 Rate Limits

**Free tier**:
- 15 requests per minute (RPM)
- 1 million tokens per minute (TPM)
- 1,500 requests per day (RPD)

**Paid tier** (Pay-as-you-go):
- 360 RPM
- 4 million TPM
- No daily limit

**Upgrade**: [Google AI Studio Pricing](https://ai.google.dev/pricing)

---

## 2. Telegram Bot Token

### 2.1 Create Bot

See [Telegram Setup Guide](./telegram-setup.md) for detailed steps.

Quick version:
1. Message @BotFather on Telegram
2. Send `/newbot`
3. Follow prompts
4. Save the bot token

### 2.2 Configure in n8n

1. Go to **Settings** → **Credentials**
2. Click **+ Add Credential**
3. Select **Telegram API**
4. Enter:
   - **Name**: `Task Assistant Bot`
   - **Access Token**: Your bot token
5. Click **Save**

### 2.3 Get Chat ID

```bash
# Send a message to your bot first, then:
curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates"
```

Find `chat.id` in response.

### 2.4 Security Best Practices

- **Never commit** token to git
- Store in environment variable:
  ```bash
  export TELEGRAM_BOT_TOKEN="your_token_here"
  ```
- Use secret token for webhook validation
- Limit bot to specific users (check `from.id`)

---

## 3. Google Tasks OAuth

### 3.1 Google Cloud Console Setup

See [Google Tasks Integration Guide](./google-tasks-integration.md) for detailed steps.

**Summary**:
1. Create Google Cloud project
2. Enable Google Tasks API
3. Configure OAuth consent screen
4. Create OAuth 2.0 client ID
5. Add authorized redirect URI: `https://your-n8n-domain.com/rest/oauth2-credential/callback`

### 3.2 Configure in n8n

1. Go to **Settings** → **Credentials**
2. Click **+ Add Credential**
3. Select **Google Tasks OAuth2 API**
4. Enter:
   - **Name**: `Google Tasks`
   - **Client ID**: From Google Cloud Console
   - **Client Secret**: From Google Cloud Console
   - **Scope**: `https://www.googleapis.com/auth/tasks`
5. Click **Connect my account**
6. Authorize with Google
7. Verify "Connected" status

### 3.3 Refresh Token

The OAuth flow automatically handles token refresh. If issues occur:

```bash
# Re-authenticate in n8n by clicking "Reconnect"
```

### 3.4 Service Account (Alternative)

For server-to-server auth without user interaction:

1. Create service account in Google Cloud Console
2. Download JSON key file
3. Use **Google Tasks Service Account** credential type in n8n
4. Upload JSON key

**Note**: Service accounts can't access personal task lists; use OAuth2 for personal assistant.

---

## 4. SQLite Database

### 4.1 Create Database File

```bash
# Choose location
DB_PATH="/home/n8n/data/task_assistant.db"

# Create database and apply schema
sqlite3 $DB_PATH < database/schema.sql

# Initialize default user
sqlite3 $DB_PATH < database/init_user.sql

# Set permissions
chown n8n:n8n $DB_PATH
chmod 660 $DB_PATH
```

### 4.2 Configure in n8n

1. Go to **Settings** → **Credentials**
2. Click **+ Add Credential**
3. Select **SQLite**
4. Enter:
   - **Name**: `Task Assistant DB`
   - **Database File Path**: `/home/n8n/data/task_assistant.db`
5. Click **Save**

### 4.3 Test Connection

```sql
-- In n8n, create test workflow with SQLite node:
SELECT * FROM users;
```

Expected: Returns default user record.

---

## 5. Environment Variables Reference

### 5.1 Create .env File

```bash
cp .env.example .env
nano .env  # Edit with your values
```

### 5.2 Load in n8n

**Option A: Docker Compose**

```yaml
# docker-compose.yml
services:
  n8n:
    environment:
      - GEMINI_API_KEY=${GEMINI_API_KEY}
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
      - DATABASE_PATH=${DATABASE_PATH}
    env_file:
      - .env
```

**Option B: Systemd Service**

```ini
# /etc/systemd/system/n8n.service
[Service]
EnvironmentFile=/path/to/.env
```

**Option C: Shell Export**

```bash
source .env
```

### 5.3 Access in Workflows

```javascript
// In Code nodes
const apiKey = $env.GEMINI_API_KEY;
const botToken = $env.TELEGRAM_BOT_TOKEN;

// In HTTP Request nodes
// Use {{ $env.VARIABLE_NAME }} in parameters
```

---

## 6. Secrets Management

### 6.1 Local Development

Use `.env` file (git-ignored):

```bash
echo ".env" >> .gitignore
```

### 6.2 Production Deployment

**Option A: AWS Secrets Manager**

```bash
# Store secret
aws secretsmanager create-secret \
  --name task-assistant/gemini-api-key \
  --secret-string "your_api_key"

# Retrieve in startup script
GEMINI_API_KEY=$(aws secretsmanager get-secret-value \
  --secret-id task-assistant/gemini-api-key \
  --query SecretString --output text)
```

**Option B: HashiCorp Vault**

```bash
# Store secret
vault kv put secret/task-assistant \
  gemini_api_key="your_api_key"

# Retrieve
vault kv get -field=gemini_api_key secret/task-assistant
```

**Option C: Environment Variables Only**

Set directly on server:

```bash
# In ~/.bashrc or /etc/environment
export GEMINI_API_KEY="your_api_key"
export TELEGRAM_BOT_TOKEN="your_token"
```

### 6.3 Rotate Credentials

**Gemini API Key**:
1. Generate new key in Google AI Studio
2. Update environment variable
3. Restart n8n
4. Delete old key

**Telegram Bot Token**:
1. Message @BotFather: `/revoke`
2. Generate new token: `/token`
3. Update n8n credential
4. Update webhook with new token

**Google OAuth**:
1. Revoke in Google Cloud Console
2. Regenerate client ID/secret
3. Re-authenticate in n8n

---

## 7. Credential Validation

### 7.1 Checklist

Before deploying, verify:

- [ ] Gemini API key works (test with curl)
- [ ] Telegram bot token valid (test with /getMe)
- [ ] Google Tasks OAuth connected (test list tasks)
- [ ] SQLite database accessible (test query)
- [ ] Webhook URL correct (test with curl)
- [ ] All environment variables set
- [ ] n8n can access credentials
- [ ] No credentials in git repository

### 7.2 Automated Test Script

```bash
#!/bin/bash
# test-credentials.sh

echo "Testing Gemini API..."
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"test"}]}]}' | grep -q "candidates"
[ $? -eq 0 ] && echo "✓ Gemini API OK" || echo "✗ Gemini API FAILED"

echo "Testing Telegram Bot..."
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe" | grep -q '"ok":true'
[ $? -eq 0 ] && echo "✓ Telegram Bot OK" || echo "✗ Telegram Bot FAILED"

echo "Testing Database..."
sqlite3 "$DATABASE_PATH" "SELECT COUNT(*) FROM users;" > /dev/null
[ $? -eq 0 ] && echo "✓ Database OK" || echo "✗ Database FAILED"

echo "Testing Webhook URL..."
curl -s -o /dev/null -w "%{http_code}" -X POST "$N8N_WEBHOOK_URL/telegram-bot" | grep -q "200\|204"
[ $? -eq 0 ] && echo "✓ Webhook URL OK" || echo "⚠ Webhook URL might need verification"
```

---

## 8. Troubleshooting

### Issue: "Invalid API key" (Gemini)

**Causes**:
- API key incorrect or expired
- API not enabled in Google Cloud project
- Rate limit exceeded

**Solutions**:
1. Verify key in Google AI Studio
2. Enable Generative Language API
3. Check quota: [API Console](https://console.cloud.google.com/apis/api/generativelanguage.googleapis.com/quotas)

### Issue: "Unauthorized" (Telegram)

**Causes**:
- Bot token incorrect
- Bot deleted or revoked

**Solutions**:
1. Verify token with: `curl "https://api.telegram.org/bot<TOKEN>/getMe"`
2. If invalid, create new bot with @BotFather

### Issue: "OAuth token expired" (Google Tasks)

**Causes**:
- Refresh token revoked
- App not verified
- User revoked access

**Solutions**:
1. Re-authenticate in n8n credentials
2. Check OAuth consent screen status
3. Verify app is not in testing mode (or user is test user)

### Issue: "Database locked" (SQLite)

**Causes**:
- Multiple processes accessing database
- Unfinished transaction

**Solutions**:
```bash
# Check for locks
lsof | grep task_assistant.db

# Restart n8n
systemctl restart n8n
```

---

## 9. Security Audit

### 9.1 Pre-Deployment Checklist

- [ ] All secrets in environment variables, not code
- [ ] `.env` file git-ignored
- [ ] HTTPS enabled on n8n
- [ ] Webhook secret token configured
- [ ] Database file permissions correct (660)
- [ ] Google OAuth consent screen configured
- [ ] Telegram bot limited to known users
- [ ] API rate limits understood
- [ ] Backup strategy for database
- [ ] Credentials documented (this guide)

### 9.2 Regular Maintenance

**Monthly**:
- Review OAuth access logs in Google Cloud Console
- Check API usage/quotas
- Rotate credentials if compromised

**Quarterly**:
- Update API keys
- Review access permissions
- Audit audit_log table for anomalies

---

## 10. Quick Reference

### Environment Variables

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `GEMINI_API_KEY` | Gemini AI API key | Yes | `AIzaSy...` |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | Yes | `123:ABC...` |
| `TELEGRAM_CHAT_ID` | Your Telegram chat ID | Yes | `987654321` |
| `DATABASE_PATH` | SQLite database path | Yes | `/home/n8n/data/task_assistant.db` |
| `N8N_WEBHOOK_URL` | n8n webhook base URL | Yes | `https://n8n.example.com/webhook` |
| `USER_TIMEZONE` | Default timezone | No | `America/New_York` |
| `TELEGRAM_SECRET_TOKEN` | Webhook validation | No | Random string |

### n8n Credential Names

| Type | Name | Usage |
|------|------|-------|
| Gemini API | N/A (env var) | HTTP Request with Query Auth |
| Telegram API | `Task Assistant Bot` | Telegram nodes |
| Google Tasks OAuth2 | `Google Tasks` | HTTP Request with OAuth2 |
| SQLite | `Task Assistant DB` | SQLite nodes |

---

## Support Resources

- [Gemini API Docs](https://ai.google.dev/docs)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Google Tasks API](https://developers.google.com/tasks)
- [n8n Credentials Guide](https://docs.n8n.io/credentials/)
