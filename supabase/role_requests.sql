-- Role Requests Table
-- Users can request to become support or admin
-- Admins can approve or reject these requests

CREATE TABLE IF NOT EXISTS role_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  requested_role TEXT NOT NULL CHECK (requested_role IN ('support', 'admin', 'coordinator')),
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_role_requests_user_id ON role_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_role_requests_status ON role_requests(status);

-- Enable RLS
ALTER TABLE role_requests ENABLE ROW LEVEL SECURITY;

-- Users can view their own requests
CREATE POLICY "Users can view own requests"
  ON role_requests FOR SELECT
  USING (auth.uid() = user_id);

-- Users can create their own requests
CREATE POLICY "Users can create own requests"
  ON role_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update (cancel) their own pending requests
CREATE POLICY "Users can cancel own pending requests"
  ON role_requests FOR UPDATE
  USING (auth.uid() = user_id AND status = 'pending');

-- Admin/Support can view all requests
CREATE POLICY "Admin can view all requests"
  ON role_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'support')
    )
  );

-- Admin can update (approve/reject) any request
CREATE POLICY "Admin can update requests"
  ON role_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Function to approve a role request
CREATE OR REPLACE FUNCTION approve_role_request(request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_request role_requests;
  v_admin_role TEXT;
BEGIN
  -- Check if caller is admin
  SELECT role INTO v_admin_role FROM profiles WHERE id = auth.uid();
  IF v_admin_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can approve requests';
  END IF;

  -- Get the request
  SELECT * INTO v_request FROM role_requests WHERE id = request_id AND status = 'pending';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found or already processed';
  END IF;

  -- Update the request status
  UPDATE role_requests
  SET status = 'approved',
      reviewed_by = auth.uid(),
      reviewed_at = NOW(),
      updated_at = NOW()
  WHERE id = request_id;

  -- Update the user's role
  UPDATE profiles
  SET role = v_request.requested_role,
      updated_at = NOW()
  WHERE id = v_request.user_id;

  RETURN jsonb_build_object('success', true, 'message', 'Request approved');
END;
$$;

-- Function to reject a role request
CREATE OR REPLACE FUNCTION reject_role_request(request_id UUID, reason TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_role TEXT;
BEGIN
  -- Check if caller is admin
  SELECT role INTO v_admin_role FROM profiles WHERE id = auth.uid();
  IF v_admin_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can reject requests';
  END IF;

  -- Update the request status
  UPDATE role_requests
  SET status = 'rejected',
      reviewed_by = auth.uid(),
      reviewed_at = NOW(),
      rejection_reason = reason,
      updated_at = NOW()
  WHERE id = request_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found or already processed';
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'Request rejected');
END;
$$;

-- Function to list all pending requests (for admin dashboard)
CREATE OR REPLACE FUNCTION list_pending_role_requests()
RETURNS TABLE (
  id UUID,
  user_id UUID,
  user_name TEXT,
  user_email TEXT,
  requested_role TEXT,
  reason TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_role TEXT;
BEGIN
  -- Check if caller is admin or support
  SELECT role INTO v_admin_role FROM profiles WHERE id = auth.uid();
  IF v_admin_role NOT IN ('admin', 'support') THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  RETURN QUERY
  SELECT
    rr.id,
    rr.user_id,
    p.full_name as user_name,
    p.email as user_email,
    rr.requested_role,
    rr.reason,
    rr.created_at
  FROM role_requests rr
  JOIN profiles p ON p.id = rr.user_id
  WHERE rr.status = 'pending'
  ORDER BY rr.created_at ASC;
END;
$$;
