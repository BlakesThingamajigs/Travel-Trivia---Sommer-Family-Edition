-- Would You Rather mode replaces Herd Reveal (a swap, not an add) — see
-- 00_Vault/2026-07-29_would-you-rather-mode_decisions.md. Bundled fallback
-- mirror: ContentCatalog.bundledModes in the app. Existing local
-- EarnedBadge rows keyed "mode-mastery-herd-reveal" are unaffected (badges
-- are local-only, never synced) and stay resolvable via
-- BadgeCatalog.retiredModeMasteryBadges().
update public.modes
set slug = 'would-you-rather', display_name = 'Would You Rather'
where slug = 'herd-reveal';
