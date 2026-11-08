---
id: TASK-072
title: Interact control (Space / left click)
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08T16:54:00Z'
updated_date: '2026-11-08T18:12:00Z'
labels:
  - input
  - gameplay
dependencies: []
priority: high
type: feature
ordinal: 74000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Objects like the cannon need a generic interact action. Space and left click already mean other things (menu confirm, intro skip, walk to cursor), so interact must take precedence only when an interactable object is in reach.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 InputMap action interact: Space and left mouse button (and a gamepad button)
- [ ] #2 When the player stands next to an interactable, press / hold go to that object and the click does not also walk the player; otherwise Space / click keep their old meaning
- [ ] #3 Interactables register generically (press, hold duration, release) so later objects can reuse it
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. InputMap action interact (Space, LMB, pad X) in build_input_map. 2. Interactable base (footprint, reach, press/hold/release) + Interactables registry node (focus, precedence via _input before menu/discovery, after intro). 3. Player suppresses pointer walking while held (SignalBus.interact_hold_changed). 4. InteractHintView glyph. 5. tools/test_interact.gd.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: scripts/world/interactable.gd, interactables.gd, interact_config.gd, scripts/rendering/interact_hint_view.gd; player.gd pointer suppression; signals interact_focus_changed / interact_hold_changed. Test tools/test_interact.gd PASS.
<!-- SECTION:NOTES:END -->
