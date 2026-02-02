# System Architecture

Comprehensive architecture documentation for the AI Personal Assistant Phase 1 MVP.

---

## Table of Contents

1. [Overview](#overview)
2. [Design Principles](#design-principles)
3. [System Components](#system-components)
4. [Data Flow](#data-flow)
5. [Database Schema](#database-schema)
6. [Workflow Architecture](#workflow-architecture)
7. [API Integration](#api-integration)
8. [Security Architecture](#security-architecture)
9. [Scalability Considerations](#scalability-considerations)

---

## Overview

### System Purpose

The AI Personal Assistant is a **draft-first task management system** that:
- Accepts natural language task requests via Telegram
- Uses AI to structure tasks with smart suggestions
- Requires explicit user confirmation before creating tasks
- Integrates with Google Tasks for task management

### Key Characteristics

- **Command-based** (not autonomous tool execution)
- **Deterministic** workflows (predictable, debuggable)
- **Asynchronous** processing via command queue
- **Fully audited** for compliance and debugging

---

## Design Principles

### 1. Draft-First Execution

**Principle**: Nothing is committed without user confirmation.

**Implementation**:
```
User Input → AI Processing → Draft Creation → User Confirmation → Execution
```

**Rationale**: Prevents unintended calendar/task modifications, builds user trust.

---

### 2. Command Queue Pattern

**Principle**: Separate intent capture from execution.

**Benefits**:
- Decouples Telegram webhook from processing
- Enables retry logic
- Provides audit trail
- Handles rate limiting naturally

**Alternative Considered**: Direct execution on webhook
- **Rejected**: Too brittle, no retry mechanism, hard to debug

---

### 3. Idempotent Operations

**Principle**: Duplicate requests have no additional effect.

**Implementation**:
- Telegram message_id stored in command payload
- Database check before creating command
- Prevents double-processing on network retries

---

### 4. Explicit Over Implicit

**Principle**: AI suggests but doesn't assume.

**Examples**:
- Clarification questions when ambiguous
- `due_date_reasoning` explains suggested dates
- Subtasks marked as "suggested"

---

## System Components

### High-Level Architecture

```
┌─────────────┐
│   Telegram  │
│     Bot     │
└──────┬──────┘
       │ Webhook (HTTPS)
       ▼
┌─────────────────────────────────────────────┐
│              n8n Workflows                  │
│  ┌─────────────────────────────────────┐   │
│  │  Workflow A: Inbound Router         │   │
│  │  • Webhook receiver                 │   │
│  │  • Gemini intent classification     │   │
│  │  • Command queue insertion          │   │
│  └─────────────────────────────────────┘   │
│                    │                        │
│                    ▼                        │
│  ┌─────────────────────────────────────┐   │
│  │  Workflow B: Command Executor       │   │
│  │  • Polls command queue (10s)        │   │
│  │  • Routes by command type           │   │
│  │  • Updates command status           │   │
│  └─────────────────────────────────────┘   │
│            │              │                 │
│            ▼              ▼                 │
│  ┌─────────────┐   ┌──────────────┐        │
│  │ Workflow D: │   │ Workflow E:  │        │
│  │Task Drafting│   │Confirmation  │        │
│  └─────────────┘   └──────────────┘        │
└─────────────────────────────────────────────┘
       │                        │
       │                        ▼
       │              ┌──────────────────┐
       │              │  Google Tasks    │
       │              │      API         │
       │              └──────────────────┘
       ▼
┌─────────────┐
│   SQLite    │
│  Database   │
└─────────────┘
```

---

### Component Descriptions

#### 1. Telegram Bot
- **Role**: User interface
- **Responsibilities**:
  - Receive user messages
  - Send responses and drafts
  - Handle button presses (inline keyboard)
- **Integration**: Webhook to n8n

#### 2. n8n Workflow Engine
- **Role**: Orchestration layer
- **Responsibilities**:
  - Process webhooks
  - Execute workflows
  - Manage credentials
  - Retry failed operations
- **Technology**: Self-hosted n8n instance

#### 3. Gemini AI
- **Role**: Natural language processing
- **Responsibilities**:
  - Intent classification (Extractor mode, temp 0.1)
  - Task structuring (Planner mode, temp 0.3)
- **Model**: Gemini 2.0 Flash

#### 4. SQLite Database
- **Role**: Data persistence and queue management
- **Responsibilities**:
  - Store commands, drafts, executions
  - Maintain audit log
  - Provide views for common queries
- **Future**: Migrate to PostgreSQL for multi-user

#### 5. Google Tasks API
- **Role**: Task backend
- **Responsibilities**:
  - Store tasks and subtasks
  - Sync across devices
  - Provide task completion tracking
- **Authentication**: OAuth2

---

## Data Flow

### 1. Message Receipt Flow

```
┌─────────┐
│  User   │
│ sends   │
│"Buy milk"
└────┬────┘
     │
     ▼
┌──────────────────┐
│ Telegram Webhook │
│  (Workflow A)    │
└────┬─────────────┘
     │
     ├─► Extract: message_id, chat_id, text
     │
     ├─► Idempotency Check
     │   SELECT FROM commands WHERE message_id = ...
     │   └─► If exists: Return "Already processing"
     │
     ├─► Gemini Intent Classification
     │   POST /generateContent
     │   └─► Returns: {intent, parameters, confidence}
     │
     ├─► Insert Command
     │   INSERT INTO commands (type, payload_json, status='pending')
     │
     ├─► Audit Log
     │   INSERT INTO audit_log (action='command_created')
     │
     └─► Telegram Response
         "Got it! Working on it... ⚙️"
```

---

### 2. Command Processing Flow

```
┌────────────────────┐
│ Workflow B (Cron)  │
│ Every 10 seconds   │
└────┬───────────────┘
     │
     ▼
SELECT * FROM commands WHERE status='pending' LIMIT 1
     │
     ├─► If no command: Sleep until next cron
     │
     ▼
UPDATE commands SET status='processing'
     │
     ▼
Switch by command.type:
     │
     ├─► 'draft_task_from_text' → Workflow D
     ├─► 'confirm_draft' → Workflow E
     ├─► 'cancel_draft' → Cancel handler
     └─► 'unknown' → Error response
     │
     ▼
UPDATE commands SET status='completed' or 'failed'
     │
     ▼
INSERT INTO audit_log (action='command_executed')
```

---

### 3. Draft Creation Flow (Workflow D)

```
┌─────────────────┐
│  Workflow D     │
│  (Sub-workflow) │
└────┬────────────┘
     │
     ├─► Extract: task_description, due_date, priority
     │
     ├─► Build Gemini Prompt (Planner mode)
     │   • Include current date for context
     │   • Request structured output with subtasks
     │
     ├─► Gemini Task Structuring
     │   POST /generateContent (temp 0.3)
     │   └─► Returns: {title, due_date, notes, subtasks, clarification}
     │
     ├─► Check: clarification_needed?
     │   └─► If yes: Send question, exit
     │
     ├─► Insert Draft
     │   INSERT INTO drafts (user_id, draft_type='task', draft_json, status='drafted')
     │
     ├─► Format Confirmation Message
     │   📝 Task Draft:
     │   Title: ...
     │   Due: ...
     │   Subtasks: ...
     │
     ├─► Send to Telegram with Inline Keyboard
     │   [✅ Confirm] [✏️ Edit] [❌ Cancel]
     │
     └─► Audit Log
         INSERT INTO audit_log (action='draft_created')
```

---

### 4. Confirmation & Execution Flow (Workflow E)

```
┌──────────────────┐
│   Workflow E     │
│  (Sub-workflow)  │
└────┬─────────────┘
     │
     ├─► Extract draft_id from callback_data
     │
     ├─► Fetch Draft
     │   SELECT * FROM drafts WHERE id=draft_id AND status='drafted'
     │
     ├─► Update Draft Status
     │   UPDATE drafts SET status='confirmed'
     │
     ├─► Validate Draft
     │   • Title not empty
     │   • Due date format valid
     │   • Title length < 1024 chars
     │
     ├─► Build Google Tasks Request
     │   {
     │     "title": "...",
     │     "due": "YYYY-MM-DDTHH:mm:ss.sssZ",
     │     "notes": "..."
     │   }
     │
     ├─► Create Main Task
     │   POST /tasks/v1/lists/@default/tasks
     │   └─► Returns: {id, title, selfLink, ...}
     │
     ├─► Loop: Create Subtasks
     │   For each subtask:
     │     POST /tasks/v1/lists/@default/tasks
     │     {
     │       "title": "...",
     │       "parent": main_task_id
     │     }
     │
     ├─► Record Execution
     │   INSERT INTO executions (draft_id, result_json, status='success')
     │
     ├─► Update Draft Status
     │   UPDATE drafts SET status='executed'
     │
     ├─► Send Success Message
     │   "✅ Task created successfully!"
     │
     └─► Audit Log
         INSERT INTO audit_log (action='task_executed')
```

---

## Database Schema

### Entity-Relationship Diagram

```
┌─────────────┐
│    users    │
│─────────────│
│ user_id PK  │
│ channel     │
│ timezone    │◄───────┐
│telegram_chat│        │
└─────────────┘        │
                       │
                       │ FK
                       │
┌─────────────┐        │
│  commands   │        │
│─────────────│        │
│ id PK       │        │
│ user_id FK  ├────────┘
│ type        │
│ payload_json│ Contains: telegram_message_id
│ status      │
│ created_at  │
│ updated_at  │
└─────────────┘
        │
        │ Linked via source_message_id
        │
        ▼
┌─────────────┐
│   drafts    │
│─────────────│
│ id PK       │◄───────┐
│ user_id FK  │        │
│ draft_type  │        │
│ draft_json  │        │ FK
│ status      │        │
│source_msg_id│        │
│ created_at  │        │
└─────────────┘        │
                       │
                       │
┌─────────────┐        │
│ executions  │        │
│─────────────│        │
│ id PK       │        │
│ draft_id FK ├────────┘
│ result_json │
│ status      │
│ executed_at │
│error_message│
└─────────────┘

┌─────────────┐
│ audit_log   │
│─────────────│
│ id PK       │
│ timestamp   │
│ action      │
│ entity_type │
│ entity_id   │
│source_msg_id│
│ details_json│
└─────────────┘
```

### Table Relationships

1. **users → commands**: One-to-many (user can have multiple commands)
2. **commands → drafts**: One-to-many (via source_message_id)
3. **drafts → executions**: One-to-many (draft can have multiple execution attempts)
4. **audit_log**: Standalone (references entities via entity_type + entity_id)

---

## Workflow Architecture

### Workflow Execution Model

**Pattern**: Sub-workflow invocation

```
Workflow A (Trigger: Webhook)
└─► Creates command

Workflow B (Trigger: Cron)
├─► Polls queue
├─► Routes to sub-workflows
│   ├─► Workflow D (Execute Workflow node)
│   └─► Workflow E (Execute Workflow node)
└─► Updates status
```

**Benefits**:
- Modular design
- Independent testing
- Easy to extend

**Drawbacks**:
- Workflow IDs must be configured
- Sub-workflows must return results

---

### State Machine

#### Command States

```
┌─────────┐
│ pending │
└────┬────┘
     │
     ▼
┌────────────┐
│ processing │
└────┬───┬───┘
     │   │
     ▼   ▼
┌────────┐  ┌────────┐
│completed│  │ failed │
└────────┘  └────────┘
```

#### Draft States

```
┌─────────┐
│ drafted │
└────┬────┘
     │
     ├─────► ┌───────────┐
     │       │ confirmed │
     │       └─────┬─────┘
     │             │
     │             ▼
     │       ┌──────────┐
     │       │ executed │
     │       └──────────┘
     │
     └─────► ┌───────────┐
             │ cancelled │
             └───────────┘
```

---

## API Integration

### External APIs Used

#### 1. Gemini AI API

**Endpoints**:
```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent
```

**Authentication**: API key (query parameter)

**Rate Limits**:
- Free: 15 RPM, 1,500 RPD
- Paid: 360 RPM, unlimited

**Usage**:
- Intent classification: ~50 tokens/request
- Task structuring: ~200 tokens/request

---

#### 2. Telegram Bot API

**Endpoints**:
```
POST https://api.telegram.org/bot<token>/sendMessage
POST https://api.telegram.org/bot<token>/setWebhook
GET  https://api.telegram.org/bot<token>/getWebhookInfo
```

**Authentication**: Bot token (URL path)

**Rate Limits**:
- 30 messages/second per bot
- 1 message/second to same user

**Usage**:
- Send messages
- Inline keyboards
- Webhook configuration

---

#### 3. Google Tasks API

**Endpoints**:
```
GET  https://tasks.googleapis.com/tasks/v1/users/@me/lists
POST https://tasks.googleapis.com/tasks/v1/lists/{listId}/tasks
GET  https://tasks.googleapis.com/tasks/v1/lists/{listId}/tasks
```

**Authentication**: OAuth2 (Access token in Authorization header)

**Rate Limits**:
- 50,000 queries/day
- 2,500 queries/100 seconds

**Usage**:
- Create tasks
- Create subtasks
- List tasks (future)

---

## Security Architecture

### Authentication & Authorization

```
┌──────────────┐
│  Telegram    │
│  Webhook     │
└──────┬───────┘
       │
       ├─► Optional: Verify X-Telegram-Bot-Api-Secret-Token header
       │
       ▼
┌──────────────────┐
│  n8n Workflow    │
│  (Internal)      │
└──────┬───────────┘
       │
       ├─► Gemini API: API key in query param
       ├─► Google Tasks: OAuth2 access token
       └─► Database: File system permissions
```

### Data Security

**At Rest**:
- Database file: 660 permissions (owner + group read/write)
- Credentials: n8n encrypted storage
- Backups: Encrypted with SQLCipher (optional)

**In Transit**:
- All APIs: HTTPS only
- Telegram webhook: HTTPS required
- n8n: HTTPS with valid certificate

**PII Handling**:
- Telegram chat_id: Stored in users table
- Message text: Stored in audit_log (consider retention policy)
- Task content: Stored in Google Tasks (user's Google account)

---

## Scalability Considerations

### Current Limitations (Phase 1 MVP)

1. **Single user**: Hardcoded to `default_user`
2. **SQLite**: No concurrent writes
3. **Polling**: 10-second granularity
4. **No caching**: Every request hits APIs

### Scaling Paths

#### For 10-100 Users

**Changes needed**:
1. Multi-user support: Remove `default_user` assumption
2. PostgreSQL: Replace SQLite
3. Rate limiting: Per-user quotas
4. Monitoring: Track API usage

**Architecture**:
```
Same workflow design, just swap database
```

---

#### For 100-1000 Users

**Additional changes**:
1. Redis queue: Replace polling with pub/sub
2. Horizontal scaling: Multiple n8n workers
3. Caching: Redis for user preferences, task lists
4. Background jobs: Celery or similar for long-running tasks

**Architecture**:
```
Load Balancer
    │
    ├─► n8n Worker 1 ──┐
    ├─► n8n Worker 2 ──┼─► PostgreSQL
    └─► n8n Worker 3 ──┘
          │
          └─► Redis (Queue + Cache)
```

---

#### For 1000+ Users

**Major redesign**:
1. Custom backend: Node.js/Python service
2. n8n for admin workflows only
3. Event-driven architecture: Kafka or RabbitMQ
4. Microservices: Separate intent classification, execution, notification services

---

## Deployment Architecture

### Recommended Setup (Phase 1)

```
┌─────────────────────────────────────┐
│      AWS Lightsail / VPS            │
│                                     │
│  ┌────────────────────────────┐    │
│  │   Nginx (Reverse Proxy)    │    │
│  │   • HTTPS termination      │    │
│  │   • Rate limiting          │    │
│  └────────────┬───────────────┘    │
│               │                     │
│               ▼                     │
│  ┌────────────────────────────┐    │
│  │   n8n (Port 5678)          │    │
│  │   • Workflows              │    │
│  │   • Credential storage     │    │
│  └────────────┬───────────────┘    │
│               │                     │
│               ▼                     │
│  ┌────────────────────────────┐    │
│  │   SQLite Database          │    │
│  │   /home/n8n/data/          │    │
│  └────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
         │              │
         │              └─► Daily backup to S3
         │
         └─► Webhook from Telegram
```

---

## Future Enhancements

### Phase 2: Calendar Integration

**New workflows**:
- Workflow C: Event drafting
- Google Calendar API integration
- Conflict detection

**Database changes**:
- New command types: `draft_event_from_text`, `draft_event_from_url`
- Draft type: 'event'

---

### Phase 3: Advanced Features

**New workflows**:
- Workflow F: Daily briefing
- Workflow G: Reminder checker
- Image parsing with Gemini Vision

**Infrastructure changes**:
- Cron jobs for scheduled notifications
- WebSocket for real-time updates (future)

---

## Monitoring & Observability

### Metrics to Track

1. **Command processing**:
   - Commands/minute
   - Average processing time
   - Success vs failure rate

2. **API usage**:
   - Gemini API calls/day
   - Google Tasks API calls/day
   - Rate limit proximity

3. **Database**:
   - Database size growth
   - Query performance
   - Lock contention

### Logging Strategy

**n8n execution logs**: Retain 30 days

**Database audit_log**: Retain 90 days

**Application logs**: stderr → journalctl

---

## Disaster Recovery

### Backup Strategy

1. **Database**: Daily automatic backups to S3
2. **Workflows**: Export JSON, commit to git
3. **Credentials**: Document (without values) in credentials-setup.md

### Recovery Procedures

1. **Database corruption**: Restore from backup
2. **Workflow deleted**: Re-import from git
3. **API key revoked**: Regenerate, update credential
4. **Server failure**: Provision new server, restore from backups

**RTO (Recovery Time Objective)**: 1 hour
**RPO (Recovery Point Objective)**: 24 hours (daily backups)

---

## Conclusion

This architecture prioritizes:
1. **Reliability**: Command queue, retries, audit trail
2. **Debuggability**: Comprehensive logging and database state
3. **User trust**: Draft-first confirmation flow
4. **Maintainability**: Modular workflows, clear data flow

Future phases will build on this foundation while maintaining these principles.
