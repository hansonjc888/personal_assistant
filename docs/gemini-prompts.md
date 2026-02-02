# Gemini AI Prompts Documentation

This document contains all LLM prompts used in the AI Personal Assistant system.

## Overview

The system uses two distinct prompting modes:
1. **Extractor Mode** (low temperature 0.1) - For intent classification and data extraction
2. **Planner Mode** (medium temperature 0.3) - For task structuring and suggestions

---

## 1. Intent Classification Prompt

**Used in**: Workflow A - Inbound Router
**Model**: Gemini 2.0 Flash
**Temperature**: 0.1
**Output**: Strict JSON

### Prompt Template

```
You are an intent classifier for a task management assistant.

Analyze the user message and output STRICT JSON:
{
  "intent": "draft_task" | "confirm_draft" | "cancel_draft" | "edit_draft" | "unknown",
  "parameters": {
    "task_description": "string",
    "mentioned_due_date": "YYYY-MM-DD or null",
    "priority_indicators": ["urgent", "important", etc] or []
  },
  "confidence": 0.0-1.0
}

Rules:
- Never guess dates if not explicitly mentioned
- Return "unknown" intent if unclear
- For callback buttons (✅/✏️/❌), extract the action
- Current date context: {current_date}

User message: {user_text}
```

### Variables
- `{current_date}` - ISO 8601 date (YYYY-MM-DD)
- `{user_text}` - Raw user message from Telegram

### Example Inputs/Outputs

**Example 1: Simple task**
```
Input: "Buy groceries tomorrow"

Output:
{
  "intent": "draft_task",
  "parameters": {
    "task_description": "Buy groceries",
    "mentioned_due_date": "2026-02-03",
    "priority_indicators": []
  },
  "confidence": 0.95
}
```

**Example 2: Urgent task**
```
Input: "URGENT: Submit report by Friday"

Output:
{
  "intent": "draft_task",
  "parameters": {
    "task_description": "Submit report",
    "mentioned_due_date": "2026-02-07",
    "priority_indicators": ["urgent"]
  },
  "confidence": 0.92
}
```

**Example 3: Confirmation button**
```
Input: "confirm_draft:123"

Output:
{
  "intent": "confirm_draft",
  "parameters": {
    "draft_id": "123"
  },
  "confidence": 1.0
}
```

**Example 4: Unclear message**
```
Input: "What about the thing?"

Output:
{
  "intent": "unknown",
  "parameters": {},
  "confidence": 0.15
}
```

---

## 2. Task Structuring Prompt

**Used in**: Workflow D - Task Drafting
**Model**: Gemini 2.0 Flash
**Temperature**: 0.3
**Output**: Strict JSON

### Prompt Template

```
You are a task planning assistant.

Original request: {task_description}
Mentioned due date: {mentioned_due_date}
Priority indicators: {priority_indicators}
Current date: {current_date}

Output STRICT JSON:
{
  "title": "string (clear, actionable task title, max 100 chars)",
  "due_date": "YYYY-MM-DD or null",
  "due_date_reasoning": "string (explain if suggested or user-mentioned)",
  "notes": "string (additional context, optional)",
  "suggested_subtasks": [
    {"title": "string", "estimated_effort": "S|M|L"}
  ],
  "clarification_needed": "string or null (ask ONE question if critical info missing)"
}

Rules:
- Temperature: 0.3
- If due date mentioned, validate it's in the future
- Suggest realistic subtasks (max 5, only if task is complex)
- Keep title concise and actionable
- Only ask for clarification if absolutely necessary
- Effort levels: S (< 30 min), M (30min - 2hr), L (> 2hr)
```

### Variables
- `{task_description}` - Extracted task description from intent classifier
- `{mentioned_due_date}` - Date mentioned by user or null
- `{priority_indicators}` - Array of priority keywords
- `{current_date}` - ISO 8601 date for context

### Example Inputs/Outputs

**Example 1: Simple task with date**
```
Input:
  task_description: "Buy groceries"
  mentioned_due_date: "2026-02-03"
  priority_indicators: []
  current_date: "2026-02-02"

Output:
{
  "title": "Buy groceries",
  "due_date": "2026-02-03",
  "due_date_reasoning": "User mentioned tomorrow",
  "notes": "Weekly grocery shopping",
  "suggested_subtasks": [
    {"title": "Make shopping list", "estimated_effort": "S"},
    {"title": "Go to store", "estimated_effort": "M"},
    {"title": "Put away groceries", "estimated_effort": "S"}
  ],
  "clarification_needed": null
}
```

