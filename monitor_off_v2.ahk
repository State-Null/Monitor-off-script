#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook  ; Force keyboard hook to prevent other applications from hijacking hotkeys

; Force the script to run as Administrator.
; This is critical to capture keyboard shortcuts (like F23/F24) when Remote Desktop or AVD is active.
if not A_IsAdmin
{
    try {
        if A_IsCompiled
            Run('*RunAs "' A_ScriptFullPath '"')
        else
            Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"')
    }
    ExitApp
}

; --- CONFIGURATION ---
global showOSD := true  ; Set to true to show the on-screen overlay, false to hide it
global isMuted := false

; --- 1. INITIALIZE THE MIC OVERLAY GUI ---
Gui_Mic := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20")
Gui_Mic.Color := "1A1A1A"  ; Dark grey background
Gui_Mic.SetFont("s11 bold", "Segoe UI")
OSDText := Gui_Mic.Add("Text", "Center w120 h22 y6 cFF5555", "MIC OFF")
WinSetTransparent(210, Gui_Mic.Hwnd)  ; Nice transparency

; Update overlay and tray icon to reflect the initial state
UpdateMicState()
return

; --- 2. MONITOR POWER OFF HOTKEY ---
; Press F24 to turn off the monitor
F24::
{
    Sleep(500)
    SendMessage(0x112, 0xF170, 2,, "Program Manager")
}

; --- 3. MICROPHONE TOGGLE HOTKEY ---
; Press F23 to toggle mic status visually and send Ctrl+Shift+M to VDI
F23::
{
    global isMuted
    isMuted := !isMuted
    
    ; Send Ctrl+Shift+M to active VDI session
    Send("^+m")
    
    UpdateMicState()
}

; --- FUNCTIONS ---
UpdateMicState() {
    global isMuted, showOSD
    
    ; Find the top-right corner of primary screen
    MonitorGetWorkArea(, &MonLeft, &MonTop, &MonRight, &MonBottom)
    xPos := MonRight - 140
    yPos := MonTop + 10
    
    if (isMuted) {
        ; --- MIC IS OFF ---
        ; 1. Update Tray Icon to Red X Circle
        TraySetIcon("shell32.dll", 132)
        A_IconTip := "Mic is OFF (Muted)"
        
        ; 2. Update Overlay Text/Color to Red
        OSDText.SetFont("cFF5555")
        OSDText.Value := "MIC OFF"
        
        ; 3. Show overlay persistently (if enabled)
        if (showOSD) {
            Gui_Mic.Show("x" xPos " y" yPos " w120 h30 NoActivate")
        } else {
            Gui_Mic.Hide()
        }
        SetTimer(HideOSD, 0) ; Disable hide timer
    } else {
        ; --- MIC IS LIVE ---
        ; 1. Update Tray Icon to Green Check Circle
        TraySetIcon("shell32.dll", 144)
        A_IconTip := "Mic is LIVE (Active)"
        
        ; 2. Update Overlay Text/Color to Green
        OSDText.SetFont("c55FF55")
        OSDText.Value := "MIC LIVE"
        
        ; 3. Show overlay and start timer to hide it (if enabled)
        if (showOSD) {
            Gui_Mic.Show("x" xPos " y" yPos " w120 h30 NoActivate")
            SetTimer(HideOSD, -1000) ; Hide after 1 second
        } else {
            Gui_Mic.Hide()
        }
    }
}

HideOSD() {
    Gui_Mic.Hide()
}
