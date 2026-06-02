#NoEnv
#SingleInstance Force
SendMode Input
SetWorkingDir %A_ScriptDir%

; --- CONFIGURATION ---
showOSD := true  ; Set to true to show the on-screen overlay, false to hide it

; --- 1. INITIALIZE THE MIC OVERLAY GUI ---
Gui, MicOSD:New, +AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20
Gui, Color, 1A1A1A  ; Dark grey background
Gui, Font, s11 bold, Segoe UI
Gui, Add, Text, vOSDText cFF5555 Center w120 h22 y6, MIC OFF
WinSet, Transparent, 210  ; Nice transparency

; Run check at startup to set the correct tray icon and OSD state
GoSub, UpdateMicState
return

; --- 2. MONITOR POWER OFF HOTKEY ---
; Press F24 to turn off the monitor
F24::
Sleep, 500
SendMessage, 0x112, 0xF170, 2,, Program Manager
return

; --- 3. MICROPHONE TOGGLE HOTKEY ---
; Press F23 to toggle default microphone mute
F23::
    toggledAny := false
    
    ; Loop through all potential audio devices to find your mic and toggle it
    Loop, 32 {
        SoundGet, tempMute, Microphone, Mute, %A_Index%
        if (ErrorLevel = 0) {
            ; Toggle it
            SoundSet, +1, Microphone, Mute, %A_Index%
            toggledAny := true
        }
    }
    
    ; Fallback: If no dedicated "Microphone" component was found, toggle master input
    if (!toggledAny) {
        SoundSet, +1, Master, Mute, 1
    }
    
    GoSub, UpdateMicState
return

; --- 4. TOGGLE ON-SCREEN DISPLAY (OSD) HOTKEY ---
; Press Shift+F23 to toggle the visual overlay on/off
+F23::
    showOSD := !showOSD
    if (!showOSD) {
        Gui, MicOSD:Hide
    } else {
        GoSub, UpdateMicState
    }
return

; --- SUBROUTINES ---
UpdateMicState:
    isMuted := "Off"
    foundMic := false
    
    ; Search for your active microphone device to read its current state
    Loop, 32 {
        SoundGet, tempMute, Microphone, Mute, %A_Index%
        if (ErrorLevel = 0) {
            isMuted := tempMute
            foundMic := true
            break
        }
    }
    
    ; Fallback if no Microphone component was found
    if (!foundMic) {
        SoundGet, isMuted, Master, Mute, 1
    }
    
    ; Find the top-right corner of your primary screen
    SysGet, Mon, MonitorWorkArea
    xPos := MonRight - 140
    yPos := MonTop + 10
    
    if (isMuted = "On") {
        ; --- MIC IS OFF (MUTED) ---
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
        ; --- MIC IS LIVE (ACTIVE) ---
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
