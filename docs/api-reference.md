# API Reference

Complete reference for all external APIs used in the AI Personal Assistant Phase 1 MVP.

---

## Overview

The system integrates with three external APIs:
1. **Gemini AI API** - Natural language processing
2. **Telegram Bot API** - Chat interface
3. **Google Tasks API** - Task management

---

## 1. Gemini AI API

### Base URL
```
https://generativelanguage.googleapis.com/v1beta
```

### Authentication
API key passed as query parameter:
```
?key=YOUR_API_KEY
```

---

### 1.1 Generate Content

Generate text using Gemini models.

**Endpoint**:
```http
POST /models/{model}:generateContent
```

**Models**:
- `gemini-2.0-flash` - Fast, cost-effective (recommended)
- `gemini-pro` - Higher quality, slower

**Request Body**:
```json
{
  "contents": [
    {
      "parts": [
        {
          "text": "Your prompt here"
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.1,
    "topK": 40,
    "topP": 0.95,
    "maxOutputTokens": 1024,
    "responseMimeType": "application/json"
  },
  "safetySettings": [
    {
      "category": "HARM_CATEGORY_HARASSMENT",
      "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    }
  ]
}
```

**Response**:
```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "{\"intent\": \"draft_task\", ...}"
          }
        ],
        "role": "model"
      },
      "finishReason": "STOP",
      "index": 0,
      "safetyRatings": [...]
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 45,
    "candidatesTokenCount": 82,
    "totalTokenCount": 127
  }
}
```

**Example (Intent Classification)**:
```bash
curl -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [{
        "text": "Classify intent: Buy milk tomorrow"
      }]
    }],
    "generationConfig": {
      "temperature": 0.1,
      "responseMimeType": "application/json"
    }
  }'
```

---

### 1.2 Rate Limits

#### Free Tier
| Limit | Value |
|-------|-------|
| Requests per minute (RPM) | 15 |
| Tokens per minute (TPM) | 1,000,000 |
| Requests per day (RPD) | 1,500 |

#### Paid Tier (Pay-as-you-go)
| Limit | Value |
|-------|-------|
| Requests per minute | 360 |
| Tokens per minute | 4,000,000 |
| Requests per day | Unlimited |

**Pricing** (as of 2026):
- Input: $0.075 per 1M tokens
- Output: $0.30 per 1M tokens

---

### 1.3 Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 400 | Bad Request | Check JSON format |
| 403 | Forbidden | Verify API key, check quota |
| 429 | Rate Limit | Implement exponential backoff |
| 500 | Internal Error | Retry with backoff |

---

## 2. Telegram Bot API

### Base URL
```
https://api.telegram.org/bot{token}
```

### Authentication
Bot token in URL path.

---

### 2.1 setWebhook

Configure webhook for receiving updates.

**Endpoint**:
```http
POST /setWebhook
```

**Parameters**:
```json
{
  "url": "https://your-n8n-domain.com/webhook/telegram-bot",
  "allowed_updates": ["message", "callback_query"],
  "secret_token": "optional_secret_for_validation",
  "drop_pending_updates": true
}
```

**Response**:
```json
{
  "ok": true,
  "result": true,
  "description": "Webhook was set"
}
```

**Example**:
```bash
curl -X POST \
  "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://n8n.example.com/webhook/telegram-bot",
    "allowed_updates": ["message", "callback_query"]
  }'
```

---

### 2.2 getWebhookInfo

Check current webhook configuration.

**Endpoint**:
```http
GET /getWebhookInfo
```

**Response**:
```json
{
  "ok": true,
  "result": {
    "url": "https://n8n.example.com/webhook/telegram-bot",
    "has_custom_certificate": false,
    "pending_update_count": 0,
    "last_error_date": 1704153600,
    "last_error_message": "Error description",
    "max_connections": 40,
    "allowed_updates": ["message", "callback_query"]
  }
}
```

---

### 2.3 sendMessage

Send text message to user.

**Endpoint**:
```http
POST /sendMessage
```

**Parameters**:
```json
{
  "chat_id": 987654321,
  "text": "Your message here",
  "parse_mode": "Markdown",
  "reply_markup": {
    "inline_keyboard": [
      [
        {"text": "Button 1", "callback_data": "data1"},
        {"text": "Button 2", "callback_data": "data2"}
      ]
    ]
  }
}
```

**Response**:
```json
{
  "ok": true,
  "result": {
    "message_id": 123,
    "from": {...},
    "chat": {...},
    "date": 1704153600,
    "text": "Your message here"
  }
}
```

**Example (with buttons)**:
```bash
curl -X POST \
  "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
  -H "Content-Type: application/json" \
  -d '{
    "chat_id": 987654321,
    "text": "Task Draft:\n\nTitle: Buy milk",
    "reply_markup": {
      "inline_keyboard": [[
        {"text": "✅ Confirm", "callback_data": "confirm_draft:123"}
      ]]
    }
  }'
```

---

### 2.4 getUpdates

