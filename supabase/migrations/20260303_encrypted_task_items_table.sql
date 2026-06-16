-- Per-task encrypted storage for conflict-safe sync (item 27).
-- Each row holds one encrypted Task JSON. The legacy encrypted_tasks table
-- (whole-collection blob) is kept for point-in-time restore (item 25).

CREATE TABLE IF NOT EXISTS encrypted_task_items (
  id         text        PRIMARY KEY,
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  data_blob  text,                        -- NULL only when deleted = true
  updated_at timestamptz NOT NULL,
  deleted    boolean     NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS encrypted_task_items_user_updated
  ON encrypted_task_items (user_id, updated_at DESC);

ALTER TABLE encrypted_task_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "task_items_owner_all" ON encrypted_task_items
  FOR ALL
  USING  (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
