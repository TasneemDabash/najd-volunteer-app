-- Run in Supabase SQL Editor AFTER task_templates_and_publish_requests.sql
-- Fixes: approve/reject publish requests when tasks.location column is missing,
-- notifies admin/support on new publish requests, enables in-app account deletion (iOS/Android).

-- ─── Approve publish request (schema-aware insert) ───────────────────────────
CREATE OR REPLACE FUNCTION approve_task_publish_request(request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req task_publish_requests;
  v_task_id UUID;
  v_reviewer_role TEXT;
  v_has_location_col boolean;
  v_has_date_col boolean;
BEGIN
  SELECT role INTO v_reviewer_role FROM profiles WHERE id = auth.uid();
  IF v_reviewer_role NOT IN ('admin', 'support') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_req FROM task_publish_requests WHERE id = request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
  IF v_req.status <> 'pending' THEN RAISE EXCEPTION 'Request already processed'; END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'tasks' AND column_name = 'location'
  ) INTO v_has_location_col;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'tasks' AND column_name = 'date'
  ) INTO v_has_date_col;

  IF v_has_location_col AND v_has_date_col THEN
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
  ELSIF v_has_date_col THEN
    INSERT INTO tasks (
      title, description, location_id, latitude, longitude,
      required_skills, date, status
    ) VALUES (
      v_req.title,
      COALESCE(v_req.description, ''),
      v_req.location_id,
      v_req.latitude,
      v_req.longitude,
      COALESCE(v_req.required_skills, '{}'),
      COALESCE(v_req.scheduled_date, NOW()),
      'pending'
    )
    RETURNING id INTO v_task_id;
  ELSE
    INSERT INTO tasks (
      title, description, location_id, latitude, longitude,
      required_skills, status
    ) VALUES (
      v_req.title,
      COALESCE(v_req.description, ''),
      v_req.location_id,
      v_req.latitude,
      v_req.longitude,
      COALESCE(v_req.required_skills, '{}'),
      'pending'
    )
    RETURNING id INTO v_task_id;
  END IF;

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

GRANT EXECUTE ON FUNCTION approve_task_publish_request(UUID) TO authenticated;

-- ─── Notify admin/support when a volunteer submits a publish request ─────────
CREATE OR REPLACE FUNCTION public.notify_coordinators_on_publish_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notifications (user_id, title, body, type)
  SELECT p.id,
         'طلب نشر مهمة جديد',
         'طلب «' || NEW.title || '» من متطوع — يرجى المراجعة',
         'task_publish_request'
  FROM public.profiles p
  WHERE p.role IN ('admin', 'support');

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_coordinators_on_publish_request
  ON public.task_publish_requests;
CREATE TRIGGER trg_notify_coordinators_on_publish_request
AFTER INSERT ON public.task_publish_requests
FOR EACH ROW
EXECUTE FUNCTION public.notify_coordinators_on_publish_request();

-- ─── Notify volunteer when request is approved/rejected ──────────────────────
CREATE OR REPLACE FUNCTION public.notify_volunteer_on_publish_request_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status
     AND NEW.status IN ('approved', 'rejected') THEN
    INSERT INTO public.notifications (user_id, title, body, type, task_id)
    VALUES (
      NEW.user_id,
      CASE WHEN NEW.status = 'approved' THEN 'تم قبول طلب نشر المهمة'
           ELSE 'تم رفض طلب نشر المهمة' END,
      CASE WHEN NEW.status = 'approved'
           THEN 'تم قبول طلبك «' || NEW.title || '» وإنشاء المهمة.'
           ELSE 'تم رفض طلبك «' || NEW.title || '».'
                || CASE WHEN NEW.rejection_reason IS NOT NULL AND NEW.rejection_reason <> ''
                        THEN ' السبب: ' || NEW.rejection_reason ELSE '' END
      END,
      'task_publish_request',
      NEW.created_task_id
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_volunteer_on_publish_request_status
  ON public.task_publish_requests;
CREATE TRIGGER trg_notify_volunteer_on_publish_request_status
AFTER UPDATE ON public.task_publish_requests
FOR EACH ROW
EXECUTE FUNCTION public.notify_volunteer_on_publish_request_status();

-- ─── Self-service account deletion (App Store / Play requirement) ────────────
CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.delete_own_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;

-- Jerusalem alias (if not already seeded)
INSERT INTO public.locations (name, region, latitude, longitude) VALUES
  ('Jerusalem', 'Jerusalem', 31.7683, 35.2137),
  ('القدس', 'Jerusalem', 31.7683, 35.2137),
  ('Ramallah', 'West Bank', 31.9038, 35.2034),
  ('رام الله', 'West Bank', 31.9038, 35.2034)
ON CONFLICT (lower(trim(name)), lower(trim(region))) DO NOTHING;
