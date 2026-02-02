# Telegram Bot Setup Guide

Complete guide for setting up and configuring the Telegram bot for the AI Personal Assistant.

---

## Overview

The AI Personal Assistant uses Telegram as the primary chat interface. This guide covers bot creation, webhook configuration, and n8n integration.

---

## Step 1: Create Telegram Bot

### 1.1 Talk to BotFather

1. Open Telegram
2. Search for `@BotFather`
3. Start a conversation: `/start`

### 1.2 Create New Bot

```
/newbot
```

BotFather will ask:
1. **Bot name**: Choose a display name (e.g., "My Task Assistant")
2. **Bot username**: Choose a unique username ending in "bot" (e.g., `mytaskassistant_bot`)

### 1.3 Save Bot Token

BotFather will respond with:
```
Done! Congratulations on your new bot. You will find it at t.me/mytaskassistant_bot
You can now add a description...

Use this token to access the HTTP API:
1234567890:ABCdefGHIjklMNOpqrSTUvwxYZ123456789

Keep your token secure and store it safely, it can be used by anyone to control your bot.
```

**IMPORTANT**: Save this token securely. You'll need it for n8n configuration.

### 1.4 Configure Bot Settings

```
/setdescription
```
Choose your bot, then send:
```
Your personal AI task assistant. I help you manage tasks and schedules through natural language.
```

```
/setabouttext
```
```
AI-powered task management assistant built with n8n and Gemini.
```

```
/setcommands
```
```
start - Start the bot
help - Get help
status - Check bot status
```

---

## Step 2: Get Your Telegram Chat ID

### 2.1 Start Conversation with Bot

1. Find your bot: `t.me/mytaskassistant_bot`
2. Click **Start**
3. Send any message

### 2.2 Get Chat ID

Use the Telegram Bot API:

```bash
# Replace YOUR_BOT_TOKEN with your actual token
curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
```

Response:
```json
{
  "ok": true,
  "result": [
    {
      "update_id": 123456789,
      "message": {
        "message_id": 1,
        "from": {
          "id": 987654321,
          "is_bot": false,
          "first_name": "John",
          "username": "john_doe"
        },
        "chat": {
          "id": 987654321,
          "first_name": "John",
          "username": "john_doe",
          "type": "private"
        },
        "text": "Hello"
      }
    }
  ]
}
```

**Save your chat ID**: The `chat.id` value (e.g., `987654321`).

### 2.3 Update Database

Update the default user record with your chat ID:

```sql
UPDATE users
SET telegram_chat_id = '987654321'
WHERE user_id = 'default_user';
```

---

## Step 3: Configure n8n Telegram Credentials

### 3.1 Add Telegram Credential

1. In n8n, go to **Settings** → **Credentials**
2. Click **+ Add Credential**
3. Select **Telegram API**
4. Fill in:
   - **Name**: `Task Assistant Bot`
   - **Access Token**: (Your bot token from Step 1.3)
5. Click **Save**

### 3.2 Test Credential

Create a test workflow:

```json
{
  "nodes": [
    {
      "name": "Send Test Message",
      "type": "n8n-nodes-base.telegram",
      "parameters": {
        "chatId": "987654321",
        "text": "Test message from n8n!"
      },
      "credentials": {
        "telegramApi": {
          "name": "Task Assistant Bot"
        }
      }
    }
  ]
}
```

You should receive the message in Telegram.

---

## Step 4: Set Up Webhook

### 4.1 Get n8n Webhook URL

1. Import Workflow A (Inbound Router)
2. Open the webhook node
3. Copy the **Production URL**

Example: `https://your-n8n-domain.com/webhook/telegram-bot`

### 4.2 Register Webhook with Telegram

**Option A: Using curl**

```bash
curl -X POST \
  "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://your-n8n-domain.com/webhook/telegram-bot",
    "allowed_updates": ["message", "callback_query"],
    "drop_pending_updates": true
  }'
```

**Option B: Using browser**

Navigate to:
```
https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook?url=https://your-n8n-domain.com/webhook/telegram-bot&allowed_updates=["message","callback_query"]&drop_pending_updates=true
```

