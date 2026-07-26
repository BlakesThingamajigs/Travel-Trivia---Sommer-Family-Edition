-- Travel Trivia — seed content
-- All 12 genres and 6 modes from the design docs, plus the 16 Riddle Realm
-- starter questions (matching the app's bundled SeedQuestions.swift).

insert into public.genres (slug, display_name, content_type, needs_media) values
    ('animal-sounds-safari', 'Animal Sounds Safari', 'sound', true),
    ('sound-fx-guess', 'Sound FX Guess', 'sound', true),
    ('name-that-tune', 'Name That Tune', 'sound', true),
    ('globe-trotter-clues', 'Globe-Trotter Clues', 'read', false),
    ('movie-quote-mashup', 'Movie Quote Mashup', 'read', false),
    ('would-you-rather', 'Would You Rather', 'read', false),
    ('riddle-realm', 'Riddle Realm', 'read', false),
    ('mythical-creatures-legends', 'Mythical Creatures & Legends', 'read', false),
    ('random-acts-of-weird-facts', 'Random Acts of Weird Facts', 'read', false),
    ('superlative-showdown', 'Superlative Showdown', 'read', false),
    ('time-machine', 'Time Machine', 'read', false),
    ('pop-culture-time-capsule', 'Pop Culture Time Capsule', 'read', false);

insert into public.modes (slug, display_name, min_players, requires_even_players, is_team_based) values
    ('elimination-bracket', 'Elimination Bracket', 4, true, false),
    ('team-relay', 'Team Relay', 4, true, true),
    ('copilots-curveball', 'Copilot''s Curveball', 2, false, false),
    ('herd-reveal', 'Herd Reveal', 3, false, false),
    ('double-or-nothing', 'Double or Nothing', 2, false, false),
    ('three-strikes', 'Three Strikes', 2, false, false);

-- 16 Riddle Realm seed questions. Option ids mirror the app's local seed
-- pack (riddle-N-I, first authored option is the correct one).
with riddle as (
    select id from public.genres where slug = 'riddle-realm'
)
insert into public.questions (genre_id, difficulty, prompt, options, correct_option_id, source)
select riddle.id, q.difficulty, q.prompt, q.options, q.correct_option_id, 'generated'
from riddle, (values
    ('easy',
     'I have keys but no locks, space but no room — you can enter, but not go outside. What am I?',
     '[{"id":"riddle-1-0","text":"Keyboard"},{"id":"riddle-1-1","text":"House"},{"id":"riddle-1-2","text":"Piano"},{"id":"riddle-1-3","text":"Map"},{"id":"riddle-1-4","text":"Wallet"},{"id":"riddle-1-5","text":"Elevator"}]'::jsonb,
     'riddle-1-0'),
    ('easy',
     'What has hands but can''t clap?',
     '[{"id":"riddle-2-0","text":"Clock"},{"id":"riddle-2-1","text":"Glove"},{"id":"riddle-2-2","text":"Statue"},{"id":"riddle-2-3","text":"Robot"},{"id":"riddle-2-4","text":"Watch"},{"id":"riddle-2-5","text":"Mannequin"}]'::jsonb,
     'riddle-2-0'),
    ('easy',
     'What has a neck but no head?',
     '[{"id":"riddle-3-0","text":"Bottle"},{"id":"riddle-3-1","text":"Shirt"},{"id":"riddle-3-2","text":"Guitar"},{"id":"riddle-3-3","text":"Turtle"},{"id":"riddle-3-4","text":"Violin"},{"id":"riddle-3-5","text":"Sweater"}]'::jsonb,
     'riddle-3-0'),
    ('easy',
     'What gets wetter the more it dries?',
     '[{"id":"riddle-4-0","text":"Towel"},{"id":"riddle-4-1","text":"Sponge"},{"id":"riddle-4-2","text":"Rain"},{"id":"riddle-4-3","text":"Ocean"},{"id":"riddle-4-4","text":"Washcloth"},{"id":"riddle-4-5","text":"Umbrella"}]'::jsonb,
     'riddle-4-0'),
    ('easy',
     'What has to be broken before you can use it?',
     '[{"id":"riddle-5-0","text":"Egg"},{"id":"riddle-5-1","text":"Promise"},{"id":"riddle-5-2","text":"Record"},{"id":"riddle-5-3","text":"Seal"},{"id":"riddle-5-4","text":"Piggy Bank"},{"id":"riddle-5-5","text":"Code"}]'::jsonb,
     'riddle-5-0'),
    ('easy',
     'What has one eye but can''t see?',
     '[{"id":"riddle-6-0","text":"Needle"},{"id":"riddle-6-1","text":"Storm"},{"id":"riddle-6-2","text":"Potato"},{"id":"riddle-6-3","text":"Cat"},{"id":"riddle-6-4","text":"Hurricane"},{"id":"riddle-6-5","text":"Button"}]'::jsonb,
     'riddle-6-0'),
    ('medium',
     'I speak without a mouth, hear without ears, and come alive with the wind. What am I?',
     '[{"id":"riddle-7-0","text":"Echo"},{"id":"riddle-7-1","text":"Ghost"},{"id":"riddle-7-2","text":"Shadow"},{"id":"riddle-7-3","text":"Whisper"},{"id":"riddle-7-4","text":"Wind"},{"id":"riddle-7-5","text":"Radio"}]'::jsonb,
     'riddle-7-0'),
    ('medium',
     'What comes once in a minute, twice in a moment, but never in a thousand years?',
     '[{"id":"riddle-8-0","text":"Letter M"},{"id":"riddle-8-1","text":"Heartbeat"},{"id":"riddle-8-2","text":"Blink"},{"id":"riddle-8-3","text":"Second"},{"id":"riddle-8-4","text":"Letter N"},{"id":"riddle-8-5","text":"Minute Hand"}]'::jsonb,
     'riddle-8-0'),
    ('medium',
     'I''m tall when I''m young and short when I''m old. What am I?',
     '[{"id":"riddle-9-0","text":"Candle"},{"id":"riddle-9-1","text":"Tree"},{"id":"riddle-9-2","text":"Person"},{"id":"riddle-9-3","text":"Pencil"},{"id":"riddle-9-4","text":"Match"},{"id":"riddle-9-5","text":"Crayon"}]'::jsonb,
     'riddle-9-0'),
    ('medium',
     'What can travel around the world while staying in a corner?',
     '[{"id":"riddle-10-0","text":"Stamp"},{"id":"riddle-10-1","text":"Map"},{"id":"riddle-10-2","text":"Globe"},{"id":"riddle-10-3","text":"Coin"},{"id":"riddle-10-4","text":"Postcard"},{"id":"riddle-10-5","text":"Sticker"}]'::jsonb,
     'riddle-10-0'),
    ('medium',
     'What building has the most stories?',
     '[{"id":"riddle-11-0","text":"Library"},{"id":"riddle-11-1","text":"Skyscraper"},{"id":"riddle-11-2","text":"Museum"},{"id":"riddle-11-3","text":"School"},{"id":"riddle-11-4","text":"Bookstore"},{"id":"riddle-11-5","text":"Apartment"}]'::jsonb,
     'riddle-11-0'),
    ('medium',
     'What''s full of holes but still holds water?',
     '[{"id":"riddle-12-0","text":"Sponge"},{"id":"riddle-12-1","text":"Net"},{"id":"riddle-12-2","text":"Colander"},{"id":"riddle-12-3","text":"Cloud"},{"id":"riddle-12-4","text":"Sieve"},{"id":"riddle-12-5","text":"Screen"}]'::jsonb,
     'riddle-12-0'),
    ('hard',
     'I''m not alive, but I grow. I don''t have lungs, but I need air. I don''t have a mouth, but water kills me. What am I?',
     '[{"id":"riddle-13-0","text":"Fire"},{"id":"riddle-13-1","text":"Plant"},{"id":"riddle-13-2","text":"Cloud"},{"id":"riddle-13-3","text":"Ice"},{"id":"riddle-13-4","text":"Smoke"},{"id":"riddle-13-5","text":"Steam"}]'::jsonb,
     'riddle-13-0'),
    ('hard',
     'What has many teeth but cannot bite?',
     '[{"id":"riddle-14-0","text":"Comb"},{"id":"riddle-14-1","text":"Saw"},{"id":"riddle-14-2","text":"Zipper"},{"id":"riddle-14-3","text":"Gear"},{"id":"riddle-14-4","text":"Rake"},{"id":"riddle-14-5","text":"Fork"}]'::jsonb,
     'riddle-14-0'),
    ('hard',
     'I shave every day, but my beard stays the same. What am I?',
     '[{"id":"riddle-15-0","text":"Barber"},{"id":"riddle-15-1","text":"Werewolf"},{"id":"riddle-15-2","text":"Goat"},{"id":"riddle-15-3","text":"Father Time"},{"id":"riddle-15-4","text":"Lumberjack"},{"id":"riddle-15-5","text":"Santa"}]'::jsonb,
     'riddle-15-0'),
    ('hard',
     'The more you take, the more you leave behind. What am I?',
     '[{"id":"riddle-16-0","text":"Footsteps"},{"id":"riddle-16-1","text":"Time"},{"id":"riddle-16-2","text":"Memories"},{"id":"riddle-16-3","text":"Breath"},{"id":"riddle-16-4","text":"Shadow"},{"id":"riddle-16-5","text":"Age"}]'::jsonb,
     'riddle-16-0')
) as q (difficulty, prompt, options, correct_option_id);
