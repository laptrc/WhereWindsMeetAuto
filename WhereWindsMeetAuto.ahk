#Requires AutoHotkey v2.0

SetTitleMatchMode 3   ; exact title match — GAME_TITLE must match precisely

if A_IsCompiled {
    TraySetIcon A_ScriptFullPath, , true
} else {
    iconPath := A_ScriptDir "\assets\logo.ico"
    if FileExist(iconPath)
        TraySetIcon iconPath, , true
}

; =============================================================================
; Global State
; =============================================================================

; Title of the game window — single source of truth used throughout the script.
; User-editable via the GUI input box; persisted in WWM_Settings.ini.
global DEFAULT_GAME_TITLE := "Where Winds Meet"
global GAME_TITLE := DEFAULT_GAME_TITLE
global SETTINGS_INI := A_ScriptDir "\WWM_Settings.ini"

; Fixed display title of this app (GUI window, MsgBox titles) — never changes
; with the game window title.
global APP_TITLE := "Where Winds Meet Auto"

; Name of the currently active macro, or "" if none is running.
; Prevents two macros from running simultaneously.
global activeMacro := ""

; Set to true by the Esc hotkey to signal the active macro to stop.
; Reset to false at the start of each macro run.
global stopRequested := false

; AutoCode configuration and state (redeem gift codes)
; All settings (window title + AutoCode) live in WWM_Settings.ini.
global AUTO_CODE_CONFIG := SETTINGS_INI
global AUTO_CODE_CONFIG_LEGACY := A_ScriptDir "\WWM_AutoCode.ini"
global AUTO_CODE_ACTION_DELAY := 500
global AUTO_CODE_LINE_DELAY := 500
global AUTO_CODE_COLOR_TOLERANCE := 30
global AUTO_CODE_COLOR_INITIAL_WAIT := 350
global AUTO_CODE_COLOR_CHECK_TIMEOUT := 1200
global AUTO_CODE_COLOR_CHECK_INTERVAL := 100

global autoCodeP1X := 0
global autoCodeP1Y := 0
global autoCodeP1Color := 0
global autoCodeP1Set := false
global autoCodeP2X := 0
global autoCodeP2Y := 0
global autoCodeP2Set := false
global autoCodeP3X := 0
global autoCodeP3Y := 0
global autoCodeP3Set := false

global autoCodeGui := 0
global autoCodeGuiVisible := false
global autoCodeCodeBox := 0
global autoCodeProfileSelect := 0
global autoCodeDelayEdit := 0
global autoCodeLineDelayEdit := 0
global autoCodeP1Text := 0
global autoCodeP2Text := 0
global autoCodeP3Text := 0
global autoCodeProfiles := []
global autoCodeCurrentProfile := ""
global autoCodeProfileSyncing := false

; Loads the saved game window title (falls back to the default if missing/empty).
LoadGameTitleSetting() {
    global GAME_TITLE, SETTINGS_INI
    saved := IniRead(SETTINGS_INI, "Window", "Title", "")
    GAME_TITLE := saved != "" ? saved : DEFAULT_GAME_TITLE
}

; One-time migration: moves all sections/keys from the old WWM_AutoCode.ini into
; WWM_Settings.ini, then deletes the legacy file. Only deletes on full success.
MigrateLegacyAutoCodeIni() {
    global AUTO_CODE_CONFIG, AUTO_CODE_CONFIG_LEGACY
    if !FileExist(AUTO_CODE_CONFIG_LEGACY)
        return
    try {
        for _, section in StrSplit(IniRead(AUTO_CODE_CONFIG_LEGACY), "`n", "`r") {
            if section = ""
                continue
            for _, kv in StrSplit(IniRead(AUTO_CODE_CONFIG_LEGACY, section), "`n", "`r") {
                pos := InStr(kv, "=")
                if pos > 1
                    IniWrite(SubStr(kv, pos + 1), AUTO_CODE_CONFIG, section, SubStr(kv, 1, pos - 1))
            }
        }
        FileDelete(AUTO_CODE_CONFIG_LEGACY)
    }
    catch as err {
        MsgBox("Could not migrate WWM_AutoCode.ini to WWM_Settings.ini: " err.Message, APP_TITLE, "Icon!")
        return
    }
}

MigrateLegacyAutoCodeIni()

AutoCodeLoadSettings()

LoadGameTitleSetting()

; =============================================================================
; Helper Functions
; =============================================================================

; Hotkey handler registered while a macro is running.
; Uses a named function (not a closure) to avoid by-ref capture issues.
StopMacroRequest(ignoreFocus := false) {
    global stopRequested, GAME_TITLE, activeMacro
    if ignoreFocus !== true && activeMacro != "Redeem Gift Codes" && !WinActive(GAME_TITLE)
        return
    stopRequested := true
}

