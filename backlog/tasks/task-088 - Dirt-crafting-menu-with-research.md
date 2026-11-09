---
id: TASK-088
title: Dirt crafting menu with research
status: Done
assignee: []
created_date: '2026-11-08T23:53:00Z'
updated_date: '2026-11-09T00:35:00Z'
labels:
  - menu
  - gameplay
  - narration
dependencies: []
priority: medium
type: feature
ordinal: 93000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Choosing dirt in the Items list opens a crafting menu: the known crafts and a Research option. At first only Research is there. Research and crafting have their own narration.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Items > dirt opens the crafting list: known crafts, then research, then back
- [x] #2 Research costs dirt and teaches the next craft from a data list; crafts cost dirt and are counted
- [x] #3 Not enough dirt: refused with a narration line
- [x] #4 Narration events for research, a new craft learned and crafting, with themed lines
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DB table craft_def (id, label, research_order, research_cost, craft_cost; 5 themed placeholder recipes, no gameplay effect yet), god table lists and seeds.TABLE_KEYS, DbConfig.tables (db_config.tres via ResourceSaver). seed.json NOT touched (user's work in progress): Save DB to seed adds the table. Crafting node (scripts/core/crafting.gd, in main): research / craft through SaveService.spend (stock = consumed - spent), learn_craft, add_crafted; narration RESEARCH_DONE + CRAFT_LEARNED, CRAFTED, CRAFT_REFUSED. MenuController: Items list shows stock; the crafting kind (dirt) opens the crafting page (recipes 'label cost', 'research cost', back), research stays selected after learning, back returns to Items on dirt. Save: spent, known_crafts, crafted. test_crafting PASS; test_save, items, menu, scroll PASS.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Items > dirt opens a crafting page: research spends dirt to learn recipes, crafting spends dirt; all narrated.
<!-- SECTION:FINAL_SUMMARY:END -->
