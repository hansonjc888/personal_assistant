# AI Personal Assistant Chatbot - Phase 1 MVP

> A task management assistant powered by n8n, Gemini AI, and Google Tasks.
> **Available for both Telegram and WhatsApp**

**Draft-first execution** — Nothing is committed to your calendar or tasks without explicit confirmation.

---

## 🎯 Overview

This AI Personal Assistant helps you manage tasks through natural language conversations via **Telegram or WhatsApp**. Simply tell it what you need to do, review the suggested task structure, and confirm to create it in Google Tasks.

### 📱 Choose Your Platform

This project includes **complete implementations for both platforms**:

- **🔵 Telegram** - Simple setup, free forever, great for personal use
- **🟢 WhatsApp Business API** - Professional, wider reach, better for business

**Not sure which to choose?** See [Telegram vs WhatsApp Comparison](docs/whatsapp/telegram-vs-whatsapp.md)

### Key Features

- ✅ **Natural language** task creation
- ✅ **Draft-first** confirmation flow (no surprises!)
- ✅ **Smart suggestions** for subtasks and due dates
- ✅ **Google Tasks** integration
- ✅ **Fully audited** command and execution history

---

## 🏗️ Architecture

### Command-Based Design

The system uses a **command queue pattern** (not autonomous tool execution):

```
Telegram Message → Intent Classification → Command Queue → Execution
                                              ↓
                                         Draft → Confirm → Google Tasks
```

### Core Components

1. **Workflow A (Inbound Router)**: Telegram webhook → Gemini intent classification → Command queue
2. **Workflow B (Command Executor)**: Polls queue → Routes to sub-workflows
3. **Workflow D (Task Drafting)**: Structures task with Gemini → Creates draft → Shows confirmation
4. **Workflow E (Confirmation & Execution)**: Validates draft → Creates in Google Tasks

### Technology Stack

- **Orchestration**: n8n (self-hosted)
- **AI**: Gemini 2.0 Flash (intent + structuring)
- **Chat**: Telegram Bot API OR WhatsApp Business API
- **Tasks**: Google Tasks API
- **Database**: SQLite (MVP), PostgreSQL (future)
- **Hosting**: AWS Lightsail (or any VPS)

---

## 🚀 Quick Start

### Prerequisites

- n8n instance with HTTPS (required for OAuth)
- **Telegram account** OR **Facebook Business account** (for WhatsApp)
- Google account
- Basic command-line knowledge

### Choose Your Platform

Pick one to get started:

#### Option A: Telegram (Recommended for Quick Start) 🔵

**Time to first message**: 10 minutes

1. **Clone repository**
   ```bash
   git clone <repository-url>
   cd task_list_helper
   ```

2. **Set up database**
   ```bash
   sqlite3 data/task_assistant.db < database/schema.sql
   sqlite3 data/task_assistant.db < database/init_user.sql
   ```

3. **Configure credentials**
   ```bash
   cp .env.example .env
   nano .env  # Fill in your API keys
   ```

4. **Import n8n workflows**
   - Import workflows from `workflows/` directory
   - Configure credentials in each workflow

5. **Set up Telegram webhook**
   ```bash
   ./scripts/set-telegram-webhook.sh
   ```

6. **Test the system**
   - Send message to your Telegram bot: "Buy milk tomorrow"
   - Verify draft is created and buttons appear
   - Click ✅ Confirm
   - Check Google Tasks for the new task

**📖 Full guide**: [Telegram Setup](docs/telegram-setup.md)

---

#### Option B: WhatsApp Business API 🟢

**Time to first message**: 1-3 days (includes business verification)

1. **Set up WhatsApp Business** (see [WhatsApp Setup Guide](docs/whatsapp/whatsapp-setup.md))
   - Create Facebook Business account
   - Set up WhatsApp Business API
   - Get business verification approved

2. **Clone and configure** (same as above)

3. **Import WhatsApp workflows**
   - Import workflows from `workflows/whatsapp/` directory
   - Configure WhatsApp Business API credentials

4. **Test with your WhatsApp**

**📖 Full guide**: [WhatsApp Setup](docs/whatsapp/whatsapp-setup.md)

---

