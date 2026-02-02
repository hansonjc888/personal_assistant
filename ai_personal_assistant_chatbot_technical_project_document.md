# AI Personal Assistant Chatbot

## Technical Project Document

**Version:** 1.0  
**Status:** Implementation-ready  
**Primary Audience:** IT Development Team / Claude Code  
**Author:** Product Owner  
**Target Environment:** Self-hosted n8n on AWS Lightsail

---

## 1. Executive Summary

This project aims to build a **chat-based personal assistant** that helps manage daily schedules, to-do lists, reminders, and planning. The assistant will ingest unstructured inputs (text, hyperlinks, images) via chat, convert them into structured drafts (calendar events or tasks), request confirmation, and then execute actions via connected services.

The system is designed to:
- Reduce manual calendar and task entry
- Prevent hallucinated or incorrect actions via draft + confirmation gates
- Be reliable, auditable, and easy to operate
- Avoid building a custom backend by leveraging n8n as the orchestration layer

The assistant will behave more like an **operations assistant** than a free-form chatbot.

---

## 2. Core Capabilities

### 2.1 Schedule Management
- Parse events from:
  - Plain text messages
  - Hyperlinks (event pages, emails, announcements)
  - Images (flyers, screenshots, posters)
- Extract structured event fields:
  - Title
  - Start / end datetime (ISO)
  - Timezone
  - Location
  - Notes
- Detect calendar conflicts
- Produce **draft events** and request confirmation before creation

### 2.2 Task & To-Do Management
- Convert vague instructions into structured tasks
- Prompt for missing details (due date, priority) one question at a time
- Suggest:
  - Subtasks
  - Reasonable due dates
  - Effort level (S/M/L)
- Create tasks only after user confirmation

### 2.3 Reminders & Planning
- Daily morning briefing (agenda + tasks)
- Proactive reminders for tasks and events
- Support snooze, reschedule, and completion actions

---

## 3. Non-Goals (Explicit)

- No autonomous calendar modification without user confirmation
- No long-term memory or personality simulation
- No multi-user collaboration (single-user system initially)
- No full project management features (e.g. dependencies, Gantt charts)

---

## 4. High-Level Architecture

### 4.1 Design Principles

- **Draft-first execution**: nothing is committed without confirmation
- **LLM for interpretation, not control flow**
- **Deterministic execution via workflows**
- **Auditability over cleverness**

### 4.2 System Overview

```
Chat Channel (Telegram / WhatsApp)
        ↓
Inbound Router Workflow (n8n)
        ↓
Intent Classification (Gemini)
        ↓
Command Queue (DB)
        ↓
Command Executor Workflow (n8n)
        ↓
Draft Storage → Confirmation → Execution
        ↓
Calendar / Task Services
```

n8n acts as the full backend: webhook handling, orchestration, scheduling, retries, and integrations.

---

## 5. Technology Stack

### 5.1 Core Platform
- n8n (self-hosted)
- AWS Lightsail (Linux VPS)

### 5.2 AI / LLM
- Gemini API
  - Flash model: intent classification, extraction
  - Pro model: daily planning, task decomposition

### 5.3 Integrations
- Chat interface:
  - Phase 1: Telegram
  - Phase 2: WhatsApp (Twilio or Cloud API)
- Calendar:
  - Google Calendar (primary write target)
  - Apple Calendar (sync/display only)
- Tasks:
  - Google Tasks

### 5.4 Storage
- PostgreSQL (preferred) or SQLite (MVP)

---

## 6. Agentic Architecture (Recommended Pattern)

### 6.1 Command-Based Model

The system does not allow the LLM to directly execute tools.

Instead:
1. LLM outputs **strict JSON intent**
2. Intent becomes a **command** stored in DB
3. Deterministic workflows execute the command

This ensures predictability and debuggability.

### 6.2 Command Types (Initial)

