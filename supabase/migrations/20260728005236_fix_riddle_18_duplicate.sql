-- Travel Trivia — fix a content duplicate in Riddle Realm.
--
-- Round 2 (20260727180000_genre_content_round2.sql) accidentally reused
-- the original pack's riddle-16 prompt ("The more you take, the more you
-- leave behind. What am I?") for riddle-18, just with slightly reworded
-- options. This replaces riddle-18 in place (same row, same option-id
-- prefix/indices, same Medium difficulty) with fresh content — mirrors
-- the same fix already made in SeedQuestions.swift.

update public.questions
set prompt = 'I begin with T, end with T, and I''m full of T. What am I?',
    options = '[{"id":"riddle-18-0","text":"A teapot"},{"id":"riddle-18-1","text":"A tent"},{"id":"riddle-18-2","text":"A toast"},{"id":"riddle-18-3","text":"A ticket"},{"id":"riddle-18-4","text":"A trumpet"},{"id":"riddle-18-5","text":"A turtle"}]'::jsonb,
    correct_option_id = 'riddle-18-0'
where prompt = 'The more you take, the more you leave behind. What am I?'
  and options @> '[{"id":"riddle-18-0"}]'::jsonb;
