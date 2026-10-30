"""god: developer launcher for the Narrator Godot game. Run with `python god/god.py`."""
from __future__ import annotations

import queue
import sys
import threading
import tkinter as tk
from tkinter import ttk

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent))

import core  # noqa: E402


class GodApp:
    def __init__(self, root: tk.Tk, controller: core.GameController):
        self.win = root
        self.ctl = controller
        self.results: "queue.Queue" = queue.Queue()
        self.running = False
        self.busy = False
        self.query_in_flight = False
        self.last_sig = object()  # forces the first render
        self.notice = ""
        root.title("god - Narrator launcher")
        root.minsize(480, 420)
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
        spikes = ttk.Frame(self.win)
        spikes.pack(fill="x", **pad)
        ttk.Label(spikes, text="Prototypes:").pack(side="left", padx=(0, 6))
        for label, scene in core.SPIKES.items():
            ttk.Button(spikes, text=label, command=lambda s=scene, l=label: self._spike(s, l)).pack(side="left", padx=(0, 6))
        self.message = ttk.Label(self.win, text="", wraplength=450, foreground="#a15c00")
        self.message.pack(anchor="w", **pad)
        ttk.Separator(self.win).pack(fill="x", padx=10, pady=4)
        ttk.Label(self.win, text="Progress", font=("Segoe UI", 10, "bold")).pack(anchor="w", **pad)
        self.progress = tk.Text(self.win, height=14, wrap="word", state="disabled", relief="flat", background=self.win.cget("background"))
        self.progress.pack(fill="both", expand=True, padx=10, pady=(0, 10))
        self.progress.tag_configure("key", font=("Segoe UI", 9, "bold"))
        self.progress.tag_configure("err", foreground="#b00020")
        self.progress.tag_configure("empty", foreground="#666666")

    # ---------------------------------------------------------------- polling
    def poll(self) -> None:
        self._refresh_file()
        if not self.query_in_flight and not self.busy:
            self.query_in_flight = True
            threading.Thread(target=self._query, daemon=True).start()
        self.win.after(core.POLL_MS, self.poll)

    def _query(self) -> None:
        self.results.put(("running", self.ctl.is_running()))

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


class _Note(Exception):
    """A successful outcome with a message to show."""


def main(auto_close_ms: int = 0) -> None:
    root_path = core.repo_root()
    ctl = core.GameController(root_path, core.find_godot(), core.save_path(root_path))
    win = tk.Tk()
    GodApp(win, ctl)
    if auto_close_ms:
        win.after(auto_close_ms, win.destroy)
    win.mainloop()


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0)
