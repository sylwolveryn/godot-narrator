"""god: developer launcher for the Narrator Godot game. Run with `python god/god.py`."""
from __future__ import annotations

import queue
import sys
import threading
import time
import tkinter as tk
from tkinter import messagebox, ttk

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent))

import core  # noqa: E402
import seeds  # noqa: E402
import palette  # noqa: E402
from palette_dialog import PaletteDialog  # noqa: E402
import mods  # noqa: E402
from mods_dialog import ModsDialog  # noqa: E402


class GodApp:
    def __init__(self, root: tk.Tk, controller: core.GameController, db: core.DbServer):
        self.win = root
        self.ctl = controller
        self.db = db
        self.db_running = False
        self.db_busy = False
        self.db_query_in_flight = False
        self.table_tabs: dict = {}
        # Table editing (task-061): per tab {tree, table, key_index, items: key text -> tree item}; undo/redo history.
        self.table_meta: dict = {}
        self.history = core.EditHistory()
        self.owner_token = None
        # Seed versions (task-020.06): last DB comparison, None until the first one.
        self.seed_state = None
        self._editor = None
        self.results: "queue.Queue" = queue.Queue()
        self.running = False
        self.busy = False
        self.query_in_flight = False
        self.last_sig = object()  # forces the first render
        self.notice = ""
        self.fps_flags = core.dev_flags_path(controller.save)
        root.title("god - Narrator launcher")
        root.minsize(640, 760)
        self._build()
        for seq in ("<Control-z>", "<Control-Z>"):
            root.bind_all(seq, self._undo)
        for seq in ("<Control-y>", "<Control-Y>", "<Control-Shift-z>", "<Control-Shift-Z>"):
            root.bind_all(seq, self._redo)
        self.poll()
        self._drain()

    # ---------------------------------------------------------------- layout
    def _build(self) -> None:
        pad = {"padx": 10, "pady": 4}
        self.status = ttk.Label(self.win, text="Game: ...", font=("Segoe UI", 11, "bold"))
        self.status.pack(anchor="w", **pad)
        row = ttk.Frame(self.win)
        row.pack(fill="x", **pad)
        self.btn_new = ttk.Button(row, text="Start new game", command=lambda: self._act(self.ctl.new_game, "Started a new game."))
        self.btn_mods = ttk.Button(row, text="New game with mods...", command=self._new_game_mods)
        self.btn_cont = ttk.Button(row, text="Continue game", command=self._continue)
        self.btn_reveal = ttk.Button(row, text="Reveal map", command=self._reveal)
        self.btn_fps = ttk.Button(row, text="FPS: off", command=self._toggle_fps)
        self.btn_import = ttk.Button(row, text="Import assets", command=self._import_assets)
        for b in (self.btn_new, self.btn_mods, self.btn_cont, self.btn_reveal, self.btn_fps, self.btn_import):
            b.pack(side="left", padx=(0, 6))
        self._build_map_pick(row)
        spikes = ttk.Frame(self.win)
        spikes.pack(fill="x", **pad)
        ttk.Label(spikes, text="Prototypes:").pack(side="left", padx=(0, 6))
        for label, scene in core.SPIKES.items():
            ttk.Button(spikes, text=label, command=lambda s=scene, l=label: self._spike(s, l)).pack(side="left", padx=(0, 6))
        self.message = ttk.Label(self.win, text="", wraplength=450, foreground="#a15c00")
        self.message.pack(anchor="w", **pad)
        ttk.Separator(self.win).pack(fill="x", padx=10, pady=4)
        ttk.Label(self.win, text="Progress", font=("Segoe UI", 10, "bold")).pack(anchor="w", **pad)
        self.progress = tk.Text(self.win, height=8, wrap="word", state="disabled", relief="flat", background=self.win.cget("background"))
        self.progress.pack(fill="x", padx=10, pady=(0, 4))
        self.progress.tag_configure("key", font=("Segoe UI", 9, "bold"))
        self.progress.tag_configure("err", foreground="#b00020")
        self.progress.tag_configure("empty", foreground="#666666")
        self._build_db()

    def _build_map_pick(self, row) -> None:
        """Map chooser (task-060): data/maps/*.txt; the choice is remembered in god/settings.json."""
        self.settings_file = core.settings_path()
        settings = core.load_settings(self.settings_file)
        maps = core.list_maps(self.ctl.root)
        ttk.Label(row, text="Map:").pack(side="left", padx=(6, 4))
        self.map_pick = ttk.Combobox(row, values=maps, state="readonly", width=18)
        chosen = core.choose_map(maps, settings.get(core.SETTING_MAP))
        if chosen:
            self.map_pick.set(chosen)
        self.ctl.map_name = chosen
        self.map_pick.bind("<<ComboboxSelected>>", self._on_map_picked)
        self.map_pick.pack(side="left")

    def _on_map_picked(self, _event=None) -> None:
        name = self.map_pick.get() or None
        self.ctl.map_name = name
        settings = core.load_settings(self.settings_file)
        settings[core.SETTING_MAP] = name
        try:
            core.save_settings(self.settings_file, settings)
        except OSError as e:
            self._log("Could not save settings: %s" % e, error=True)

    def _build_db(self) -> None:
        pad = {"padx": 10, "pady": 4}
        ttk.Separator(self.win).pack(fill="x", padx=10, pady=4)
        head = ttk.Frame(self.win)
        head.pack(fill="x", **pad)
        ttk.Label(head, text="Database", font=("Segoe UI", 10, "bold")).pack(side="left", padx=(0, 10))
        # Running / stopped light: green / red dot (grey until the first poll).
        self.db_light = tk.Canvas(head, width=16, height=16, highlightthickness=0, background=self.win.cget("background"))
        self.db_dot = self.db_light.create_oval(2, 2, 14, 14, fill=core.indicator_color(None), outline="#333333")
        self.db_light.pack(side="left", padx=(0, 6))
        self.db_status = ttk.Label(head, text="DB: ...", font=("Segoe UI", 10, "bold"))
        self.db_status.pack(side="left")
        ttk.Label(head, text="   double-click a cell to edit (saved at once), Ctrl+Z / Ctrl+Y undo / redo",
                  foreground="#666666").pack(side="left")
        row1 = ttk.Frame(self.win)
        row1.pack(fill="x", **pad)
        self.db_buttons = [
            ttk.Button(row1, text="Start DB", command=self._db_start),
            ttk.Button(row1, text="Stop DB", command=self._db_stop),
            ttk.Button(row1, text="Publish module", command=self._db_publish),
            ttk.Button(row1, text="Reload game data", command=lambda: self._db_call(
                "bump_config_version", "Config version bumped: running games reload their tables.")),
            ttk.Button(row1, text="Clear missing", command=lambda: self._db_call(
                "clear_missing", "Missing narration list cleared.")),
        ]
        for b in self.db_buttons:
            b.pack(side="left", padx=(0, 6))
        row2 = ttk.Frame(self.win)
        row2.pack(fill="x", **pad)
        ttk.Label(row2, text="Table:").pack(side="left", padx=(0, 6))
        self.table_pick = ttk.Combobox(row2, values=core.DB_TABLES, state="readonly", width=20)
        self.table_pick.current(0)
        self.table_pick.pack(side="left", padx=(0, 6))
        self.btn_read = ttk.Button(row2, text="Read table", command=lambda: self._db_read([self.table_pick.get()]))
        self.btn_read_all = ttk.Button(row2, text="Read all", command=lambda: self._db_read(list(core.DB_TABLES)))
        for b in (self.btn_read, self.btn_read_all):
            b.pack(side="left", padx=(0, 6))
            self.db_buttons.append(b)
        self._build_seed_row(pad)
        # Player movement (DB movement_profile): edit a profile; the running game picks it up on its next poll.
        row3 = ttk.Frame(self.win)
        row3.pack(fill="x", **pad)
        ttk.Label(row3, text="Movement:").pack(side="left", padx=(0, 6))
        self.move_pick = ttk.Combobox(row3, values=core.MOVEMENT_PROFILES, width=9)
        self.move_pick.current(0)
        self.move_pick.pack(side="left", padx=(0, 6))
        self.move_vars = {}
        for field in core.MOVEMENT_FIELDS:
            ttk.Label(row3, text=field.replace("_", " ")).pack(side="left", padx=(4, 2))
            var = tk.StringVar()
            ttk.Entry(row3, textvariable=var, width=6).pack(side="left")
            self.move_vars[field] = var
        self.btn_move_load = ttk.Button(row3, text="Load", command=self._move_load)
        self.btn_move_apply = ttk.Button(row3, text="Apply", command=self._move_apply)
        for b in (self.btn_move_load, self.btn_move_apply):
            b.pack(side="left", padx=(6, 0))
            self.db_buttons.append(b)
        self.tabs = ttk.Notebook(self.win)
        self.tabs.pack(fill="both", expand=True, padx=10, pady=(4, 10))
        log_frame = ttk.Frame(self.tabs)
        self.db_log = tk.Text(log_frame, height=10, wrap="word", state="disabled", font=("Consolas", 9))
        log_scroll = ttk.Scrollbar(log_frame, orient="vertical", command=self.db_log.yview)
        self.db_log.configure(yscrollcommand=log_scroll.set)
        log_scroll.pack(side="right", fill="y")
        self.db_log.pack(side="left", fill="both", expand=True)
        self.db_log.tag_configure("err", foreground="#b00020")
        self.tabs.add(log_frame, text="Log")

    def _build_seed_row(self, pad: dict) -> None:
        """Seed versions (task-020.06): save the DB into data/db/seed.json (rotating current -> previous -> old)
        and reseed the DB from a chosen version."""
        row = ttk.Frame(self.win)
        row.pack(fill="x", **pad)
        ttk.Label(row, text="Seed:").pack(side="left", padx=(0, 6))
        self.seed_pick = ttk.Combobox(row, values=seeds.existing_versions(self.ctl.root), state="readonly", width=9)
        if self.seed_pick["values"]:
            self.seed_pick.current(0)
        self.seed_pick.pack(side="left", padx=(0, 6))
        self.btn_seed_save = ttk.Button(row, text="Save DB to seed", command=self._seed_save)
        self.btn_seed_load = ttk.Button(row, text="Reseed DB", command=self._seed_reseed)
        for b in (self.btn_seed_save, self.btn_seed_load):
            b.pack(side="left", padx=(0, 6))
        self.seed_status = ttk.Label(row, text="", foreground="#666666")
        self.seed_status.pack(side="left", padx=(6, 0))

    def _render_seed(self) -> None:
        versions = seeds.existing_versions(self.ctl.root)
        chosen = self.seed_pick.get()
        self.seed_pick.config(values=versions)
        if chosen not in versions:
            self.seed_pick.set(versions[0] if versions else "")
        st = self.seed_state
        up = self.db_running and st is not None and not self.db_busy
        # Save only when the DB differs from the current seed (or there is no seed file yet).
        self.btn_seed_save.config(state="normal" if up and st["match"] != "current" else "disabled")
        self.btn_seed_load.config(state="normal" if up and self.seed_pick.get() else "disabled")
        if not self.db_running:
            text = "DB not running"
        elif st is None:
            text = "comparing DB with the seeds..."
        elif st.get("error"):
            text = "cannot compare: %s" % st["error"]
        elif st["match"] == "current":
            text = "DB = current seed (nothing to save)"
        elif st["match"]:
            text = "DB = %s seed; differs from current" % st["match"]
        else:
            text = "DB has unsaved changes" if "current" in versions else "no seed file yet"
        self.seed_status.config(text=text)

    def _seed_compare(self) -> dict:
        try:
            snap = seeds.snapshot(self.db.client.read_table)
        except Exception as e:  # shown next to the buttons
            return {"match": None, "error": str(e)}
        return {"match": seeds.matching_version(self.ctl.root, snap), "error": None}

    def _seed_save(self) -> None:
        def run() -> str:
            snap = seeds.snapshot(self.db.client.read_table)
            current = seeds.version_path(self.ctl.root, "current")
            if current.is_file() and seeds.same(seeds.load_seed(current), snap):
                return "The DB equals the current seed; nothing saved."
            versions = seeds.save_rotating(self.ctl.root, snap)
            self.results.put(("seed_state", {"match": "current", "error": None}))
            return "Saved the DB to %s (kept: %s)." % (current.relative_to(self.ctl.root).as_posix(), ", ".join(versions))

        self._db_job("Save DB to seed", run)

    def _seed_reseed(self) -> None:
        label = self.seed_pick.get()
        if not label:
            return
        path = seeds.version_path(self.ctl.root, label)
        if not messagebox.askyesno("Reseed DB", "Replace the DB lookup tables with the %s seed (%s)?\n\n"
                                   "Player data (stats, deaths, language understanding, narration counters) is kept. "
                                   "Unsaved DB changes are lost." % (label, path.name), parent=self.win):
            return

        def run() -> str:
            if not self.owner_token:
                self.owner_token = core.cli_token(self.db.spacetime)
                if not self.owner_token:
                    raise RuntimeError("no owner token: run `spacetime login --server-issued-login local`")
            data = seeds.load_seed(path)
            log = lambda text: self.results.put(("db_log", (text, False)))
            rows = seeds.reseed(data, self.db.client.read_table,
                                lambda q: self.db.client.sql_as(self.owner_token, q),
                                lambda: self.db.client.call("bump_config_version"), log)
            self.results.put(("seed_state", self._seed_compare()))
            return "Reseeded the DB from the %s seed (%d rows); running games reload their tables." % (label, rows)

        self._db_job("Reseed DB from %s seed" % label, run)

    # ---------------------------------------------------------------- polling
    def poll(self) -> None:
        self._refresh_file()
        if not self.query_in_flight and not self.busy:
            self.query_in_flight = True
            threading.Thread(target=self._query, daemon=True).start()
        if not self.db_query_in_flight:
            self.db_query_in_flight = True
            threading.Thread(target=self._db_query, daemon=True).start()
        self.win.after(core.POLL_MS, self.poll)

    def _query(self) -> None:
        self.results.put(("running", self.ctl.is_running()))

    def _db_state(self) -> tuple:
        return self.db.is_running(), self.db.owns_server()

    def _db_query(self) -> None:
        state = self._db_state()
        self.results.put(("db_status", state))
        if state[0] and not self.db_busy:
            self.results.put(("seed_state", self._seed_compare()))

    def _drain(self) -> None:
        try:
            while True:
                kind, value = self.results.get_nowait()
                if kind == "running":
                    self.query_in_flight = False
                    self.running = value
                    self.ctl.sync(value)
                elif kind == "done":
                    self.busy = False
                    self.notice = value
                    self.last_sig = object()
                elif kind == "db_status":
                    self.db_query_in_flight = False
                    self.db_running, owned = value
                    self.db_status.config(text=core.db_status_text(self.db_running, owned, bool(self.db.spacetime)))
                    self.db_light.itemconfigure(self.db_dot, fill=core.indicator_color(self.db_running))
                elif kind == "seed_state":
                    self.seed_state = value
                elif kind == "db_log":
                    self._log(*value)
                elif kind == "db_table":
                    self._show_table(*value)
                elif kind == "move_fill":
                    for field, var in self.move_vars.items():
                        var.set("%g" % float(value.get(field, 0.0)))
                elif kind == "cell_set":
                    self._set_cell(*value)
                elif kind == "db_confirm":
                    self._confirm_kill(value)
                elif kind == "db_done":
                    self.db_busy = False
                    if value:
                        self._log(*value)
                    self._render_db_buttons()
                self._render()
        except queue.Empty:
            pass
        self.win.after(150, self._drain)

    def _refresh_file(self) -> None:
        sig = core.file_signature(self.ctl.save)
        if sig != self.last_sig:
            self.last_sig = sig
            self._render_progress()
        self._render()

    # ---------------------------------------------------------------- rendering
    def _render(self) -> None:
        st = core.ui_state(self.ctl.save_exists(), self.running, self.ctl.warned, bool(self.ctl.godot))
        self.status.config(text=st.status)
        self.btn_cont.config(text=st.continue_text, state="normal" if st.continue_enabled and not self.busy else "disabled")
        self.btn_reveal.config(state="normal" if st.reveal_enabled and not self.busy else "disabled")
        self.btn_new.config(state="disabled" if self.busy else "normal")
        self.btn_mods.config(state="disabled" if self.busy else "normal")
        self.btn_import.config(state="disabled" if self.busy or not self.ctl.godot else "normal")
        self.btn_fps.config(text="FPS: on" if core.read_perf_overlay(self.fps_flags) else "FPS: off")
        self.message.config(text=st.hint or self.notice)
        self._render_seed()

    def _render_progress(self) -> None:
        state, data = core.read_progress(self.ctl.save)
        t = self.progress
        t.config(state="normal")
        t.delete("1.0", "end")
        if state == "missing":
            t.insert("end", "No save yet. Start a new game to create one.", "empty")
        elif state == "error":
            t.insert("end", str(data), "err")
        elif not data:
            t.insert("end", "Save has no progress fields.", "empty")
        else:
            for k, v in data.items():
                t.insert("end", k + ": ", "key")
                t.insert("end", core.format_value(v) + "\n")
        t.config(state="disabled")

    # ---------------------------------------------------------------- actions
    def _act(self, fn, done_text: str) -> None:
        if self.busy:
            return
        self.busy = True
        self.notice = "Working..."
        self._render()

        def work() -> None:
            try:
                fn()
                self.results.put(("done", done_text))
            except Exception as e:  # surfaced to the user, not fatal
                self.results.put(("done", "Error: %s" % e))

        threading.Thread(target=work, daemon=True).start()

    def _continue(self) -> None:
        if self.busy:
            return
        self.busy = True
        self.notice = "Working..."
        self._render()

        def work() -> None:
            try:
                outcome = self.ctl.continue_game()
                text = {"started": "Game started.", "restarted": "Game restarted.",
                        "warned": "", "no_save": "No save to continue."}[outcome]
                self.results.put(("done", text))
            except Exception as e:
                self.results.put(("done", "Error: %s" % e))

        threading.Thread(target=work, daemon=True).start()

    def _reveal(self) -> None:
        """A running game reveals its current map live (DevBridge); otherwise the save is edited headless for the
        map chosen in the Map box."""
        map_name = self.ctl.map_name

        def run() -> None:
            if self.ctl.is_running():
                core.request_live_reveal(self.fps_flags)
                raise _Note(core.REVEAL_LIVE_NOTE)
            if not self.ctl.godot:
                raise RuntimeError("Godot not found: set GODOT_BIN")
            ok, line = core.run_reveal_tool(self.ctl.godot, self.ctl.root, map_name)
            if not ok:
                raise RuntimeError(line)

        self._act_note(run, "Map %s revealed in the save." % (map_name or "m1_awakening"))

    def _new_game_mods(self) -> None:
        """Start new game with mods (task-078): the popup, then a fresh save written with the mods, then the game."""
        if self.busy:
            return
        settings = core.load_settings(self.settings_file)

        def start(choices: dict) -> None:
            fresh = core.load_settings(self.settings_file)
            fresh[mods.SETTING_MODS] = choices
            try:
                core.save_settings(self.settings_file, fresh)
            except OSError as e:
                self._log("Could not save settings: %s" % e, error=True)
            args = mods.tool_args(choices)
            self._act(lambda: self.ctl.new_game_with_mods(args),
                      "Started a new game with mods: %s." % mods.summary(choices))

        ModsDialog(self.win, mods.merged(settings.get(mods.SETTING_MODS)), start)

    def _toggle_fps(self) -> None:
        """FPS / frametime / CPU / GPU graphs on or off; applies live to a running game (and to later starts)."""
        on = not core.read_perf_overlay(self.fps_flags)
        try:
            core.write_perf_overlay(self.fps_flags, on)
            self.notice = "FPS overlay %s." % ("on" if on else "off")
        except OSError as e:
            self.notice = "Error: %s" % e
        self._render()

    def _import_assets(self) -> None:
        """Runs Godot's headless import so every new asset gets its .import file (and changed ones re-import)."""
        def run() -> None:
            if not self.ctl.godot:
                raise RuntimeError("Godot not found: set GODOT_BIN")
            ok, msg = core.run_import(self.ctl.godot, self.ctl.root)
            if not ok:
                raise RuntimeError(msg)
            raise _Note(msg)

        if self.busy:
            return
        missing = len(core.missing_imports(self.ctl.root))
        self._act_note(run, "")
        self.notice = "Importing assets (%d .import file(s) missing)..." % missing
        self._render()

    def _spike(self, scene: str, label: str) -> None:
        def run() -> None:
            if not self.ctl.godot:
                raise RuntimeError("Godot not found: set GODOT_BIN")
            core.spawn_spike(self.ctl.godot, self.ctl.root, scene)

        self._act_note(run, "%s started." % label)

    def _act_note(self, fn, done_text: str) -> None:
        if self.busy:
            return
        self.busy = True
        self.notice = "Working..."
        self._render()

        def work() -> None:
            try:
                fn()
                self.results.put(("done", done_text))
            except _Note as n:
                self.results.put(("done", str(n)))
            except Exception as e:
                self.results.put(("done", "Error: %s" % e))

        threading.Thread(target=work, daemon=True).start()


    # ---------------------------------------------------------------- database
    def _log(self, text: str, error: bool = False) -> None:
        t = self.db_log
        t.config(state="normal")
        t.insert("end", text.rstrip() + "\n", "err" if error else ())
        t.see("end")
        t.config(state="disabled")

    def _render_db_buttons(self) -> None:
        for b in self.db_buttons:
            b.config(state="disabled" if self.db_busy else "normal")
        self._render_seed()

    def _db_job(self, label: str, fn) -> None:
        """Run fn() in a thread. fn returns a log line (or None); exceptions are logged as errors."""
        if self.db_busy:
            return
        self.db_busy = True
        self._render_db_buttons()
        self._log("> " + label)

        def work() -> None:
            try:
                msg = fn()
                self.results.put(("db_done", (msg, False) if msg else None))
            except Exception as e:  # surfaced in the log, not fatal
                self.results.put(("db_done", ("Error: %s" % e, True)))
            self.results.put(("db_status", self._db_state()))

        threading.Thread(target=work, daemon=True).start()

    def _db_start(self) -> None:
        def run() -> str:
            if self.db.start() == "already":
                return "DB is already running at %s." % core.DB_URL
            for _ in range(core.DB_START_WAIT_TRIES):
                if self.db.is_running():
                    return "DB started (PID %s). Log: %s" % (self.db.own_pid, core.db_log_path())
                time.sleep(core.DB_START_WAIT_STEP)
            return "DB process started (PID %s) but %s does not answer yet. Log: %s" % (
                self.db.own_pid, core.DB_URL, core.db_log_path())

        self._db_job("Start DB", run)

    def _db_stop(self) -> None:
        def run():
            if self.db.stop_own():
                return "DB stopped (process tree started by god)."
            procs = self.db.external_processes()
            if not procs:
                if self.db.is_running():
                    return "DB answers at %s but no spacetime process was found to stop." % core.DB_URL
                return "No SpacetimeDB process found."
            self.results.put(("db_confirm", procs))
            return None

        self._db_job("Stop DB", run)

    def _confirm_kill(self, procs: list) -> None:
        lines = "\n".join("%s (PID %d)" % (p.name, p.pid) for p in procs)
        if not messagebox.askyesno("Stop SpacetimeDB",
                                   "The DB was not started by god. Kill these processes?\n\n" + lines,
                                   parent=self.win):
            self._log("Stop cancelled.")
            return

        def run() -> str:
            self.db.kill_processes(procs)
            return "Killed %d SpacetimeDB process(es)." % len(procs)

        self._db_job("Kill external DB", run)

    def _db_publish(self) -> None:
        def run() -> str:
            ok, out = self.db.publish()
            self.results.put(("db_log", (out or "(no output)", not ok)))
            if not ok:
                raise core.DbError("publish failed")
            return "Module published to %s." % core.DB_NAME

        self._db_job("Publish module", run)

    def _db_call(self, reducer: str, done_text: str) -> None:
        def run() -> str:
            self.db.client.call(reducer)
            return done_text

        self._db_job("Call %s" % reducer, run)

    def _move_load(self) -> None:
        profile = self.move_pick.get()

        def run() -> str:
            table = self.db.client.read_table("movement_profile")
            self.results.put(("db_table", ("movement_profile", table)))
            row = core.movement_row(table, profile)
            if row is None:
                return "No movement profile %r yet; Apply creates it." % profile
            self.results.put(("move_fill", row))
            return "Loaded movement profile %r." % profile

        self._db_job("Load movement " + profile, run)

    def _move_apply(self) -> None:
        try:
            args = core.movement_args(self.move_pick.get(), {f: v.get() for f, v in self.move_vars.items()})
        except ValueError as e:
            self._log("Movement: %s" % e, True)
            return

        def run() -> str:
            self.db.client.call("upsert_movement_profile", args)
            return "Movement profile %r set to speed %.2f, accel %.2f, decel %.2f (game applies it within a few s)." % tuple(args)

        self._db_job("Apply movement " + args[0], run)

    def _db_read(self, tables: list) -> None:
        def run() -> str:
            for name in tables:
                self.results.put(("db_table", (name, self.db.client.read_table(name))))
            return "Read %s." % (tables[0] if len(tables) == 1 else "%d tables" % len(tables))

        self._db_job("Read " + ", ".join(tables), run)

    def _show_table(self, name: str, table: core.SqlTable) -> None:
        """One notebook tab per table, replaced on every read."""
        frame = self.table_tabs.get(name)
        if frame is None:
            frame = ttk.Frame(self.tabs)
            self.tabs.add(frame, text=name)
            self.table_tabs[name] = frame
        for child in frame.winfo_children():
            child.destroy()
        cols = list(table.columns)
        rows = core.format_table(table)
        tree = ttk.Treeview(frame, columns=cols, show="headings", selectmode="extended")
        ys = ttk.Scrollbar(frame, orient="vertical", command=tree.yview)
        xs = ttk.Scrollbar(frame, orient="horizontal", command=tree.xview)
        tree.configure(yscrollcommand=ys.set, xscrollcommand=xs.set)
        for i, c in enumerate(cols):
            tree.heading(c, text=c)
            tree.column(c, width=core.column_width(c, [r[i] for r in rows if i < len(r)]), stretch=False, anchor="w")
        key = core.DB_PRIMARY_KEYS.get(name)
        key_index = cols.index(key) if key in cols else -1
        items = {}
        raw = {}
        for r, values in zip(rows, table.rows):
            item = tree.insert("", "end", values=r)
            raw[item] = list(values)
            if key_index >= 0:
                items[str(r[key_index])] = item
        # raw: item -> the row's DB values (kept current by saved edits); order: the selection in click order.
        self.table_meta[name] = {"tree": tree, "table": table, "key_index": key_index, "items": items,
                                 "raw": raw, "order": []}
        tree.bind("<Double-1>", lambda e, n=name: self._begin_edit(n, e))
        tree.bind("<<TreeviewSelect>>", lambda _e, n=name: self._track_selection(n))
        for seq in ("<Control-c>", "<Control-C>"):
            tree.bind(seq, lambda _e, n=name: self._copy_rows(n))
        for seq in ("<Control-a>", "<Control-A>"):
            tree.bind(seq, lambda _e, t=tree: (t.selection_set(t.get_children()), "break")[1])
        tree.bind("<Shift-Up>", lambda _e, n=name: self._extend_selection(n, -1))
        tree.bind("<Shift-Down>", lambda _e, n=name: self._extend_selection(n, 1))
        note = "" if key_index >= 0 else "  (read only)"
        ttk.Label(frame, text="%d row(s)%s" % (len(rows), note)).pack(side="bottom", anchor="w")
        xs.pack(side="bottom", fill="x")
        ys.pack(side="right", fill="y")
        tree.pack(side="left", fill="both", expand=True)
        self.tabs.tab(frame, text="%s (%d)" % (name, len(rows)))
        self.tabs.select(frame)


    # ---------------------------------------------------------------- selection and copy (task-078)
    def _track_selection(self, name: str) -> None:
        """Keeps the selection in the order rows were picked (several at once, e.g. a Shift range, in grid order)."""
        meta = self.table_meta.get(name)
        if meta is None:
            return
        tree = meta["tree"]
        chosen = set(tree.selection())
        order = [i for i in meta["order"] if i in chosen]
        order += [i for i in tree.selection() if i not in order]
        meta["order"] = order

    def _extend_selection(self, name: str, step: int) -> str:
        """Shift+Up / Shift+Down: moves the focus row and adds it to the selection."""
        meta = self.table_meta.get(name)
        if meta is None:
            return "break"
        tree = meta["tree"]
        children = tree.get_children()
        if not children:
            return "break"
        focus = tree.focus() or (tree.selection()[-1] if tree.selection() else children[0])
        index = max(0, min(len(children) - 1, children.index(focus) + step))
        target = children[index]
        tree.selection_add(target)
        tree.focus(target)
        tree.see(target)
        return "break"

    def _copy_rows(self, name: str) -> str:
        """Ctrl+C: the selected rows (in pick order) as JSON with column names and current values."""
        meta = self.table_meta.get(name)
        if meta is None:
            return "break"
        self._track_selection(name)
        items = meta["order"]
        if not items:
            self._log("Nothing selected in %s to copy." % name)
            return "break"
        text = core.rows_json(name, list(meta["table"].columns), [meta["raw"][i] for i in items])
        self.win.clipboard_clear()
        self.win.clipboard_append(text)
        self._log("Copied %d %s row(s) as JSON." % (len(items), name))
        return "break"

    # ---------------------------------------------------------------- table editing (task-061)
    def _begin_edit(self, name: str, event) -> None:
        """Double-click on a cell: an entry over the cell; Enter or leaving it saves, Escape cancels."""
        meta = self.table_meta.get(name)
        if meta is None or meta["key_index"] < 0 or self.db_busy:
            return
        tree = meta["tree"]
        item, col_id = tree.identify_row(event.y), tree.identify_column(event.x)
        if not item or not col_id:
            return
        col = int(col_id[1:]) - 1
        table = meta["table"]
        column, type_name = table.columns[col], table.types[col]
        if not core.is_editable(name, column, type_name):
            why = "the row key" if column == core.DB_PRIMARY_KEYS.get(name) else type_name
            self._log("%s.%s is not editable (%s)." % (name, column, why))
            return
        self._close_editor()
        bbox = tree.bbox(item, col_id)
        if not bbox:
            return
        x, y, w, h = bbox
        values = tree.item(item, "values")
        old = str(values[col])
        if palette.is_palette_cell(column, type_name, old) and self._palette_edit(name, column, old, values, meta):
            return
        var = tk.StringVar(value=old)
        entry = ttk.Entry(tree, textvariable=var)
        entry.place(x=x, y=y, width=max(w, 80), height=h)
        entry.focus_set()
        entry.select_range(0, "end")
        key_text = str(values[meta["key_index"]])
        key_type = table.types[meta["key_index"]]
        done = {"closed": False}

        def commit(_e=None) -> None:
            if done["closed"]:
                return
            done["closed"] = True
            new = var.get()
            self._close_editor()
            if new == old:
                return
            edit = core.CellEdit(name, core.DB_PRIMARY_KEYS[name], key_type, key_text, column, type_name, old, new)
            try:
                edit.sql()
            except ValueError as e:
                self._log("%s.%s: %s" % (name, column, e), True)
                return
            self._apply_edit(edit, undo=False, record=True)

        def cancel(_e=None) -> None:
            done["closed"] = True
            self._close_editor()

        entry.bind("<Return>", commit)
        entry.bind("<KP_Enter>", commit)
        entry.bind("<FocusOut>", commit)
        entry.bind("<Escape>", cancel)
        self._editor = entry

    def _palette_edit(self, name: str, column: str, old: str, values, meta: dict) -> bool:
        """Palette cells (task-077) open the palette editor; OK saves like a typed edit. False when the cell text is
        not a valid palette (the plain text entry opens instead)."""
        try:
            palette.parse(old)
        except ValueError as e:
            self._log("%s.%s: %s; editing as text." % (name, column, e), True)
            return False
        table = meta["table"]
        key_text = str(values[meta["key_index"]])
        key_type = table.types[meta["key_index"]]

        def save(new: str) -> None:
            edit = core.CellEdit(name, core.DB_PRIMARY_KEYS[name], key_type, key_text, column, "String", old, new)
            self._apply_edit(edit, undo=False, record=True)

        PaletteDialog(self.win, "%s.%s  (%s)" % (name, column, key_text), old, palette.limit(name, column), save)
        return True

    def _close_editor(self) -> None:
        if self._editor is not None:
            editor, self._editor = self._editor, None
            editor.destroy()

    def _apply_edit(self, edit, undo: bool, record: bool = False) -> None:
        """Writes the edit (or takes it back) with the owner's token, then bumps config_version so a running game
        reloads its tables. The grid cell follows once the DB accepted it."""
        verb = "Undo" if undo else ("Save" if record else "Redo")
        value = edit.old_text if undo else edit.new_text

        def run() -> str:
            try:
                if not self.owner_token:
                    self.owner_token = core.cli_token(self.db.spacetime)
                    if not self.owner_token:
                        raise core.DbError("no owner token: log the spacetime CLI in (spacetime login) to edit tables")
                self.db.client.sql_as(self.owner_token, edit.sql(undo=undo))
            except core.DbError:
                if not record:
                    (self.history.restore_undo if undo else self.history.restore_redo)(edit)
                raise
            if record:
                self.history.push(edit)
            self.results.put(("cell_set", (edit.table, edit.key_text, edit.column, value)))
            if edit.table not in core.DB_NO_RELOAD_TABLES:
                self.db.client.call("bump_config_version")
            return "%s %s[%s].%s = %s" % (verb, edit.table, edit.key_text, edit.column, value)

        self._db_job("%s %s.%s" % (verb, edit.table, edit.column), run)

    def _undo(self, _event=None):
        if self._editor is not None or self.db_busy or self._typing_elsewhere():
            return None
        edit = self.history.undo()
        if edit is None:
            self._log("Nothing to undo.")
        else:
            self._apply_edit(edit, undo=True)
        return "break"

    def _redo(self, _event=None):
        if self._editor is not None or self.db_busy or self._typing_elsewhere():
            return None
        edit = self.history.redo()
        if edit is None:
            self._log("Nothing to redo.")
        else:
            self._apply_edit(edit, undo=False)
        return "break"

    def _typing_elsewhere(self) -> bool:
        """True while another text field has the focus (its own Ctrl+Z / Ctrl+Y stay with it)."""
        focus = self.win.focus_get()
        return isinstance(focus, (tk.Entry, ttk.Entry, tk.Text, ttk.Combobox))

    def _set_cell(self, table: str, key_text: str, column: str, value: str) -> None:
        meta = self.table_meta.get(table)
        if meta is None or key_text not in meta["items"] or column not in meta["table"].columns:
            return
        tree, item = meta["tree"], meta["items"][key_text]
        values = list(tree.item(item, "values"))
        index = meta["table"].columns.index(column)
        values[index] = value
        tree.item(item, values=values)
        if item in meta.get("raw", {}):
            meta["raw"][item][index] = core.cell_value(value, meta["table"].types[index])


class _Note(Exception):
    """A successful outcome with a message to show."""


def main(auto_close_ms: int = 0) -> None:
    root_path = core.repo_root()
    ctl = core.GameController(root_path, core.find_godot(), core.save_path(root_path))
    db = core.DbServer(root_path, core.find_spacetime(), core.DbClient())
    win = tk.Tk()
    GodApp(win, ctl, db)
    if auto_close_ms:
        win.after(auto_close_ms, win.destroy)
    win.mainloop()


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0)
