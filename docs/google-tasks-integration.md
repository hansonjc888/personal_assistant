# Google Tasks API Integration Guide

Complete guide for integrating Google Tasks API with n8n workflows.

---

## Overview

The AI Personal Assistant creates tasks in Google Tasks using OAuth2 authentication. This guide covers setup, API usage, and troubleshooting.

---

## Prerequisites

- Google Cloud Console project
- Google Tasks API enabled
- OAuth 2.0 credentials created
- n8n instance with HTTPS (required for OAuth callback)

---

## Step 1: Google Cloud Setup

### 1.1 Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click **Create Project**
3. Name: `AI Personal Assistant`
4. Click **Create**

### 1.2 Enable Google Tasks API

1. In project dashboard, go to **APIs & Services** → **Library**
2. Search for "Google Tasks API"
3. Click **Google Tasks API**
4. Click **Enable**

### 1.3 Configure OAuth Consent Screen

1. Go to **APIs & Services** → **OAuth consent screen**
2. Select **External** (or Internal if Google Workspace)
3. Fill in required fields:
   - **App name**: AI Personal Assistant
   - **User support email**: your-email@example.com
   - **Developer contact**: your-email@example.com
4. Click **Save and Continue**
5. Add scopes:
   - Click **Add or Remove Scopes**
   - Search for "Google Tasks API"
   - Select: `https://www.googleapis.com/auth/tasks`
6. Click **Save and Continue**
7. Add test users (your email)
8. Click **Save and Continue**

### 1.4 Create OAuth 2.0 Credentials

1. Go to **APIs & Services** → **Credentials**
2. Click **+ Create Credentials** → **OAuth client ID**
3. Application type: **Web application**
4. Name: `n8n Integration`
5. Authorized redirect URIs:
   - Add: `https://your-n8n-domain.com/rest/oauth2-credential/callback`
6. Click **Create**
7. **Save** the Client ID and Client Secret

---

## Step 2: n8n OAuth Configuration

### 2.1 Add Google Tasks Credential

1. In n8n, go to **Settings** → **Credentials**
2. Click **+ Add Credential**
3. Select **Google Tasks OAuth2 API**
4. Fill in:
   - **Name**: `Google Tasks`
   - **Client ID**: (from Step 1.4)
   - **Client Secret**: (from Step 1.4)
   - **Scope**: `https://www.googleapis.com/auth/tasks`
5. Click **Connect my account**
6. Sign in with Google
7. Grant permissions
8. Verify "Connected" status

### 2.2 Test Credential

Create a test workflow:

```json
{
  "nodes": [
    {
      "name": "List Task Lists",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "https://tasks.googleapis.com/tasks/v1/users/@me/lists",
        "authentication": "predefinedCredentialType",
        "nodeCredentialType": "googleTasksOAuth2Api"
      },
      "credentials": {
        "googleTasksOAuth2Api": {
          "name": "Google Tasks"
        }
      }
    }
  ]
}
```

Expected result: List of task lists including "@default".

---

## Step 3: API Usage Reference

### 3.1 Get Default Task List ID

```http
GET https://tasks.googleapis.com/tasks/v1/users/@me/lists
```

Response:
```json
{
  "items": [
    {
      "id": "MDxxxxxxxxxx",
      "title": "My Tasks",
      "updated": "2026-02-02T10:00:00.000Z"
    }
  ]
}
```

**Note**: Use `@default` as shorthand for default list.

### 3.2 Create Task

```http
POST https://tasks.googleapis.com/tasks/v1/lists/@default/tasks
Content-Type: application/json

{
  "title": "Buy groceries",
  "notes": "Weekly shopping\n\nCreated by AI Assistant",
  "due": "2026-02-03T00:00:00.000Z"
}
```

Response:
```json
{
  "id": "abc123xyz",
  "title": "Buy groceries",
  "notes": "Weekly shopping\n\nCreated by AI Assistant",
  "due": "2026-02-03T00:00:00.000Z",
  "updated": "2026-02-02T10:15:00.000Z",
  "selfLink": "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks/abc123xyz",
  "status": "needsAction"
}
```

