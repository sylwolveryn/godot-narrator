---
id: TASK-008
title: Adaptive input discovery
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-30T15:30:00Z'
updated_date: '2026-10-30T16:26:00Z'
labels:
  - input
  - player
milestone: m-0
dependencies:
  - TASK-007
  - TASK-001
documentation:
  - docs/game_design.md
priority: high
type: feature
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Movement is discovered, not explained. The game must register whichever input device the player uses first (keyboard, mouse, gamepad) and map movement to it, without any tutorial text.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Any supported input (WASD, arrow keys, mouse, or gamepad) is accepted as the first input.
- [ ] #2 The first registered input is used to map movement, and the mapping is stored for the run.
- [ ] #3 All movement input goes through `InputMap` actions in `project.godot`; no raw keycode checks.
- [ ] #4 Inputs that are not supported do not change the mapping.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. InputScheme constants + InputMap actions (tools/build_input_map.gd writes project.godot [input]; drop legacy transform).
2. InputDiscovery node: classifies event device type + matches move actions; emits SignalBus.input_scheme_discovered on first/changed supported scheme; RunManager stores it in RunState.
3. Headless test tools/test_input_movement.gd.
<!-- SECTION:PLAN:END -->
