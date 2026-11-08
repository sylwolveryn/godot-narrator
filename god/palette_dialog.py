"""Palette editor dialog for god (task-077): shows the colours of a palette cell as swatches; add, change, remove and
reorder them, or type a hex code. OK hands the new cell text to a callback (saved like any other cell edit)."""
from __future__ import annotations

import tkinter as tk
from tkinter import colorchooser, ttk
from typing import Callable, Optional

import palette

SWATCH_W = 44
SWATCH_H = 26
STRIP_H = 22
NEW_COLOR = "#ffffff"


class PaletteDialog:
    def __init__(self, parent: tk.Misc, title: str, text: str, max_colors: Optional[int],
                 on_ok: Callable[[str], None]):
        self.colors = palette.parse(text)
        self.original = palette.format_palette(self.colors)
        self.max_colors = max_colors
        self.on_ok = on_ok
        self.selected = 0 if self.colors else -1
        self.win = tk.Toplevel(parent)
        self.win.title(title)
        self.win.transient(parent.winfo_toplevel())
        self.win.resizable(True, False)
        self._build()
        self._render()
        self.win.grab_set()
        self.win.bind("<Escape>", lambda _e: self.win.destroy())
        self.win.bind("<Return>", lambda _e: self._ok())

    # ---------------------------------------------------------------- layout
    def _build(self) -> None:
        pad = {"padx": 10, "pady": 4}
        self.strip = tk.Canvas(self.win, height=STRIP_H, highlightthickness=0)
        self.strip.pack(fill="x", **pad)
        self.strip.bind("<Configure>", lambda _e: self._draw_strip())
        self.swatches = tk.Canvas(self.win, height=SWATCH_H + 24, highlightthickness=0)
        self.swatches.pack(fill="x", **pad)
        self.swatches.bind("<Button-1>", self._click)
        self.swatches.bind("<Double-Button-1>", lambda e: (self._click(e), self._change()))
        row = ttk.Frame(self.win)
        row.pack(fill="x", **pad)
        ttk.Label(row, text="Hex:").pack(side="left")
        self.hex_var = tk.StringVar()
        self.hex_entry = ttk.Entry(row, textvariable=self.hex_var, width=10)
        self.hex_entry.pack(side="left", padx=(4, 4))
        self.hex_entry.bind("<Return>", lambda _e: (self._apply_hex(), "break")[1])
        ttk.Button(row, text="Set", command=self._apply_hex).pack(side="left")
        buttons = ttk.Frame(self.win)
        buttons.pack(fill="x", **pad)
        self.btn_add = ttk.Button(buttons, text="Add...", command=self._add)
        self.btn_change = ttk.Button(buttons, text="Change...", command=self._change)
        self.btn_remove = ttk.Button(buttons, text="Remove", command=self._remove)
        self.btn_left = ttk.Button(buttons, text="< Move", command=lambda: self._move(-1))
        self.btn_right = ttk.Button(buttons, text="Move >", command=lambda: self._move(1))
        for b in (self.btn_add, self.btn_change, self.btn_remove, self.btn_left, self.btn_right):
            b.pack(side="left", padx=(0, 6))
        self.note = ttk.Label(self.win, text="", foreground="#a15c00")
        self.note.pack(anchor="w", **pad)
        end = ttk.Frame(self.win)
        end.pack(fill="x", padx=10, pady=(4, 10))
        ttk.Button(end, text="Cancel", command=self.win.destroy).pack(side="right")
        ttk.Button(end, text="OK", command=self._ok).pack(side="right", padx=(0, 6))

    # ---------------------------------------------------------------- drawing
    def _render(self) -> None:
        c = self.swatches
        c.delete("all")
        width = max(len(self.colors), 1) * (SWATCH_W + 6) + 6
        c.config(width=width)
        for i, color in enumerate(self.colors):
            x = 6 + i * (SWATCH_W + 6)
            outline, w = ("#000000", 3) if i == self.selected else ("#777777", 1)
            c.create_rectangle(x, 4, x + SWATCH_W, 4 + SWATCH_H, fill=color, outline=outline, width=w)
            c.create_text(x + SWATCH_W / 2, 4 + SWATCH_H / 2, text=str(i + 1), fill=palette.text_color(color))
            c.create_text(x + SWATCH_W / 2, SWATCH_H + 16, text=color, font=("Consolas", 7))
        if not self.colors:
            c.create_text(8, 4 + SWATCH_H / 2, text="(empty) Add a colour", anchor="w", fill="#666666")
        has = 0 <= self.selected < len(self.colors)
        self.hex_var.set(self.colors[self.selected] if has else "")
        for b in (self.btn_change, self.btn_remove):
            b.config(state="normal" if has else "disabled")
        self.btn_left.config(state="normal" if has and self.selected > 0 else "disabled")
        self.btn_right.config(state="normal" if has and self.selected < len(self.colors) - 1 else "disabled")
        note = ""
        if self.max_colors is not None and len(self.colors) > self.max_colors:
            note = "The game uses only the first %d colours of this palette." % self.max_colors
        self.note.config(text=note)
        self._draw_strip()

    def _draw_strip(self) -> None:
        """The palette as the game cycles it: a smooth blend through the colours."""
        s = self.strip
        s.delete("all")
        w = max(s.winfo_width(), 1)
        n = len(self.colors)
        if n == 0:
            return
        rgb = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in self.colors]
        steps = max(w // 4, 1)
        for k in range(steps):
            u = k / steps * n
            a, b = rgb[int(u) % n], rgb[(int(u) + 1) % n]
            f = u - int(u)
            col = "#%02x%02x%02x" % tuple(round(a[j] + (b[j] - a[j]) * f) for j in range(3))
            x0 = k * w / steps
            s.create_rectangle(x0, 0, x0 + w / steps + 1, STRIP_H, fill=col, outline="")

    # ---------------------------------------------------------------- actions
    def _click(self, event) -> None:
        i = int((event.x - 6) // (SWATCH_W + 6))
        if 0 <= i < len(self.colors):
            self.selected = i
            self._render()

    def _ask(self, initial: str) -> Optional[str]:
        result = colorchooser.askcolor(color=initial, parent=self.win, title="Pick a colour")
        return palette.normalize(result[1]) if result and result[1] else None

    def _add(self) -> None:
        start = self.colors[self.selected] if 0 <= self.selected < len(self.colors) else NEW_COLOR
        color = self._ask(start)
        if color is None:
            return
        at = self.selected + 1 if self.selected >= 0 else len(self.colors)
        self.colors.insert(at, color)
        self.selected = at
        self._render()

    def _change(self) -> None:
        if not 0 <= self.selected < len(self.colors):
            return
        color = self._ask(self.colors[self.selected])
        if color is not None:
            self.colors[self.selected] = color
            self._render()

    def _remove(self) -> None:
        if not 0 <= self.selected < len(self.colors):
            return
        del self.colors[self.selected]
        self.selected = min(self.selected, len(self.colors) - 1)
        self._render()

    def _move(self, step: int) -> None:
        i, j = self.selected, self.selected + step
        if 0 <= i < len(self.colors) and 0 <= j < len(self.colors):
            self.colors[i], self.colors[j] = self.colors[j], self.colors[i]
            self.selected = j
            self._render()

    def _apply_hex(self) -> None:
        try:
            color = palette.normalize(self.hex_var.get())
        except ValueError:
            self.note.config(text="Type a colour as #rrggbb.")
            return
        if 0 <= self.selected < len(self.colors):
            self.colors[self.selected] = color
        else:
            self.colors.append(color)
            self.selected = len(self.colors) - 1
        self._render()

    def _ok(self) -> None:
        text = palette.format_palette(self.colors)
        self.win.destroy()
        if text != self.original:
            self.on_ok(text)
