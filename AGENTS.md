# Agent Notes — WhereWindsMeetAuto

## Project Type
Single-file AutoHotkey v2 script (`WhereWindsMeetAuto.ahk`). No package manager, no tests, no linter, no formatter.

## How to verify changes
- Install [AutoHotkey v2](https://www.autohotkey.com/).
- Right-click `WhereWindsMeetAuto.ahk` → **Run as administrator** (required for `ControlSend` to reach the game).
- The GUI will appear; use **Start** buttons or hotkeys to test macros.
- Press **Esc** to stop any running macro.

## Build & Release
- **No local build step.** The CI workflow (`.github/workflows/release.yml`) compiles `WhereWindsMeetAuto.ahk` → `WhereWindsMeetAuto.exe` on every push to `main` using Ahk2Exe.
- `WhereWindsMeetAuto.exe` is `.gitignore`d — **never commit it**.
- CI uses **Conventional Commits** to auto-bump semver (`feat` → minor, `fix/refactor/perf` → patch, `BREAKING CHANGE`/`!` → major) and creates a GitHub Release with the compiled `.exe`.

## Adding or editing a macro
The script is monolithic. To add a macro you must touch four places in `WhereWindsMeetAuto.ahk`:
1. **Function** — e.g. `RunMineStone(*)`.
2. **Hotkey** — e.g. `^!m:: RunMineStone()`.
3. **GUI metadata** — append to the `features` array (name, hotkey, notes, optional url).
4. **Function reference** — append the function reference to `macroFuncs` in the same order as `features`.

## Architecture notes
- `GAME_TITLE` is the single source of truth for the target window (`"Where Winds Meet"`).
- `SetTitleMatchMode 3` enforces **exact** title matching.
- `ControlSend` sends inputs without requiring the window to be foregrounded; `FocusGame()` is used by GUI **Start** buttons to bring the game forward before starting.
- Macros are mutually exclusive (`activeMacro` global). `Esc` sets `stopRequested` and breaks out of loops via `SleepChecked`.

## Tunable parameters
- `RunBeefTendon()` contains `GameHold(key, ms)` movement timings under `; --- walk to drops ---` and `; --- reposition for next loop ---`. These are **session-dependent** because enemy respawn positions shift; they are the primary values users tweak per login. Changing them in the source is expected.

## MacroRecorder folder
Contains `.mrf` files for the [Macro Recorder](https://www.macrorecorder.com/) tool. These are visual alternatives for non-programmers and are **not** the primary automation path. The Beef Tendon Macro Recorder workflow is known to be unreliable since game v1.7 (rapid key taps no longer move the character predictably). Prefer AutoHotkey for any timing-critical macro.
