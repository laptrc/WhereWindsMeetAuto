#Requires AutoHotkey v2.0

SetTitleMatchMode 3   ; exact title match — GAME_TITLE must match precisely

; =============================================================================
; Global State
; =============================================================================

; Title of the game window — single source of truth used throughout the script.
global GAME_TITLE := "Where Winds Meet"

; Name of the currently active macro, or "" if none is running.
; Prevents two macros from running simultaneously.
global activeMacro := ""

; =============================================================================
; Helper Functions
; =============================================================================

; Attempts to start a macro. Returns true if the macro may proceed, false if
; this macro or any other macro is already running.
; Registers Esc to flip the running flag off.
StartMacro(&running, name) {
    global activeMacro
    if running
        return false
    if activeMacro != ""
        return false
    running := true
    activeMacro := name
    Hotkey "Esc", (*) => (running := false), "On"
    return true
}

; Cleans up after a macro loop ends: clears the running flag, resets the
; global active macro tracker, and disables the Esc hotkey.
StopMacro(&running) {
    global activeMacro
    running := false
    activeMacro := ""
    Hotkey "Esc", "Off"
}

; Focuses the game window. Returns true on success, false if the window was
; not found or could not be activated within 3 seconds.
FocusGame() {
    global GAME_TITLE
    if !WinExist(GAME_TITLE) {
        MsgBox(GAME_TITLE " is not running.", GAME_TITLE " Auto", "Icon!")
        return false
    }
    WinActivate GAME_TITLE
    WinWaitActive GAME_TITLE, , 3
    if WinActive(GAME_TITLE)
        return true
    MsgBox("Could not focus " GAME_TITLE ".", GAME_TITLE " Auto", "Icon!")
    return false
}

; Sends keystrokes directly to the game window without requiring focus.
GameSend(keys) {
    global GAME_TITLE
    ControlSend keys, , GAME_TITLE
}

; Factory that captures fn at call time so each button gets its own closure.
MakeStartHandler(fn) {
    return (*) => (FocusGame() && fn())
}

; =============================================================================
; Macro Functions
; =============================================================================

RunCatchFish(*) {
    static running := false
    if !StartMacro(&running, "Catch Fish")
        return
    loop {
        if !running
            break
        GameSend "{Alt down}"
        Sleep 1000
        GameSend "2"
        GameSend "{Alt up}"
        Sleep 1000
    }
    StopMacro(&running)
}

RunToxicPowder(*) {
    static running := false
    if !StartMacro(&running, "Farm Toxic Powder")
        return
    loop {
        if !running
            break
        GameSend "{Space down}"
        Sleep 1000
        GameSend "{Space up}"
        Sleep 750
        GameSend "{Space}"
        Sleep 4500
        GameSend "q"
        Sleep 1500
        GameSend "1"
        Sleep 10000
    }
    StopMacro(&running)
}

RunGatherHerbF(*) {
    static running := false
    if !StartMacro(&running, "Gather Herb (F)")
        return
    loop {
        if !running
            break
        GameSend "f"
        Sleep 200
        GameSend "z"
        Sleep 200
    }
    StopMacro(&running)
}

RunGatherHerbN(*) {
    static running := false
    if !StartMacro(&running, "Gather Herb (N)")
        return
    loop {
        if !running
            break
        GameSend "{n down}"
        Sleep 1000
        GameSend "{n up}"
        Sleep 100
        GameSend "{Esc}"
        Sleep 200
        GameSend "z"
        Sleep 200
    }
    StopMacro(&running)
}

RunMineStone(*) {
    static running := false
    if !StartMacro(&running, "Mine Stone")
        return
    loop {
        if !running
            break
        GameSend "q"
        Sleep 200
        GameSend "``"
        Sleep 200
    }
    StopMacro(&running)
}

RunPlaySwing(*) {
    static running := false
    if !StartMacro(&running, "Play Swing")
        return
    loop {
        if !running
            break
        GameSend "f"
        Sleep 200
    }
    StopMacro(&running)
}

; =============================================================================
; Hotkeys
; =============================================================================

^!c:: RunCatchFish()   ; Ctrl+Alt+C — Catch Fish
^!f:: RunToxicPowder() ; Ctrl+Alt+F — Farm Toxic Powder
^!g:: RunGatherHerbF() ; Ctrl+Alt+G — Gather Herb (F)
^!n:: RunGatherHerbN() ; Ctrl+Alt+N — Gather Herb (N)
^!m:: RunMineStone()   ; Ctrl+Alt+M — Mine Stone
^!p:: RunPlaySwing()   ; Ctrl+Alt+P — Play Swing

