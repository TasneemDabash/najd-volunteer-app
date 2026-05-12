-- Najd Volunteer — Locations, presence, voice messages & calls migration
-- Safe / idempotent: can be run multiple times.
--
-- Adds:
--   1. public.locations (controlled location picker + coordinates)
--   2. profiles.is_online / is_available / last_seen / current_location_id / latitude / longitude
--   3. tasks.location_id / latitude / longitude
--   4. trigger: notify volunteers on task_assignments insert
--   5. trigger: notify assigned volunteers on task status update
--   6. support_chat_messages.media_type / media_url / duration_ms (voice notes)
--   7. public.call_sessions (voice/video signalling state)
--   8. RPCs: list_volunteers_for_coordinator (with online/availability/distance),
--           set_my_presence, get_nearest_volunteers, start_call, end_call,
--           list_my_assigned_tasks
--   9. Storage bucket `voice-messages` (run via Supabase dashboard if SQL fails)
--
-- Run after migrate_profiles_based_mvp.sql in Supabase SQL Editor.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) LOCATIONS (controlled picker, optional coordinates)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  region text NOT NULL DEFAULT '',
  latitude double precision NULL,
  longitude double precision NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_locations_name_region
  ON public.locations (lower(trim(name)), lower(trim(region)));

CREATE INDEX IF NOT EXISTS idx_locations_active ON public.locations (is_active);

-- Seed common locations (idempotent via ON CONFLICT)
INSERT INTO public.locations (name, region, latitude, longitude) VALUES
  ('Ramallah',     'West Bank', 31.9038, 35.2034),
  ('Nablus',       'West Bank', 32.2211, 35.2544),
  ('Hebron',       'West Bank', 31.5326, 35.0998),
  ('Bethlehem',    'West Bank', 31.7054, 35.2024),
  ('Jenin',        'West Bank', 32.4634, 35.2956),
  ('Tulkarm',      'West Bank', 32.3104, 35.0286),
  ('Qalqilya',     'West Bank', 32.1896, 34.9706),
  ('Jericho',      'West Bank', 31.8569, 35.4444),
  ('Salfit',       'West Bank', 32.0850, 35.1804),
  ('Tubas',        'West Bank', 32.3211, 35.3697),
  ('East Jerusalem','Jerusalem', 31.7833, 35.2333),
  ('Gaza City',    'Gaza',      31.5018, 34.4663),
  ('Khan Younis',  'Gaza',      31.3417, 34.3046),
  ('Rafah',        'Gaza',      31.2939, 34.2433),
  ('Deir al-Balah','Gaza',      31.4181, 34.3505)
