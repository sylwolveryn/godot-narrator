---
id: TASK-084
title: >-
  Narration speakers: distinct font and colour palette for world, own and
  narrator lines
status: To Do
assignee: []
created_date: '2026-11-08T23:17:00Z'
labels:
  - narration
  - ui
dependencies: []
priority: medium
type: feature
ordinal: 89000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Players cannot tell who speaks: world, the character's own memory and the narrator lines look alike. Give each layer a clearly different font and colour palette (NarrationOverlay), data-driven.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 World, own and narrator lines differ in font family and colour at a glance
- [ ] #2 Fonts and colours per layer come from config (DB or resource), not code
- [ ] #3 Readable on every map's lighting at 1920x1080 and on the low-end laptop
<!-- AC:END -->