### 3.3 Create Subtask

```http
POST https://tasks.googleapis.com/tasks/v1/lists/@default/tasks
Content-Type: application/json

{
  "title": "Make shopping list [S]",
  "parent": "abc123xyz"
}
```

**Important**: Subtasks are created as separate tasks with a `parent` field.

### 3.4 Update Task

```http
PATCH https://tasks.googleapis.com/tasks/v1/lists/@default/tasks/abc123xyz
Content-Type: application/json

{
  "status": "completed"
}
```

### 3.5 Delete Task

```http
DELETE https://tasks.googleapis.com/tasks/v1/lists/@default/tasks/abc123xyz
```

---

## Step 4: n8n Workflow Integration

### 4.1 Create Main Task Node

```json
{
  "name": "Create Main Task",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks",
    "method": "POST",
    "authentication": "predefinedCredentialType",
    "nodeCredentialType": "googleTasksOAuth2Api",
    "sendBody": true,
    "contentType": "application/json",
    "body": "={{ JSON.stringify($json.task_request) }}"
  },
  "credentials": {
    "googleTasksOAuth2Api": {
      "name": "Google Tasks"
    }
  }
}
```

### 4.2 Create Subtask Loop

```json
{
  "name": "Create Subtask",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks",
    "method": "POST",
    "authentication": "predefinedCredentialType",
    "nodeCredentialType": "googleTasksOAuth2Api",
    "sendBody": true,
    "contentType": "application/json",
    "body": "={{ JSON.stringify({title: $json.subtask_title, parent: $json.main_task_id}) }}"
  }
}
```

---

## Step 5: Data Format Specifications

### 5.1 Task Object Schema

```typescript
interface Task {
  // Required
  title: string;  // Max 1024 chars

  // Optional
  notes?: string;  // Max 8192 chars
  due?: string;    // RFC 3339 format (YYYY-MM-DDTHH:mm:ss.sssZ)
  parent?: string; // Parent task ID (for subtasks)

  // Read-only (returned by API)
  id?: string;
  status?: 'needsAction' | 'completed';
  updated?: string;
  selfLink?: string;
  position?: string;
  completed?: string;
}
```

### 5.2 Due Date Format

**Format**: RFC 3339 timestamp

**Examples**:
```javascript
// Today at midnight UTC
"2026-02-02T00:00:00.000Z"

// Specific time
"2026-02-02T14:30:00.000Z"

// Different timezone (converts to UTC)
"2026-02-02T09:00:00-05:00"  // 9 AM EST = 14:00 UTC
```

**Important**: Google Tasks only uses the date component; time is ignored for due dates.

### 5.3 Notes Format

```
{notes_content}

Due date reasoning: {reasoning}

Created by AI Assistant
```

**Markdown support**: None (plain text only)

---

## Step 6: Error Handling

### 6.1 Common Errors

#### 401 Unauthorized

**Cause**: OAuth token expired or invalid.

**Solution**:
1. Re-authenticate in n8n credentials
2. Verify scopes include `https://www.googleapis.com/auth/tasks`

#### 403 Forbidden

**Cause**: API not enabled or quota exceeded.