ON CONFLICT (lower(trim(name)), lower(trim(region))) DO NOTHING;

ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='locations' AND policyname='locations_read_all'
  ) THEN
    CREATE POLICY locations_read_all
    ON public.locations
    FOR SELECT
    TO authenticated
    USING (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='locations' AND policyname='locations_admin_write'
  ) THEN
    CREATE POLICY locations_admin_write
    ON public.locations
    FOR ALL
    TO authenticated
    USING (public.is_profile_admin())
    WITH CHECK (public.is_profile_admin());
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) PROFILES — presence + location fields
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_online boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_available boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS last_seen timestamptz NULL,
  ADD COLUMN IF NOT EXISTS current_location_id uuid NULL,
  ADD COLUMN IF NOT EXISTS latitude double precision NULL,
  ADD COLUMN IF NOT EXISTS longitude double precision NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'profiles_current_location_fk'
      AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_current_location_fk
      FOREIGN KEY (current_location_id) REFERENCES public.locations (id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_profiles_online ON public.profiles (is_online);
CREATE INDEX IF NOT EXISTS idx_profiles_available ON public.profiles (is_available);
CREATE INDEX IF NOT EXISTS idx_profiles_current_location ON public.profiles (current_location_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) TASKS — location_id + coordinates
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS location_id uuid NULL,
  ADD COLUMN IF NOT EXISTS latitude double precision NULL,
  ADD COLUMN IF NOT EXISTS longitude double precision NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'tasks_location_fk'
      AND conrelid = 'public.tasks'::regclass
  ) THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_location_fk
      FOREIGN KEY (location_id) REFERENCES public.locations (id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_tasks_location ON public.tasks (location_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4) NOTIFICATIONS — service-side inserts (bypass RLS) need a helper
-- ─────────────────────────────────────────────────────────────────────────────

-- Allow coordinators/triggers to insert notifications for other users.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='notifications' AND policyname='notifications_insert_coordinator'
  ) THEN
    CREATE POLICY notifications_insert_coordinator
    ON public.notifications
    FOR INSERT
    TO authenticated
    WITH CHECK (public.is_profile_coordinator());
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5) TASK ASSIGNMENT NOTIFICATIONS (trigger)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_volunteer_on_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  task_title text;
BEGIN
  SELECT title INTO task_title FROM public.tasks WHERE id = NEW.task_id;
  IF task_title IS NULL THEN
    task_title := 'A task';
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, task_id)
  VALUES (
    NEW.volunteer_id,
    'New task assigned',
    'You have been assigned: ' || task_title,
    'task_assignment',
    NEW.task_id
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_volunteer_on_assignment ON public.task_assignments;
CREATE TRIGGER trg_notify_volunteer_on_assignment
AFTER INSERT ON public.task_assignments
FOR EACH ROW
EXECUTE FUNCTION public.notify_volunteer_on_assignment();

-- ─────────────────────────────────────────────────────────────────────────────
-- 6) TASK STATUS NOTIFICATIONS (trigger)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_volunteers_on_task_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  snippet text;
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    snippet := 'Task "' || coalesce(NEW.title, '(untitled)') || '" is now ' || NEW.status || '.';
    INSERT INTO public.notifications (user_id, title, body, type, task_id)
    SELECT ta.volunteer_id,
           'Task status updated',
           snippet,
           'task_status',
           NEW.id
    FROM public.task_assignments ta
    WHERE ta.task_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_volunteers_on_task_status ON public.tasks;
CREATE TRIGGER trg_notify_volunteers_on_task_status
AFTER UPDATE ON public.tasks
FOR EACH ROW
EXECUTE FUNCTION public.notify_volunteers_on_task_status();

-- ─────────────────────────────────────────────────────────────────────────────
-- 7) SUPPORT CHAT — voice / media columns
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.support_chat_messages
  ADD COLUMN IF NOT EXISTS media_type text NULL,
  ADD COLUMN IF NOT EXISTS media_url text NULL,
  ADD COLUMN IF NOT EXISTS duration_ms int NULL;

-- Body becomes nullable when a voice message is attached
ALTER TABLE public.support_chat_messages
  ALTER COLUMN body DROP NOT NULL;