#### Want Both?

You can run **both platforms simultaneously** using the same database and business logic. See [Telegram vs WhatsApp Comparison](docs/whatsapp/telegram-vs-whatsapp.md) for details.

---

## 📚 Documentation

### Setup Guides

- **[Credentials Setup](docs/credentials-setup.md)** - Configure all API keys and OAuth
- **[Telegram Setup](docs/telegram-setup.md)** - Create bot and configure webhook
- **[Google Tasks Integration](docs/google-tasks-integration.md)** - OAuth setup and API usage
- **[n8n Database Setup](docs/n8n-database-setup.md)** - SQLite configuration

### Reference

- **[Gemini Prompts](docs/gemini-prompts.md)** - All LLM prompts with examples
- **[Architecture](docs/architecture.md)** - System design and data flow
- **[Testing Guide](docs/testing-guide.md)** - Test scenarios and validation
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[API Reference](docs/api-reference.md)** - External API documentation

---

## 🎬 Usage Examples

### Create Simple Task

```
You: Buy groceries tomorrow
Bot: Got it! Working on it... ⚙️

Bot: 📝 Task Draft:

     Title: Buy groceries
     Due: Tomorrow (Feb 3, 2026)
     Notes: Weekly shopping

     Suggested subtasks:
      • Make shopping list (S)
      • Go to store (M)
      • Put away groceries (S)

     [✅ Confirm] [✏️ Edit] [❌ Cancel]

You: [Click ✅ Confirm]
Bot: ✅ Task created successfully!
```

### Complex Project

```
You: Plan team offsite next month
Bot: 📝 Task Draft:

     Title: Plan team offsite
     Due: March 2, 2026 (suggested: allows prep time)
     Notes: Team building event requiring coordination

     Suggested subtasks:
      • Research venue options (M)
      • Create budget proposal (M)
      • Survey team for dates (S)
      • Book venue and catering (L)
      • Plan activities (L)

     [✅ Confirm] [✏️ Edit] [❌ Cancel]
```

### Clarification Request

```
You: Call about the thing
Bot: Who do you need to call and what is it regarding?

You: Call dentist to schedule cleaning
Bot: 📝 Task Draft:

     Title: Call dentist to schedule cleaning
     Due: No due date
     ...
```

---

## 🗂️ Project Structure

```
task_list_helper/
├── database/
│   ├── schema.sql           # Database schema
│   ├── init_user.sql         # Default user setup
│   └── test-queries.sql      # Debugging queries
├── workflows/
│   ├── 01-inbound-router.json
│   ├── 02-command-executor.json
│   ├── 04-task-drafting.json
│   └── 05-confirmation-execution.json
├── docs/
│   ├── credentials-setup.md
│   ├── telegram-setup.md
│   ├── google-tasks-integration.md
│   ├── n8n-database-setup.md
│   ├── gemini-prompts.md
│   ├── architecture.md
│   ├── testing-guide.md
│   ├── troubleshooting.md
│   └── api-reference.md
├── scripts/
│   └── set-telegram-webhook.sh
├── .env.example
├── CLAUDE.md                 # Project instructions
└── README.md
```

---

## 🔧 Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Required
GEMINI_API_KEY=your_gemini_api_key
TELEGRAM_BOT_TOKEN=your_bot_token
DATABASE_PATH=/path/to/task_assistant.db
N8N_WEBHOOK_URL=https://your-n8n-domain.com/webhook

# Optional
USER_TIMEZONE=America/New_York
TELEGRAM_SECRET_TOKEN=random_secret_for_validation
```

See [Credentials Setup Guide](docs/credentials-setup.md) for detailed instructions.

---

## 🧪 Testing

### Manual Testing

1. **Simple task**: "Buy milk"
2. **Task with date**: "Submit report by Friday"
3. **Complex task**: "Plan birthday party"
4. **Vague task**: "Fix the issue" (should ask for clarification)
5. **Confirmation flow**: Draft → Edit → Confirm

### Database Verification

```bash
# Check recent commands
sqlite3 $DATABASE_PATH "SELECT * FROM commands ORDER BY created_at DESC LIMIT 5;"

