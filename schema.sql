-- =====================================================
-- WATCHTOWER SCHEMA
-- Run this whole file in Supabase → SQL Editor → New query → Run
-- =====================================================

-- ---------- COMPANIES ----------
create table if not exists companies (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Acme Corp',
  founder_score int not null default 71,
  headcount int not null default 128,
  pipeline text not null default '$746k',
  approvals int not null default 4,
  open_requisitions int not null default 4,
  ai_risk_score int not null default 32,
  created_at timestamptz not null default now()
);

-- ---------- PROFILES (extends Supabase auth.users) ----------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  company_id uuid references companies(id) on delete cascade,
  full_name text,
  role text not null default 'employee' check (role in ('ceo','admin','employee')),
  created_at timestamptz not null default now()
);

-- ---------- DEPARTMENTS ----------
create table if not exists departments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete cascade,
  name text not null,
  score int not null,
  sort_order int not null default 0
);

-- ---------- ALERTS ----------
create table if not exists alerts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete cascade,
  level text not null check (level in ('CRIT','HIGH','MED')),
  title text not null,
  description text not null,
  created_at timestamptz not null default now()
);

-- ---------- ACTIONS ----------
create table if not exists actions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete cascade,
  title text not null,
  description text not null,
  sort_order int not null default 0
);

-- ---------- ACTIVITIES (live pulse) ----------
create table if not exists activities (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete cascade,
  actor_name text not null,
  action_text text not null,
  type text not null default 'blue' check (type in ('blue','green','yellow')),
  created_at timestamptz not null default now()
);

-- ---------- WINS ----------
create table if not exists wins (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete cascade,
  text text not null,
  created_at timestamptz not null default now()
);

-- ---------- RISKS ----------
create table if not exists risks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete cascade,
  name text not null,
  level text not null,
  value int not null,
  class_name text not null check (class_name in ('critical','high','low')),
  sort_order int not null default 0
);

-- ---------- AI MONITORING ----------
create table if not exists ai_monitoring (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete cascade,
  title text not null,
  number text not null,
  description text not null,
  status text not null,
  sort_order int not null default 0
);

-- =====================================================
-- ROW LEVEL SECURITY
-- Every table is scoped to the caller's own company_id,
-- looked up from their profiles row.
-- =====================================================

alter table companies enable row level security;
alter table profiles enable row level security;
alter table departments enable row level security;
alter table alerts enable row level security;
alter table actions enable row level security;
alter table activities enable row level security;
alter table wins enable row level security;
alter table risks enable row level security;
alter table ai_monitoring enable row level security;

-- helper: current user's company_id
create or replace function my_company_id()
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select company_id from profiles where id = auth.uid();
$$;

-- profiles: users can read their own row
create policy "read own profile" on profiles
  for select using (id = auth.uid());

create policy "update own profile" on profiles
  for update using (id = auth.uid());

-- companies: readable if it's your company
create policy "read own company" on companies
  for select using (id = my_company_id());

-- generic read policy for the rest, all scoped by company_id
create policy "read own company data" on departments for select using (company_id = my_company_id());
create policy "read own company data" on alerts for select using (company_id = my_company_id());
create policy "read own company data" on actions for select using (company_id = my_company_id());
create policy "read own company data" on activities for select using (company_id = my_company_id());
create policy "read own company data" on wins for select using (company_id = my_company_id());
create policy "read own company data" on risks for select using (company_id = my_company_id());
create policy "read own company data" on ai_monitoring for select using (company_id = my_company_id());

-- only ceo/admin can write (insert/update/delete) — employees are read-only
create policy "ceo_admin write departments" on departments for all
  using (company_id = my_company_id() and (select role from profiles where id = auth.uid()) in ('ceo','admin'))
  with check (company_id = my_company_id());

create policy "ceo_admin write alerts" on alerts for all
  using (company_id = my_company_id() and (select role from profiles where id = auth.uid()) in ('ceo','admin'))
  with check (company_id = my_company_id());

create policy "ceo_admin write actions" on actions for all
  using (company_id = my_company_id() and (select role from profiles where id = auth.uid()) in ('ceo','admin'))
  with check (company_id = my_company_id());

create policy "ceo_admin write activities" on activities for all
  using (company_id = my_company_id() and (select role from profiles where id = auth.uid()) in ('ceo','admin'))
  with check (company_id = my_company_id());