- `draft_event_from_text`
- `draft_event_from_url`
- `draft_event_from_image`
- `draft_task_from_text`
- `edit_draft`
- `confirm_draft`
- `cancel_draft`
- `daily_brief`

---

## 7. Key Workflows (n8n)

### 7.1 Workflow A — Inbound Message Router

**Trigger:** Chat webhook

Steps:
1. Normalize inbound message (text, media, sender, message_id)
2. Compute idempotency key
3. Load conversation state
4. Call Gemini Intent Classifier (strict JSON)
5. Persist command to DB

Output: command row

---

### 7.2 Workflow B — Command Executor

**Trigger:** Cron (every 5–15 seconds)

Steps:
1. Fetch next pending command
2. Switch by command type
3. Call sub-workflow
4. Update status
5. Write audit log
6. Send response to user

---

### 7.3 Workflow C — Schedule Drafting

Handles:
- Text parsing
- URL fetching + extraction
- Image extraction (Gemini Vision)

Produces:
- Draft event JSON
- Missing fields list

Stores draft and prompts user for confirmation or edits.

---

### 7.4 Workflow D — Task Drafting

Produces:
- Task title
- Suggested due date
- Subtasks
- Clarification questions

Stores task draft and awaits confirmation.

---

### 7.5 Workflow E — Confirmation & Execution

On confirmation:
- Validate draft completeness
- Detect conflicts (calendar)
- Create calendar event or task
- Log execution

---

### 7.6 Workflow F — Daily Briefing

**Trigger:** Scheduled (e.g. 07:30 daily)

Steps:
1. Fetch today’s calendar events
2. Fetch due / overdue tasks
3. Gemini planning summary
4. Send concise plan to chat

---

### 7.7 Workflow G — Reminder Checker

**Trigger:** Scheduled (every 10–15 minutes)

Steps:
1. Query tasks/events nearing reminder threshold
2. Send reminder
3. Mark reminder sent or snoozed

---

## 8. Data Model (Minimum)

### 8.1 Tables

**users**
- user_id
- channel
- timezone

**commands**
- id
- user_id
- type
- payload_json
- status
- created_at

**drafts**
- id
- user_id
- draft_type (event|task)
- draft_json
- status (drafted|confirmed|executed|cancelled)
- source_message_id

**executions**
- id
- draft_id
- result_json
- status

**audit_log**
- timestamp
- action
- entity_id
- source_message_id

---

## 9. Prompting & LLM Rules

### 9.1 Strict Separation of Modes

**Extractor Mode**:
- Temperature low
- No guessing
- Must return missing_fields if unclear

**Planner Mode**:
- Can suggest
- Must explain assumptions

### 9.2 Output Rules

- JSON only
- ISO 8601 datetime
- Explicit timezone
- Never fabricate dates or times

---

## 10. Error Handling & Reliability

- Idempotency on all inbound messages
- Command retries with backoff
- Dead-letter queue for failures
- Manual override command: `STOP BOT`

---

## 11. Security Considerations

- HTTPS only
- Webhook signature validation
- Minimal PII storage
- No long-term message logging unless required

---

## 12. Deployment Plan

### Phase 1 (MVP)
- Telegram chat
- Task drafting + confirmation
- Google Tasks integration

### Phase 2
- Schedule drafting (text + URL)
- Google Calendar integration

### Phase 3
- Image parsing
- Daily briefing
- Reminder automation

---

## 13. Success Criteria

- ≥90% correct intent routing
- Zero unconfirmed calendar/task creation
- Draft → confirm flow under 3 messages
- Daily briefing delivered reliably

---

## 14. Open Extensions (Future)

- WhatsApp channel
- Location-aware reminders
- End-of-day review
- Personal productivity analytics

---

## 15. Handoff Notes for Developers

- Prioritize determinism over autonomy
- Keep agent prompts narrow and explicit
- Treat n8n workflows as production code
- Log everything that mutates state

This document is intended to be sufficient for a development team or Claude Code to implement the system end-to-end without additional clarification.

