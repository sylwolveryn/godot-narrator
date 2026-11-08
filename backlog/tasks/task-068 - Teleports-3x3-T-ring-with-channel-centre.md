---
id: TASK-068
title: Teleports (3x3 T ring with channel centre)
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08T16:09:00Z'
updated_date: '2026-11-08T16:42:00Z'
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
- [x] #1 Only an exact 3x3 T ring with a channel centre is a working teleport; other T groups are broken (no teleport)
- [x] #2 Destination = next higher channel present (order 0-9, a-z, A-Z, wrapping); random among that channel's teleports; no teleport when only the same channel or a single teleport exists
- [x] #3 Teleport takes 3 s, movement blocked: 0.7 s glow-in with colour waves on floor and walls, eased camera move to the target, intense arrival wave
- [x] #4 Several candidates: camera zooms out fully, half-strength glow ping-pongs over the candidate teleports, then zooms in on the chosen one; arrival wave area and intensity x number of candidates
- [x] #5 Arena map has working teleports (several channels, multi-candidate case) and a broken one; tests cover parsing, destination choice and the event flow
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
TeleportPad parsing (exact 8-cell 3x3 T border + channel centre 0-9a-zA-Z; anything else broken), TeleportSystem (only writer: pad entry, next-higher-channel destination with wrap, seeded RNG, 3 s trip, movement + menu blocked, body moved via Player.place_at, re-fire blocked until the centre is left), TeleportView (frame/rune Label3Ds, broken cracks, eased CameraRig.override_view travel, zoom-out to zoom_max + half-strength pings over candidates, arrival ripples with area/intensity x N via sqrt(N) radius), glyph-surface wave uniforms (zero cost when idle). Arena: channels 0 (x2), 1, 7 (x3) + one broken ring. Signals teleport_started / teleport_arrived / teleport_finished. Verified: test_teleports + all 25 suites, god tests, captured frames. Not verified: GPU cost on target; at zoom_max not all three channel-7 pads fit on screen.
<!-- SECTION:FINAL_SUMMARY:END -->
