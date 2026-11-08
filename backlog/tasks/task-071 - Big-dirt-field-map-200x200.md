---
id: TASK-071
title: Big dirt field map (200x200)
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-08T16:54:00Z'
labels:
  - world
dependencies:
  - TASK-070
priority: medium
type: feature
ordinal: 73000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A stress and play map: 200x200 cells, plain # walls around, everything inside is dirt D, the player in the middle. It also checks that maps, dirt and rendering scale to 40,000 cells on potato hardware.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 data/maps/m4_dirt_field.txt: 200x200, # border, D everywhere inside, @ in the centre
- [ ] #2 Loads and plays at the potato target (load time and frame cost measured and reported); eating dirt works across the map
<!-- AC:END -->
