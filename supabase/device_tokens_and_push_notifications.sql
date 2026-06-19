-- Device tokens table for FCM push notifications
-- Run this in your Supabase SQL Editor

-- Create device_tokens table
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- Enable RLS
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for re-running this script)
DROP POLICY IF EXISTS "Users can insert own tokens" ON device_tokens;
DROP POLICY IF EXISTS "Users can update own tokens" ON device_tokens;
DROP POLICY IF EXISTS "Users can delete own tokens" ON device_tokens;
DROP POLICY IF EXISTS "Users can read own tokens" ON device_tokens;
DROP POLICY IF EXISTS "Service role can read all tokens" ON device_tokens;

-- Users can manage their own tokens
CREATE POLICY "Users can insert own tokens" ON device_tokens
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tokens" ON device_tokens
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own tokens" ON device_tokens
    FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can read own tokens" ON device_tokens
    FOR SELECT USING (auth.uid() = user_id);

-- Service role can read all tokens (for sending notifications)
CREATE POLICY "Service role can read all tokens" ON device_tokens
    FOR SELECT USING (auth.role() = 'service_role');

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);

-- Function to get all volunteer device tokens (for broadcasting)
CREATE OR REPLACE FUNCTION get_volunteer_device_tokens()
RETURNS TABLE(token TEXT, platform TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT dt.token, dt.platform
    FROM device_tokens dt
    JOIN profiles p ON p.id = dt.user_id
    WHERE p.role = 'volunteer';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to notify volunteers when a new task is published
-- This will be called by an Edge Function or database trigger
CREATE OR REPLACE FUNCTION notify_new_task()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert notification for all volunteers
    INSERT INTO notifications (user_id, type, title, body, data)
    SELECT
        p.id,
        'new_task',
        'مهمة جديدة متاحة',
        NEW.title,
        jsonb_build_object('task_id', NEW.id)
    FROM profiles p
    WHERE p.role = 'volunteer';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create in-app notifications when task is published
-- Uncomment if you want automatic in-app notifications
-- CREATE TRIGGER on_task_published
--     AFTER INSERT ON tasks
--     FOR EACH ROW
--     WHEN (NEW.status = 'published')
--     EXECUTE FUNCTION notify_new_task();

-- ============================================================================
-- SETUP INSTRUCTIONS FOR PUSH NOTIFICATIONS
-- ============================================================================
--
-- 1. Run this SQL in Supabase SQL Editor to create the device_tokens table
--
-- 2. Get your FCM Server Key from Firebase Console:
--    - Go to Firebase Console → Project Settings → Cloud Messaging
--    - Copy the "Server key" (legacy)
--
-- 3. Deploy the Edge Function:
--    supabase functions deploy send-push-notification
--
-- 4. Set the FCM_SERVER_KEY secret:
--    supabase secrets set FCM_SERVER_KEY=your_fcm_server_key
--
-- 5. Set up a Database Webhook in Supabase Dashboard:
--    - Go to Database → Webhooks → Create webhook
--    - Table: tasks
--    - Events: INSERT
--    - URL: https://YOUR_PROJECT.supabase.co/functions/v1/send-push-notification
--    - Headers: Authorization: Bearer YOUR_SERVICE_ROLE_KEY
--    - Body: {"title": "مهمة جديدة متاحة", "body": "{{record.title}}"}
-- ============================================================================