Expected response:
```json
{
  "ok": true,
  "result": true,
  "description": "Webhook was set"
}
```

### 4.3 Verify Webhook

```bash
curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getWebhookInfo"
```

Response:
```json
{
  "ok": true,
  "result": {
    "url": "https://your-n8n-domain.com/webhook/telegram-bot",
    "has_custom_certificate": false,
    "pending_update_count": 0,
    "allowed_updates": ["message", "callback_query"],
    "max_connections": 40
  }
}
```

**Verify**:
- ✅ `url` matches your n8n webhook
- ✅ `pending_update_count` is 0
- ✅ `allowed_updates` includes "message" and "callback_query"

---

## Step 5: Test End-to-End Flow

### 5.1 Send Test Message

In Telegram, send to your bot:
```
Buy milk tomorrow
```

### 5.2 Expected Behavior

1. Bot responds: "Got it! Working on it... ⚙️"
2. After ~10 seconds, bot sends draft:
   ```
   📝 Task Draft:

   Title: Buy milk
   Due: Tomorrow (Feb 3, 2026)
   Notes: ...

   Suggested subtasks:
   • ...

   [✅ Confirm] [✏️ Edit] [❌ Cancel]
   ```

3. Click **✅ Confirm**
4. Bot responds: "✅ Task created successfully!"
5. Check Google Tasks - task should appear

### 5.3 Verify in Database

```sql
-- Check command was created
SELECT * FROM commands ORDER BY created_at DESC LIMIT 1;

-- Check draft was created
SELECT * FROM drafts ORDER BY created_at DESC LIMIT 1;

-- Check execution record
SELECT * FROM executions ORDER BY executed_at DESC LIMIT 1;

-- Check audit trail
SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 5;
```

---

## Step 6: Telegram Message Formats

### 6.1 Inline Keyboards (Buttons)

Used for confirmation flow:

```javascript
// n8n Telegram node
{
  "chatId": "987654321",
  "text": "Task Draft:\n...",
  "additionalFields": {
    "reply_markup": {
      "inline_keyboard": [
        [
          {"text": "✅ Confirm", "callback_data": "confirm_draft:123"},
          {"text": "✏️ Edit", "callback_data": "edit_draft:123"},
          {"text": "❌ Cancel", "callback_data": "cancel_draft:123"}
        ]
      ]
    }
  }
}
```

### 6.2 Markdown Formatting

**Not supported in Phase 1** - Use plain text with emojis:

```
📝 Task Draft:

Title: Buy groceries
Due: Tomorrow (Feb 3, 2026)
Notes: Weekly shopping

Suggested subtasks:
 • Make shopping list (S)
 • Go to store (M)
 • Put away groceries (S)
```

### 6.3 Message Limits

- **Max message length**: 4096 characters
- **Max button text**: 64 characters
- **Max callback_data**: 64 bytes

If draft exceeds limits, truncate notes or reduce subtasks.

---

## Step 7: Webhook Security

### 7.1 Enable Secret Token (Recommended)

```bash
# Generate secret token
SECRET_TOKEN=$(openssl rand -hex 32)

# Set webhook with secret
curl -X POST \
  "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://your-n8n-domain.com/webhook/telegram-bot",
    "secret_token": "'$SECRET_TOKEN'"
  }'
```

In n8n webhook node, verify header:

```javascript
// Code node before processing
const secretToken = $('Telegram Webhook').item.json.headers['x-telegram-bot-api-secret-token'];

if (secretToken !== process.env.TELEGRAM_SECRET_TOKEN) {
  throw new Error('Unauthorized webhook request');
}

return $input.all();
```

### 7.2 IP Whitelisting (Optional)

Telegram webhook IPs:
```
149.154.160.0/20
91.108.4.0/22
```

Configure in firewall/reverse proxy.

---

## Step 8: Troubleshooting

### Issue: Webhook not receiving messages

**Verify webhook status**:
```bash
curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getWebhookInfo"
```

**Check for errors**:
- `last_error_date`: Timestamp of last error
- `last_error_message`: Error description

