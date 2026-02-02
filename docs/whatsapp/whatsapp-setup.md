# WhatsApp Business API Setup Guide

Complete guide for setting up the WhatsApp version of the AI Personal Assistant.

---

## Overview

This guide covers how to set up WhatsApp Business API instead of Telegram for the AI Personal Assistant chatbot.

**Key Differences from Telegram**:
- Requires Facebook Business account
- Uses WhatsApp Business API (cloud-hosted by Meta)
- More complex setup but better for business use
- Different button/interactive message format

---

## Prerequisites

- Facebook Business account
- Phone number for WhatsApp Business
- n8n instance with HTTPS
- WhatsApp Business account approved by Meta

---

## Step 1: Create Facebook Business Account

### 1.1 Register Business

1. Go to [Facebook Business](https://business.facebook.com/)
2. Click **Create Account**
3. Fill in business details:
   - Business name
   - Your name
   - Business email
4. Click **Submit**

### 1.2 Verify Business

Meta may require business verification:
- Upload business documents
- Phone number verification
- Email confirmation

**Approval time**: 1-3 business days

---

## Step 2: Set Up WhatsApp Business API

### 2.1 Create App

1. Go to [Meta for Developers](https://developers.facebook.com/)
2. Click **My Apps** → **Create App**
3. Select **Business** type
4. Fill in:
   - App name: `AI Task Assistant`
   - Contact email: your-email@example.com
   - Business account: Select your business
5. Click **Create App**

### 2.2 Add WhatsApp Product

1. In app dashboard, find **WhatsApp** product
2. Click **Set Up**
3. Select **Business Portfolio**
4. Complete setup wizard

### 2.3 Configure Phone Number

**Option A: Use Test Number (for development)**
- Meta provides a test phone number
- Can only message 5 pre-approved numbers
- Free, instant setup

**Option B: Add Your Own Number (for production)**
1. Click **Add Phone Number**
2. Enter phone number
3. Verify via SMS/call
4. Complete business verification

**Important**: Phone number must not be registered with WhatsApp consumer app.

---

## Step 3: Get API Credentials

### 3.1 Get Access Token

1. In WhatsApp dashboard, go to **API Setup**
2. Find **Temporary Access Token** (24 hours)
   - Copy this for initial testing

**For production**, generate permanent token:
1. Go to **Settings** → **Business settings** → **System Users**
2. Create system user: `n8n-integration`
3. Assign assets: Your WhatsApp Business account
4. Generate token with permissions:
   - `whatsapp_business_management`
   - `whatsapp_business_messaging`
5. **Save securely** - shown only once

### 3.2 Get Phone Number ID

1. In WhatsApp dashboard → **API Setup**
2. Find **Phone Number ID** (starts with numbers, e.g., `1234567890123`)
3. Copy this ID

### 3.3 Get WhatsApp Business Account ID

1. In WhatsApp dashboard → **API Setup**
2. Find **WhatsApp Business Account ID**
3. Copy this ID

---

## Step 4: Configure Webhook

### 4.1 Get n8n Webhook URL

1. Import **WhatsApp Inbound Router** workflow
2. Open webhook node
3. Copy production URL

Example: `https://your-n8n-domain.com/webhook/whatsapp-bot`

### 4.2 Set Webhook in Meta

1. In WhatsApp dashboard → **Configuration**
2. Click **Edit** under Webhook
3. Fill in:
   - **Callback URL**: Your n8n webhook URL
   - **Verify Token**: Create a random string (save it!)
     ```bash
     openssl rand -hex 32
     ```
   - Save verify token as `WHATSAPP_VERIFY_TOKEN` in .env

4. Click **Verify and Save**

Meta will send GET request to verify:
```
GET https://your-n8n-domain.com/webhook/whatsapp-bot?hub.mode=subscribe&hub.challenge=CHALLENGE&hub.verify_token=YOUR_TOKEN
```

Your workflow must respond with the challenge.

### 4.3 Subscribe to Webhook Fields

1. After webhook verified, click **Manage**
2. Subscribe to:
   - ✅ **messages** (required)
   - ✅ **message_status** (optional, for delivery receipts)
3. Click **Save**

---

## Step 5: Configure n8n Credentials

### 5.1 Add WhatsApp Business API Credential

1. n8n → **Settings** → **Credentials**
2. Click **+ Add Credential**
3. Select **HTTP Header Auth**
4. Configure:
   - **Name**: `WhatsApp Business API`
   - **Name (Header)**: `Authorization`
   - **Value**: `Bearer YOUR_ACCESS_TOKEN`
5. Click **Save**

### 5.2 Set Environment Variables

Update `.env`:
```bash
# WhatsApp Business API
WHATSAPP_ACCESS_TOKEN=your_permanent_access_token
WHATSAPP_PHONE_NUMBER_ID=1234567890123
WHATSAPP_BUSINESS_ACCOUNT_ID=your_business_account_id
WHATSAPP_VERIFY_TOKEN=your_random_verify_token

# Your WhatsApp number (for testing)
WHATSAPP_USER_PHONE=+1234567890
```

---

## Step 6: Update Database

### 6.1 Add WhatsApp User

```sql
-- Update users table
UPDATE users
SET
  channel = 'whatsapp',
  telegram_chat_id = NULL  -- Clear Telegram ID
WHERE user_id = 'default_user';

-- Or add new column if needed
ALTER TABLE users ADD COLUMN whatsapp_phone TEXT;

UPDATE users
SET whatsapp_phone = '+1234567890'
WHERE user_id = 'default_user';
```

---

## Step 7: Import WhatsApp Workflows

### 7.1 Import Workflows

1. **WhatsApp Inbound Router**: `workflows/whatsapp/01-whatsapp-inbound-router.json`
2. **WhatsApp Task Drafting**: `workflows/whatsapp/04-whatsapp-task-drafting.json`
3. Reuse existing:
   - Command Executor (Workflow B)
   - Confirmation & Execution (Workflow E)

### 7.2 Configure Workflow IDs

Update environment variables:
```bash
# After importing, get workflow IDs from URL
WORKFLOW_A_WHATSAPP_ID=10  # WhatsApp Inbound Router
WORKFLOW_D_WHATSAPP_ID=12  # WhatsApp Task Drafting
```

Update Command Executor to route to WhatsApp workflows.

---

## Step 8: Test End-to-End

### 8.1 Add Test Number

1. In WhatsApp dashboard → **API Setup**
2. Scroll to **To**
3. Click **Manage phone number list**
4. Add your personal WhatsApp number

### 8.2 Send Test Message

From your WhatsApp:
1. Send message to business number: `Hello`
2. Should receive: "Got it! Working on it... ⚙️"

### 8.3 Test Task Creation

Send: `Buy milk tomorrow`

Expected flow:
1. Acknowledgment message
2. Draft with interactive buttons:
   ```
   📝 Task Draft

   Title: Buy milk
   Due: Tomorrow (Feb 3, 2026)
   ...

   [✅ Confirm] [❌ Cancel]
   ```
3. Click **✅ Confirm**
4. Confirmation: "✅ Task created successfully!"
5. Check Google Tasks

---

## Step 9: Message Format Reference

### 9.1 Text Message

```json
{
  "messaging_product": "whatsapp",
  "to": "+1234567890",
  "type": "text",
  "text": {
    "body": "Your message here"
  }
}
```

### 9.2 Interactive Buttons (max 3)

```json
{
  "messaging_product": "whatsapp",
  "to": "+1234567890",
  "type": "interactive",
  "interactive": {
    "type": "button",
    "body": {
      "text": "Message with buttons"
    },
    "action": {
      "buttons": [
        {
          "type": "reply",
          "reply": {
            "id": "confirm_draft:123",
            "title": "✅ Confirm"
          }
        },
        {
          "type": "reply",
          "reply": {
            "id": "cancel_draft:123",
            "title": "❌ Cancel"
          }
        }
      ]
    }
  }
}
```

**Button limits**:
- Max 3 buttons per message
- Title max 20 characters
- ID max 256 characters

### 9.3 Interactive List (for > 3 options)

```json
{
  "messaging_product": "whatsapp",
  "to": "+1234567890",
  "type": "interactive",
  "interactive": {
    "type": "list",
    "header": {
      "type": "text",
      "text": "Choose an option"
    },
    "body": {
      "text": "Select from the list"
    },
    "action": {
      "button": "Options",
      "sections": [
        {
          "title": "Actions",
          "rows": [
            {"id": "confirm", "title": "Confirm"},
            {"id": "edit", "title": "Edit"},
            {"id": "cancel", "title": "Cancel"}
          ]
        }
      ]
    }
  }
}
```

---

## Step 10: Webhook Payload Reference

### 10.1 Incoming Text Message

```json
{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "BUSINESS_ACCOUNT_ID",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "15551234567",
              "phone_number_id": "PHONE_NUMBER_ID"
            },
            "contacts": [
              {
                "profile": {
                  "name": "John Doe"
                },
                "wa_id": "1234567890"
              }
            ],
            "messages": [
              {
                "from": "1234567890",
                "id": "wamid.ABC123==",
                "timestamp": "1704153600",
                "type": "text",
                "text": {
                  "body": "Buy milk tomorrow"
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}
```

### 10.2 Button Click

```json
{
  "messages": [
    {
      "from": "1234567890",
      "id": "wamid.DEF456==",
      "timestamp": "1704153700",
      "type": "interactive",
      "interactive": {
        "type": "button_reply",
        "button_reply": {
          "id": "confirm_draft:123",
          "title": "✅ Confirm"
        }
      }
    }
  ]
}
```

---

## Step 11: Rate Limits & Costs

### 11.1 Rate Limits

**Cloud API (Free tier)**:
- 1,000 free conversations/month
- Then pay-as-you-go

**Rate limits**:
- 80 messages/second (per phone number)
- 600,000 messages/day

**Conversation window**: 24 hours from last user message

### 11.2 Messaging Costs

**Conversation-based pricing**:
- **User-initiated**: $0 (free within 24hr window)
- **Business-initiated**: $0.0042 - $0.0217 per conversation (varies by country)

**Conversation**: Any message exchange within 24 hours.

**Free tier**: 1,000 conversations/month

**Example** (US rates):
- User sends "Buy milk" → Free
- Bot responds → Free (same conversation)
- User confirms → Free (within 24hrs)
- Daily briefing (business-initiated) → ~$0.0084

**Monthly estimate** (100 tasks/month):
- User-initiated: 100 × $0 = $0
- Business-initiated (briefings): 30 × $0.0084 = $0.25/month

---

## Step 12: Production Checklist

Before going live:

- [ ] Business verification approved
- [ ] Permanent access token generated
- [ ] Own phone number registered (not test number)
- [ ] Webhook verified and active
- [ ] n8n workflows active
- [ ] Database updated with WhatsApp phone
- [ ] Tested end-to-end flow
- [ ] Message templates approved (for business-initiated)
- [ ] Monitoring set up
- [ ] Backup strategy in place

---

## Step 13: Message Templates (Business-Initiated)

For messages **outside** 24hr window, use templates:

### 13.1 Create Template

1. WhatsApp dashboard → **Message Templates**
2. Click **Create Template**
3. Fill in:
   - Name: `daily_briefing`
   - Category: `UTILITY`
   - Language: English
   - Content:
     ```
     Good morning! Here's your daily briefing:

     {{1}}

     Have a productive day!
     ```
4. Submit for approval (1-3 days)

### 13.2 Send Template Message

```bash
curl -X POST \
  "https://graph.facebook.com/v18.0/$PHONE_NUMBER_ID/messages" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "messaging_product": "whatsapp",
    "to": "+1234567890",
    "type": "template",
    "template": {
      "name": "daily_briefing",
      "language": {"code": "en"},
      "components": [
        {
          "type": "body",
          "parameters": [
            {"type": "text", "text": "• Task 1\n• Task 2"}
          ]
        }
      ]
    }
  }'
```

---

## Troubleshooting

### Issue: Webhook Not Receiving Messages

**Check**:
```bash
curl "https://graph.facebook.com/v18.0/$PHONE_NUMBER_ID/subscribed_apps?access_token=$ACCESS_TOKEN"
```

Should return: `{"data": [{"subscribed_fields": ["messages"]}]}`

**Solution**: Re-subscribe webhook fields.

---

### Issue: "Cloud API number not allowed"

**Cause**: Trying to message unregistered number in test mode.

**Solution**: Add recipient to allowed numbers list.

---

### Issue: Messages Not Sending

**Check**:
- Access token valid
- Phone number ID correct
- Recipient format: `+` + country code + number (e.g., `+1234567890`)

**Test API**:
```bash
curl -X POST \
  "https://graph.facebook.com/v18.0/$PHONE_NUMBER_ID/messages" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "messaging_product": "whatsapp",
    "to": "+1234567890",
    "type": "text",
    "text": {"body": "Test message"}
  }'
```

---

## Resources

- [WhatsApp Business Platform Docs](https://developers.facebook.com/docs/whatsapp)
- [Cloud API Quickstart](https://developers.facebook.com/docs/whatsapp/cloud-api/get-started)
- [Message Templates](https://developers.facebook.com/docs/whatsapp/message-templates)
- [Webhook Reference](https://developers.facebook.com/docs/whatsapp/cloud-api/webhooks/components)
- [Pricing](https://developers.facebook.com/docs/whatsapp/pricing)

---

## Next Steps

After Phase 1 MVP working:
- Add message templates for daily briefing
- Implement rich media (images, documents)
- Add quick replies for common actions
- Set up analytics dashboard
