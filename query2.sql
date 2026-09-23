-- =====================================================
-- WATCHTOWER — SHADOW AI TELEMETRY
-- =====================================================

create table if not exists ai_telemetry (
  id uuid primary key default gen_random_uuid(),

  company_id uuid not null
    references companies(id)
    on delete cascade,

  tool_name text not null,

  event_type text not null default 'usage'
    check (event_type in (
      'usage',
      'policy_violation',
      'blocked',
      'approved'
    )),

  department text,

  risk_level text not null default 'low'
    check (risk_level in (
      'low',
      'medium',
      'high',
      'critical'
    )),

  source text not null default 'telemetry',

  detected_at timestamptz not null default now(),

  created_at timestamptz not null default now()
);

create index if not exists idx_ai_telemetry_company
on ai_telemetry(company_id);

create index if not exists idx_ai_telemetry_detected_at
on ai_telemetry(detected_at);

create index if not exists idx_ai_telemetry_tool
on ai_telemetry(company_id, tool_name);

create index if not exists idx_ai_telemetry_department
on ai_telemetry(company_id, department);

alter table ai_telemetry enable row level security;

drop policy if exists "company read ai telemetry"
on ai_telemetry;

create policy "company read ai telemetry"
on ai_telemetry
for select
using (
  company_id = my_company_id()
);

insert into ai_telemetry
(
  company_id,
  tool_name,
  event_type,
  department,
  risk_level,
  source
)
values

(
  (select id from companies where name = 'Acme Corp' limit 1),
  'ChatGPT',
  'usage',
  'Engineering',
  'medium',
  'test'
),

(
  (select id from companies where name = 'Acme Corp' limit 1),
  'Claude',
  'usage',
  'Marketing',
  'medium',
  'test'
),

(
  (select id from companies where name = 'Acme Corp' limit 1),
  'Unknown AI Service',
  'policy_violation',
  'Engineering',
  'high',
  'test'
);