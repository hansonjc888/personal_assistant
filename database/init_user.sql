-- Initialize default user record for Phase 1 MVP
-- This creates a single-user setup for the personal assistant

-- Insert default user (update values as needed)
INSERT OR IGNORE INTO users (
    user_id,
    channel,
    timezone,
    telegram_chat_id
) VALUES (
    'default_user',
    'telegram',
    'America/New_York',  -- Update to your timezone
    NULL  -- Will be populated from first message
);

-- Verify user creation
SELECT * FROM users;
