-- ==============================================================================
-- RASARI CENTRAL HOUSE: VARNACULAR PER-STUDENT PROGRESS ISOLATION
-- ==============================================================================
-- Run this in your Supabase SQL Editor: https://supabase.com/dashboard/project/dchwazmerymfevcschut/sql

-- 1. Ensure column student_id exists in varnacular.user_progress
ALTER TABLE varnacular.user_progress 
  ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.students(id) ON DELETE CASCADE;

-- 2. Backfill existing progress rows: if any row has NULL student_id,
-- assign it to the parent's earliest varnacular student profile.
UPDATE varnacular.user_progress up
SET student_id = (
  SELECT s.id 
  FROM public.students s 
  WHERE s.parent_id = up.user_id 
    AND (s.app = 'varnacular' OR s.app IS NULL)
  ORDER BY s.created_at ASC 
  LIMIT 1
)
WHERE up.student_id IS NULL;

-- 3. Delete any orphaned rows where parent has no students yet (clean slate for test accounts)
DELETE FROM varnacular.user_progress WHERE student_id IS NULL;

-- 4. Make student_id NOT NULL now that legacy rows are backfilled or pruned
ALTER TABLE varnacular.user_progress 
  ALTER COLUMN student_id SET NOT NULL;

-- 5. Drop the old single-user primary key constraint
ALTER TABLE varnacular.user_progress 
  DROP CONSTRAINT IF EXISTS user_progress_pkey;

-- 6. Add composite primary key on (user_id, student_id)
-- This allows 1 parent to have separate, completely isolated progress records for each child
ALTER TABLE varnacular.user_progress 
  ADD CONSTRAINT user_progress_pkey PRIMARY KEY (user_id, student_id);

-- 7. Ensure Row Level Security (RLS) policies allow parents to manage all their children's progress
ALTER TABLE varnacular.user_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own children progress" ON varnacular.user_progress;
DROP POLICY IF EXISTS "Allow user to manage own progress" ON varnacular.user_progress;

CREATE POLICY "Users can manage own children progress"
  ON varnacular.user_progress
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
