# Email notifications patch
# Apply after existing migrations: psql ... -f patch_email_notifications.sql
# Or: supabase db push

\i migrations/20260730000007_email_notifications.sql
