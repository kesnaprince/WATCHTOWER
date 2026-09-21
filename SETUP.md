# WatchTower — Real stack setup

**Stack**
- **Vercel** → hosts the frontend (`index.html`)
- **Supabase** → Auth + API (backend)
- **PostgreSQL** → database (inside Supabase)

---

## 1. PostgreSQL / Supabase database

1. Create a project at [supabase.com](https://supabase.com)
2. Open **SQL Editor** → New query
3. Paste the full contents of **`schema.sql`** → Run
4. Confirm tables exist under **Table Editor** (companies, profiles, approvals, issues, etc.)

---

## 2. Link your user after first signup

In SQL Editor (replace email):

```sql
update profiles
set company_id = (select id from companies where name = 'Acme Corp' limit 1),
    role = 'ceo',
    full_name = 'Your Name'
where id = (select id from auth.users where email = 'you@company.com');
```

Manager example:

```sql
update profiles
set company_id = (select id from companies where name = 'Acme Corp' limit 1),
    role = 'manager',
    department = 'Engineering'
where id = (select id from auth.users where email = 'manager@company.com');
```

---

## 3. Frontend config (Supabase keys)

In **`index.html`**, near the top of the `<script>` block:

```js
const SUPABASE_URL = "https://YOUR_PROJECT.supabase.co";
const SUPABASE_ANON_KEY = "YOUR_ANON_PUBLIC_KEY";
```

Get these from: Supabase → **Settings → API**

---

## 4. Deploy frontend on Vercel

1. Put these files in a GitHub repo (or deploy from local):
   - `index.html`
   - `vercel.json`
2. Import the repo in [vercel.com](https://vercel.com)
3. Deploy (static site — no build command needed)
4. Open the Vercel URL → Sign up → then run the SQL link step above if needed

Optional: enable **Email confirmations** off in Supabase Auth settings for faster demo signups.

---

## Files in this package

| File | Role |
|------|------|
| `schema.sql` | PostgreSQL schema + RLS + triggers + seed (run in Supabase) |
| `index.html` | Frontend app (Auth, dashboards, issues, approvals, etc.) |
| `vercel.json` | Vercel static deploy config |

---

## Data flow (real-time)

```
Browser (index.html on Vercel)
    → Supabase JS client (Auth + PostgREST)
        → PostgreSQL (RLS enforces ceo / manager / employee)
            → Triggers auto-approve + high-risk notifications
```

All create/update/list for approvals, issues, employees, finance, sales, procurement, and automations go through Supabase to PostgreSQL — not local demo storage.
