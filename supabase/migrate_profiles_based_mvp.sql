-- Najd Volunteer — Profiles-based single-source-of-truth migration
-- Safe / idempotent: can be run multiple times.
--
-- Goals:
-- 1) Ensure public.profiles exists with all app-required columns
-- 2) Align tasks + task_assignments + notifications with Flutter code
-- 3) Add support inbox MVP (thread status/priority/assigned staff) + chat messages
-- 4) Install understandable RLS policies
-- 5) Install secure RPCs for admin/support coordinator flows
-- 6) Refresh PostgREST schema cache
--
-- Run in Supabase SQL Editor (same project as lib/config/app_config.dart).

-- Extensions (safe)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) PROFILES (single source of truth)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  full_name text NOT NULL DEFAULT '',
  email text NOT NULL DEFAULT '',
  phone text NOT NULL DEFAULT '',
  city text NOT NULL DEFAULT '',
  skills text[] NOT NULL DEFAULT '{}'::text[],
  availability text[] NOT NULL DEFAULT '{}'::text[],
  notes text NULL,
  role text NOT NULL DEFAULT 'volunteer',
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Add missing columns if the table already existed with fewer fields
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS full_name text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS email text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS phone text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS city text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS skills text[] NOT NULL DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS availability text[] NOT NULL DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS notes text NULL,
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'volunteer',
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- Light constraints (idempotent via DO blocks)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'profiles_role_check'
      AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_role_check
      CHECK (lower(trim(role)) IN ('volunteer', 'support', 'admin'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'profiles_status_check'
      AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_status_check
      CHECK (lower(trim(status)) IN ('active', 'inactive', 'deactivated'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles (role);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON public.profiles (created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) TASKS + ASSIGNMENTS (profiles-based)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NULL,
  location text NULL,
  required_skills text[] NOT NULL DEFAULT '{}'::text[],
  date timestamptz NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS location text,
  ADD COLUMN IF NOT EXISTS required_skills text[] NOT NULL DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS date timestamptz,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'tasks_status_check'
      AND conrelid = 'public.tasks'::regclass
  ) THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_status_check
      CHECK (lower(trim(status)) IN ('pending', 'active', 'completed'));
  END IF;
END $$;

-- Backfill scheduled date (non-destructive)
UPDATE public.tasks
SET date = COALESCE(date, created_at, now())
WHERE date IS NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks (status);
CREATE INDEX IF NOT EXISTS idx_tasks_date ON public.tasks (date DESC);

CREATE TABLE IF NOT EXISTS public.task_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES public.tasks (id) ON DELETE CASCADE,
  volunteer_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (task_id, volunteer_id)
);

ALTER TABLE public.task_assignments
  ADD COLUMN IF NOT EXISTS task_id uuid,
  ADD COLUMN IF NOT EXISTS volunteer_id uuid,
  ADD COLUMN IF NOT EXISTS assigned_at timestamptz NOT NULL DEFAULT now();

-- Ensure task_assignments.volunteer_id references public.profiles (not public.volunteers)
DO $$
DECLARE
  c record;
BEGIN
  -- Drop any existing foreign keys on volunteer_id that reference another table (e.g. public.volunteers)
  FOR c IN
    SELECT con.conname
    FROM pg_constraint con
    JOIN pg_attribute att
      ON att.attrelid = con.conrelid
     AND att.attnum = ANY (con.conkey)
    WHERE con.contype = 'f'
      AND con.conrelid = 'public.task_assignments'::regclass
      AND att.attname = 'volunteer_id'
  LOOP
    EXECUTE format('ALTER TABLE public.task_assignments DROP CONSTRAINT IF EXISTS %I', c.conname);
  END LOOP;

  -- Add correct FK if missing
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE contype = 'f'
      AND conrelid = 'public.task_assignments'::regclass
      AND confrelid = 'public.profiles'::regclass
      AND conname = 'task_assignments_volunteer_id_fkey_profiles'
  ) THEN
    ALTER TABLE public.task_assignments
      ADD CONSTRAINT task_assignments_volunteer_id_fkey_profiles
      FOREIGN KEY (volunteer_id) REFERENCES public.profiles (id) ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_task_assignments_task ON public.task_assignments (task_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_volunteer ON public.task_assignments (volunteer_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) NOTIFICATIONS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  type text NULL,
  task_id uuid NULL REFERENCES public.tasks (id) ON DELETE SET NULL,
  read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS user_id uuid,
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS body text,
  ADD COLUMN IF NOT EXISTS type text,
  ADD COLUMN IF NOT EXISTS task_id uuid,
  ADD COLUMN IF NOT EXISTS read boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4) SUPPORT INBOX + CHAT (MVP fields)
-- ─────────────────────────────────────────────────────────────────────────────

-- Threads table: one per volunteer; holds status/priority/assigned staff (MVP)
CREATE TABLE IF NOT EXISTS public.support_threads (
  volunteer_id uuid PRIMARY KEY REFERENCES public.profiles (id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'open',
  priority text NOT NULL DEFAULT 'normal',
  assigned_staff_id uuid NULL REFERENCES public.profiles (id) ON DELETE SET NULL,
  last_message_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.support_threads
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'open',
  ADD COLUMN IF NOT EXISTS priority text NOT NULL DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS assigned_staff_id uuid NULL,
  ADD COLUMN IF NOT EXISTS last_message_at timestamptz NULL,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'support_threads_status_check'
      AND conrelid = 'public.support_threads'::regclass
  ) THEN
    ALTER TABLE public.support_threads
      ADD CONSTRAINT support_threads_status_check
      CHECK (lower(trim(status)) IN ('open', 'closed'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'support_threads_priority_check'
      AND conrelid = 'public.support_threads'::regclass
  ) THEN
    ALTER TABLE public.support_threads
      ADD CONSTRAINT support_threads_priority_check
      CHECK (lower(trim(priority)) IN ('low', 'normal', 'high', 'urgent'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_support_threads_last_at
  ON public.support_threads (last_message_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_support_threads_assigned
  ON public.support_threads (assigned_staff_id);

-- Messages: thread key is volunteer_id (same as existing Flutter design)
CREATE TABLE IF NOT EXISTS public.support_chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_volunteer_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.support_chat_messages
  ADD COLUMN IF NOT EXISTS thread_volunteer_id uuid,
  ADD COLUMN IF NOT EXISTS sender_id uuid,
  ADD COLUMN IF NOT EXISTS body text,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_support_chat_thread_created
  ON public.support_chat_messages (thread_volunteer_id, created_at ASC);

-- Realtime: enable in Dashboard → Database → Replication if INSERT events do not arrive.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.support_chat_messages;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
  WHEN undefined_object THEN
    -- Some projects may not have the publication available in SQL context; configure via Dashboard.
    NULL;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5) RLS POLICIES (profiles-based)
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_chat_messages ENABLE ROW LEVEL SECURITY;

-- Helpers: SECURITY DEFINER avoids RLS recursion when checking coordinator/admin role.
CREATE OR REPLACE FUNCTION public.is_profile_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND lower(trim(coalesce(role::text, ''))) = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_profile_coordinator()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND lower(trim(coalesce(role::text, ''))) IN ('admin', 'support')
  );
$$;

REVOKE ALL ON FUNCTION public.is_profile_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_profile_coordinator() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_profile_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_profile_coordinator() TO authenticated;

-- Reset policies on core tables (safe: drops only for the target table)
DO $$
DECLARE
  pol text;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='profiles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol);
  END LOOP;
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='notifications'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.notifications', pol);
  END LOOP;
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='support_threads'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.support_threads', pol);
  END LOOP;
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='support_chat_messages'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.support_chat_messages', pol);
  END LOOP;
END $$;

-- profiles: own row, coordinators can select all, admins can update all
CREATE POLICY profiles_select_own_or_coordinator
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id OR public.is_profile_coordinator());

CREATE POLICY profiles_insert_own
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

CREATE POLICY profiles_update_own
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY profiles_update_admin_any
ON public.profiles
FOR UPDATE
TO authenticated
USING (public.is_profile_admin())
WITH CHECK (public.is_profile_admin());

-- tasks + assignments: MVP-friendly (all authenticated can read/write)
-- If you want stricter rules later (volunteers read-only), we can tighten in Phase 2.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='tasks' AND policyname='tasks_all_authenticated'
  ) THEN
    CREATE POLICY tasks_all_authenticated
    ON public.tasks
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='task_assignments' AND policyname='task_assignments_all_authenticated'
  ) THEN
    CREATE POLICY task_assignments_all_authenticated
    ON public.task_assignments
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);
  END IF;