**Solution**:
1. Verify Google Tasks API is enabled
2. Check quota: [Google Cloud Console](https://console.cloud.google.com/apis/api/tasks.googleapis.com/quotas)

#### 404 Not Found

**Cause**: Task or list ID doesn't exist.

**Solution**:
- Verify using `@default` for default task list
- Check task ID is valid

#### 400 Bad Request

**Cause**: Invalid request format.

**Solution**:
- Validate JSON structure
- Check due date is RFC 3339 format
- Ensure title is not empty

### 6.2 Retry Logic

```javascript
// In n8n Code node
const maxRetries = 3;
let retries = 0;
let success = false;

while (retries < maxRetries && !success) {
  try {
    // Attempt API call
    success = true;
  } catch (error) {
    if (error.statusCode === 401) {
      // Re-auth needed, don't retry
      throw error;
    }
    retries++;
    if (retries >= maxRetries) throw error;

    // Exponential backoff
    await new Promise(r => setTimeout(r, 1000 * Math.pow(2, retries)));
  }
}
```

---

## Step 7: Rate Limits & Quotas

### 7.1 Default Quotas

| Limit Type | Value |
|------------|-------|
| Queries per day | 50,000 |
| Queries per 100 seconds per user | 2,500 |
| Queries per second per user | 25 |

**Note**: These are default; can be increased in Google Cloud Console.

### 7.2 Best Practices

- **Batch operations**: Group subtask creation
- **Caching**: Store task list IDs (rarely change)
- **Exponential backoff**: For 429 (rate limit) errors
- **Avoid polling**: Use webhooks when available (limited for Tasks API)

---

## Step 8: Testing

### 8.1 Manual API Testing

Use curl or Postman:

```bash
# Get access token from n8n credential
# Then test API

curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  https://tasks.googleapis.com/tasks/v1/users/@me/lists
```

### 8.2 n8n Test Scenarios

1. **Create simple task**
   ```json
   {
     "title": "Test task",
     "notes": "Testing API"
   }
   ```

2. **Create task with due date**
   ```json
   {
     "title": "Task with deadline",
     "due": "2026-02-10T00:00:00.000Z"
   }
   ```

3. **Create task with subtasks**
   - Create main task (get ID)
   - Create subtasks with `parent` field

4. **Handle errors**
   - Try invalid task ID
   - Verify error handling in workflow

---

## Step 9: Advanced Features (Future)

### 9.1 Task Lists

Create separate lists for different contexts:

```http
POST https://tasks.googleapis.com/tasks/v1/users/@me/lists
Content-Type: application/json

{
  "title": "Work Tasks"
}
```

### 9.2 Task Completion

Mark tasks as complete:

```http
PATCH https://tasks.googleapis.com/tasks/v1/lists/@default/tasks/abc123xyz
Content-Type: application/json

{
  "status": "completed"
}
```

### 9.3 Recurring Tasks

**Not natively supported** - implement in workflow:
1. Store recurring rule in draft metadata
2. On completion, create new instance
3. Update due date based on recurrence

---

## Troubleshooting

### OAuth Token Refresh Issues

**Symptom**: Intermittent 401 errors

**Solution**:
```bash
# In n8n credentials, re-authenticate
# Ensure offline_access is granted
```

### Subtasks Not Showing

**Symptom**: Subtasks created but not visible

**Solution**:
- Verify `parent` field matches main task ID
- Check task list is correct
- Refresh Google Tasks app

### Due Dates Not Showing Correctly

**Symptom**: Due date appears one day off

**Solution**:
- Use `T00:00:00.000Z` for midnight UTC
- Google Tasks interprets based on user timezone

---

## Reference Links

- [Google Tasks API Documentation](https://developers.google.com/tasks)
- [OAuth 2.0 Setup Guide](https://developers.google.com/identity/protocols/oauth2)
- [n8n Google Tasks Node](https://docs.n8n.io/integrations/builtin/credentials/google/)

---

## Security Notes

- **Never commit** Client ID/Secret to version control
- **Store credentials** in n8n's encrypted storage
- **Minimize scope**: Only use `tasks` scope
- **Audit access**: Review OAuth consent periodically
- **Rotate credentials**: If compromised, revoke and regenerate

---

## Appendix: Complete API Reference

### Endpoints Used

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/tasks/v1/users/@me/lists` | List task lists |
| POST | `/tasks/v1/lists/{listId}/tasks` | Create task |
| PATCH | `/tasks/v1/lists/{listId}/tasks/{taskId}` | Update task |
| DELETE | `/tasks/v1/lists/{listId}/tasks/{taskId}` | Delete task |
| GET | `/tasks/v1/lists/{listId}/tasks` | List tasks |
| GET | `/tasks/v1/lists/{listId}/tasks/{taskId}` | Get task details |

### Special Values

- **@default**: Default task list
- **@me**: Current authenticated user
