---
id: TASK-028
title: 'Spike B: glyph-object morph moments'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T21:53:00Z'
updated_date: '2026-10-30T21:57:00Z'
labels:
  - rendering
  - player
  - narrator
  - ux
milestone: m-3
dependencies: []
documentation:
  - docs/architecture.md
priority: high
type: spike
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
decision-002 defines morph as many glyph objects that fly, rotate and reassemble (Effulgence-style). A throwaway prototype must show three key moments and prove they are cheap enough (batched glyph quads, potato budget). Lives under scenes/spikes/ and must not change the main game.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Hero grows: a single-glyph hero rearranges into a larger multi-glyph entity and back
- [ ] #2 Surroundings to menu: nearby world glyphs lift off and rearrange into readable menu items, then return
- [ ] #3 Narration assembles: letters fly in to form a readable sentence, hold, then disperse
- [ ] #4 All glyph objects are batched (e.g. MultiMeshInstance3D or one canvas batch); captures, draw calls and GPU frame time at --max-fps 30 are in the task notes, and the spike runs from one command or from god
<!-- AC:END -->
