---
id: TASK-068
title: Teleports (3x3 T ring with channel centre)
status: To Do
assignee:
  - '@claude'
created_date: '2026-11-08T16:09:00Z'
labels:
  - world
  - rendering
  - gameplay
dependencies: []
priority: high
type: feature
ordinal: 70000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A new map object: a teleport is exactly a 3x3 ring of T with a channel character in the middle (0-9, a-z, A-Z). Stepping on the centre sends the player to the next higher channel present on the map (wrapping Z -> 0), randomly to one of that channel's teleports. Anything else made of T is a broken teleport. The trip is a 3 s event with a glow-in, colour waves on floor and walls, an eased camera move, and, when several destinations exist, a zoomed-out ping-pong between them before the camera settles on the chosen one, whose arrival wave scales with the number of candidates.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Only an exact 3x3 T ring with a channel centre is a working teleport; other T groups are broken (no teleport)
- [ ] #2 Destination = next higher channel present (order 0-9, a-z, A-Z, wrapping); random among that channel's teleports; no teleport when only the same channel or a single teleport exists
- [ ] #3 Teleport takes 3 s, movement blocked: 0.7 s glow-in with colour waves on floor and walls, eased camera move to the target, intense arrival wave
- [ ] #4 Several candidates: camera zooms out fully, half-strength glow ping-pongs over the candidate teleports, then zooms in on the chosen one; arrival wave area and intensity x number of candidates
- [ ] #5 Arena map has working teleports (several channels, multi-candidate case) and a broken one; tests cover parsing, destination choice and the event flow
<!-- AC:END -->
