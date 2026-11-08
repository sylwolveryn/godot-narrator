"""The "Start new game with mods" popup (task-078): one checkbox per mod with its number fields. Start hands the
choices to a callback; Cancel does nothing."""
from __future__ import annotations

import tkinter as tk
from tkinter import ttk
from typing import Callable

import mods


class ModsDialog:
    def __init__(self, parent: tk.Misc, choices: dict, on_start: Callable[[dict], None]):
        self.on_start = on_start
        self.vars: dict = {}
        self.win = tk.Toplevel(parent)
        self.win.title("Start new game with mods")
        self.win.transient(parent.winfo_toplevel())
        self.win.resizable(False, False)
        pad = {"padx": 12, "pady": 4}
        ttk.Label(self.win, text="The current save is deleted; the new game starts with these tweaks.",
                  foreground="#a15c00").pack(anchor="w", padx=12, pady=(10, 6))
        for m in mods.MODS:
            box = ttk.LabelFrame(self.win, text=m.title)
            box.pack(fill="x", **pad)
            on = tk.BooleanVar(value=bool(choices[m.key]["on"]))
            row = ttk.Frame(box)
            row.pack(fill="x", padx=8, pady=6)
            ttk.Checkbutton(row, text="on", variable=on).pack(side="left", padx=(0, 10))
            fields = {}
            for f in m.fields:
                ttk.Label(row, text=f.label).pack(side="left", padx=(6, 4))
                var = tk.StringVar(value=str(choices[m.key][f.arg]))
                ttk.Spinbox(row, from_=f.minimum, to=f.maximum, textvariable=var, width=9).pack(side="left")
                fields[f.arg] = var
            ttk.Label(box, text=m.help, foreground="#666666").pack(anchor="w", padx=8, pady=(0, 6))
            self.vars[m.key] = (on, fields)
        self.error = ttk.Label(self.win, text="", foreground="#b00020")
        self.error.pack(anchor="w", padx=12)
        end = ttk.Frame(self.win)
        end.pack(fill="x", padx=12, pady=(6, 12))
        ttk.Button(end, text="Cancel", command=self.win.destroy).pack(side="right")
        ttk.Button(end, text="Start", command=self._start).pack(side="right", padx=(0, 6))
        self.win.bind("<Escape>", lambda _e: self.win.destroy())
        self.win.bind("<Return>", lambda _e: self._start())
        self.win.grab_set()

    def choices(self) -> dict:
        """The dialog's values; raises ValueError for a number field that is not a whole number."""
        out = {}
        for m in mods.MODS:
            on, fields = self.vars[m.key]
            entry = {"on": bool(on.get())}
            for f in m.fields:
                text = fields[f.arg].get().strip()
                try:
                    entry[f.arg] = mods.clamp(f, int(text))
                except ValueError:
                    raise ValueError("%s: %s is not a whole number" % (m.title, f.label))
            out[m.key] = entry
        return out

    def _start(self) -> None:
        try:
            choices = self.choices()
        except ValueError as e:
            self.error.config(text=str(e))
            return
        self.win.destroy()
        self.on_start(choices)
