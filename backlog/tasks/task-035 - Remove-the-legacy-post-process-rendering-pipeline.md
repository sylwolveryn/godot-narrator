---
id: TASK-035
title: Remove the legacy post-process rendering pipeline
status: To Do
assignee: []
created_date: '2026-10-30T22:45:00Z'
updated_date: '2026-10-31T07:40:00Z'
labels:
  - rendering
milestone: m-5
dependencies:
  - TASK-031
priority: medium
type: chore
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Once the glyph world is in the game, the superseded post-process pipeline (ascii_post, SDF atlas bake, data-encoded world materials, palette LUT, encoding test, related configs) is dead weight and a source of confusion.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Legacy post-process shaders, scripts, configs and tests are removed, and nothing references them
- [ ] #2 All remaining tools/test_*.gd pass and the headless boot has zero ERROR lines
- [ ] #3 docs/architecture.md describes only the glyph-world pipeline
<!-- AC:END -->
