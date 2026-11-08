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


class GodApp:
    def __init__(self, root: tk.Tk, controller: core.GameController, db: core.DbServer):
        self.win = root
        self.ctl = controller
        self.db = db
        self.db_running = False
        self.db_busy = False
        self.db_query_in_flight = False
        self.table_tabs: dict = {}
        self.results: "queue.Queue" = queue.Queue()
        self.running = False
        self.busy = False
        self.query_in_flight = False
        self.last_sig = object()  # forces the first render
        self.notice = ""
        root.title("god - Narrator launcher")
        root.minsize(640, 760)
        self._build()
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
        self.btn_cont = ttk.Button(row, text="Continue game", command=self._continue)
        self.btn_reveal = ttk.Button(row, text="Reveal map", command=self._reveal)
        for b in (self.btn_new, self.btn_cont, self.btn_reveal):
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
        self.db_status = ttk.Label(head, text="DB: ...", font=("Segoe UI", 10, "bold"))
        self.db_status.pack(side="left")
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
        self.results.put(("db_status", self._db_state()))

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
                elif kind == "db_log":
                    self._log(*value)
                elif kind == "db_table":
                    self._show_table(*value)
                elif kind == "move_fill":
                    for field, var in self.move_vars.items():
                        var.set("%g" % float(value.get(field, 0.0)))
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
        self.message.config(text=st.hint or self.notice)

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
        def run() -> None:
            if not self.ctl.godot:
                raise RuntimeError("Godot not found: set GODOT_BIN")
            ok, line = core.run_reveal_tool(self.ctl.godot, self.ctl.root)
            if not ok:
                raise RuntimeError(line)
            if self.ctl.is_running():
                raise _Note(core.REVEAL_RUNNING_NOTE)

        self._act_note(run, "Map revealed.")

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
        tree = ttk.Treeview(frame, columns=cols, show="headings")
        ys = ttk.Scrollbar(frame, orient="vertical", command=tree.yview)
        xs = ttk.Scrollbar(frame, orient="horizontal", command=tree.xview)
        tree.configure(yscrollcommand=ys.set, xscrollcommand=xs.set)
        for i, c in enumerate(cols):
            tree.heading(c, text=c)
            tree.column(c, width=core.column_width(c, [r[i] for r in rows if i < len(r)]), stretch=False, anchor="w")
        for r in rows:
            tree.insert("", "end", values=r)
        ttk.Label(frame, text="%d row(s)" % len(rows)).pack(side="bottom", anchor="w")
        xs.pack(side="bottom", fill="x")
        ys.pack(side="right", fill="y")
        tree.pack(side="left", fill="both", expand=True)
        self.tabs.tab(frame, text="%s (%d)" % (name, len(rows)))
        self.tabs.select(frame)


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