-- Allow voice-only submission via RPC
CREATE OR REPLACE FUNCTION public.submit_support_voice_message(
  p_media_url text,
  p_duration_ms int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  mid uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF p_media_url IS NULL OR length(trim(p_media_url)) < 1 THEN
    RAISE EXCEPTION 'media url required' USING ERRCODE = '22023';
  END IF;

  PERFORM public.ensure_support_thread(auth.uid());

  INSERT INTO public.support_chat_messages
    (thread_volunteer_id, sender_id, body, media_type, media_url, duration_ms)
  VALUES (auth.uid(), auth.uid(), NULL, 'audio', p_media_url, p_duration_ms)
  RETURNING id INTO mid;

  UPDATE public.support_threads
  SET last_message_at = now(), updated_at = now()
  WHERE volunteer_id = auth.uid();

  INSERT INTO public.notifications (user_id, title, body, type)
  SELECT pr.id, 'New voice message from a volunteer', '🎙 Voice message', 'support_message'
  FROM public.profiles pr
  WHERE lower(trim(coalesce(pr.role::text, ''))) IN ('admin', 'support');

  RETURN mid;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_support_voice_message(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_support_voice_message(text, int) TO authenticated;

CREATE OR REPLACE FUNCTION public.support_reply_voice(
  p_volunteer_id uuid,
  p_media_url text,
  p_duration_ms int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  mid uuid;
BEGIN
  IF NOT public.is_profile_coordinator() THEN
    RAISE EXCEPTION 'only admin or support can reply' USING ERRCODE = '42501';
  END IF;
  IF p_media_url IS NULL OR length(trim(p_media_url)) < 1 THEN
    RAISE EXCEPTION 'media url required' USING ERRCODE = '22023';
  END IF;

  PERFORM public.ensure_support_thread(p_volunteer_id);

  INSERT INTO public.support_chat_messages
    (thread_volunteer_id, sender_id, body, media_type, media_url, duration_ms)
  VALUES (p_volunteer_id, auth.uid(), NULL, 'audio', p_media_url, p_duration_ms)
  RETURNING id INTO mid;

  UPDATE public.support_threads
  SET last_message_at = now(), updated_at = now()
  WHERE volunteer_id = p_volunteer_id;

  INSERT INTO public.notifications (user_id, title, body, type)
  VALUES (p_volunteer_id, 'Support sent a voice message', '🎙 Voice message', 'support_reply');

  RETURN mid;
END;
$$;

REVOKE ALL ON FUNCTION public.support_reply_voice(uuid, text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.support_reply_voice(uuid, text, int) TO authenticated;

-- Replace list functions to include media columns
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

-- ─────────────────────────────────────────────────────────────────────────────
-- 8) CALL SESSIONS (voice/video signalling state)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.call_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  caller_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  callee_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  call_type text NOT NULL DEFAULT 'voice',
  status text NOT NULL DEFAULT 'ringing',
  channel_name text NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  answered_at timestamptz NULL,
  ended_at timestamptz NULL
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname='call_sessions_type_check' AND conrelid='public.call_sessions'::regclass
  ) THEN
    ALTER TABLE public.call_sessions
      ADD CONSTRAINT call_sessions_type_check
      CHECK (lower(trim(call_type)) IN ('voice','video'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname='call_sessions_status_check' AND conrelid='public.call_sessions'::regclass
  ) THEN
    ALTER TABLE public.call_sessions
      ADD CONSTRAINT call_sessions_status_check
      CHECK (lower(trim(status)) IN ('ringing','answered','declined','ended','missed','cancelled'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_call_sessions_caller ON public.call_sessions (caller_id);
CREATE INDEX IF NOT EXISTS idx_call_sessions_callee ON public.call_sessions (callee_id);
CREATE INDEX IF NOT EXISTS idx_call_sessions_started ON public.call_sessions (started_at DESC);

ALTER TABLE public.call_sessions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='call_sessions' AND policyname='call_sessions_select_party'
  ) THEN
    CREATE POLICY call_sessions_select_party
    ON public.call_sessions
    FOR SELECT
    TO authenticated
    USING (auth.uid() IN (caller_id, callee_id) OR public.is_profile_coordinator());
  END IF;
END $$;

-- Direct writes blocked — go through RPCs below
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='call_sessions' AND policyname='call_sessions_no_direct_write'
  ) THEN
    CREATE POLICY call_sessions_no_direct_write
    ON public.call_sessions
    FOR INSERT
    TO authenticated
    WITH CHECK (false);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.start_call(
  p_callee_id uuid,
  p_call_type text
)
RETURNS public.call_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cs public.call_sessions;
  ctype text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF p_callee_id IS NULL OR p_callee_id = auth.uid() THEN
    RAISE EXCEPTION 'invalid callee' USING ERRCODE = '22023';
  END IF;

  ctype := coalesce(lower(trim(p_call_type)), 'voice');
  IF ctype NOT IN ('voice','video') THEN
    ctype := 'voice';
  END IF;

  INSERT INTO public.call_sessions
    (caller_id, callee_id, call_type, status, channel_name)
  VALUES
    (auth.uid(), p_callee_id, ctype, 'ringing',
     'najd_' || replace(gen_random_uuid()::text, '-', ''))
  RETURNING * INTO cs;

  INSERT INTO public.notifications (user_id, title, body, type, task_id)
  VALUES (
    p_callee_id,
    'Incoming ' || ctype || ' call',
    'Tap to answer.',
    'call_' || ctype,
    NULL
  );

  RETURN cs;
END;
$$;

REVOKE ALL ON FUNCTION public.start_call(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_call(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.update_call_status(
  p_call_id uuid,
  p_status text
)
RETURNS public.call_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cs public.call_sessions;
  s text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  s := coalesce(lower(trim(p_status)), '');
  IF s NOT IN ('answered','declined','ended','missed','cancelled') THEN
    RAISE EXCEPTION 'invalid status' USING ERRCODE = '22023';
  END IF;

  UPDATE public.call_sessions
  SET
    status = s,
    answered_at = CASE WHEN s = 'answered' AND answered_at IS NULL THEN now() ELSE answered_at END,
    ended_at   = CASE WHEN s IN ('ended','declined','missed','cancelled') THEN now() ELSE ended_at END
  WHERE id = p_call_id
    AND auth.uid() IN (caller_id, callee_id)
  RETURNING * INTO cs;

  IF cs IS NULL THEN
    RAISE EXCEPTION 'call not found or not yours' USING ERRCODE = 'P0002';
  END IF;
  RETURN cs;
END;
$$;

REVOKE ALL ON FUNCTION public.update_call_status(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_call_status(uuid, text) TO authenticated;

-- Realtime publication (best-effort)
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.call_sessions;
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9) PRESENCE RPCs
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_my_presence(
  p_is_online boolean DEFAULT NULL,
  p_is_available boolean DEFAULT NULL,
  p_current_location_id uuid DEFAULT NULL,
  p_latitude double precision DEFAULT NULL,
  p_longitude double precision DEFAULT NULL
)
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  pr public.profiles;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;

  UPDATE public.profiles
  SET
    is_online           = COALESCE(p_is_online, is_online),
    is_available        = COALESCE(p_is_available, is_available),
    current_location_id = COALESCE(p_current_location_id, current_location_id),
    latitude            = COALESCE(p_latitude, latitude),
    longitude           = COALESCE(p_longitude, longitude),
    last_seen           = now(),
    updated_at          = now()
  WHERE id = auth.uid()
  RETURNING * INTO pr;

  RETURN pr;
END;
$$;

REVOKE ALL ON FUNCTION public.set_my_presence(boolean, boolean, uuid, double precision, double precision) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_my_presence(boolean, boolean, uuid, double precision, double precision) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 10) Coordinator listing with computed distance and joined location
-- ─────────────────────────────────────────────────────────────────────────────
-- Haversine distance helper (kilometers)
CREATE OR REPLACE FUNCTION public.haversine_km(
  lat1 double precision, lon1 double precision,
  lat2 double precision, lon2 double precision
)
RETURNS double precision
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  r double precision := 6371.0; -- Earth radius in km
  dlat double precision;
  dlon double precision;
  a double precision;
BEGIN
  IF lat1 IS NULL OR lon1 IS NULL OR lat2 IS NULL OR lon2 IS NULL THEN
    RETURN NULL;
  END IF;
  dlat := radians(lat2 - lat1);
  dlon := radians(lon2 - lon1);
  a := sin(dlat/2) * sin(dlat/2)
     + cos(radians(lat1)) * cos(radians(lat2))
     * sin(dlon/2) * sin(dlon/2);
  RETURN 2 * r * asin(sqrt(a));
END;
$$;

DROP FUNCTION IF EXISTS public.list_volunteers_for_coordinator(double precision, double precision);
CREATE OR REPLACE FUNCTION public.list_volunteers_for_coordinator(
  p_origin_lat double precision DEFAULT NULL,
  p_origin_lon double precision DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  full_name text,
  email text,
  phone text,
  city text,
  skills text[],
  availability text[],
  notes text,
  role text,
  status text,
  is_online boolean,
  is_available boolean,
  last_seen timestamptz,
  current_location_id uuid,
  latitude double precision,
  longitude double precision,
  location_name text,
  location_region text,
  distance_km double precision,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_profile_coordinator() THEN
    RAISE EXCEPTION 'only admin or support can list volunteers' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    pr.id, pr.full_name, pr.email, pr.phone, pr.city, pr.skills, pr.availability,
    pr.notes, pr.role, pr.status, pr.is_online, pr.is_available, pr.last_seen,
    pr.current_location_id, pr.latitude, pr.longitude,
    l.name, l.region,
    public.haversine_km(
      p_origin_lat, p_origin_lon,
      COALESCE(pr.latitude, l.latitude),
      COALESCE(pr.longitude, l.longitude)
    ) AS distance_km,
    pr.created_at, pr.updated_at
  FROM public.profiles pr
  LEFT JOIN public.locations l ON l.id = pr.current_location_id
  ORDER BY
    CASE WHEN p_origin_lat IS NOT NULL AND p_origin_lon IS NOT NULL
         THEN public.haversine_km(p_origin_lat, p_origin_lon,
                                  COALESCE(pr.latitude, l.latitude),
                                  COALESCE(pr.longitude, l.longitude))
         ELSE NULL END NULLS LAST,
    pr.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_volunteers_for_coordinator(double precision, double precision) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_volunteers_for_coordinator(double precision, double precision) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 11) Volunteer: list my assigned tasks
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.list_my_assigned_tasks();
CREATE OR REPLACE FUNCTION public.list_my_assigned_tasks()
RETURNS TABLE (
  id uuid,
  title text,
  description text,
  location text,
  location_id uuid,
  location_name text,
  latitude double precision,
  longitude double precision,
  required_skills text[],
  date timestamptz,
  status text,
  created_at timestamptz,
  assigned_at timestamptz
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
  SELECT t.id, t.title, t.description, t.location, t.location_id, l.name,
         t.latitude, t.longitude, t.required_skills, t.date, t.status,
         t.created_at, ta.assigned_at
  FROM public.task_assignments ta
  JOIN public.tasks t ON t.id = ta.task_id
  LEFT JOIN public.locations l ON l.id = t.location_id
  WHERE ta.volunteer_id = auth.uid()
  ORDER BY t.date DESC NULLS LAST, t.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_my_assigned_tasks() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_my_assigned_tasks() TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 12) Tighten task_assignments writes (coordinator only) but still allow volunteer
--     to read their own assignments
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  pol text;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname='public' AND tablename='task_assignments'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.task_assignments', pol);
  END LOOP;
END $$;

CREATE POLICY task_assignments_select_self_or_coordinator
ON public.task_assignments
FOR SELECT
TO authenticated
USING (auth.uid() = volunteer_id OR public.is_profile_coordinator());

CREATE POLICY task_assignments_modify_coordinator
ON public.task_assignments
FOR ALL
TO authenticated
USING (public.is_profile_coordinator())
WITH CHECK (public.is_profile_coordinator());

-- ─────────────────────────────────────────────────────────────────────────────
-- 13) Storage bucket for voice messages (idempotent; ignored if not allowed)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='storage' AND table_name='buckets') THEN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('voice-messages', 'voice-messages', true)
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- Public read of voice files, authenticated upload to own folder.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='storage' AND table_name='objects') THEN
    -- read
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects'
        AND policyname='voice_messages_public_read'
    ) THEN
      CREATE POLICY voice_messages_public_read
      ON storage.objects
      FOR SELECT
      TO public
      USING (bucket_id = 'voice-messages');
    END IF;
    -- write (authenticated, own folder = auth.uid())
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects'
        AND policyname='voice_messages_owner_insert'
    ) THEN
      CREATE POLICY voice_messages_owner_insert
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'voice-messages'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
    END IF;
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 14) PostgREST schema cache refresh
-- ─────────────────────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