**Example 2: Complex project**
```
Input:
  task_description: "Plan birthday party next week"
  mentioned_due_date: "2026-02-09"
  priority_indicators: ["important"]
  current_date: "2026-02-02"

Output:
{
  "title": "Plan birthday party",
  "due_date": "2026-02-09",
  "due_date_reasoning": "User mentioned next week",
  "notes": "Important event requiring coordination",
  "suggested_subtasks": [
    {"title": "Create guest list", "estimated_effort": "S"},
    {"title": "Book venue", "estimated_effort": "M"},
    {"title": "Order cake", "estimated_effort": "S"},
    {"title": "Send invitations", "estimated_effort": "M"},
    {"title": "Plan activities and menu", "estimated_effort": "L"}
  ],
  "clarification_needed": null
}
```

**Example 3: Needs clarification**
```
Input:
  task_description: "Call about the thing"
  mentioned_due_date: null
  priority_indicators: []
  current_date: "2026-02-02"

Output:
{
  "title": "Make phone call",
  "due_date": null,
  "due_date_reasoning": "No due date specified",
  "notes": "",
  "suggested_subtasks": [],
  "clarification_needed": "Who do you need to call and what is it regarding?"
}
```

**Example 4: No subtasks needed**
```
Input:
  task_description: "Send email to John"
  mentioned_due_date: null
  priority_indicators: []
  current_date: "2026-02-02"

Output:
{
  "title": "Send email to John",
  "due_date": null,
  "due_date_reasoning": "No due date needed for quick task",
  "notes": "",
  "suggested_subtasks": [],
  "clarification_needed": null
}
```

---

## Prompt Design Principles

### Extractor Mode (Intent Classification)

**Key characteristics**:
- **Low temperature (0.1)** - Maximize consistency and predictability
- **Strict JSON schema** - Enforce structured output
- **No guessing** - Return null/unknown when uncertain
- **Explicit rules** - Clear boundaries for decision-making

**Best practices**:
- Always provide current date context
- Use enum values for intents
- Include confidence scoring
- Never fabricate information

### Planner Mode (Task Structuring)

**Key characteristics**:
- **Medium temperature (0.3)** - Allow reasonable creativity
- **Suggestion-based** - Offer helpful additions without overreach
- **Context-aware** - Consider priority and timing
- **Clarification-first** - Ask before assuming

**Best practices**:
- Limit subtask count (max 5)
- Provide effort estimates
- Explain reasoning for suggested dates
- Only one clarification question at a time
- Keep titles concise and actionable

---

## Testing Prompts

### Test Cases for Intent Classification

```bash
# Test 1: Basic task
"Remind me to call mom tomorrow"
Expected: draft_task, due_date="2026-02-03"

# Test 2: No date
"Buy milk"
Expected: draft_task, due_date=null

# Test 3: Callback button
"confirm_draft:42"
Expected: confirm_draft, draft_id="42"

# Test 4: Ambiguous
"What's the weather?"
Expected: unknown, confidence < 0.5
```

### Test Cases for Task Structuring

```bash
# Test 1: Complex task
"Organize team offsite next month"
Expected: 3-5 subtasks, suggested due date

# Test 2: Simple task
"Water plants"
Expected: 0 subtasks, no due date

# Test 3: Needs clarification
"Fix the issue"
Expected: clarification_needed != null
```

---

## Future Enhancements (Phase 2+)

### Event Extraction Prompt
For calendar event creation:
- Extract start/end times
- Parse location information
- Identify recurring patterns
- Handle timezone ambiguity

### Daily Briefing Prompt
For generating daily summaries:
- Prioritize tasks by urgency
- Highlight conflicts
- Suggest time blocking
- Provide motivational framing

### Image Parsing Prompt (Gemini Vision)
For extracting tasks from screenshots:
- OCR text extraction
- Identify action items
- Parse dates and times
- Handle handwritten notes

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-02 | Initial prompts for Phase 1 MVP |

---

## Notes

- All prompts use ISO 8601 date format (YYYY-MM-DD)
- Explicit timezone handling deferred to Phase 2
- Temperature values are optimized for balance between consistency and creativity
- JSON schema validation happens in code, not in prompts
