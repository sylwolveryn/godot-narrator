---
id: TASK-046
title: SpacetimeDB data module for narration, languages, player and glyph animation
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T13:18:00Z'
updated_date: '2026-11-08T13:19:00Z'
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
- [ ] #1 Rust module publishes to the local server as database-narrator and holds tables: event_def, language_def, narration, player_stats, missing_narration, glyph_anim, config_version
- [ ] #2 init reducer seeds every event and the languages EN_GB, HU_HU, ALIEN, MATRIX, DREAM, DE_DE, RU_RU, JP_HAN, JP_KANA, one narration row per event x language, and the default glyph animation rows
- [ ] #3 Reducers exist for: counting a narration trigger, recording player stats (time, steps, transformations, death cause, language understanding), reporting a missing file (duplicates ignored) and bumping the config version
<!-- AC:END -->
