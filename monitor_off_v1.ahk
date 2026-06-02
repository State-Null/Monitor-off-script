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

isMuted := false

; Update tray icon to reflect the initial state
GoSub, UpdateMicState
return

; --- 1. MONITOR POWER OFF HOTKEY ---
; Press F24 to turn off the monitor
F24::
Sleep, 500
SendMessage, 0x112, 0xF170, 2,, Program Manager
return

; --- 2. MICROPHONE TOGGLE HOTKEY ---
; Passively listen to Ctrl+Shift+M (sent by iCUE or keyboard) to toggle visual state, while letting the key pass through to VDI/Teams
~^+m::
    isMuted := !isMuted
    GoSub, UpdateMicState
return

; --- SUBROUTINES ---
UpdateMicState:
    if (isMuted) {
        ; --- MIC IS OFF ---
        ; Update Tray Icon to Red X Circle
        Menu, Tray, Icon, shell32.dll, 132
        Menu, Tray, Tip, Mic is OFF (Muted)
    } else {
        ; --- MIC IS LIVE ---
        ; Update Tray Icon to Green Check Circle
        Menu, Tray, Icon, shell32.dll, 144
        Menu, Tray, Tip, Mic is LIVE (Active)
    }
return
