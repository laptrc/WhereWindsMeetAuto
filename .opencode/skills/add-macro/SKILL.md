---
name: add-macro
description: How to add a new macro to the WhereWindsMeetAuto.ahk AutoHotkey v2 script. Use this skill whenever the user wants to create a new macro, add automation for a gameplay task, or extend the script with new functionality. Make sure to use this skill when the user mentions adding macros, creating new automation, or extending the script - even if they don't explicitly say "add a macro".
---

# Adding a New Macro to WhereWindsMeetAuto.ahk

This skill guides you through adding a new macro to the `WhereWindsMeetAuto.ahk` script. You must update **five places** in the codebase to properly add a macro.

## Before You Start

Confirm with the user:
1. **Macro name** - What should appear in the GUI (e.g., "Mine Stone", "Catch Fish")
2. **Key sequence and timing** - The exact keys to press and wait times (user provides this)
3. **Prerequisites** - What equipment, skills, or setup the macro requires (for README/notes)
4. **Hotkey** - Suggest an unused Ctrl+Alt+key combo and get confirmation

## Step 1: Find an Available Hotkey

Read `WhereWindsMeetAuto.ahk` and check the hotkey section (around line 289-297) to find unused Ctrl+Alt+key combinations. Common patterns:
- Letters: `^!c::`, `^!w::`, `^!s::`, `^!b::`, `^!f::`, `^!n::`, `^!m::`, `^!p::`
- Numbers: `^!6::`

**Suggest one to the user and confirm before proceeding.**

## Step 2: Add the Function

Find the "Macro Functions" section (around line 109-270) and add a new function following the existing pattern:

```autohotkey
RunYourMacroName(*) {
    global stopRequested
    if !StartMacro("Display Name")
        return
    loop {
        if stopRequested
            break
        ; --- user's key sequence here ---
        GameSend "q"
        SleepChecked 200
        ; Example: hold a key for X ms
        GameHold("w", 1000)
        ; --- end of key sequence ---
    }
    StopMacro()
}
```

**Key utilities available:**
- `GameSend "key"` - Send a keystroke
- `GameHold("key", ms)` - Hold key down for ms milliseconds
- `SleepChecked ms)` - Sleep while monitoring stopRequested
- Always check `stopRequested` in loops for Esc responsiveness

## Step 3: Add the Hotkey Binding

In the "Hotkeys" section (around line 289-297), add the binding:

```autohotkey
^!x:: RunYourMacroName()    ; Ctrl+Alt+X — Your Macro Name
```

Use the hotkey the user confirmed in Step 1.

## Step 4: Add GUI Metadata

Find the `features` array (around line 303-331) and append a new entry. Match the existing format:

```autohotkey
{ name: "Your Macro Name",
    hotkey: "Ctrl+Alt+X",
    url: "",  ; or YouTube guide URL if available
    notes: "Requires: <prerequisites>`nKeys: <key sequence explanation>" },
```

**Important:** End with a comma since more entries may be added later.

## Step 5: Add Function Reference

Find the `macroFuncs` array (around line 334-336) and append the function reference:

```autohotkey
global macroFuncs := [RunCatchFish, RunToxicPowderWBW, ..., RunYourMacroName]
```

**Critical:** The order must match the `features` array exactly.

## Step 6: Update README.md

Update the Features table in `README.md` (lines 14-23). Add a new row:

```markdown
| Your Macro Name | Ctrl+Alt+X | <prerequisites> |
```

Match the table's column alignment and formatting.

## Step 7: Validation

After making all changes, verify:

1. **Array length match** - `features` and `macroFuncs` must have the same number of entries
2. **Syntax check** - No missing commas, unmatched braces, or broken strings
3. **Hotkey uniqueness** - Confirm the new hotkey doesn't duplicate existing ones
4. **README table** - Verify the new row aligns with existing columns

## Common Patterns from Existing Macros

**Simple two-key循环:**
```autohotkey
RunMineStone(*) {
    global stopRequested
    if !StartMacro("Mine Stone")
        return
    loop {
        if stopRequested
            break
        GameSend "q"
        SleepChecked 200
        GameSend "``"
        SleepChecked 200
    }
    StopMacro()
}
```

**Movement with GameHold:**
```autohotkey
; Walk forward for 1 second
GameHold("w", 1000)
```

**Complex sequence with multiple actions:**
See `RunBeefTendon()` for a full example with combat, movement, and looting.

## What This Skill Does NOT Cover

- Editing existing macros (timings, keys, notes)
- Removing macros
- Figuring out key sequences from vague descriptions - the user must provide exact keys and timings