END $$;

-- notifications: each user can only see/update their own notifications
CREATE POLICY notifications_select_own
ON public.notifications
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY notifications_update_own
ON public.notifications
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY notifications_insert_own
ON public.notifications
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- support threads/messages:
-- - volunteer can select own thread/messages
-- - coordinators (admin/support) can select all
-- Writes happen via RPCs (SECURITY DEFINER), not direct inserts.
CREATE POLICY support_threads_select_volunteer
ON public.support_threads
FOR SELECT
TO authenticated
USING (auth.uid() = volunteer_id);

CREATE POLICY support_threads_select_coordinator
ON public.support_threads
FOR SELECT
TO authenticated
USING (public.is_profile_coordinator());

CREATE POLICY support_chat_select_volunteer
ON public.support_chat_messages
FOR SELECT
TO authenticated
USING (auth.uid() = thread_volunteer_id);

CREATE POLICY support_chat_select_coordinator
ON public.support_chat_messages
FOR SELECT
TO authenticated
USING (public.is_profile_coordinator());

-- ─────────────────────────────────────────────────────────────────────────────
-- 6) RPCs (admin/support coordinator flows + support chat)
-- ─────────────────────────────────────────────────────────────────────────────

-- Admins only — list all profiles (used by User management)
CREATE OR REPLACE FUNCTION public.admin_list_all_profiles()
RETURNS SETOF public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;

  IF NOT public.is_profile_admin() THEN
    RAISE EXCEPTION 'only admins can list all profiles' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT *
  FROM public.profiles
  ORDER BY created_at DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_all_profiles() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_all_profiles() TO authenticated;