; Silent sync: saves the title typed in the GUI input to GAME_TITLE + INI.
; Skips when the input is empty or unchanged. No dialogs — callers report errors.
SyncGameTitleFromInput() {
    global GAME_TITLE, SETTINGS_INI, gameTitleEdit
    if !IsObject(gameTitleEdit)
        return
    newTitle := Trim(gameTitleEdit.Value)
    if newTitle = "" || newTitle = GAME_TITLE
        return
    GAME_TITLE := newTitle
    IniWrite(newTitle, SETTINGS_INI, "Window", "Title")
}

; Apply button: validates the GUI input, saves it, and warns if no window
; matches the title yet.
ApplyGameTitle(*) {
    global GAME_TITLE, gameTitleEdit
    if Trim(gameTitleEdit.Value) = "" {
        MsgBox("Please enter a window title.", APP_TITLE, "Icon!")
        return
    }
    SyncGameTitleFromInput()
    if !WinExist(GAME_TITLE)
        MsgBox("No window named '" GAME_TITLE "' found. Macros will start once the game is running.", APP_TITLE, "Icon!")
}

; Attempts to start a macro. Returns true if the macro may proceed, false if
; any other macro is already running.
; Resets stopRequested and enables the Esc hotkey.
StartMacro(name) {
    global activeMacro, stopRequested
    SyncGameTitleFromInput()
    if activeMacro != ""
        return false
    activeMacro := name
    stopRequested := false
    Hotkey "Esc", StopMacroRequest, "On"
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
; Syncs GAME_TITLE from the GUI input first, so typing a new title takes effect
; even without pressing Apply.
FocusGame() {
    global GAME_TITLE
    SyncGameTitleFromInput()
    if !WinExist(GAME_TITLE) {
        MsgBox(GAME_TITLE " is not running.", APP_TITLE, "Icon!")
        return false
    }
    WinActivate GAME_TITLE
    WinWaitActive GAME_TITLE, , 3
    if WinActive(GAME_TITLE)
        return true
    MsgBox("Could not focus " GAME_TITLE ".", APP_TITLE, "Icon!")
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
MakeStartHandler(fn, shouldFocusGame := true) {
    return shouldFocusGame ? ((*) => (FocusGame() && fn())) : ((*) => fn())
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

RunSandstormTavern(*) {
    global stopRequested
    if !StartMacro("Sandstorm Tavern")
        return
    ; Dialogue choices per tavern run, one per 15 s step.
    dialogueKeys := ["n", "y", "n", "n", "y"]
    dialogueWait := 15000
    loop {
        if stopRequested
            break
        GameHold("w", 900)
        SleepChecked 1000
        GameSend "f"
        SleepChecked dialogueWait
        for key in dialogueKeys {
            if stopRequested
                break
            GameSend key
            SleepChecked dialogueWait
        }
        if stopRequested
            break
        SleepChecked dialogueWait
        GameSend "f"
        SleepChecked dialogueWait
    }
    StopMacro()
}

RunAutoCode(*) {
    AutoCodeShowGui()
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
^!t:: RunSandstormTavern() ; Ctrl+Alt+T — Sandstorm Tavern

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
                                    notes: "Go to Swing Play on a boat, press F to sit down first`nKeys: F (Interaction)" }, { name: "Sandstorm Tavern",
                                        hotkey: "Ctrl+Alt+T",
                                        url: "",
                                        notes: "Requires: Speed ×3, tick `"Don't remind today`"`nKeys: N, Y (cycle: N -> Y -> N -> N -> Y)" },
{ name: "Redeem Gift Codes",
    hotkey: "F1/F2/F3/F5",
    url: "https://www.youtube.com/watch?v=EMZKfgAHP5k",
    focusGame: false,
    notes: "Set P1/P2/P3 in sub window, then press F5 or Start`nKeys: F1/F2/F3 (Set Points), F5 (Start), Esc (Stop while running)" },
]

; Function references in the same order as features above.
global macroFuncs := [RunCatchFish, RunToxicPowderWBW, RunToxicPowderSilkbind, RunBeefTendon, RunGatherHerbF,
    RunGatherHerbN, RunGatherHerbFleethoof, RunMineStone, RunPlaySwing, RunSandstormTavern, RunAutoCode]

AppGui := Gui("-Resize", APP_TITLE)

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
    btn.OnEvent("Click", MakeStartHandler(fn, feat.HasProp("focusGame") ? feat.focusGame : true))
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
stopBtn := AppGui.Add("Button", "x12 y" rowY " w90 h26", "Stop")
stopBtn.OnEvent("Click", (*) => StopMacroRequest(true))
AppGui.SetFont("s8 Norm", "Segoe UI")
AppGui.Add("Text", "x112 y" (rowY + 6) " w380", "Esc stops macro when game is focused (or during Redeem Gift Codes).")
rowY += 34

; --- Game window title input ---
AppGui.SetFont("s9 Norm", "Segoe UI")
AppGui.Add("Text", "x12 y" rowY " w130 h21", "Game Window Title:")
global gameTitleEdit := AppGui.AddEdit("x145 y" rowY " w247 h21", GAME_TITLE)
applyTitleBtn := AppGui.Add("Button", "x397 y" (rowY - 1) " w80 h24", "Apply")
applyTitleBtn.OnEvent("Click", ApplyGameTitle)
rowY += 30
AppGui.SetFont("s8 Norm", "Segoe UI")
AppGui.Add("Text", "x12 y" rowY " w480", "Note: while any macro is active, the script sends Space once during 04:01 Asia/Ho_Chi_Minh (UTC+7) to close the Monthly Pass popup.")

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

AutoDismissMonthlyPassPopup() {
    global activeMacro
    if activeMacro = ""
        return
    ; Asia/Ho_Chi_Minh is fixed at UTC+7, so derive the target time from UTC.
    if FormatTime(DateAdd(A_NowUTC, 7, "Hours"), "HHmm") != "0401"
        return
    GameSend "{Space}"
}

SetTimer UpdateUI, 200
SetTimer AutoDismissMonthlyPassPopup, 60000

AutoCodeShowGui() {
    global autoCodeGui, autoCodeGuiVisible
    if !IsObject(autoCodeGui)
        AutoCodeCreateGui()
    AutoCodeRefreshProfileOptions()
    AutoCodeRefreshPointLabels()
    autoCodeGui.Show("w320 h420")
    autoCodeGuiVisible := true
}

AutoCodeCreateGui() {
    global autoCodeGui, autoCodeCodeBox, autoCodeProfileSelect, autoCodeDelayEdit, autoCodeLineDelayEdit
    global autoCodeP1Text, autoCodeP2Text, autoCodeP3Text

    autoCodeGui := Gui("", "WWM Auto Code")
    autoCodeGui.SetFont("s8 Bold", "Segoe UI")
    autoCodeGui.AddText("x10 y8 w300 Center", "WHERE WINDS MEET - AUTO CODE")
    autoCodeGui.SetFont("s8 Norm", "Segoe UI")

    autoCodeGui.AddText("x10 y30 w300", "Profile (by resolution):")
    autoCodeProfileSelect := autoCodeGui.AddDropDownList("x10 y46 w200", [])
    autoCodeProfileSelect.OnEvent("Change", AutoCodeOnProfileChanged)
    btnUseCurrent := autoCodeGui.AddButton("x215 y45 w95 h24", "Use Current")
    btnUseCurrent.OnEvent("Click", (*) => AutoCodeUseCurrentResolutionProfile())

    autoCodeGui.AddText("x10 y78 w300", "Code List - One code per line:")
    autoCodeCodeBox := autoCodeGui.AddEdit("x10 y96 w300 h105 Multi VScroll")

    autoCodeGui.AddText("x10 y218 w25", "P1:")
    autoCodeP1Text := autoCodeGui.AddText("x38 y218 w145", AutoCodePointText(1))
    btnP1 := autoCodeGui.AddButton("x205 y212 w105 h26", "SET (F1)")
    btnP1.OnEvent("Click", (*) => AutoCodeSetPointFromButton(1))

    autoCodeGui.AddText("x10 y250 w25", "P2:")
    autoCodeP2Text := autoCodeGui.AddText("x38 y250 w145", AutoCodePointText(2))
    btnP2 := autoCodeGui.AddButton("x205 y244 w105 h26", "SET (F2)")
    btnP2.OnEvent("Click", (*) => AutoCodeSetPointFromButton(2))

    autoCodeGui.AddText("x10 y282 w25", "P3:")
    autoCodeP3Text := autoCodeGui.AddText("x38 y282 w145", AutoCodePointText(3))
    btnP3 := autoCodeGui.AddButton("x205 y276 w105 h26", "SET (F3)")
    btnP3.OnEvent("Click", (*) => AutoCodeSetPointFromButton(3))

    autoCodeGui.AddText("x10 y314 w45", "Action:")
    autoCodeDelayEdit := autoCodeGui.AddEdit("x55 y310 w45", AUTO_CODE_ACTION_DELAY)
    autoCodeGui.AddText("x103 y314 w18", "ms")

    autoCodeGui.AddText("x160 y314 w35", "Line:")
    autoCodeLineDelayEdit := autoCodeGui.AddEdit("x195 y310 w45", AUTO_CODE_LINE_DELAY)
    autoCodeGui.AddText("x243 y314 w18", "ms")

    btnStart := autoCodeGui.AddButton("x10 y342 w145 h30", "START (F5)")
    btnStop := autoCodeGui.AddButton("x165 y342 w145 h30", "STOP (ESC)")
    btnStart.OnEvent("Click", (*) => AutoCodeStart())
    btnStop.OnEvent("Click", (*) => AutoCodeStop())

    autoCodeGui.AddText("x10 y380 w300 h25 Center", "F1/F2/F3 = Set | F5 = Start | ESC = Stop")
    autoCodeGui.OnEvent("Close", (*) => AutoCodeHideGui())
}

AutoCodeHideGui() {
    global autoCodeGui, autoCodeGuiVisible
    if IsObject(autoCodeGui)
        autoCodeGui.Hide()
    autoCodeGuiVisible := false
}

AutoCodeRefreshPointLabels() {
    global autoCodeP1Text, autoCodeP2Text, autoCodeP3Text
    if IsObject(autoCodeP1Text)
        autoCodeP1Text.Text := AutoCodePointText(1)
    if IsObject(autoCodeP2Text)
        autoCodeP2Text.Text := AutoCodePointText(2)
    if IsObject(autoCodeP3Text)
        autoCodeP3Text.Text := AutoCodePointText(3)
}

AutoCodeNormalizeProfileName(name) {
    cleaned := Trim(name)
    return cleaned = "" ? "Default" : cleaned
}

AutoCodeGetCurrentResolutionProfile() {
    global GAME_TITLE
    hwnd := WinExist(GAME_TITLE)
    if hwnd {
        WinGetClientPos(&gameX, &gameY, &gameW, &gameH, "ahk_id " hwnd)
        if gameW > 0 && gameH > 0
            return gameW "x" gameH
    }
    return A_ScreenWidth "x" A_ScreenHeight
}

AutoCodeFindProfileIndex(profileName) {
    global autoCodeProfiles
    for i, name in autoCodeProfiles {
        if name = profileName
            return i
    }
    return 0
}

AutoCodeEnsureProfile(profileName) {
    global autoCodeProfiles
    profileName := AutoCodeNormalizeProfileName(profileName)
    if AutoCodeFindProfileIndex(profileName) = 0
        autoCodeProfiles.Push(profileName)
    return profileName
}

AutoCodeProfileSection(profileName) {
    safeName := RegExReplace(profileName, "[^0-9A-Za-z_]", "_")
    return "POINTS_" safeName
}

AutoCodeRefreshProfileOptions() {
    global autoCodeProfileSelect, autoCodeProfiles, autoCodeCurrentProfile, autoCodeProfileSyncing
    if !IsObject(autoCodeProfileSelect)
        return

    autoCodeProfileSyncing := true
    autoCodeProfileSelect.Delete()
    if autoCodeProfiles.Length = 0
        autoCodeProfiles.Push(AutoCodeGetCurrentResolutionProfile())
    autoCodeProfileSelect.Add(autoCodeProfiles)
    idx := AutoCodeFindProfileIndex(autoCodeCurrentProfile)
    if idx = 0 {
        idx := 1
        autoCodeCurrentProfile := autoCodeProfiles[1]
    }
    autoCodeProfileSelect.Choose(idx)
    autoCodeProfileSyncing := false
}

AutoCodeOnProfileChanged(ctrl, *) {
    global autoCodeProfileSyncing, autoCodeCurrentProfile
    if autoCodeProfileSyncing
        return
    selected := AutoCodeNormalizeProfileName(ctrl.Text)
    if selected = autoCodeCurrentProfile
        return
    AutoCodeSwitchProfile(selected)
}

AutoCodeSwitchProfile(profileName) {
    global autoCodeCurrentProfile
    profileName := AutoCodeEnsureProfile(profileName)
    autoCodeCurrentProfile := profileName
    AutoCodeLoadPointsForProfile(profileName)
    AutoCodeRefreshProfileOptions()
    AutoCodeRefreshPointLabels()
    AutoCodeSaveSettings()
}

AutoCodeUseCurrentResolutionProfile() {
    profileName := AutoCodeGetCurrentResolutionProfile()
    AutoCodeSwitchProfile(profileName)
    ToolTip("Using profile: " profileName)
    SetTimer(() => ToolTip(), -1200)
}

AutoCodeLoadPointsForProfile(profileName) {
    global AUTO_CODE_CONFIG
    global autoCodeP1X, autoCodeP1Y, autoCodeP1Color, autoCodeP1Set
    global autoCodeP2X, autoCodeP2Y, autoCodeP2Set
    global autoCodeP3X, autoCodeP3Y, autoCodeP3Set

    section := AutoCodeProfileSection(profileName)
    if !FileExist(AUTO_CODE_CONFIG) {
        autoCodeP1X := 0, autoCodeP1Y := 0, autoCodeP1Color := 0, autoCodeP1Set := false
        autoCodeP2X := 0, autoCodeP2Y := 0, autoCodeP2Set := false
        autoCodeP3X := 0, autoCodeP3Y := 0, autoCodeP3Set := false
        return
    }

    try {
        autoCodeP1X := Integer(IniRead(AUTO_CODE_CONFIG, section, "P1X", "0"))
        autoCodeP1Y := Integer(IniRead(AUTO_CODE_CONFIG, section, "P1Y", "0"))
        autoCodeP1Color := Integer(IniRead(AUTO_CODE_CONFIG, section, "P1COLOR", "0"))
        autoCodeP1Set := IniRead(AUTO_CODE_CONFIG, section, "P1SET", "0") = "1"
        autoCodeP2X := Integer(IniRead(AUTO_CODE_CONFIG, section, "P2X", "0"))
        autoCodeP2Y := Integer(IniRead(AUTO_CODE_CONFIG, section, "P2Y", "0"))
        autoCodeP2Set := IniRead(AUTO_CODE_CONFIG, section, "P2SET", "0") = "1"
        autoCodeP3X := Integer(IniRead(AUTO_CODE_CONFIG, section, "P3X", "0"))
        autoCodeP3Y := Integer(IniRead(AUTO_CODE_CONFIG, section, "P3Y", "0"))
        autoCodeP3Set := IniRead(AUTO_CODE_CONFIG, section, "P3SET", "0") = "1"
    }
    catch {
        autoCodeP1X := 0, autoCodeP1Y := 0, autoCodeP1Color := 0, autoCodeP1Set := false
        autoCodeP2X := 0, autoCodeP2Y := 0, autoCodeP2Set := false
        autoCodeP3X := 0, autoCodeP3Y := 0, autoCodeP3Set := false
    }
}

AutoCodeSetPointFromButton(number) {
    if !FocusGame()
        return
    ToolTip("Move mouse to Point " number "`nand press F" number " again.")
    SetTimer(() => ToolTip(), -2500)
}

AutoCodeSetPoint(number) {
    global GAME_TITLE
    global autoCodeP1X, autoCodeP1Y, autoCodeP1Color, autoCodeP1Set
    global autoCodeP2X, autoCodeP2Y, autoCodeP2Set
    global autoCodeP3X, autoCodeP3Y, autoCodeP3Set

    hwnd := WinExist(GAME_TITLE)
    if !hwnd || !WinActive("ahk_id " hwnd)
        return

    CoordMode "Mouse", "Screen"
    MouseGetPos(&screenX, &screenY)

    AutoCodeClientOriginToScreen(hwnd, &clientScreenX, &clientScreenY)
    x := screenX - clientScreenX
    y := screenY - clientScreenY

    WinGetClientPos(&gameX, &gameY, &gameW, &gameH, "ahk_id " hwnd)
    if (x < 0 || y < 0 || x >= gameW || y >= gameH) {
        ToolTip("Point must be inside the game window.")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    switch number {
        case 1:
            autoCodeP1X := x
            autoCodeP1Y := y
            CoordMode "Pixel", "Screen"
            try autoCodeP1Color := PixelGetColor(screenX, screenY, "RGB")
            catch {
                MsgBox("Unable to capture Point 1.", APP_TITLE, "Icon!")
                return
            }
            autoCodeP1Set := true
        case 2:
            autoCodeP2X := x
            autoCodeP2Y := y
            autoCodeP2Set := true
        case 3:
            autoCodeP3X := x
            autoCodeP3Y := y
            autoCodeP3Set := true
    }

    AutoCodeSaveSettings()
    AutoCodeRefreshPointLabels()
    ToolTip("Point " number " saved")
    SetTimer(() => ToolTip(), -1000)
}

AutoCodeClientOriginToScreen(hwnd, &x, &y) {
    pt := Buffer(8, 0)
    NumPut("Int", 0, pt, 0)
    NumPut("Int", 0, pt, 4)
    DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", pt)
    x := NumGet(pt, 0, "Int")
    y := NumGet(pt, 4, "Int")
}

AutoCodeGamePointToScreen(hwnd, clientX, clientY, &screenX, &screenY) {
    pt := Buffer(8, 0)
    NumPut("Int", clientX, pt, 0)
    NumPut("Int", clientY, pt, 4)
    DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", pt)
    screenX := NumGet(pt, 0, "Int")
    screenY := NumGet(pt, 4, "Int")
}

AutoCodeClickGamePoint(clientX, clientY) {
    global GAME_TITLE, stopRequested
    if stopRequested
        return false

    hwnd := WinExist(GAME_TITLE)
    if !hwnd
        return false

    if !WinActive("ahk_id " hwnd) {
        if !FocusGame()
            return false
    }

    AutoCodeGamePointToScreen(hwnd, clientX, clientY, &screenX, &screenY)
    CoordMode "Mouse", "Screen"
    MouseMove(screenX, screenY, 0)
    Sleep 50
    if stopRequested
        return false
    Click "Left"
    return true
}

AutoCodeSleep(ms) {
    global stopRequested
    elapsed := 0
    while elapsed < ms {
        if stopRequested
            return false
        amount := Min(50, ms - elapsed)
        Sleep amount
        elapsed += amount
    }
    return true
}

AutoCodeReplaceInputWithCode(code) {
    global stopRequested
    if stopRequested
        return false

    SendEvent "^a"
    if !AutoCodeSleep(100)
        return false

    backup := ClipboardAll()
    A_Clipboard := ""
    A_Clipboard := code
    if !ClipWait(1) {
        A_Clipboard := backup
        return false
    }

    SendEvent "^v"
    Sleep 100
    A_Clipboard := backup
    return true
}

AutoCodeGetCurrentP1Color() {
    global GAME_TITLE, autoCodeP1X, autoCodeP1Y
    hwnd := WinExist(GAME_TITLE)
    if !hwnd
        return -1

    AutoCodeGamePointToScreen(hwnd, autoCodeP1X, autoCodeP1Y, &screenX, &screenY)
    CoordMode "Pixel", "Screen"
    try {
        return PixelGetColor(screenX, screenY, "RGB")
    }
    catch {
        return -1
    }
}

AutoCodeColorSimilar(color1, color2, tolerance) {
    r1 := (color1 >> 16) & 0xFF
    g1 := (color1 >> 8) & 0xFF
    b1 := color1 & 0xFF
    r2 := (color2 >> 16) & 0xFF
    g2 := (color2 >> 8) & 0xFF
    b2 := color2 & 0xFF
    return Abs(r1 - r2) <= tolerance && Abs(g1 - g2) <= tolerance && Abs(b1 - b2) <= tolerance
}

AutoCodeWaitForP1NormalColor() {
    global autoCodeP1Color, AUTO_CODE_COLOR_TOLERANCE, AUTO_CODE_COLOR_INITIAL_WAIT
    global AUTO_CODE_COLOR_CHECK_TIMEOUT, AUTO_CODE_COLOR_CHECK_INTERVAL, stopRequested

    if !AutoCodeSleep(AUTO_CODE_COLOR_INITIAL_WAIT)
        return false

    elapsed := 0
    while elapsed <= AUTO_CODE_COLOR_CHECK_TIMEOUT {
        if stopRequested
            return false
        currentColor := AutoCodeGetCurrentP1Color()
        if currentColor != -1 && AutoCodeColorSimilar(currentColor, autoCodeP1Color, AUTO_CODE_COLOR_TOLERANCE)
            return true
        if !AutoCodeSleep(AUTO_CODE_COLOR_CHECK_INTERVAL)
            return false
        elapsed += AUTO_CODE_COLOR_CHECK_INTERVAL
    }
    return false
}

AutoCodeParseCodes(raw) {
    codes := []
    Loop Parse, raw, "`n", "`r" {
        code := Trim(A_LoopField)
        if code != ""
            codes.Push(code)
    }
    return codes
}

AutoCodeStart() {
    global activeMacro, stopRequested, GAME_TITLE
    global autoCodeP1Set, autoCodeP2Set, autoCodeP3Set
    global autoCodeP1X, autoCodeP1Y, autoCodeP2X, autoCodeP2Y, autoCodeP3X, autoCodeP3Y
    global autoCodeCodeBox, autoCodeDelayEdit, autoCodeLineDelayEdit
    global AUTO_CODE_ACTION_DELAY, AUTO_CODE_LINE_DELAY

    if activeMacro = "Redeem Gift Codes"
        return

    if !StartMacro("Redeem Gift Codes") {
        MsgBox("Another macro is running. Stop it before starting Auto Code.", APP_TITLE, "Icon!")
        return
    }

    if (!autoCodeP1Set || !autoCodeP2Set || !autoCodeP3Set) {
        MsgBox("Please set all three points first.", APP_TITLE, "Icon!")
        StopMacro()
        return
    }

    raw := autoCodeCodeBox.Value
    if Trim(raw) = "" {
        MsgBox("Please enter at least one code.", APP_TITLE, "Icon!")
        StopMacro()
        return
    }

    codes := AutoCodeParseCodes(raw)
    if codes.Length = 0 {
        StopMacro()
        return
    }

    try {
        delay := Integer(autoCodeDelayEdit.Value)
    }
    catch {
        delay := AUTO_CODE_ACTION_DELAY
    }
    delay := Max(50, delay)

    try {
        lineDelay := Integer(autoCodeLineDelayEdit.Value)
    }
    catch {
        lineDelay := AUTO_CODE_LINE_DELAY
    }
    lineDelay := Max(50, lineDelay)

    if !FocusGame() {
        StopMacro()
        return
    }

    needPoint1 := true
    completedAllCodes := true

    if !AutoCodeSleep(300)
        completedAllCodes := false

    if completedAllCodes {
        for _, code in codes {
            if stopRequested {
                completedAllCodes := false
                break
            }

            if !WinActive(GAME_TITLE) {
                if !FocusGame() {
                    completedAllCodes := false
                    stopRequested := true
                    break
                }
                if !AutoCodeSleep(300) {
                    completedAllCodes := false
                    break
                }
            }

            if needPoint1 {
                if !AutoCodeClickGamePoint(autoCodeP1X, autoCodeP1Y) {
                    completedAllCodes := false
                    break
                }
                if !AutoCodeSleep(delay) {
                    completedAllCodes := false
                    break
                }
            }

            if !AutoCodeClickGamePoint(autoCodeP2X, autoCodeP2Y) {
                completedAllCodes := false
                break
            }
            if !AutoCodeSleep(delay) {
                completedAllCodes := false
                break
            }

            if !AutoCodeReplaceInputWithCode(code) {
                completedAllCodes := false
                break
            }
            if !AutoCodeSleep(delay) {
                completedAllCodes := false
                break
            }

            if !AutoCodeClickGamePoint(autoCodeP3X, autoCodeP3Y) {
                completedAllCodes := false
                break
            }

            isNormal := AutoCodeWaitForP1NormalColor()
            if stopRequested {
                completedAllCodes := false
                break
            }
            needPoint1 := isNormal

            if !AutoCodeSleep(lineDelay) {
                completedAllCodes := false
                break
            }
        }
    }

    wasStopped := stopRequested
    stopRequested := false
    StopMacro()

    if wasStopped {
        ToolTip("Auto Code stopped.")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    if completedAllCodes {
        ToolTip("All codes completed!")
        SetTimer(() => ToolTip(), -2500)
        return
    }

    ToolTip("Auto Code stopped.")
    SetTimer(() => ToolTip(), -1500)
}

AutoCodeStop() {
    global activeMacro, stopRequested
    if activeMacro = "Redeem Gift Codes"
        stopRequested := true
}

AutoCodePointText(number) {
    global autoCodeP1Set, autoCodeP1X, autoCodeP1Y
    global autoCodeP2Set, autoCodeP2X, autoCodeP2Y
    global autoCodeP3Set, autoCodeP3X, autoCodeP3Y
    switch number {
        case 1:
            if autoCodeP1Set
                return "X:" autoCodeP1X " Y:" autoCodeP1Y
        case 2:
            if autoCodeP2Set
                return "X:" autoCodeP2X " Y:" autoCodeP2Y
        case 3:
            if autoCodeP3Set
                return "X:" autoCodeP3X " Y:" autoCodeP3Y
    }
    return "Not set"
}

AutoCodeSaveSettings() {
    global AUTO_CODE_CONFIG, autoCodeProfiles, autoCodeCurrentProfile
    global autoCodeP1X, autoCodeP1Y, autoCodeP1Color, autoCodeP1Set
    global autoCodeP2X, autoCodeP2Y, autoCodeP2Set
    global autoCodeP3X, autoCodeP3Y, autoCodeP3Set

    profileName := AutoCodeEnsureProfile(autoCodeCurrentProfile)
    autoCodeCurrentProfile := profileName
    section := AutoCodeProfileSection(profileName)
    profilesText := ""
    for i, name in autoCodeProfiles {
        profilesText .= (i = 1 ? "" : "|") name
    }

    try {
        IniWrite(profileName, AUTO_CODE_CONFIG, "META", "CurrentProfile")
        IniWrite(profilesText, AUTO_CODE_CONFIG, "META", "Profiles")
        IniWrite(autoCodeP1X, AUTO_CODE_CONFIG, section, "P1X")
        IniWrite(autoCodeP1Y, AUTO_CODE_CONFIG, section, "P1Y")
        IniWrite(autoCodeP1Color, AUTO_CODE_CONFIG, section, "P1COLOR")
        IniWrite(autoCodeP1Set ? 1 : 0, AUTO_CODE_CONFIG, section, "P1SET")
        IniWrite(autoCodeP2X, AUTO_CODE_CONFIG, section, "P2X")
        IniWrite(autoCodeP2Y, AUTO_CODE_CONFIG, section, "P2Y")
        IniWrite(autoCodeP2Set ? 1 : 0, AUTO_CODE_CONFIG, section, "P2SET")
        IniWrite(autoCodeP3X, AUTO_CODE_CONFIG, section, "P3X")
        IniWrite(autoCodeP3Y, AUTO_CODE_CONFIG, section, "P3Y")
        IniWrite(autoCodeP3Set ? 1 : 0, AUTO_CODE_CONFIG, section, "P3SET")
    }
}

AutoCodeLoadSettings() {
    global AUTO_CODE_CONFIG, autoCodeProfiles, autoCodeCurrentProfile
    global autoCodeP1X, autoCodeP1Y, autoCodeP1Color, autoCodeP1Set
    global autoCodeP2X, autoCodeP2Y, autoCodeP2Set
    global autoCodeP3X, autoCodeP3Y, autoCodeP3Set

    autoCodeProfiles := []
    defaultProfile := AutoCodeGetCurrentResolutionProfile()

    if !FileExist(AUTO_CODE_CONFIG) {
        autoCodeCurrentProfile := defaultProfile
        AutoCodeEnsureProfile(defaultProfile)
        AutoCodeLoadPointsForProfile(defaultProfile)
        return
    }

    try {
        profilesRaw := IniRead(AUTO_CODE_CONFIG, "META", "Profiles", "")
        if profilesRaw != "" {
            for _, profileName in StrSplit(profilesRaw, "|") {
                profileName := AutoCodeNormalizeProfileName(profileName)
                if AutoCodeFindProfileIndex(profileName) = 0
                    autoCodeProfiles.Push(profileName)
            }
        }
        autoCodeCurrentProfile := AutoCodeNormalizeProfileName(IniRead(AUTO_CODE_CONFIG, "META", "CurrentProfile", defaultProfile))
    }
    catch {
        autoCodeCurrentProfile := defaultProfile
    }

    legacyLoaded := false
    if autoCodeProfiles.Length = 0 {
        try {
            p1x := IniRead(AUTO_CODE_CONFIG, "POINTS", "P1X", "")
            if p1x != "" {
                autoCodeP1X := Integer(p1x)
                autoCodeP1Y := Integer(IniRead(AUTO_CODE_CONFIG, "POINTS", "P1Y", "0"))
                autoCodeP1Color := Integer(IniRead(AUTO_CODE_CONFIG, "POINTS", "P1COLOR", "0"))
                autoCodeP1Set := IniRead(AUTO_CODE_CONFIG, "POINTS", "P1SET", "0") = "1"
                autoCodeP2X := Integer(IniRead(AUTO_CODE_CONFIG, "POINTS", "P2X", "0"))
                autoCodeP2Y := Integer(IniRead(AUTO_CODE_CONFIG, "POINTS", "P2Y", "0"))
                autoCodeP2Set := IniRead(AUTO_CODE_CONFIG, "POINTS", "P2SET", "0") = "1"
                autoCodeP3X := Integer(IniRead(AUTO_CODE_CONFIG, "POINTS", "P3X", "0"))
                autoCodeP3Y := Integer(IniRead(AUTO_CODE_CONFIG, "POINTS", "P3Y", "0"))
                autoCodeP3Set := IniRead(AUTO_CODE_CONFIG, "POINTS", "P3SET", "0") = "1"
                autoCodeCurrentProfile := defaultProfile
                AutoCodeEnsureProfile(defaultProfile)
                legacyLoaded := true
            }
        }
    }

    if !legacyLoaded {
        AutoCodeEnsureProfile(defaultProfile)
        AutoCodeEnsureProfile(autoCodeCurrentProfile)
        AutoCodeLoadPointsForProfile(autoCodeCurrentProfile)
    }
}

AutoCodeHotkeysEnabled() {
    global autoCodeGuiVisible, activeMacro
    return autoCodeGuiVisible || activeMacro = "Redeem Gift Codes"
}

AutoCodeHandlePointHotkey(number) {
    global autoCodeGui, autoCodeGuiVisible, GAME_TITLE
    if !AutoCodeHotkeysEnabled()
        return

    if WinActive(GAME_TITLE) {
        AutoCodeSetPoint(number)
        return
    }

    if autoCodeGuiVisible && IsObject(autoCodeGui) && WinActive("ahk_id " autoCodeGui.Hwnd) {
        if !FocusGame()
            return
        ToolTip("Move mouse to Point " number "`nand press F" number " again.")
        SetTimer(() => ToolTip(), -2000)
    }
}

#HotIf AutoCodeHotkeysEnabled()

F1:: AutoCodeHandlePointHotkey(1)
F2:: AutoCodeHandlePointHotkey(2)
F3:: AutoCodeHandlePointHotkey(3)
F5:: AutoCodeStart()

#HotIf
