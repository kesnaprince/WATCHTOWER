-- =====================================================
-- WATCHTOWER SCHEMA v2 — run this AFTER schema.sql
-- Adds: Approval Engine, Notification Center, HR/Org Directory,
-- Sales pipeline, Procurement requests, Finance transactions
-- =====================================================

-- ---------- APPROVALS ----------
create table if not exists approvals (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete cascade,
  title text not null,
  description text,
  amount text,
  category text default 'General',
  requested_by text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);

alter table approvals enable row level security;

create policy "read own company approvals" on approvals
  for select using (company_id = my_company_id());

-- any signed-in member of the company can submit a request
create policy "members create approvals" on approvals
  for insert with check (company_id = my_company_id());

-- only ceo/admin can change status (approve/reject)
create policy "ceo_admin update approvals" on approvals
  for update using (
    company_id = my_company_id()
    and (select role from profiles where id = auth.uid()) in ('ceo','admin')
  );

-- ---------- NOTIFICATIONS ----------
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete cascade,
  title text not null,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table notifications enable row level security;

create policy "read own company notifications" on notifications
  for select using (company_id = my_company_id());

create policy "members mark notifications read" on notifications
  for update using (company_id = my_company_id());

create policy "ceo_admin create notifications" on notifications
  for insert with check (
    company_id = my_company_id()
    and (select role from profiles where id = auth.uid()) in ('ceo','admin')
  );

-- ---------- EMPLOYEES (HR / Org Directory) ----------
create table if not exists employees (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete cascade,
  name text not null,
  title text,
  department text,
  email text,
  status text not null default 'active' check (status in ('active','on_leave','offboarded')),
  risk text not null default 'low' check (risk in ('low','medium','high')),
  created_at timestamptz not null default now()
);

alter table employees enable row level security;

create policy "read own company employees" on employees
  for select using (company_id = my_company_id());

create policy "ceo_admin write employees" on employees
  for all using (
    company_id = my_company_id()
    and (select role from profiles where id = auth.uid()) in ('ceo','admin')
  )
  with check (company_id = my_company_id());

-- ---------- DEALS (Sales pipeline) ----------
create table if not exists deals (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete cascade,
  name text not null,
  stage text not null default 'prospecting' check (stage in ('prospecting','negotiation','closed_won','closed_lost')),
  value numeric not null default 0,
  owner text,
  close_date date,
  created_at timestamptz not null default now()
);

alter table deals enable row level security;

create policy "read own company deals" on deals
  for select using (company_id = my_company_id());

create policy "ceo_admin write deals" on deals
  for all using (
    company_id = my_company_id()
    and (select role from profiles where id = auth.uid()) in ('ceo','admin')
  )
  with check (company_id = my_company_id());

-- ---------- PROCUREMENT REQUESTS ----------
create table if not exists procurement_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete cascade,
  vendor text not null,
  item text not null,
  amount numeric not null default 0,
  requested_by text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);

alter table procurement_requests enable row level security;

create policy "read own company procurement" on procurement_requests
  for select using (company_id = my_company_id());

create policy "members create procurement" on procurement_requests
  for insert with check (company_id = my_company_id());

create policy "ceo_admin update procurement" on procurement_requests
  for update using (
    company_id = my_company_id()
    and (select role from profiles where id = auth.uid()) in ('ceo','admin')
  );

-- ---------- FINANCE TRANSACTIONS ----------
create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete cascade,
  description text not null,
  amount numeric not null,
  type text not null check (type in ('income','expense')),
  occurred_on date not null default current_date,
  created_at timestamptz not null default now()
);

alter table transactions enable row level security;

create policy "read own company transactions" on transactions
  for select using (company_id = my_company_id());

create policy "ceo_admin write transactions" on transactions
  for all using (
    company_id = my_company_id()
    and (select role from profiles where id = auth.uid()) in ('ceo','admin')
  )
  with check (company_id = my_company_id());

-- =====================================================
-- SEED DATA
-- =====================================================

do $$
declare cid uuid;
begin
  select id into cid from companies where name = 'Acme Corp' order by created_at desc limit 1;

  insert into approvals (company_id, title, description, amount, category, requested_by, status) values
    (cid,'Design conference travel','Karthik Iyer requesting travel + ticket for UX conference.','$1,850','Travel','Karthik Iyer','pending'),
    (cid,'New Figma seats','3 additional design seats for the growing team.','$135/mo','Software','Priya Nair','pending'),
    (cid,'Q3 marketing budget increase','Requesting +$12k for paid campaigns this quarter.','$12,000','Marketing','Ananya Rao','pending'),
    (cid,'Laptop replacement','MacBook Pro replacement for damaged unit.','$2,400','Equipment','Vikram Shah','approved');

  insert into notifications (company_id, title, message, is_read) values
    (cid,'Shadow AI detected','Character.AI usage detected in the Marketing team.', false),
    (cid,'New approval request','Karthik Iyer submitted a travel approval request.', false),
    (cid,'Contract renewal upcoming','Umbrella Retail contract renews in 45 days.', false),
    (cid,'Deal closed','Stark Logistics deal closed for $180,000 ARR.', true);

  insert into employees (company_id, name, title, department, email, status, risk) values
    (cid,'Priya Nair','Head of People','HR','priya@acmecorp.com','active','low'),
    (cid,'Karthik Iyer','Product Designer','Engineering','karthik@acmecorp.com','active','low'),
    (cid,'Meera Krishnan','Customer Success Lead','Customer Success','meera@acmecorp.com','active','high'),
    (cid,'Vikram Shah','Senior Engineer','Engineering','vikram@acmecorp.com','active','high'),
    (cid,'Ananya Rao','Finance Manager','Finance','ananya@acmecorp.com','active','low');

  insert into deals (company_id, name, stage, value, owner, close_date) values
    (cid,'Stark Logistics','closed_won',180000,'Ananya Rao','2026-08-20'),
    (cid,'Umbrella Retail','negotiation',95000,'Ananya Rao','2026-10-15'),
    (cid,'Wayne Enterprises','prospecting',220000,'Ananya Rao','2026-11-30'),
    (cid,'Oscorp Labs','negotiation',60000,'Ananya Rao','2026-09-25');

  insert into procurement_requests (company_id, vendor, item, amount, requested_by, status) values
    (cid,'Dell','15 laptops for new hires',18000,'Priya Nair','pending'),
    (cid,'WeWork','Additional desk space',4200,'Vikram Shah','pending'),
    (cid,'AWS','Increased compute budget',6000,'Vikram Shah','approved');

  insert into transactions (company_id, description, amount, type, occurred_on) values
    (cid,'Stark Logistics — contract payment',180000,'income','2026-08-20'),
    (cid,'AWS infrastructure',-6200,'expense','2026-09-01'),
    (cid,'Payroll — August',-142000,'expense','2026-08-31'),
    (cid,'Umbrella Retail — retainer',15000,'income','2026-09-01');
end $$;
