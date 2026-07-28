-- Travel Trivia — fact-check fixes for two Superlative Showdown round-2
-- questions (super-51 and super-60).
--
-- super-51: "saltiest body of water" previously named The Dead Sea
-- (~34% salinity) as correct, but Don Juan Pond in Antarctica's Dry
-- Valleys (~44% salinity) is the actual record holder and wasn't even
-- among the options. Replaced with a corrected prompt/options; bumped
-- Medium -> Hard since Don Juan Pond is a more obscure fact than the
-- Dead Sea.
--
-- super-60: "fastest production car" named Bugatti as correct via a
-- "currently fastest" framing, which has gone stale now that a newer
-- car holds a faster verified record — this category changes too often
-- for a durable trivia answer. Reworded to an evergreen historical
-- framing (Bugatti's Chiron Super Sport 300+ record) with the same
-- correct answer and options, so no answer-key change, just a prompt
-- fix so it stays true regardless of future record changes.
--
-- Same UPDATE-by-content pattern as 20260728005236_fix_riddle_18_duplicate.sql
-- (match by current prompt text, not a blind ID guess).

update public.questions
set prompt = 'What''s the saltiest body of water on Earth, found in Antarctica''s Dry Valleys?',
    difficulty = 'hard',
    options = '[{"id":"super-51-0","text":"Don Juan Pond"},{"id":"super-51-1","text":"The Dead Sea"},{"id":"super-51-2","text":"The Great Salt Lake"},{"id":"super-51-3","text":"The Caspian Sea"},{"id":"super-51-4","text":"Lake Assal"},{"id":"super-51-5","text":"The Red Sea"}]'::jsonb,
    correct_option_id = 'super-51-0'
where prompt = 'What''s among the saltiest bodies of water in the world?'
  and options @> '[{"id":"super-51-0"}]'::jsonb;

update public.questions
set prompt = 'Which car brand held the officially verified top-speed record for production cars for several years with its Chiron Super Sport 300+?',
    options = '[{"id":"super-60-0","text":"Bugatti"},{"id":"super-60-1","text":"Koenigsegg"},{"id":"super-60-2","text":"SSC"},{"id":"super-60-3","text":"Hennessey"},{"id":"super-60-4","text":"McLaren"},{"id":"super-60-5","text":"Ferrari"}]'::jsonb,
    correct_option_id = 'super-60-0'
where prompt = 'What''s among the fastest production cars in the world by top speed record?'
  and options @> '[{"id":"super-60-0"}]'::jsonb;