Manually fetch updates (alternative to webhook).

**Endpoint**:
```http
GET /getUpdates?offset={offset}&limit={limit}
```

**Parameters**:
- `offset`: Sequential update ID to start from
- `limit`: Number of updates to fetch (max 100)

**Response**:
```json
{
  "ok": true,
  "result": [
    {
      "update_id": 12345,
      "message": {
        "message_id": 1,
        "from": {
          "id": 987654321,
          "is_bot": false,
          "first_name": "John"
        },
        "chat": {
          "id": 987654321,
          "type": "private"
        },
        "text": "Buy milk"
      }
    }
  ]
}
```

**Use cases**:
- Get chat_id for initial setup
- Clear pending updates: `?offset=-1`

---

### 2.5 Webhook Update Structure

When webhook receives an update:

**Message Update**:
```json
{
  "update_id": 12345,
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
      "type": "private"
    },
    "date": 1704153600,
    "text": "Buy milk tomorrow"
  }
}
```

**Callback Query Update** (button press):
```json
{
  "update_id": 12346,
  "callback_query": {
    "id": "abc123",
    "from": {
      "id": 987654321,
      "first_name": "John"
    },
    "message": {
      "message_id": 2,
      "chat": {
        "id": 987654321
      }
    },
    "data": "confirm_draft:123"
  }
}
```

---

### 2.6 Rate Limits

| Limit | Value |
|-------|-------|
| Messages per second (per bot) | 30 |
| Messages per second (to same user) | 1 |
| Group messages per minute | 20 |

**Handling**: Telegram returns 429 with `retry_after` seconds.

---

### 2.7 Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 400 | Bad Request | Check parameter format |
| 401 | Unauthorized | Verify bot token |
| 403 | Forbidden | User blocked bot |
| 429 | Rate Limit | Wait retry_after seconds |

---

## 3. Google Tasks API

### Base URL
```
https://tasks.googleapis.com/tasks/v1
```

### Authentication
OAuth2 access token in Authorization header:
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

---

### 3.1 List Task Lists

Get all task lists for authenticated user.

**Endpoint**:
```http
GET /users/@me/lists
```

**Response**:
```json
{
  "kind": "tasks#taskLists",
  "items": [
    {
      "kind": "tasks#taskList",
      "id": "MDxxxxxxxxxx",
      "title": "My Tasks",
      "updated": "2026-02-02T10:00:00.000Z",
      "selfLink": "https://tasks.googleapis.com/tasks/v1/users/@me/lists/MDxxxxxxxxxx"
    }
  ]
}
```

**Note**: Use `@default` to reference the default task list.

---

### 3.2 Create Task

Create a new task in a task list.

**Endpoint**:
```http
POST /lists/{listId}/tasks
```

**Request Body**:
```json
{
  "title": "Buy groceries",
  "notes": "Weekly shopping\n\nCreated by AI Assistant",
  "due": "2026-02-03T00:00:00.000Z"
}
```

**Response**:
```json
{
  "kind": "tasks#task",
  "id": "abc123xyz",
  "etag": "\"LTE2Nzg5NDM2MA\"",
  "title": "Buy groceries",
  "updated": "2026-02-02T10:15:00.000Z",
  "selfLink": "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks/abc123xyz",
  "position": "00000000000000000001",
  "status": "needsAction",
  "due": "2026-02-03T00:00:00.000Z",
  "notes": "Weekly shopping\n\nCreated by AI Assistant"
}
```

**Example**:
```bash
curl -X POST \
  "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Buy groceries",
    "due": "2026-02-03T00:00:00.000Z",
    "notes": "Weekly shopping"
  }'
```

---

### 3.3 Create Subtask

Create a subtask (child task).

**Endpoint**:
```http
POST /lists/{listId}/tasks
```

**Request Body**:
```json
{
  "title": "Make shopping list [S]",
  "parent": "abc123xyz"
}
```

**Response**:
Same as Create Task, with `parent` field set.

**Note**: Subtasks are regular tasks with a `parent` field pointing to the main task ID.

---

### 3.4 Update Task

Update an existing task.

**Endpoint**:
```http
PATCH /lists/{listId}/tasks/{taskId}
```

**Request Body** (partial update):
```json
{
  "status": "completed"
}
```

**Response**:
Updated task object.

---

### 3.5 Delete Task

Delete a task.

**Endpoint**:
```http
DELETE /lists/{listId}/tasks/{taskId}
```

**Response**:
```
204 No Content
```

---

### 3.6 List Tasks

List all tasks in a task list.

**Endpoint**:
```http
GET /lists/{listId}/tasks
```

**Query Parameters**:
- `showCompleted`: boolean (default: true)
- `showDeleted`: boolean (default: false)
- `showHidden`: boolean (default: false)
- `updatedMin`: RFC 3339 timestamp (filter by update time)

**Response**:
```json
{
  "kind": "tasks#tasks",
  "items": [
    {
      "kind": "tasks#task",
      "id": "abc123",
      "title": "Buy groceries",
      "status": "needsAction",
      ...
    }
  ]
}
```

