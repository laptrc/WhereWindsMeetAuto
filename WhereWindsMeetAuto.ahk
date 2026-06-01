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

; Set to true by the Esc hotkey to signal the active macro to stop.
; Reset to false at the start of each macro run.
global stopRequested := false

; =============================================================================
; Helper Functions
; =============================================================================

; Hotkey handler registered while a macro is running.
; Uses a named function (not a closure) to avoid by-ref capture issues.
RequestStop(*) {
    global stopRequested
    stopRequested := true
}

; Attempts to start a macro. Returns true if the macro may proceed, false if
; any other macro is already running.
; Resets stopRequested and enables the Esc hotkey.
StartMacro(name) {
    global activeMacro, stopRequested
    if activeMacro != ""
        return false
    activeMacro := name
    stopRequested := false
    Hotkey "Esc", RequestStop, "On"
    return true
}

; Cleans up after a macro loop ends: resets the global active macro tracker
; and disables the Esc hotkey.
StopMacro() {
    global activeMacro
    activeMacro := ""
    Hotkey "Esc", "Off"
}

; Sleeps for ms milliseconds in 50 ms increments, returning early if
; stopRequested is set. This keeps Esc responsive during long waits.
SleepChecked(ms) {
    global stopRequested
    loop (ms // 50) {
        if stopRequested
            return
        Sleep 50
    }
    remainder := Mod(ms, 50)
    if remainder > 0 && !stopRequested
        Sleep remainder
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

; Holds a key down for ms milliseconds, then releases it.
GameHold(key, ms) {
    GameSend "{" key " down}"
    SleepChecked ms
    GameSend "{" key " up}"
}

; Factory that captures fn at call time so each button gets its own closure.
MakeStartHandler(fn) {
    return (*) => (FocusGame() && fn())
}

OpenLink(ctrl, id, href) {
    Run href
}

MakeUrlText(url) {
    return '<a href="' url '">Youtube Guide</a>'
}

; =============================================================================
; Macro Functions
; =============================================================================

RunCatchFish(*) {
    global stopRequested
    if !StartMacro("Catch Fish")
        return
    loop {
        if stopRequested
            break
        GameSend "{Alt down}"
        SleepChecked 1000
        GameSend "2"
        GameSend "{Alt up}"
        SleepChecked 1000
    }
    StopMacro()
}

RunToxicPowderWBW(*) {
    global stopRequested
    if !StartMacro("Farm Toxic Powder (Wind Beneath Wings)")
        return
    loop {
        if stopRequested
            break
        GameHold("Space", 1000)
        SleepChecked 750
        GameSend "{Space}"
        SleepChecked 4500
        GameSend "q"
        SleepChecked 1500
        GameSend "1"
        SleepChecked 10000
    }
    StopMacro()
}

RunToxicPowderSilkbind(*) {
    global stopRequested
    if !StartMacro("Farm Toxic Powder (Silkbind - Deluge)")
        return
    loop {
        if stopRequested
            break
        GameHold("Space", 1000)
        SleepChecked 750
        GameSend "{Space}"
        SleepChecked 4500
        GameSend "q"
        SleepChecked 1500
        GameSend "1"
        SleepChecked 3000
        GameSend "q"
        SleepChecked 1000
        GameSend "q"
        SleepChecked 6000
    }
    StopMacro()
}

RunBeefTendon(*) {
    global stopRequested
    if !StartMacro("Farm Beef Tendon")
        return
    loop {
        if stopRequested
            break
        GameHold("Space", 1000)
        SleepChecked 750
        GameSend "{Space}"
        SleepChecked 4500
        GameSend "q"
        SleepChecked 1500
        GameSend "1"
        SleepChecked 3000
        GameSend "q"
        SleepChecked 1000
        GameSend "q"
        SleepChecked 3000
        ; --- walk to drops ---
        GameHold("s", 500)
        GameHold("a", 500)
        GameHold("w", 1250)
        GameHold("d", 750)
        ; --- loot drops ---
        SleepChecked 200
        GameSend "f"
        ; --- reposition for next loop ---
        GameHold("a", 750)
        GameHold("s", 1500)
        GameHold("d", 500)
        GameHold("w", 1250)
        ; --- wait for cooldown ---
        SleepChecked 10000
    }
    StopMacro()
}

RunGatherHerbF(*) {
    global stopRequested
    if !StartMacro("Gather Herb (F)")
        return
    loop {
        if stopRequested
            break
        GameSend "f"
        SleepChecked 200
        GameSend "z"
        SleepChecked 200
    }
    StopMacro()
}

RunGatherHerbN(*) {
    global stopRequested
    if !StartMacro("Gather Herb (N)")
        return
    loop {
        if stopRequested
            break
        GameSend "{n down}"
        SleepChecked 1000
        GameSend "{n up}"
        SleepChecked 100
        GameSend "{Esc}"
        SleepChecked 200
        GameSend "z"
        SleepChecked 200
    }
    StopMacro()
}

RunGatherHerbFleethoof(*) {
    global stopRequested
    if !StartMacro("Gather Herb (Fleethoof)")
        return
    loop {
        if stopRequested
            break
        GameSend "6"
        SleepChecked 200
        GameSend "1"
        SleepChecked 200
    }
    StopMacro()
}

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

RunPlaySwing(*) {
    global stopRequested
    if !StartMacro("Play Swing")
        return
    loop {
        if stopRequested
            break
        GameSend "f"
        SleepChecked 200
    }
    StopMacro()
}

; =============================================================================
; Hotkeys
; =============================================================================

^!c:: RunCatchFish()            ; Ctrl+Alt+C — Catch Fish
^!w:: RunToxicPowderWBW()      ; Ctrl+Alt+W — Farm Toxic Powder (Wind Beneath Wings)
^!s:: RunToxicPowderSilkbind() ; Ctrl+Alt+S — Farm Toxic Powder (Silkbind - Deluge)
^!b:: RunBeefTendon()          ; Ctrl+Alt+B — Farm Beef Tendon
^!f:: RunGatherHerbF() ; Ctrl+Alt+F — Gather Herb (F)
^!n:: RunGatherHerbN() ; Ctrl+Alt+N — Gather Herb (N)
^!6:: RunGatherHerbFleethoof() ; Ctrl+Alt+6 — Gather Herb (Fleethoof)
^!m:: RunMineStone()   ; Ctrl+Alt+M — Mine Stone
^!p:: RunPlaySwing()   ; Ctrl+Alt+P — Play Swing

; =============================================================================
; GUI — Feature list with hotkeys, notes, and Start buttons
; =============================================================================

global features := [{ name: "Catch Fish",
    hotkey: "Ctrl+Alt+C",
    url: "",
    notes: "Requires: Alt+2 set to Tai Chi" }, { name: "★ Farm Toxic Powder (Wind Beneath Wings)",
        hotkey: "Ctrl+Alt+W",
        url: "https://www.youtube.com/watch?v=hl45VFzlvcY",
        notes: "Requires: Toxic Powder Farm Tower, Wind Beneath Wings, Auto Recovery`nKeys: Space (Jump), Q (Mighty Drop), 1 (Dragon's Breath)" }, { name: "Farm Toxic Powder (Silkbind - Deluge)",
            url: "https://www.youtube.com/watch?v=hl45VFzlvcY",
            hotkey: "Ctrl+Alt+S",
            notes: "Requires: Toxic Powder Farm Tower, Silkbind - Deluge`nKeys: Space (Jump), Q (Mighty Drop), 1 (Dragon's Breath)" }, { name: "⚠️ Farm Beef Tendon",
                url: "https://www.youtube.com/watch?v=QqNRHs7eag0",
                hotkey: "Ctrl+Alt+B",
                notes: "Requires: Beef Tendon Farm Tower, Silkbind - Deluge (Wind Beneath Wings not working)`nKeys: Space (Jump), Q (Mighty Drop), 1 (Dragon's Breath)" }, { name: "Gather Herb (F)",
                    hotkey: "Ctrl+Alt+F",
                    url: "",
                    notes: "Requires: Horse - Spirited Courser (call it, press F to mount)`nKeys: F (Interaction), Z (Temp Skill)" }, { name: "Gather Herb (N)",
                        hotkey: "Ctrl+Alt+N",
                        url: "",
                        notes: "Requires: Horse - Spirited Courser, map marker placed`nKeys: N (Wayfinder), Z (Temp Skill)" }, { name: "★ Gather Herb (Fleethoof)",
                            hotkey: "Ctrl+Alt+6",
                            url: "",
                            notes: "Requires: Horse - Fleethoof, 1 set to Spirit Gift - Gather`nKeys: 6 (Call Horse), 1 (Spirit Gift Skill)" }, { name: "Mine Stone",
                                hotkey: "Ctrl+Alt+M",
                                url: "",
                                notes: "Requires: Weapon - Thundercry Blade`nKeys: Q (Martial Art Skill), ``/~ (Special Skill)" }, { name: "Play Swing",
                                    hotkey: "Ctrl+Alt+P",
                                    url: "",
                                    notes: "Go to Swing Play on a boat, press F to sit down first`nKeys: F (Interaction)" },
]

; Function references in the same order as features above.
global macroFuncs := [RunCatchFish, RunToxicPowderWBW, RunToxicPowderSilkbind, RunBeefTendon, RunGatherHerbF,
    RunGatherHerbN, RunGatherHerbFleethoof, RunMineStone, RunPlaySwing]

AppGui := Gui("-Resize", GAME_TITLE " Auto")

; --- Status row ---
AppGui.SetFont("s9 Norm", "Segoe UI")
AppGui.Add("Text", "x12 y15 w98", "Active Macro:")
AppGui.SetFont("s10 Bold", "Segoe UI")
global activeLabel := AppGui.Add("Text", "x113 y14 w379", "None")

; --- Divider ---
AppGui.Add("Text", "x8 y34 w484 h1 +0x10")

; --- Column headers ---
AppGui.SetFont("s8 Bold", "Segoe UI")
AppGui.Add("Text", "x12  y44 w294", "FEATURE")
AppGui.Add("Text", "x314 y44 w90", "HOTKEY")
AppGui.Add("Text", "x412 y44 w80", "ACTION")

; --- Feature rows ---
rowY := 62
for i, feat in features {
    fn := macroFuncs[i]

    ; Feature name (bold heading), hotkey, and Start button
    AppGui.SetFont("s10 Bold", "Segoe UI")
    AppGui.Add("Text", "x12  y" rowY " w294 h22", feat.name)
    AppGui.SetFont("s10 Norm", "Segoe UI")
    AppGui.Add("Text", "x314 y" rowY " w90 h22", feat.hotkey)
    btn := AppGui.Add("Button", "x412 y" (rowY - 1) " w80 h24", "Start")
    btn.OnEvent("Click", MakeStartHandler(fn))
    rowY += 24

    ; Notes (secondary, indented)
    AppGui.SetFont("s8 Norm", "Segoe UI")
    noteLines := StrSplit(feat.notes, "`n").Length
    noteH := noteLines * 16
    AppGui.Add("Text", "x24 y" rowY " w460 h" noteH, feat.notes)
    rowY += noteH
    if feat.url != "" {
        linkH := 16
        lnk := AppGui.Add("Link", "x24 y" rowY " w460 h" linkH, MakeUrlText(feat.url))
        lnk.OnEvent("Click", OpenLink)
        rowY += linkH
    }
    rowY += 12
}

; --- Divider ---
AppGui.Add("Text", "x8 y" rowY " w484 h1 +0x10")
rowY += 10

; --- Stop button + hint ---
AppGui.SetFont("s9 Norm", "Segoe UI")
stopBtn := AppGui.Add("Button", "x12 y" rowY " w90 h26", "Stop  (Esc)")
stopBtn.OnEvent("Click", (*) => Send("{Esc}"))
AppGui.SetFont("s8 Norm", "Segoe UI")
AppGui.Add("Text", "x112 y" (rowY + 6) " w380", "Press Esc anytime to stop the active macro")

AppGui.Show("w500")

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