; =============================================================================
; GUI — Feature list with hotkeys, notes, and Start buttons
; =============================================================================

global features := [
    { name: "Catch Fish",
      hotkey: "Ctrl+Alt+C",
      notes: "Requires: Alt+2 set to Tai Chi" },
    { name: "Farm Toxic Powder",
      hotkey: "Ctrl+Alt+F",
      notes: "Requires: Toxic Power Farm Tower`nMust be farmable manually first`nKeys: Space (Jump), Q (Mighty Drop), 1 (Dragon's Breath)" },
    { name: "Gather Herb (F)",
      hotkey: "Ctrl+Alt+G",
      notes: "Requires: Horse - Spirited Courser (call it, press F to mount)`nKeys: F (Interaction), Z (Temp Skill)" },
    { name: "Gather Herb (N)",
      hotkey: "Ctrl+Alt+N",
      notes: "Requires: Horse - Spirited Courser + map marker placed`nKeys: N (Wayfinder), Z (Temp Skill)" },
    { name: "Mine Stone",
      hotkey: "Ctrl+Alt+M",
      notes: "Requires: Weapon - Thundercry Blade`nKeys: Q (Martial Art Skill), ``/~ (Special Skill)" },
    { name: "Play Swing",
      hotkey: "Ctrl+Alt+P",
      notes: "Go to Swing Play on a boat, press F to sit down first`nKeys: F (Interaction)" },
]

; Function references in the same order as features above.
global macroFuncs := [RunCatchFish, RunToxicPowder, RunGatherHerbF, RunGatherHerbN, RunMineStone, RunPlaySwing]

AppGui := Gui("-Resize", GAME_TITLE " Auto")

; --- Status row ---
AppGui.SetFont("s9 Norm", "Segoe UI")
AppGui.Add("Text", "x12 y15 w98", "Active Macro:")
AppGui.SetFont("s10 Bold", "Segoe UI")
global activeLabel := AppGui.Add("Text", "x113 y14 w247", "None")

; --- Divider ---
AppGui.Add("Text", "x8 y34 w354 h1 +0x10")

; --- Column headers ---
AppGui.SetFont("s8 Bold", "Segoe UI")
AppGui.Add("Text", "x12  y44 w153", "FEATURE")
AppGui.Add("Text", "x170 y44 w105", "HOTKEY")
AppGui.Add("Text", "x280 y44 w80",  "ACTION")

; --- Feature rows ---
rowY := 62
for i, feat in features {
    fn := macroFuncs[i]

    ; Feature name (bold heading), hotkey, and Start button
    AppGui.SetFont("s10 Bold", "Segoe UI")
    AppGui.Add("Text",   "x12  y" rowY      " w153 h22", feat.name)
    AppGui.SetFont("s10 Norm", "Segoe UI")
    AppGui.Add("Text",   "x170 y" rowY      " w105 h22", feat.hotkey)
    btn := AppGui.Add("Button", "x280 y" (rowY - 1) " w80 h24", "Start")
    btn.OnEvent("Click", MakeStartHandler(fn))
    rowY += 24

    ; Notes (secondary, indented)
    AppGui.SetFont("s8 Norm", "Segoe UI")
    noteLines := StrSplit(feat.notes, "`n").Length
    noteH     := noteLines * 16
    AppGui.Add("Text", "x24 y" rowY " w336 h" noteH, feat.notes)
    rowY += noteH + 12
}

; --- Divider ---
AppGui.Add("Text", "x8 y" rowY " w354 h1 +0x10")
rowY += 10

; --- Stop button + hint ---
AppGui.SetFont("s9 Norm", "Segoe UI")
stopBtn := AppGui.Add("Button", "x12 y" rowY " w90 h26", "Stop  (Esc)")
stopBtn.OnEvent("Click", (*) => Send("{Esc}"))
AppGui.SetFont("s8 Norm", "Segoe UI")
AppGui.Add("Text", "x112 y" (rowY + 6) " w248", "Press Esc anytime to stop the active macro")

AppGui.Show("w370")

; --- Close button hides the window instead of exiting ---
AppGui.OnEvent("Close", (*) => AppGui.Hide())

; --- Tray icon: double-click to restore the window ---
A_TrayMenu.Insert("1&", "Show", (*) => AppGui.Show())
A_TrayMenu.Default := "Show"

; =============================================================================
; UI update timer (200 ms) — syncs Active label
; =============================================================================

UpdateUI() {
    global activeMacro, activeLabel
    activeLabel.Text := (activeMacro != "") ? activeMacro : "None"
}

SetTimer UpdateUI, 200
