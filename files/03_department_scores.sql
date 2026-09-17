-- =====================================================
-- STEP 3: Make department scores real (not hand-typed numbers)
--
-- Honest limitation: only Finance, HR, and Sales have real
-- underlying tables right now. Engineering, Marketing,
-- IT & Security, Customer Success, and Legal have no data
-- source yet — leave those as manually-set numbers until
-- you build those modules.
-- =====================================================

create or replace function refresh_department_scores(cid uuid)
returns void as $$
declare
  income numeric;
  expense numeric;
  net_margin numeric;
  finance_score int;

  total_emp int;
  high_risk_emp int;
  hr_score int;

  total_closed_deals int;
  won_deals int;
  sales_score int;
begin
  -- FINANCE: net margin (income - expense)/income, mapped onto 0-100
  select coalesce(sum(amount) filter (where type = 'income'), 0),
         coalesce(sum(abs(amount)) filter (where type = 'expense'), 0)
  into income, expense
  from transactions where company_id = cid;

  net_margin := case when income = 0 then 0 else (income - expense) / income end;
  finance_score := greatest(0, least(100, round((50 + net_margin * 50)::numeric)));

  update departments set score = finance_score where company_id = cid and name = 'Finance';

  -- HR: penalize for % of active employees flagged high risk
  select count(*) filter (where status = 'active'),
         count(*) filter (where status = 'active' and risk = 'high')
  into total_emp, high_risk_emp
  from employees where company_id = cid;

  hr_score := case when total_emp = 0 then 75
    else greatest(0, least(100, round((100 - (high_risk_emp::numeric / total_emp) * 100))))
  end;

  update departments set score = hr_score where company_id = cid and name = 'HR';

  -- SALES: win rate among closed deals
  select count(*) filter (where stage in ('closed_won','closed_lost')),
         count(*) filter (where stage = 'closed_won')
  into total_closed_deals, won_deals
  from deals where company_id = cid;

  sales_score := case when total_closed_deals = 0 then 75
    else greatest(0, least(100, round((won_deals::numeric / total_closed_deals) * 100)))
  end;

  update departments set score = sales_score where company_id = cid and name = 'Sales';
end;
$$ language plpgsql security definer;

-- Run it once for all companies:
select refresh_department_scores(id) from companies;

-- To keep it live going forward, schedule it the same way as the
-- employee-risk-agent (pg_cron), e.g. hourly:
--
-- select cron.schedule(
--   'refresh-department-scores-hourly',
--   '0 * * * *',
--   $$ select refresh_department_scores(id) from companies; $$
-- );
