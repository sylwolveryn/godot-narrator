**Project goal:** A 2.5D roguelike, storyteller ascii art game built in Godot using GDScript

**Godot version:** Godot 4.7.2
    
**Hard rules:**
- Never edit `.tscn` or `.tres` files as raw text. Use headless tool scripts in `tools/` or the Godot MCP.
- Always use `--headless` for any CLI run.
- Use snake_case for files/folders, PascalCase for node names.
- Signals travel UP only: UI never modifies data directly; data layer speaks through signals.
- No magic numbers in gameplay code. Values live in `.tres` resources or exported vars.
- Never reference files under `docs/art/` from code or scenes. They are reference material, not assets.
- git: work in main, commit and push your changes.

## Potato-First Rule (non-negotiable)
Target hardware: Low-end laptop with integrated GPU that only supports OpenGL 3.3 (e.g., Intel HD Graphics 2500/4000 class). This is Godot's official minimum GPU baseline for the Compatibility renderer. The game must run at stable 30+ FPS on this class of machine.

Project settings that MUST stay:
- Renderer: Compatibility (OpenGL 3.3). Never switch to Forward+ or Mobile.
- `physics_ticks_per_second`: 60. Never raise it.
- `--max-fps 30` on every CLI run.

# Model Routing
- Documentation, ADR, progress reports, task breakdown → use subagent `doc-writer` (Haiku)
- Gameplay code, scenes, GDScript → Sonnet (current session default)
- Game design decisions, systems, balance → use subagent `game-designer` (Opus) OR ask me to switch to Opus via `/model`

## When Stuck
If a Haiku task produces something wrong or incomplete, do NOT retry endlessly.
Stop, report what failed, and ask the main session to either:
1. Take over directly (Sonnet/Opus), or
2. Escalate to `game-designer` (Opus) if it's a design problem.
    
## Where to Find Things
- Game design details (mechanics, numbers, content lists): `docs/game_design.md`
- Current milestones and tasks: `docs/roadmap.md`
- Godot CLI command reference: `docs/godot_cli.md`
- Godot code/scene conventions: `.claude/skills/godot-conventions/SKILL.md`
- Visual references (moodboard, character concepts, target screenshots): `docs/art/`
  — these are documentation only, never used as runtime assets

## Validation Commands
1. `godot --headless --check-only --script <edited>.gd`   (parse errors, fast)
2. `godot --headless --path . --quit-after 60`            (boots without runtime errors)
3. For UI/visual changes: launch and look at the rendered result. A green run is not the same as the screen looking right.

## When to use the validator subagent
After any GDScript change, ask: "use the godot-validator to check my last change." Do not run validation inline in the main session if the log output may be long.

## When to use the Godot MCP
Prefer MCP for scene-tree inspection and node edits on the currently open editor. Prefer CLI headless for fast syntax checks and boot smoke tests. Do not use both for the same edit.

<!-- BACKLOG.MD GUIDELINES START -->
<!-- backlog.md-instructions-version: 1.55.3 -->
<CRITICAL_INSTRUCTION>

## Backlog.md Workflow

This project uses Backlog.md for task and project management.

**At the beginning of each conversation in this project, run `backlog instructions overview` before answering or taking action. Re-read it only if you have not read it yet in the current conversation.**

Use the overview to decide whether to search, read, create, or update Backlog tasks.

Before task lifecycle actions, read the matching detailed guide:
- `backlog instructions task-creation` before creating or splitting tasks
- `backlog instructions task-execution` before planning, changing status or assignee, adding a plan or implementation notes, or implementing task work
- `backlog instructions task-finalization` before checking acceptance criteria, writing final summaries, or moving tasks to terminal statuses

Use `backlog <command> --help` before running unfamiliar commands. Help shows options, fields, and examples.

Do not edit Backlog task, draft, document, decision, or milestone markdown files directly. Use the `backlog` CLI so metadata, relationships, and history stay consistent.

</CRITICAL_INSTRUCTION>
<!-- BACKLOG.MD GUIDELINES END -->