-- Admin or support — list all profiles (directory/dashboard)
CREATE OR REPLACE FUNCTION public.list_profiles_for_coordinator()
RETURNS SETOF public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;

  IF NOT public.is_profile_coordinator() THEN
    RAISE EXCEPTION 'only admin or support can list profiles' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT *
  FROM public.profiles
  ORDER BY created_at DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.list_profiles_for_coordinator() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_profiles_for_coordinator() TO authenticated;

-- Admin-only update (role/status)
CREATE OR REPLACE FUNCTION public.admin_set_profile_role_and_status(
  p_user_id uuid,
  p_role text DEFAULT NULL,
  p_status text DEFAULT NULL
)
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result public.profiles;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;

  IF NOT public.is_profile_admin() THEN
    RAISE EXCEPTION 'only admins can change roles or status' USING ERRCODE = '42501';
  END IF;

  IF p_role IS NOT NULL AND lower(trim(p_role)) NOT IN ('volunteer','support','admin') THEN
    RAISE EXCEPTION 'invalid role %', p_role USING ERRCODE = '22023';
  END IF;
  IF p_status IS NOT NULL AND lower(trim(p_status)) NOT IN ('active','inactive','deactivated') THEN
    RAISE EXCEPTION 'invalid status %', p_status USING ERRCODE = '22023';
  END IF;

  UPDATE public.profiles
  SET
    role = COALESCE(p_role, role),
    status = COALESCE(p_status, status),
    updated_at = now()
  WHERE id = p_user_id
  RETURNING * INTO result;

  IF result IS NULL THEN
    RAISE EXCEPTION 'profile not found for id %', p_user_id USING ERRCODE = 'P0002';
  END IF;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_profile_role_and_status(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_profile_role_and_status(uuid, text, text) TO authenticated;

-- Helper: ensure a thread row exists
CREATE OR REPLACE FUNCTION public.ensure_support_thread(p_volunteer_id uuid)
RETURNS public.support_threads
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  t public.support_threads;
BEGIN
  INSERT INTO public.support_threads (volunteer_id)
  VALUES (p_volunteer_id)
  ON CONFLICT (volunteer_id) DO UPDATE
    SET updated_at = now()
  RETURNING * INTO t;
  RETURN t;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_support_thread(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_support_thread(uuid) TO authenticated;

-- Volunteer sends message → create/refresh thread, insert chat row, notify staff
CREATE OR REPLACE FUNCTION public.submit_support_message(p_body text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  mid uuid;
  snippet text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;

  IF p_body IS NULL OR length(trim(p_body)) < 1 THEN
    RAISE EXCEPTION 'message cannot be empty' USING ERRCODE = '22023';
  END IF;

  PERFORM public.ensure_support_thread(auth.uid());

  INSERT INTO public.support_chat_messages (thread_volunteer_id, sender_id, body)
  VALUES (auth.uid(), auth.uid(), trim(p_body))
  RETURNING id INTO mid;

  UPDATE public.support_threads
  SET
    last_message_at = now(),
    updated_at = now()
  WHERE volunteer_id = auth.uid();

  snippet := left(trim(p_body), 200);

  INSERT INTO public.notifications (user_id, title, body, type)
  SELECT pr.id,
         'New message from a volunteer',
         snippet,
         'support_message'
  FROM public.profiles pr
  WHERE lower(trim(coalesce(pr.role::text, ''))) IN ('admin', 'support');

  RETURN mid;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_support_message(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_support_message(text) TO authenticated;

-- Coordinator reply → insert chat row, notify volunteer
CREATE OR REPLACE FUNCTION public.support_reply_chat(p_volunteer_id uuid, p_body text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  mid uuid;
  snippet text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;

  IF NOT public.is_profile_coordinator() THEN
    RAISE EXCEPTION 'only admin or support can reply' USING ERRCODE = '42501';
  END IF;

  IF p_volunteer_id IS NULL THEN
    RAISE EXCEPTION 'volunteer id required' USING ERRCODE = '22023';
  END IF;

  IF p_body IS NULL OR length(trim(p_body)) < 1 THEN
    RAISE EXCEPTION 'message cannot be empty' USING ERRCODE = '22023';
  END IF;

  PERFORM public.ensure_support_thread(p_volunteer_id);

  INSERT INTO public.support_chat_messages (thread_volunteer_id, sender_id, body)
  VALUES (p_volunteer_id, auth.uid(), trim(p_body))
  RETURNING id INTO mid;

  UPDATE public.support_threads
  SET
    last_message_at = now(),
    updated_at = now()
  WHERE volunteer_id = p_volunteer_id;

  snippet := left(trim(p_body), 200);
  INSERT INTO public.notifications (user_id, title, body, type)
  VALUES (p_volunteer_id, 'Support replied', snippet, 'support_reply');

  RETURN mid;
END;
$$;

REVOKE ALL ON FUNCTION public.support_reply_chat(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.support_reply_chat(uuid, text) TO authenticated;

-- Volunteer: list own chat
CREATE OR REPLACE FUNCTION public.list_my_support_chat()
RETURNS TABLE (
  id uuid,
  thread_volunteer_id uuid,
  sender_id uuid,
  body text,
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
  SELECT m.id, m.thread_volunteer_id, m.sender_id, m.body, m.created_at
  FROM public.support_chat_messages m
  WHERE m.thread_volunteer_id = auth.uid()
  ORDER BY m.created_at ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_my_support_chat() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_my_support_chat() TO authenticated;

-- Coordinator: list messages for a volunteer thread
CREATE OR REPLACE FUNCTION public.list_support_chat_thread(p_volunteer_id uuid)
RETURNS TABLE (
  id uuid,
  thread_volunteer_id uuid,
  sender_id uuid,
  body text,
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
  IF p_volunteer_id IS NULL THEN
    RAISE EXCEPTION 'volunteer id required' USING ERRCODE = '22023';
  END IF;
  RETURN QUERY
  SELECT m.id, m.thread_volunteer_id, m.sender_id, m.body, m.created_at
  FROM public.support_chat_messages m
  WHERE m.thread_volunteer_id = p_volunteer_id
  ORDER BY m.created_at ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_support_chat_thread(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_support_chat_thread(uuid) TO authenticated;

-- Coordinator: inbox list with MVP fields (one row per volunteer thread)
-- IMPORTANT: if an older version exists with a different RETURNS TABLE shape,
-- Postgres will refuse CREATE OR REPLACE. Drop first to keep this migration re-runnable.
DROP FUNCTION IF EXISTS public.list_support_threads_for_coordinator();
CREATE OR REPLACE FUNCTION public.list_support_threads_for_coordinator()
RETURNS TABLE (
  thread_volunteer_id uuid,
  last_body text,
  last_at timestamptz,
  volunteer_email text,
  volunteer_name text,
  thread_status text,
  thread_priority text,
  assigned_staff_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_profile_coordinator() THEN
    RAISE EXCEPTION 'only admin or support can list support threads' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH last_per AS (
    SELECT DISTINCT ON (m.thread_volunteer_id)
      m.thread_volunteer_id,
      m.body,
      m.created_at
    FROM public.support_chat_messages m
    ORDER BY m.thread_volunteer_id, m.created_at DESC
  )
  SELECT
    t.volunteer_id,
    coalesce(l.body, ''),
    coalesce(l.created_at, t.last_message_at),
    coalesce(p.email, ''),
    coalesce(p.full_name, ''),
    t.status,
    t.priority,
    t.assigned_staff_id
  FROM public.support_threads t
  LEFT JOIN last_per l ON l.thread_volunteer_id = t.volunteer_id
  LEFT JOIN public.profiles p ON p.id = t.volunteer_id
  ORDER BY coalesce(l.created_at, t.last_message_at) DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.list_support_threads_for_coordinator() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_support_threads_for_coordinator() TO authenticated;

-- Backwards-compatible function name used by current Flutter code (returns subset)
DROP FUNCTION IF EXISTS public.list_support_messages_for_coordinator();
CREATE OR REPLACE FUNCTION public.list_support_messages_for_coordinator()
RETURNS TABLE (
  id uuid,
  body text,
  created_at timestamptz,
  from_user_id uuid,
  sender_email text,
  sender_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.thread_volunteer_id AS id,
    t.last_body AS body,
    t.last_at AS created_at,
    t.thread_volunteer_id AS from_user_id,
    t.volunteer_email AS sender_email,
    t.volunteer_name AS sender_name
  FROM public.list_support_threads_for_coordinator() t;
END;
$$;

REVOKE ALL ON FUNCTION public.list_support_messages_for_coordinator() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_support_messages_for_coordinator() TO authenticated;

-- Coordinator inbox management: set status/priority/assignment
CREATE OR REPLACE FUNCTION public.support_set_thread_fields(
  p_volunteer_id uuid,
  p_status text DEFAULT NULL,
  p_priority text DEFAULT NULL,
  p_assigned_staff_id uuid DEFAULT NULL
)
RETURNS public.support_threads
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result public.support_threads;
BEGIN
  IF NOT public.is_profile_coordinator() THEN
    RAISE EXCEPTION 'only admin or support can manage threads' USING ERRCODE = '42501';
  END IF;

  PERFORM public.ensure_support_thread(p_volunteer_id);

  IF p_status IS NOT NULL AND lower(trim(p_status)) NOT IN ('open','closed') THEN
    RAISE EXCEPTION 'invalid status %', p_status USING ERRCODE = '22023';
  END IF;
  IF p_priority IS NOT NULL AND lower(trim(p_priority)) NOT IN ('low','normal','high','urgent') THEN
    RAISE EXCEPTION 'invalid priority %', p_priority USING ERRCODE = '22023';
  END IF;

  UPDATE public.support_threads
  SET
    status = COALESCE(p_status, status),
    priority = COALESCE(p_priority, priority),
    assigned_staff_id = COALESCE(p_assigned_staff_id, assigned_staff_id),
    updated_at = now()
  WHERE volunteer_id = p_volunteer_id
  RETURNING * INTO result;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.support_set_thread_fields(uuid, text, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.support_set_thread_fields(uuid, text, text, uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7) PostgREST schema cache refresh
-- ─────────────────────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';

