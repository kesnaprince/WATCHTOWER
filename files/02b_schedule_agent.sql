-- =====================================================
-- Alternative to Dashboard cron trigger: schedule the
-- employee-risk-agent Edge Function via pg_cron + pg_net.
-- Run once in Supabase SQL Editor after deploying the function.
-- =====================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'employee-risk-agent-daily',
  '0 8 * * *', -- daily at 8am UTC — adjust to your timezone
  $$
  select net.http_post(
    url := 'https://YOUR_PROJECT_REF.functions.supabase.co/employee-risk-agent',
    headers := jsonb_build_object(
      'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY',
      'Content-Type', 'application/json'
    )
  );
  $$
);

-- To check scheduled jobs:
select * from cron.job;

-- To remove it later:
-- select cron.unschedule('employee-risk-agent-daily');
