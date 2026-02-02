# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an **AI Personal Assistant Chatbot** that manages schedules, tasks, and reminders through a chat interface. The system uses n8n as the orchestration layer (self-hosted on AWS Lightsail) rather than a custom backend.

**Critical Design Principle**: Draft-first execution — nothing is committed to calendar or tasks without user confirmation.

## Architecture

### Command-Based Model (Not Tool-Based Agentic)

The LLM does **not** directly execute tools. Instead:
1. LLM outputs strict JSON intent
2. Intent becomes a **command** stored in database
3. Deterministic n8n workflows execute the command

This ensures predictability and debuggability over autonomy.

### Core Workflows

The system is built around 7 main n8n workflows:

- **Workflow A (Inbound Router)**: Webhook → Intent Classification → Command Queue
- **Workflow B (Command Executor)**: Cron-triggered processor that switches by command type
- **Workflow C (Schedule Drafting)**: Parses text/URL/images → draft events
- **Workflow D (Task Drafting)**: Creates task drafts with suggestions
- **Workflow E (Confirmation & Execution)**: Validates drafts → creates calendar/task entries
- **Workflow F (Daily Briefing)**: Scheduled summary of agenda + tasks
- **Workflow G (Reminder Checker)**: Periodic reminder notifications

### Data Flow

```
Chat (Telegram) → Inbound Router → Intent Classification (Gemini)
                                           ↓
                                    Command Queue (DB)
                                           ↓
                                   Command Executor
                                           ↓
                            Draft Storage → Confirmation → Execution
                                           ↓
                                Calendar / Tasks (Google)
```

## Technology Stack

- **Platform**: n8n (self-hosted), AWS Lightsail
- **AI**: Gemini API (Flash for extraction, Pro for planning)
- **Chat**: Telegram (Phase 1), WhatsApp (Phase 2)
- **Calendar**: Google Calendar (write), Apple Calendar (sync only)
- **Tasks**: Google Tasks
- **Database**: PostgreSQL preferred, SQLite for MVP

## Data Model

### Core Tables

**commands**
- Stores pending/processing/completed commands
- Fields: id, user_id, type, payload_json, status, created_at

**drafts**
- Stores event/task drafts awaiting confirmation
- Fields: id, user_id, draft_type (event|task), draft_json, status, source_message_id
- Status: drafted → confirmed → executed (or cancelled)

**executions**
- Audit trail of executed drafts
- Fields: id, draft_id, result_json, status

**users**
- User profiles with timezone
- Fields: user_id, channel, timezone

**audit_log**
- Full action history for debugging

## Command Types

Initial set:
- `draft_event_from_text`
- `draft_event_from_url`
- `draft_event_from_image`
- `draft_task_from_text`
- `edit_draft`
- `confirm_draft`
- `cancel_draft`
- `daily_brief`

## LLM Prompting Rules

### Extractor Mode (low temperature)
- No guessing
- Return `missing_fields` if unclear
- JSON only with ISO 8601 datetime
- Explicit timezone required

### Planner Mode
- Can suggest subtasks, due dates, effort levels
- Must explain assumptions
- One clarification question at a time

### Output Format
- Strict JSON only
- ISO 8601 for all datetimes
- Never fabricate dates/times
- Explicit timezone in all events

## Development Workflow

### n8n Workflow Development
Since this is n8n-based, "code" is workflows:
- Treat n8n workflows as production code
- Export workflows as JSON for version control
- Test command flows end-to-end via test messages
- Use n8n's execution logs for debugging

### Testing Approach
- Send test messages through Telegram webhook
- Verify command queue entries in database
- Check draft creation and status transitions
- Validate final API calls to Google Calendar/Tasks

### Debugging
- Check n8n execution logs
- Query command and draft tables for status
- Review audit_log for action history
- Use idempotency keys to trace message flows

## Critical Constraints

### Non-Goals (Do Not Implement)
- No autonomous calendar modification without confirmation
- No long-term memory or personality simulation
- No multi-user collaboration (single-user initially)
- No full project management (dependencies, Gantt charts)

### Error Handling
- Idempotency on all inbound messages
- Command retries with exponential backoff
- Dead-letter queue for failures
- Manual override: `STOP BOT` command

### Security
- HTTPS only
- Webhook signature validation
- Minimal PII storage
- No long-term message logging unless required

## Phased Deployment

**Phase 1 (MVP)**
- Telegram chat
- Task drafting + confirmation
- Google Tasks integration

**Phase 2**
- Schedule drafting (text + URL)
- Google Calendar integration

**Phase 3**
- Image parsing (Gemini Vision)
- Daily briefing
- Reminder automation

## Success Metrics

- ≥90% correct intent routing
- Zero unconfirmed calendar/task creation
- Draft → confirm flow under 3 messages
- Daily briefing delivered reliably