**Common causes**:
1. **SSL certificate invalid**: Ensure n8n uses valid HTTPS
2. **Webhook URL unreachable**: Test with `curl https://your-n8n-domain.com/webhook/telegram-bot`
3. **n8n workflow inactive**: Activate Workflow A

**Solution**:
```bash
# Delete webhook
curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/deleteWebhook?drop_pending_updates=true"

# Set again
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://your-n8n-domain.com/webhook/telegram-bot"}'
```

### Issue: Bot not responding

**Check n8n execution logs**:
1. Go to **Executions** in n8n
2. Find recent webhook executions
3. Check for errors

**Test directly**:
```bash
# Send test update to webhook
curl -X POST "https://your-n8n-domain.com/webhook/telegram-bot" \
  -H "Content-Type: application/json" \
  -d '{
    "update_id": 1,
    "message": {
      "message_id": 1,
      "from": {"id": 987654321, "first_name": "Test"},
      "chat": {"id": 987654321, "type": "private"},
      "text": "Test message"
    }
  }'
```

### Issue: Buttons not working

**Verify callback_query handling**:
- `allowed_updates` includes "callback_query"
- Intent classifier handles callback data format

**Debug callback**:
```bash
curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates"
```

Look for `callback_query` in response.

### Issue: Duplicate messages

**Symptom**: Bot processes same message multiple times

**Cause**: Idempotency check not working

**Solution**:
1. Verify `telegram_message_id` is unique in database
2. Check idempotency query in Workflow A
3. Clear pending updates:
   ```bash
   curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates?offset=-1"
   ```

---

## Step 9: Commands Reference

### Bot Commands

```
/start - Welcome message and introduction
/help - Usage instructions and examples
/status - Show pending drafts and recent tasks
```

### User Commands (Natural Language)

Examples:
```
Buy milk tomorrow
Submit report by Friday
Plan team meeting next week
Call dentist
Finish project proposal by end of month
```

---

## Step 10: Advanced Features (Future)

### 10.1 Rich Media

Support images for task creation:
```javascript
// Handle photo messages
if (message.photo) {
  const fileId = message.photo[message.photo.length - 1].file_id;
  // Download and process with Gemini Vision
}
```

### 10.2 Voice Messages

Transcribe voice to text:
```javascript
if (message.voice) {
  const fileId = message.voice.file_id;
  // Download, transcribe (Whisper API), process
}
```

### 10.3 Location-Based Reminders

```javascript
if (message.location) {
  const { latitude, longitude } = message.location;
  // Store location with task for geo-fencing
}
```

---

## Security Best Practices

1. **Never expose bot token** - Store in environment variables
2. **Use secret token** - Validate webhook requests
3. **Limit to known users** - Check `from.id` against whitelist
4. **Rate limiting** - Prevent spam/abuse
5. **Audit logging** - Track all interactions

---

## Reference Scripts

Save to `scripts/set-telegram-webhook.sh`:

```bash
#!/bin/bash
# Set Telegram webhook for AI Personal Assistant

# Configuration
BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
WEBHOOK_URL="${N8N_WEBHOOK_URL}/telegram-bot"

if [ -z "$BOT_TOKEN" ] || [ -z "$WEBHOOK_URL" ]; then
  echo "Error: TELEGRAM_BOT_TOKEN and N8N_WEBHOOK_URL must be set"
  exit 1
fi

# Set webhook
echo "Setting webhook to: $WEBHOOK_URL"

RESPONSE=$(curl -s -X POST \
  "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d "{
    \"url\": \"${WEBHOOK_URL}\",
    \"allowed_updates\": [\"message\", \"callback_query\"],
    \"drop_pending_updates\": true
  }")

echo "Response: $RESPONSE"

# Verify
echo -e "\nVerifying webhook..."
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo" | jq
```

---

## Resources

- [Telegram Bot API Documentation](https://core.telegram.org/bots/api)
- [BotFather Commands Reference](https://core.telegram.org/bots#botfather)
- [Webhook Guide](https://core.telegram.org/bots/webhooks)
- [n8n Telegram Node](https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.telegram/)