create policy "ceo_admin write wins" on wins for all
  using (company_id = my_company_id() and (select role from profiles where id = auth.uid()) in ('ceo','admin'))
  with check (company_id = my_company_id());

create policy "ceo_admin write risks" on risks for all
  using (company_id = my_company_id() and (select role from profiles where id = auth.uid()) in ('ceo','admin'))
  with check (company_id = my_company_id());

create policy "ceo_admin write ai_monitoring" on ai_monitoring for all
  using (company_id = my_company_id() and (select role from profiles where id = auth.uid()) in ('ceo','admin'))
  with check (company_id = my_company_id());

create policy "ceo_admin update company" on companies for update
  using (id = my_company_id() and (select role from profiles where id = auth.uid()) in ('ceo','admin'));

-- =====================================================
-- AUTO-CREATE A PROFILE WHEN SOMEONE SIGNS UP
-- New users get dropped into the first company that exists
-- (fine for a single-company setup; adjust later for multi-tenant).
-- Role defaults to 'employee' — promote yourself to 'ceo' manually after signup.
-- =====================================================

create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  default_company_id uuid;
begin
  select id into default_company_id from companies order by created_at asc limit 1;

  insert into public.profiles (id, company_id, full_name, role)
  values (new.id, default_company_id, coalesce(new.raw_user_meta_data->>'full_name', new.email), 'employee');

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- =====================================================
-- SEED DATA — same content as your original DATA object
-- =====================================================

insert into companies (name, founder_score, headcount, pipeline, approvals, open_requisitions, ai_risk_score)
values ('Acme Corp', 71, 128, '$746k', 4, 4, 32);

-- grab the company id we just made
do $$
declare cid uuid;
begin
  select id into cid from companies where name = 'Acme Corp' order by created_at desc limit 1;

  insert into departments (company_id, name, score, sort_order) values
    (cid,'Finance',80,1),(cid,'Engineering',74,2),(cid,'HR',65,3),(cid,'Sales',83,4),
    (cid,'Marketing',70,5),(cid,'IT & Security',59,6),(cid,'Customer Success',75,7),(cid,'Legal',88,8);

  insert into alerts (company_id, level, title, description) values
    (cid,'CRIT','Shadow AI detected','2 unauthorized AI tools detected in active use.'),
    (cid,'HIGH','Employee attrition risk','2 employees are currently flagged as high risk.'),
    (cid,'HIGH','Burnout risk','2 employees showing high burnout based on engagement and after-hours activity.'),
    (cid,'MED','Contract renewal','Umbrella Retail contract renews in 45 days.'),
    (cid,'MED','Pending approvals','4 approvals are waiting across departments.');

  insert into actions (company_id, title, description, sort_order) values
    (cid,'Review Shadow AI activity','Character.AI detected in Marketing — critical data exposure risk.',1),
    (cid,'Check employee wellbeing','Vikram Shah and Meera Krishnan are showing elevated burnout risk.',2),
    (cid,'Review pending approvals','4 items require executive attention. Oldest request is 3 days old.',3),
    (cid,'Begin Umbrella Retail renewal','Contract expires in 45 days.',4);

  insert into activities (company_id, actor_name, action_text, type) values
    (cid,'Priya Nair','updated the Q3 hiring plan','blue'),
    (cid,'Karthik Iyer','requested design conference travel approval','blue'),
    (cid,'Meera Krishnan','escalated ticket CS-231','yellow'),
    (cid,'Vikram Shah','merged PR #482 — Approval Engine v2','green'),
    (cid,'Ananya Rao','approved a $4,200 purchase order','green');

  insert into wins (company_id, text) values
    (cid,'Stark Logistics deal closed — $180,000 ARR'),
    (cid,'Engineering shipped Universal Approval Engine v1'),
    (cid,'Customer NPS improved to 61 (+8 this quarter)');

  insert into risks (company_id, name, level, value, class_name, sort_order) values
    (cid,'Shadow AI','Critical',90,'critical',1),
    (cid,'Employee risk','High',70,'high',2),
    (cid,'Compliance','Low',28,'low',3);

  insert into ai_monitoring (company_id, title, number, description, status, sort_order) values
    (cid,'Unauthorized AI tools','2','Unapproved AI applications detected inside the organization.','CRITICAL',1),
    (cid,'AI risk score','32','Overall organizational exposure from AI usage and data risk.','MONITOR',2),
    (cid,'AI agents active','7','Internal AI agents currently operating across departments.','ACTIVE',3);
end $$;
