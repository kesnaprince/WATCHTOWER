# WatchTower — Going Live

This turns your static dashboard into a real app: **Supabase** for the database + login,
**Vercel** for hosting.

---

## 1. Create your Supabase project

1. Go to [supabase.com](https://supabase.com) → sign up → **New Project**.
2. Pick a name, a database password (save it somewhere), and a region close to you.
3. Wait ~2 minutes for it to spin up.

## 2. Create the database

1. In your Supabase project, open **SQL Editor** → **New query**.
2. Paste in the entire contents of `schema.sql` (included here).
3. Click **Run**.

This creates all your tables (`companies`, `departments`, `alerts`, `actions`,
`activities`, `wins`, `risks`, `ai_monitoring`, `profiles`), sets up Row Level
Security so each user only ever sees their own company's data, and seeds it with
the same sample data your dashboard already had.

It also creates a trigger: **every new sign-up automatically gets a `profiles` row**
linked to the first company in the table, with the role `employee`.

## 3. Get your API keys

In Supabase: **Settings → API**. Copy:
- **Project URL**
- **anon public** key

Open `index.html` and replace these two lines near the bottom of the `<script>` tag:

```js
const SUPABASE_URL = "YOUR_SUPABASE_PROJECT_URL";
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
```

> The anon key is safe to expose in frontend code — it's designed for that. Row Level
> Security (set up by `schema.sql`) is what actually protects your data, not this key.

## 4. Create your first account and make yourself CEO

1. Open `index.html` locally in a browser (just double-click it, or run `npx serve .`).
2. Click **Sign up**, enter your email + a password.
3. If you have email confirmations on (default), check your inbox and confirm.
4. Sign in.

By default you'll show up as "Employee." To make yourself CEO, go back to Supabase
**SQL Editor** and run:

```sql
update profiles set role = 'ceo' where id = (
  select id from auth.users where email = 'you@yourcompany.com'
);
```

Refresh the dashboard — the "Viewing as" badge and write permissions update immediately.

## 5. Deploy to Vercel

**Easiest path (no git required):**

1. Go to [vercel.com](https://vercel.com) → sign up (GitHub, GitLab, or email).
2. Click **Add New → Project → Deploy without Git** (or drag-and-drop).
3. Drag your folder containing `index.html` into the upload area.
4. Click **Deploy**. You'll get a live URL like `watchtower.vercel.app` in under a minute.

**Recommended path (so future edits redeploy automatically):**

1. Push this folder to a new GitHub repo.
2. In Vercel: **Add New → Project → Import Git Repository** → pick the repo.
3. Framework preset: **Other** (it's a static HTML file, no build step needed).
4. Click **Deploy**.

## 6. Lock down auth redirect (optional but recommended)

In Supabase: **Authentication → URL Configuration**, add your Vercel URL
(e.g. `https://watchtower.vercel.app`) to **Site URL** and **Redirect URLs**.

---

## What's now dynamic vs. what's still hardcoded

| Data | Source |
|---|---|
| Company info, founder score, KPIs | `companies` table |
| Department scores | `departments` table |
| Alerts | `alerts` table |
| Top actions | `actions` table |
| Live pulse / activities | `activities` table |
| Daily wins | `wins` table |
| Risk overview | `risks` table |
| AI monitoring | `ai_monitoring` table |
| Login / roles / "Viewing as" | Supabase Auth + `profiles` table |

Sidebar nav items (Finance, Sales, etc.) are still static placeholders — they don't
route anywhere yet. That's a good next step once the core dashboard is live.

## Adding/editing data

For now, add or edit rows directly in Supabase: **Table Editor** → pick a table → edit
cells or **Insert row**. The dashboard re-fetches everything on every login/page load.

If you want *live* updates without a page refresh (e.g. a new alert appearing instantly
for everyone), that's a small addition using Supabase's Realtime subscriptions — ask
and I can wire that in next.

## Multi-company support

Right now every new sign-up gets attached to whichever company was created first
(fine for a single-company internal tool). If you'll have multiple client companies
each with their own WatchTower instance, that needs a small change to the sign-up
flow (e.g. an invite-code or company-picker step) — let me know if you want that added.
