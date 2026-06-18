-- Task templates (permanent / suggested) and volunteer publish requests.
-- Run in Supabase SQL editor after profiles-based MVP migrations.

-- ─── Task templates ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS task_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  required_skills TEXT[] DEFAULT '{}',
  kind TEXT NOT NULL DEFAULT 'suggested'
    CHECK (kind IN ('permanent', 'suggested')),
  usage_count INT NOT NULL DEFAULT 0,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_task_templates_kind ON task_templates(kind);
CREATE INDEX IF NOT EXISTS idx_task_templates_active ON task_templates(is_active);

ALTER TABLE task_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can read active templates" ON task_templates;
DROP POLICY IF EXISTS "Coordinators manage templates" ON task_templates;

CREATE POLICY "Anyone authenticated can read active templates"
  ON task_templates FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND (is_active = TRUE OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'support')
    ))
  );

CREATE POLICY "Coordinators manage templates"
  ON task_templates FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'support')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'support')
    )
  );

-- Seed a few common templates (idempotent by title)
INSERT INTO task_templates (title, description, required_skills, kind, sort_order)
SELECT v.title, v.description, v.skills, v.kind, v.sort_order
FROM (VALUES
  ('توزيع مساعدات', 'توزيع المواد الغذائية والإمدادات على المحتاجين', ARRAY['لوجستي','مساعدة عامة']::TEXT[], 'permanent', 1),
  ('دعم طبي ميداني', 'تقديم الإسعافات الأولية والدعم الطبي في الموقع', ARRAY['طبي']::TEXT[], 'permanent', 2),
  ('نقل متطوعين', 'نقل المتطوعين والمعدات إلى موقع المهمة', ARRAY['قيادة','لوجستي']::TEXT[], 'suggested', 3),
  ('ترجمة فورية', 'ترجمة بين المتطوعين والمستفيدين', ARRAY['ترجمة']::TEXT[], 'suggested', 4)
) AS v(title, description, skills, kind, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM task_templates LIMIT 1);

CREATE OR REPLACE FUNCTION increment_task_template_usage(p_template_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE task_templates
  SET usage_count = usage_count + 1, updated_at = NOW()
  WHERE id = p_template_id;
END;
$$;

-- ─── Task publish requests ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS task_publish_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  location TEXT DEFAULT '',
  location_id UUID,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  required_skills TEXT[] DEFAULT '{}',
  scheduled_date TIMESTAMPTZ,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_task_id UUID REFERENCES tasks(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_task_publish_requests_user ON task_publish_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_task_publish_requests_status ON task_publish_requests(status);

ALTER TABLE task_publish_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view own publish requests" ON task_publish_requests;
DROP POLICY IF EXISTS "Users create publish requests" ON task_publish_requests;
DROP POLICY IF EXISTS "Coordinators view all publish requests" ON task_publish_requests;
DROP POLICY IF EXISTS "Coordinators update publish requests" ON task_publish_requests;

CREATE POLICY "Users view own publish requests"
  ON task_publish_requests FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users create publish requests"
  ON task_publish_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Coordinators view all publish requests"
  ON task_publish_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'support')
    )
  );

CREATE POLICY "Coordinators update publish requests"
  ON task_publish_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'support')
    )
  );

CREATE OR REPLACE FUNCTION approve_task_publish_request(request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_req task_publish_requests;
  v_task_id UUID;
  v_reviewer_role TEXT;
BEGIN
  SELECT role INTO v_reviewer_role FROM profiles WHERE id = auth.uid();
  IF v_reviewer_role NOT IN ('admin', 'support') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_req FROM task_publish_requests WHERE id = request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
  IF v_req.status <> 'pending' THEN RAISE EXCEPTION 'Request already processed'; END IF;

  INSERT INTO tasks (
    title, description, location, location_id, latitude, longitude,
    required_skills, date, status
  ) VALUES (
    v_req.title,
    COALESCE(v_req.description, ''),
    COALESCE(v_req.location, ''),
    v_req.location_id,
    v_req.latitude,
    v_req.longitude,
    COALESCE(v_req.required_skills, '{}'),
    COALESCE(v_req.scheduled_date, NOW()),
    'pending'
  )
  RETURNING id INTO v_task_id;

  UPDATE task_publish_requests
  SET status = 'approved',
      reviewed_by = auth.uid(),
      reviewed_at = NOW(),
      created_task_id = v_task_id,
      updated_at = NOW()
  WHERE id = request_id;

  RETURN jsonb_build_object('task_id', v_task_id);
END;
$$;

CREATE OR REPLACE FUNCTION reject_task_publish_request(request_id UUID, reason TEXT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_reviewer_role TEXT;
BEGIN
  SELECT role INTO v_reviewer_role FROM profiles WHERE id = auth.uid();
  IF v_reviewer_role NOT IN ('admin', 'support') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE task_publish_requests
  SET status = 'rejected',
      reviewed_by = auth.uid(),
      reviewed_at = NOW(),
      rejection_reason = reason,
      updated_at = NOW()
  WHERE id = request_id AND status = 'pending';
END;
$$;

CREATE OR REPLACE FUNCTION list_pending_task_publish_requests()
RETURNS SETOF task_publish_requests
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT tpr.*
  FROM task_publish_requests tpr
  WHERE tpr.status = 'pending'
  ORDER BY tpr.created_at ASC;
$$;
