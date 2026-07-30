-- Enable Supabase Realtime for encrypted_task_items so per-device task
-- changes propagate live via postgres_changes, without waiting for
-- connectivity-regain polling or app-resume.
ALTER PUBLICATION supabase_realtime ADD TABLE encrypted_task_items;
