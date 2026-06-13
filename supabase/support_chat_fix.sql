-- ============================================================================
-- Support Chat Fix - Run this in Supabase SQL Editor
-- ============================================================================

-- 1) Create the support_chat_messages table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.support_chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_volunteer_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2) Add media columns if they don't exist
ALTER TABLE public.support_chat_messages
  ADD COLUMN IF NOT EXISTS media_type TEXT,
  ADD COLUMN IF NOT EXISTS media_url TEXT,
  ADD COLUMN IF NOT EXISTS duration_ms INT;

-- 3) Create index for performance
CREATE INDEX IF NOT EXISTS idx_support_chat_thread_created
  ON public.support_chat_messages (thread_volunteer_id, created_at ASC);

-- 4) Enable RLS
ALTER TABLE public.support_chat_messages ENABLE ROW LEVEL SECURITY;

-- 5) RLS Policies
DROP POLICY IF EXISTS "support_chat_select_volunteer" ON public.support_chat_messages;
CREATE POLICY "support_chat_select_volunteer"
ON public.support_chat_messages FOR SELECT TO authenticated
USING (auth.uid() = thread_volunteer_id);

DROP POLICY IF EXISTS "support_chat_select_coordinator" ON public.support_chat_messages;
CREATE POLICY "support_chat_select_coordinator"
ON public.support_chat_messages FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND lower(trim(coalesce(p.role::text, ''))) IN ('admin', 'support')
  )
);

DROP POLICY IF EXISTS "support_chat_insert_own" ON public.support_chat_messages;
CREATE POLICY "support_chat_insert_own"
ON public.support_chat_messages FOR INSERT TO authenticated
WITH CHECK (auth.uid() = sender_id);

GRANT SELECT, INSERT ON public.support_chat_messages TO authenticated;

-- 6) Helper function to check if user is coordinator/admin/support
CREATE OR REPLACE FUNCTION public.is_profile_coordinator()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND lower(trim(coalesce(role::text, ''))) IN ('admin', 'support', 'coordinator')
  );
END;
$$;

-- 7) Volunteer: list own chat messages
DROP FUNCTION IF EXISTS public.list_my_support_chat();
CREATE OR REPLACE FUNCTION public.list_my_support_chat()
RETURNS TABLE (
  id uuid,
  thread_volunteer_id uuid,
  sender_id uuid,
  body text,
  media_type text,
  media_url text,
  duration_ms int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  RETURN QUERY
  SELECT m.id, m.thread_volunteer_id, m.sender_id, m.body,
         m.media_type, m.media_url, m.duration_ms, m.created_at
  FROM public.support_chat_messages m
  WHERE m.thread_volunteer_id = auth.uid()
  ORDER BY m.created_at ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_my_support_chat() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_my_support_chat() TO authenticated;

-- 8) Coordinator: list messages for a specific volunteer thread
DROP FUNCTION IF EXISTS public.list_support_chat_thread(uuid);
CREATE OR REPLACE FUNCTION public.list_support_chat_thread(p_volunteer_id uuid)
RETURNS TABLE (
  id uuid,
  thread_volunteer_id uuid,
  sender_id uuid,
  body text,
  media_type text,
  media_url text,
  duration_ms int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_profile_coordinator() THEN
    RAISE EXCEPTION 'only admin or support can read support threads' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT m.id, m.thread_volunteer_id, m.sender_id, m.body,
         m.media_type, m.media_url, m.duration_ms, m.created_at
  FROM public.support_chat_messages m
  WHERE m.thread_volunteer_id = p_volunteer_id
  ORDER BY m.created_at ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_support_chat_thread(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_support_chat_thread(uuid) TO authenticated;

-- 9) Volunteer: send a message in their own thread
DROP FUNCTION IF EXISTS public.volunteer_send_support_chat(text);
CREATE OR REPLACE FUNCTION public.volunteer_send_support_chat(p_body text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  INSERT INTO public.support_chat_messages (thread_volunteer_id, sender_id, body)
  VALUES (auth.uid(), auth.uid(), p_body)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.volunteer_send_support_chat(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.volunteer_send_support_chat(text) TO authenticated;

-- 10) Coordinator: reply to a volunteer's thread
DROP FUNCTION IF EXISTS public.support_reply_chat(uuid, text);
CREATE OR REPLACE FUNCTION public.support_reply_chat(p_volunteer_id uuid, p_body text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_profile_coordinator() THEN
    RAISE EXCEPTION 'only admin or support can reply' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.support_chat_messages (thread_volunteer_id, sender_id, body)
  VALUES (p_volunteer_id, auth.uid(), p_body)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.support_reply_chat(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.support_reply_chat(uuid, text) TO authenticated;

-- 11) Enable realtime for support_chat_messages (optional - may error if already added)
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.support_chat_messages;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;
