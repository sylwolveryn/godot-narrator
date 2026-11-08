---
id: TASK-069
title: Per-map visibility settings from the DB
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T16:44:00Z'
updated_date: '2026-11-08T17:17:00Z'
labels:
  - world
  - database
  - rendering
dependencies: []
priority: high
type: feature
ordinal: 71000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Maps need different visibility rules: the new dirt map is fully revealed with no fog, while the existing maps keep fog, a limited sight radius and dark surroundings. These rules move to a DB table per map, with today's behaviour as the fallback when a map has no row.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 DB table map_settings (one row per map id) holds reveal/fog/sight/light settings; editable in the god window grid
- [ ] #2 A map without a row behaves exactly as today (fog on, reveal radius with line of sight, darkness and memory look outside the light)
- [ ] #3 A map can start fully revealed with no fog/darkness so everything is visible all the time
- [ ] #4 Settings are applied when the map loads and on a DB reload; tests cover default and override
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. MapSettings (pure data: effective visibility rules, resolve(row, RevealConfig, GlyphWorldConfig); a missing row or a negative number = today's config value).
2. MapSettingsResolver node (data layer, the one owner of the per-map row): row for MapLoader.map_id from GameDatabase table map_settings; emits settings_changed on tables_loaded.
3. MapReveal: reveal radius / line of sight from the settings; reveal_all = every drawn cell seen at run start (no memory look). GlyphWorldView: fog (fog_strength, depth fade), darkness (ambient level/colour, memory look), player light radius from the settings; re-applied on settings_changed.
4. DB: Rust table map_settings + seed row m3_dirt, reset_defaults; seed.json; DbConfig.tables; god DB_TABLES / DB_PRIMARY_KEYS.
5. tools/test_map_settings.gd: no row = identical uniforms/reveal to the configs; m3_dirt row = all seen, fog/darkness off; DB reload re-applies.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: MapSettings (scripts/world/map_settings.gd) + MapSettingsResolver (scripts/data/map_settings_resolver.gd, node in main). MapReveal / GlyphWorldView resolve on map build, begin_run and settings_changed (DB reload). New shader uniform ambient_color (default = old hardcoded value). DB table map_settings (Rust + seed.json + DbConfig.tables + god DB_TABLES/DB_PRIMARY_KEYS), seed row m3_dirt; module published locally + seed_defaults. tools/test_map_settings.gd PASS; m1 frame pixel-identical to HEAD apart from the random identity glyph.
<!-- SECTION:NOTES:END -->
