---
id: TASK-056
title: Crystalline glow on the player glyph
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-08T14:07:00Z'
labels:
  - rendering
dependencies: []
priority: medium
type: enhancement
ordinal: 58000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The avatar looks good but static. A slow, cheap colour-shift glow (old-school ASCII feel, no heavy effects) makes it feel alive. Tuning lives in the DB so it can be changed live.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The player glyph slowly shifts through a crystal palette with a soft glow; cost stays in the existing actor shader
- [ ] #2 Palette, speed and strength come from the DB avatar_fx table and apply on reload
<!-- AC:END -->