---

### 3.7 Task Object Schema

```typescript
interface Task {
  // Core fields
  id: string;              // Read-only
  title: string;           // Max 1024 chars
  notes?: string;          // Max 8192 chars
  status: 'needsAction' | 'completed';
  due?: string;            // RFC 3339 format
  parent?: string;         // Parent task ID (for subtasks)

  // Metadata (read-only)
  kind: 'tasks#task';
  etag: string;
  updated: string;         // RFC 3339
  selfLink: string;
  position: string;
  completed?: string;      // RFC 3339 (if status=completed)
  deleted?: boolean;
  hidden?: boolean;
}
```

---

### 3.8 Date Format

**RFC 3339 format**: `YYYY-MM-DDTHH:mm:ss.sssZ`

**Examples**:
```
2026-02-03T00:00:00.000Z  # Midnight UTC on Feb 3, 2026
2026-02-03T14:30:00.000Z  # 2:30 PM UTC
```

**Important**: Google Tasks only uses the date portion; time is ignored for `due` field.

---

### 3.9 Rate Limits

| Limit | Value |
|-------|-------|
| Queries per day | 50,000 |
| Queries per 100 seconds per user | 2,500 |
| Queries per second per user | 25 |

**Quotas**: Can be increased in Google Cloud Console.

---

### 3.10 Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 400 | Bad Request | Check request format |
| 401 | Unauthorized | Refresh OAuth token |
| 403 | Forbidden | Check API enabled, quota |
| 404 | Not Found | Verify task/list ID |
| 429 | Rate Limit | Implement exponential backoff |

**Error Response**:
```json
{
  "error": {
    "code": 401,
    "message": "Request had invalid authentication credentials.",
    "status": "UNAUTHENTICATED"
  }
}
```

---

## 4. API Usage Patterns

### 4.1 Exponential Backoff

For handling rate limits:

```javascript
async function apiCallWithRetry(fn, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (error.statusCode === 429 || error.statusCode >= 500) {
        const delay = Math.pow(2, i) * 1000; // 1s, 2s, 4s
        await new Promise(r => setTimeout(r, delay));
        continue;
      }
      throw error;
    }
  }
  throw new Error('Max retries exceeded');
}
```

---

### 4.2 Batch Operations

**Google Tasks API** supports batch requests:

```http
POST https://tasks.googleapis.com/batch
Content-Type: multipart/mixed; boundary=batch_boundary

--batch_boundary
Content-Type: application/http

POST /tasks/v1/lists/@default/tasks
Content-Type: application/json

{"title": "Task 1"}

--batch_boundary
Content-Type: application/http

POST /tasks/v1/lists/@default/tasks
Content-Type: application/json

{"title": "Task 2"}

--batch_boundary--
```

**Note**: Not implemented in Phase 1 MVP, but useful for future optimization.

---

### 4.3 Caching Strategy

**Recommended**:
- Task list IDs: Cache for 24 hours (rarely change)
- User preferences: Cache for session
- OAuth tokens: Refresh before expiry

**Not recommended**:
- Task content (should always be fresh)

---

## 5. Quota Management

### 5.1 Monitoring

**Gemini API**:
```bash
# Check usage in Google Cloud Console
https://console.cloud.google.com/apis/api/generativelanguage.googleapis.com/quotas
```

**Google Tasks API**:
```bash
https://console.cloud.google.com/apis/api/tasks.googleapis.com/quotas
```

**Telegram**: No quota dashboard; monitor via error responses.

---

### 5.2 Cost Estimation

**Gemini AI** (Free tier):
- 1,500 requests/day
- Avg 100 tokens/request = 150K tokens/day
- Free tier: 1M tokens/day
- **Cost**: $0/day (within free tier)

**Paid tier** (if exceed free):
- 100 requests/day × 100 tokens = 10K tokens
- Input: 10K × $0.075/1M = $0.00075/day
- Output: 20K × $0.30/1M = $0.006/day
- **Total**: ~$0.007/day = $2.50/year

**Google Tasks API**: Free (no charges)

**Telegram Bot API**: Free

---

## 6. Testing APIs

### 6.1 Test Scripts

**Gemini API**:
```bash
./tests/test-gemini-api.sh
```

**Telegram API**:
```bash
./tests/test-telegram-api.sh
```

**Google Tasks API**:
```bash
./tests/test-google-tasks-api.sh
```

---

### 6.2 Postman Collection

Import API collection for testing:
```
/tests/postman-collection.json
```

---

## 7. API Versioning

| API | Current Version | Status |
|-----|-----------------|--------|
| Gemini AI | v1beta | Beta (stable) |
| Telegram Bot | Latest | Stable |
| Google Tasks | v1 | Stable |

**Migration plan**: Monitor for deprecation notices, update before EOL.

---

## Resources

- [Gemini AI Documentation](https://ai.google.dev/docs)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Google Tasks API](https://developers.google.com/tasks)
- [OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)