# Check drafts
sqlite3 $DATABASE_PATH "SELECT * FROM drafts ORDER BY created_at DESC LIMIT 5;"

# Check executions
sqlite3 $DATABASE_PATH "SELECT * FROM executions ORDER BY executed_at DESC LIMIT 5;"

# Audit trail
sqlite3 $DATABASE_PATH "SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 10;"
```

See [Testing Guide](docs/testing-guide.md) for comprehensive test scenarios.

---

## 🎯 Phase 1 MVP Scope

### ✅ Implemented

- Task drafting from text messages
- Intent classification with Gemini AI
- Confirmation flow with inline buttons
- Google Tasks integration (main tasks + subtasks)
- Command queue system
- Draft management
- Execution tracking
- Full audit logging
- Idempotency handling

### 🚫 Explicitly Out of Scope

- Calendar/event management (Phase 2)
- Image parsing (Phase 3)
- Daily briefing (Phase 3)
- Multi-user support
- Voice messages
- Location-based reminders

---

## 🔐 Security

### Best Practices

- ✅ All credentials in environment variables (not code)
- ✅ HTTPS required for all webhooks
- ✅ OAuth2 for Google Tasks
- ✅ Optional webhook secret token validation
- ✅ Database file permissions (660)
- ✅ No long-term message storage
- ✅ Full audit trail for compliance

### Rate Limits

**Gemini API (Free tier)**:
- 15 requests/minute
- 1,500 requests/day

**Google Tasks API**:
- 50,000 queries/day
- 2,500 queries/100 seconds

**Telegram Bot API**:
- 30 messages/second

See [API Reference](docs/api-reference.md) for quota management.

---

## 🐛 Troubleshooting

### Common Issues

1. **Bot not responding**
   - Check webhook status: `curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"`
   - Verify n8n workflows are active
   - Check database permissions

2. **Tasks not creating**
   - Verify Google Tasks OAuth connected
   - Check n8n execution logs
   - Review executions table for errors

3. **Duplicate messages**
   - Verify idempotency check in Workflow A
   - Clear pending updates: `curl "https://api.telegram.org/bot<TOKEN>/getUpdates?offset=-1"`

See [Troubleshooting Guide](docs/troubleshooting.md) for detailed solutions.

---

## 🗺️ Roadmap

### Phase 2: Calendar Management
- Event creation from text and URLs
- Google Calendar integration
- Conflict detection
- Time parsing and timezone handling

### Phase 3: Advanced Features
- Image parsing with Gemini Vision
- Daily briefing workflow
- Reminder notifications
- Voice message support

### Future Enhancements
- WhatsApp support
- Multi-user mode
- PostgreSQL migration
- Analytics dashboard
- Custom recurrence rules

---

## 📊 Success Metrics

### Phase 1 Targets

- ✅ ≥90% correct intent classification
- ✅ Zero unconfirmed task creation
- ✅ Draft → confirm flow in ≤3 messages
- ✅ Full audit trail coverage

### Monitoring

```sql
-- Intent classification accuracy
SELECT
  json_extract(payload_json, '$.confidence') as confidence,
  COUNT(*) as count
FROM commands
WHERE type = 'draft_task_from_text'
GROUP BY confidence;

-- Success rate
SELECT
  status,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM executions), 2) as percentage
FROM executions
GROUP BY status;
```

---

## 🤝 Contributing

This is a personal project, but suggestions are welcome:

1. Open an issue describing the problem/feature
2. Discuss approach before implementing
3. Follow existing code style and patterns
4. Update documentation for any changes

---

## 📝 License

[MIT License](LICENSE)

---

## 🙏 Acknowledgments

Built with:
- [n8n](https://n8n.io/) - Workflow automation
- [Gemini AI](https://ai.google.dev/) - Natural language understanding
- [Telegram](https://telegram.org/) - Chat interface
- [Google Tasks](https://developers.google.com/tasks) - Task management

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/task_list_helper/issues)
- **Documentation**: See `docs/` directory
- **Debugging**: Check `database/test-queries.sql`

---

## 📅 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-02 | Phase 1 MVP release |

---

**Note**: This is a Phase 1 MVP focused on task management only. Calendar integration and advanced features coming in future phases.
