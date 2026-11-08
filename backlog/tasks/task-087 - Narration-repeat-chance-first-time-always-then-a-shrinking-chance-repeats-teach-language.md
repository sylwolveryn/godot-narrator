---
id: TASK-087
title: >-
  Narration repeat chance: first time always, then a shrinking chance; repeats
  teach language
status: To Do
assignee: []
created_date: '2026-11-08T23:53:00Z'
labels:
  - narration
dependencies: []
priority: high
type: feature
ordinal: 92000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A trigger's line plays the first time always, even when it has to wait in the queue. Later firings of the same trigger play with a shrinking chance: 80, 60, 50, 35, 20, 12, 6, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, then 1 % forever. Hearing a line again gives the selected language 1 to 3 %.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A line never heard is guaranteed to play once its turn comes (never dropped from the queue)
- [ ] #2 Repeat chance follows the ladder by how many times the line was heard, minimum 1 %; the ladder is data, not code
- [ ] #3 Every repeat adds 1 to 3 % (random) to the selected language, within its cap
- [ ] #4 Origin claim / broken / recant lines keep their once-only rules
<!-- AC:END -->
