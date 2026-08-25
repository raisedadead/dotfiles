#!/usr/bin/env python3
"""layout — build a herdr workspace from a declarative TOML file.

Layouts live in ~/.config/herdr/layouts/<name>.toml. A layout outside that
directory runs only when its path is passed explicitly: every `panes` entry
reaches `herdr pane run`, so auto-discovering a layout from the working
directory would execute whatever a cloned repository shipped.

    name = "dotfiles"
    cwd = "~/.dotfiles"

    [[tabs]]
    name = "code"
    panes = ["nvim", ""]

    [[tabs]]
    name = "agents"
    panes = ["claude"]

Each tab's first entry is its root pane. Every later entry splits the previous
one, right while the pane is at least 160 columns wide and down below that. An
empty string leaves a bare shell.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

import tomllib

HERDR = os.environ.get("HERDR_BIN_PATH", "herdr")
LAYOUT_DIR = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "herdr",
    "layouts",
)
WIDE_COLUMNS = 160


def herdr(*argv: str) -> dict:
    proc = subprocess.run(
        [HERDR, *argv], capture_output=True, text=True, check=False, timeout=30
    )
    if proc.returncode != 0:
        raise RuntimeError(f"herdr {' '.join(argv)}: {proc.stderr.strip()}")
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return {}


def pane_width(pane_id: str) -> int:
    layout = herdr("pane", "layout", "--pane", pane_id).get("result", {})
    for pane in layout.get("layout", {}).get("panes", []):
        if pane.get("pane_id") == pane_id:
            return int(pane.get("rect", {}).get("width", 0))
    return 0


def discover() -> dict[str, str]:
    found: dict[str, str] = {}
    if os.path.isdir(LAYOUT_DIR):
        for entry in sorted(os.listdir(LAYOUT_DIR)):
            if entry.endswith(".toml"):
                found[entry[: -len(".toml")]] = os.path.join(LAYOUT_DIR, entry)
    return found


def build(spec: dict, path: str) -> str:
    default_cwd = os.path.expanduser(str(spec.get("cwd", os.getcwd())))
    label = str(spec.get("name") or os.path.basename(path)[: -len(".toml")])
    tabs = spec.get("tabs") or []
    if not isinstance(tabs, list) or not tabs:
        raise RuntimeError(f"{path}: no [[tabs]]")

    workspace = herdr(
        "workspace", "create", "--cwd", default_cwd, "--label", label, "--no-focus"
    )["result"]
    workspace_id = workspace["workspace"]["workspace_id"]
    first_tab = workspace["tab"]["tab_id"]
    root_pane = workspace["root_pane"]["pane_id"]

    try:
        for index, tab in enumerate(tabs):
            if not isinstance(tab, dict):
                raise TypeError(f"{path}: [[tabs]] entry {index + 1} is not a table")
            tab_cwd = os.path.expanduser(str(tab.get("cwd", default_cwd)))
            tab_name = str(tab.get("name") or f"tab{index + 1}")
            if index == 0:
                tab_id, pane_id = first_tab, root_pane
            else:
                created = herdr(
                    "tab",
                    "create",
                    "--workspace",
                    workspace_id,
                    "--cwd",
                    tab_cwd,
                    "--label",
                    tab_name,
                    "--no-focus",
                )["result"]
                tab_id = created["tab"]["tab_id"]
                pane_id = created["root_pane"]["pane_id"]
            herdr("tab", "rename", tab_id, tab_name)

            commands = tab.get("panes") or [""]
            if not isinstance(commands, list):
                raise TypeError(f"{path}: {tab_name} panes is not an array")
            for position, command in enumerate(commands):
                if not isinstance(command, str):
                    raise TypeError(
                        f"{path}: {tab_name} pane {position + 1} is not a string"
                    )
                if position > 0:
                    direction = (
                        "right" if pane_width(pane_id) >= WIDE_COLUMNS else "down"
                    )
                    pane_id = herdr(
                        "pane",
                        "split",
                        "--pane",
                        pane_id,
                        "--direction",
                        direction,
                        "--cwd",
                        tab_cwd,
                        "--no-focus",
                    )["result"]["pane"]["pane_id"]
                if command.strip():
                    herdr("pane", "run", pane_id, command)
    except (RuntimeError, KeyError, TypeError, AttributeError):
        herdr("workspace", "close", workspace_id)
        raise

    return workspace_id


def main() -> int:
    argv = sys.argv[1:]
    layouts = discover()

    if not argv or argv[0] in ("-l", "--list"):
        for name, path in layouts.items():
            print(f"{name}\t{path}")
        return 0

    wanted = argv[0]
    if wanted == "--pick":
        if not layouts:
            print("layout: no layouts found", file=sys.stderr)
            return 1
        picker = subprocess.run(
            [
                "fzf",
                "--height=100%",
                "--no-keep-right",
                "--border=rounded",
                "--border-label= Layouts ",
                "--prompt=build > ",
                "--with-nth=1",
                "--delimiter=\t",
            ],
            input="\n".join(f"{n}\t{p}" for n, p in layouts.items()),
            capture_output=True,
            text=True,
            check=False,
        )
        wanted = picker.stdout.split("\t")[0].strip()
        if not wanted:
            return 0
        argv = [wanted, "--focus"]

    path = layouts.get(wanted)
    if path is None and os.path.isfile(wanted):
        path = wanted
    if path is None:
        print(f"layout: no layout named {wanted!r}", file=sys.stderr)
        return 1

    try:
        with open(path, "rb") as handle:
            spec = tomllib.load(handle)
        workspace_id = build(spec, path)
    except (
        OSError,
        tomllib.TOMLDecodeError,
        RuntimeError,
        KeyError,
        TypeError,
        AttributeError,
    ) as err:
        print(f"layout: {err}", file=sys.stderr)
        return 1

    if "--focus" in argv:
        herdr("workspace", "focus", workspace_id)
    print(workspace_id)
    return 0


if __name__ == "__main__":
    sys.exit(main())
