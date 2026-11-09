---
id: TASK-020.07
title: 'god: narration queue debug overlay toggle'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-09T09:41:00Z'
updated_date: '2026-11-09T09:48:00Z'
labels:
  - tools
  - narration
dependencies: []
parent_task_id: TASK-020
ordinal: 105000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The narration queue (text beats, chained layers, reactive FIFO, waiting FIFO, TTL queue) and the voice/mood audio are hard to follow. A debug overlay on the left side of the running game shows them live, with the waiting periods visualised, switched from god like the FPS overlay.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 god has a Queue on/off button that shows the current state
- [ ] #2 Toggling it shows/hides a left-side overlay in a running game within about a second
- [x] #3 Overlay shows the narrator state with phase timeline (morph in, hold, morph out, gap) and time left
- [x] #4 Overlay shows the queued beat with its TTL, chained layers, reactive and waiting FIFOs
- [x] #5 Overlay shows mood and voice playback progress and flags a voice cut off by the next beat
- [x] #6 Overlay shows a recent event log and a history strip of text and voice activity
- [x] #7 When never switched on, nothing is instanced
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Narrator.debug_note signal traces every queue decision; read-only accessors added. NarrationDebugOverlay (scripts/ui) draws one Control at 10 Hz. DevBridge [overlay] narration=true instances it lazily; god Queue button writes the flag. Verified: 115 god unittests, test_narrator/triggers/library PASS, headless boot clean, windowed capture via tools/capture_narration_debug.gd. Not yet verified: clicking god's Queue button against a live game (AC 1-2).
<!-- SECTION:NOTES:END -->
