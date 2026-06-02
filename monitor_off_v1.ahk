#NoEnv
#SingleInstance Force
#UseHook  ; Force keyboard hook to prevent other applications from hijacking hotkeys
SendMode Input
SetWorkingDir %A_ScriptDir%

; Force the script to run as Administrator.
; This is critical to capture keyboard shortcuts (like Ctrl+Shift+M/F24) when Remote Desktop or AVD is active.
if not A_IsAdmin
{
    try {
        if A_IsCompiled
            Run *RunAs "%A_ScriptFullPath%"
        else
            Run *RunAs "%A_AhkPath%" "%A_ScriptFullPath%"
    }
    ExitApp
}

; --- CONFIGURATION ---
showOSD := true  ; Set to true to show the on-screen overlay, false to hide it
isMuted := false

; --- 1. INITIALIZE THE MIC OVERLAY GUI ---
Gui, MicOSD:New, +AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20
Gui, Color, 1A1A1A  ; Dark grey background
Gui, Font, s11 bold, Segoe UI
Gui, Add, Text, vOSDText cFF5555 Center w120 h22 y6, MIC OFF
WinSet, Transparent, 210  ; Nice transparency

; Update overlay and tray icon to reflect the initial state
GoSub, UpdateMicState
return

; --- 2. MONITOR POWER OFF HOTKEY ---
; Press F24 to turn off the monitor
F24::
Sleep, 500
SendMessage, 0x112, 0xF170, 2,, Program Manager
return

; --- 3. MICROPHONE TOGGLE HOTKEY ---
; Passively listen to Ctrl+Shift+M (sent by iCUE or keyboard) to toggle visual state, while letting the key pass through to VDI/Teams
~^+m::
    isMuted := !isMuted
    GoSub, UpdateMicState
return

; --- SUBROUTINES ---
UpdateMicState:
    ; Find the top-right corner of primary screen
    SysGet, Mon, MonitorWorkArea
    xPos := MonRight - 140
    yPos := MonTop + 10
    
    if (isMuted) {
        ; --- MIC IS OFF ---
        ; 1. Update Tray Icon to Red X Circle
        Menu, Tray, Icon, shell32.dll, 132
        Menu, Tray, Tip, Mic is OFF (Muted)
        
        ; 2. Update Overlay Text/Color to Red
        Gui, MicOSD:Font, cFF5555
        GuiControl, MicOSD:Font, OSDText
        GuiControl, MicOSD:, OSDText, MIC OFF
        
        ; 3. Show overlay persistently (if enabled)
        if (showOSD) {
            Gui, MicOSD:Show, x%xPos% y%yPos% w120 h30 NoActivate
        } else {
            Gui, MicOSD:Hide
        }
        SetTimer, HideOSD, Off
    } else {
        ; --- MIC IS LIVE ---
        ; 1. Update Tray Icon to Green Check Circle
        Menu, Tray, Icon, shell32.dll, 144
        Menu, Tray, Tip, Mic is LIVE (Active)
        
        ; 2. Update Overlay Text/Color to Green
        Gui, MicOSD:Font, c55FF55
        GuiControl, MicOSD:Font, OSDText
        GuiControl, MicOSD:, OSDText, MIC LIVE
        
        ; 3. Show overlay and start timer to hide it (if enabled)
        if (showOSD) {
            Gui, MicOSD:Show, x%xPos% y%yPos% w120 h30 NoActivate
            SetTimer, HideOSD, -1000 ; Hide after 1 second
        } else {
            Gui, MicOSD:Hide
        }
    }
return

HideOSD:
    Gui, MicOSD:Hide
return
