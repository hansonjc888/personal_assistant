#!/bin/bash

# AI Personal Assistant - Telegram Webhook Setup Script
# This script configures the Telegram webhook to point to your n8n instance

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
WEBHOOK_URL="${N8N_WEBHOOK_URL}/telegram-bot"
SECRET_TOKEN="${TELEGRAM_SECRET_TOKEN:-}"

# Usage
usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Set or update Telegram webhook for the AI Personal Assistant bot.

Options:
  -t, --token TOKEN       Bot token (or set TELEGRAM_BOT_TOKEN env var)
  -u, --url URL          Webhook URL (or set N8N_WEBHOOK_URL env var)
  -s, --secret SECRET    Secret token for webhook validation (optional)
  -d, --delete           Delete the current webhook
  -i, --info             Show current webhook info
  -h, --help             Show this help message

Examples:
  # Set webhook using environment variables
  export TELEGRAM_BOT_TOKEN="123:ABC"
  export N8N_WEBHOOK_URL="https://n8n.example.com/webhook"
  $0

  # Set webhook with command-line arguments
  $0 -t "123:ABC" -u "https://n8n.example.com/webhook"

  # Delete webhook
  $0 -d

  # Show webhook info
  $0 -i

Environment Variables:
  TELEGRAM_BOT_TOKEN    Telegram bot token from @BotFather
  N8N_WEBHOOK_URL       Base URL of your n8n webhook endpoint
  TELEGRAM_SECRET_TOKEN Optional secret token for validation

EOF
  exit 1
}

# Parse arguments
ACTION="set"
while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--token)
      BOT_TOKEN="$2"
      shift 2
      ;;
    -u|--url)
      WEBHOOK_URL="$2/telegram-bot"
      shift 2
      ;;
    -s|--secret)
      SECRET_TOKEN="$2"
      shift 2
      ;;
    -d|--delete)
      ACTION="delete"
      shift
      ;;
    -i|--info)
      ACTION="info"
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      usage
      ;;
  esac
done

# Validate required variables
if [ -z "$BOT_TOKEN" ]; then
  echo -e "${RED}Error: TELEGRAM_BOT_TOKEN is not set${NC}"
  echo "Set it via environment variable or use -t option"
  exit 1
fi

# Telegram API base URL
API_URL="https://api.telegram.org/bot${BOT_TOKEN}"

# Function: Get webhook info
get_webhook_info() {
  echo -e "${YELLOW}Fetching webhook information...${NC}\n"

  RESPONSE=$(curl -s "${API_URL}/getWebhookInfo")

  # Pretty print with jq if available
  if command -v jq &> /dev/null; then
    echo "$RESPONSE" | jq .
  else
    echo "$RESPONSE"
  fi
}

# Function: Delete webhook
delete_webhook() {
  echo -e "${YELLOW}Deleting current webhook...${NC}\n"

  RESPONSE=$(curl -s -X POST "${API_URL}/deleteWebhook?drop_pending_updates=true")

  if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo -e "${GREEN}✓ Webhook deleted successfully${NC}\n"
  else
    echo -e "${RED}✗ Failed to delete webhook${NC}"
    echo "$RESPONSE"
    exit 1
  fi

  get_webhook_info
}

# Function: Set webhook
set_webhook() {
  if [ -z "$WEBHOOK_URL" ]; then
    echo -e "${RED}Error: Webhook URL is not set${NC}"
    echo "Set N8N_WEBHOOK_URL environment variable or use -u option"
    exit 1
  fi

  echo -e "${YELLOW}Setting webhook to: ${NC}${WEBHOOK_URL}\n"

  # Build JSON payload
  PAYLOAD=$(cat <<EOF
{
  "url": "${WEBHOOK_URL}",
  "allowed_updates": ["message", "callback_query"],
  "drop_pending_updates": true
EOF
)

  # Add secret token if provided
  if [ -n "$SECRET_TOKEN" ]; then
    PAYLOAD="${PAYLOAD},
  \"secret_token\": \"${SECRET_TOKEN}\""
    echo -e "${GREEN}✓ Using secret token for webhook validation${NC}"
  fi

  PAYLOAD="${PAYLOAD}
}"

  # Set webhook
  RESPONSE=$(curl -s -X POST \
    "${API_URL}/setWebhook" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  # Check response
  if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo -e "${GREEN}✓ Webhook set successfully!${NC}\n"
  else
    echo -e "${RED}✗ Failed to set webhook${NC}"
    echo "$RESPONSE"
    exit 1
  fi

  # Verify
  echo -e "${YELLOW}Verifying webhook configuration...${NC}\n"
  get_webhook_info

  # Test webhook endpoint
  echo -e "\n${YELLOW}Testing webhook endpoint accessibility...${NC}\n"

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d '{"update_id":1,"message":{"message_id":1,"from":{"id":1},"chat":{"id":1},"text":"test"}}' || echo "000")

  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
    echo -e "${GREEN}✓ Webhook endpoint is accessible (HTTP $HTTP_CODE)${NC}"
  else
    echo -e "${RED}⚠ Warning: Webhook endpoint returned HTTP $HTTP_CODE${NC}"
    echo "This might be normal if n8n requires specific headers."
    echo "Send a test message to your bot to verify it works."
  fi

  # Success message
  echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}✓ Webhook setup complete!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  echo -e "Next steps:"
  echo -e "  1. Send a message to your bot on Telegram"
  echo -e "  2. Check n8n execution logs for incoming webhooks"
  echo -e "  3. Verify command is created in database:\n"
  echo -e "     ${YELLOW}sqlite3 \$DATABASE_PATH 'SELECT * FROM commands;'${NC}\n"
}

# Execute action
case $ACTION in
  set)
    set_webhook
    ;;
  delete)
    delete_webhook
    ;;
  info)
    get_webhook_info
    ;;
esac
