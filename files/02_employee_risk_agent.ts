// =====================================================
// STEP 2: Your first real "AI Agent"
// This is a scheduled backend job (Supabase Edge Function),
// NOT frontend code. It reads employees, decides if there's
// a risk pattern, and writes an alert — same shape every
// future agent (Shadow AI, Burnout, Contract Renewal, etc.)
// should follow.
//
// DEPLOY:
//   supabase functions deploy employee-risk-agent
//
// SCHEDULE (pick one):
//   A) Dashboard: Edge Functions -> employee-risk-agent -> Add Cron Trigger
//      e.g. "0 8 * * *" (daily 8am)
//   B) pg_cron (see 02b_schedule_agent.sql)
// =====================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")! // service role = runs as backend, bypasses RLS
  );

  const { data: companies, error: companiesError } = await supabase
    .from("companies")
    .select("id");

  if (companiesError || !companies) {
    return new Response(`error loading companies: ${companiesError?.message}`, { status: 500 });
  }

  let alertsCreated = 0;

  for (const company of companies) {
    const { data: highRiskEmployees } = await supabase
      .from("employees")
      .select("id, name")
      .eq("company_id", company.id)
      .eq("status", "active")
      .eq("risk", "high");

    if (!highRiskEmployees || highRiskEmployees.length === 0) continue;

    // dedupe: don't re-alert if we already raised this in the last 24h
    const { data: existing } = await supabase
      .from("alerts")
      .select("id")
      .eq("company_id", company.id)
      .eq("title", "Employee attrition risk")
      .gte("created_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

    if (existing && existing.length > 0) continue;

    await supabase.from("alerts").insert({
      company_id: company.id,
      level: "high",
      title: "Employee attrition risk",
      description: `${highRiskEmployees.length} employee(s) flagged as high risk: ${highRiskEmployees
        .map((e) => e.name)
        .join(", ")}.`,
    });

    alertsCreated++;
  }

  return new Response(JSON.stringify({ ok: true, alertsCreated }), {
    headers: { "Content-Type": "application/json" },
  });
});
