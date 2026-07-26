-- Travel Trivia — initial content schema
-- genres / modes / questions, all public-readable via the anon key
-- (non-host players have no account and still need to pull questions).

create table public.genres (
    id uuid primary key default gen_random_uuid(),
    slug text unique not null,
    display_name text not null,
    content_type text not null check (content_type in ('sound', 'read')),
    needs_media boolean not null default false
);

create table public.modes (
    id uuid primary key default gen_random_uuid(),
    slug text unique not null,
    display_name text not null,
    min_players integer not null default 2,
    requires_even_players boolean not null default false,
    is_team_based boolean not null default false
);

create table public.questions (
    id uuid primary key default gen_random_uuid(),
    genre_id uuid not null references public.genres (id),
    difficulty text not null check (difficulty in ('easy', 'medium', 'hard')),
    prompt text not null,
    -- Ordered clue array; only populated for Globe-Trotter Clues
    -- (progressive-reveal scoring).
    clues jsonb,
    -- Only for the 3 sound genres.
    media_url text,
    -- Array of {id, text}; always 6 per the 2x3 answer grid.
    options jsonb not null,
    -- References an option's id (not an index) so client-side display
    -- shuffling is safe.
    correct_option_id text not null,
    source text not null default 'generated'
        check (source in ('generated', 'open_trivia_db')),
    -- Required when source is open_trivia_db (CC BY-SA).
    attribution text,
    created_at timestamptz not null default now()
);

create index questions_genre_difficulty_idx
    on public.questions (genre_id, difficulty);

alter table public.genres enable row level security;
alter table public.modes enable row level security;
alter table public.questions enable row level security;

create policy "Public read access" on public.genres
    for select using (true);

create policy "Public read access" on public.modes
    for select using (true);

create policy "Public read access" on public.questions
    for select using (true);
