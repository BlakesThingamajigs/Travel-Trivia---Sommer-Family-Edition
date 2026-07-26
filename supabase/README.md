# Supabase migrations

Schema + seed content for the Travel Trivia Supabase project (`genres`,
`modes`, `questions`, all public-readable via the anon key — see the
2026-07-26 schema design note in the vault).

**Status: written but not yet applied.** No credentials for the Travel
Trivia Supabase project existed on this machine during the first build
session (no CLI login, no service key, no `Supabase.xcconfig.local`), so
the migrations could not be run remotely.

To apply, either:

1. **Supabase CLI** (preferred, keeps migration history):
   ```sh
   brew install supabase/tap/supabase
   supabase login
   supabase link --project-ref <PROJECT_REF>
   supabase db push
   ```
2. **Dashboard fallback:** paste each file from `migrations/` into the SQL
   editor in timestamp order and run.

Afterwards, verify the seed content is queryable anonymously:

```sh
curl "https://<PROJECT_REF>.supabase.co/rest/v1/questions?select=prompt&limit=3" \
  -H "apikey: <ANON_KEY>"
```

Also copy `Travel Trivia/Supabase/Supabase.xcconfig.example` to
`Supabase.xcconfig.local` (same folder) with the real URL + anon key so the
app's stubbed client can light up in a later session.
