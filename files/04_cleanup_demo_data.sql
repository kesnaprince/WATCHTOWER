-- =====================================================
-- STEP 4: Wipe demo/seed data, keep structure + policies
-- Run only when you're ready to start using the app for real.
-- The UI already has empty-state handling, so nothing breaks.
-- =====================================================

do $$
declare cid uuid;
begin
  select id into cid from companies where name = 'Acme Corp' order by created_at desc limit 1;

  delete from approvals where company_id = cid;
  delete from notifications where company_id = cid;
  delete from employees where company_id = cid;
  delete from deals where company_id = cid;
  delete from procurement_requests where company_id = cid;
  delete from transactions where company_id = cid;
  delete from alerts where company_id = cid;
end $$;

-- Note: this does NOT delete your own profile/company row —
-- only the seeded demo records inside it.
