-- =====================================================
-- STEP 1: Link your login to Acme Corp as CEO
-- Run these one at a time in Supabase SQL Editor.
-- =====================================================

-- 1a. Find your auth user id (replace with the email you signed up with)
select id, email from auth.users where email = 'YOUR_EMAIL_HERE';

-- 1b. Confirm the company id
select id, name from companies where name = 'Acme Corp';

-- 1c. Create/update your profile row, linking you as CEO
-- Paste the id from 1a into USER_ID, and the id from 1b into COMPANY_ID.
insert into profiles (id, company_id, role, full_name)
values (
  'USER_ID_FROM_STEP_1a',
  'COMPANY_ID_FROM_STEP_1b',
  'ceo',
  'Your Name'
)
on conflict (id) do update
set company_id = excluded.company_id,
    role = excluded.role,
    full_name = excluded.full_name;

-- 1d. Verify
select p.id, p.role, p.full_name, c.name as company
from profiles p
join companies c on c.id = p.company_id
where p.id = 'USER_ID_FROM_STEP_1a';
