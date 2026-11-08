---
id: TASK-046
title: SpacetimeDB data module for narration, languages, player and glyph animation
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:29:00Z'
labels:
  - database
dependencies: []
references:
  - https://spacetimedb.com/docs/quickstarts/rust
  - database/CLAUDE.md
priority: high
type: feature
ordinal: 48000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Narration, event names, languages and visual tuning are baked into .tres files, so changing them needs a rebuild and players cannot mod them. A local SpacetimeDB database (Rust module in database/, quickstart: https://spacetimedb.com/docs/quickstarts/rust) becomes the editable source of these lookup tables and of player track records.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Rust module publishes to the local server as database-narrator and holds tables: event_def, language_def, narration, player_stats, missing_narration, glyph_anim, config_version
- [x] #2 init reducer seeds every event and the languages EN_GB, HU_HU, ALIEN, MATRIX, DREAM, DE_DE, RU_RU, JP_HAN, JP_KANA, one narration row per event x language, and the default glyph animation rows
- [x] #3 Reducers exist for: counting a narration trigger, recording player stats (time, steps, transformations, death cause, language understanding), reporting a missing file (duplicates ignored) and bumping the config version
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Module in database/spacetimedb/src/lib.rs, spacetime.json -> local server. Also seeds event TRANSFORMED (fallback for TRANSFORMED_TO_ONE/MANY): 22 events x 9 languages = 198 narration rows. Verified via spacetime sql/call and curl: seeds, narration_triggered, record_death, add_play_stats, set_language_understanding (clamps), report_missing (dupes ignored), clear_missing, bump_config_version, reset_defaults. HTTP: POST /v1/identity -> {identity, token}; POST /v1/database/database-narrator/sql (raw SQL, Bearer) -> [{schema:{elements:[{name:{some}, algebraic_type}]}, rows:[[...]]}], Timestamp = [micros]; POST .../call/<reducer> JSON array -> 200 empty body, 400 text on bad args. Template client bindings in database/src regenerated.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
SpacetimeDB module database-narrator with event_def, language_def, narration, player_stats, player_death, player_language, missing_narration, glyph_anim, config_version tables, idempotent seeding and the gameplay reducers. Published to the local server and verified over CLI and plain HTTP.
<!-- SECTION:FINAL_SUMMARY:END -->
