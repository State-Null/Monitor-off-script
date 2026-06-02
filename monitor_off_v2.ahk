#Requires AutoHotkey v2.0
#SingleInstance Force

; --- CONFIGURATION ---
global showOSD := true  ; Set to true to show the on-screen overlay, false to hide it

; --- 1. INITIALIZE THE MIC OVERLAY GUI ---
Gui_Mic := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20")
Gui_Mic.Color := "1A1A1A"  ; Dark grey background
Gui_Mic.SetFont("s11 bold", "Segoe UI")
OSDText := Gui_Mic.Add("Text", "Center w120 h22 y6 cFF5555", "MIC OFF")
WinSetTransparent(210, Gui_Mic.Hwnd)  ; Nice transparency

; Run check at startup to set the correct tray icon and OSD state
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
; Press F23 to toggle default microphone mute
F23::
{
    toggledAny := false
    
    ; Loop through all potential audio devices to find your mic and toggle it
    Loop 32 {
        try {
            SoundSetMute(-1, "Microphone", A_Index)
            toggledAny := true
        }
    }
    
    ; Fallback if no specific index was toggled
    if (!toggledAny) {
        try {
            SoundSetMute(-1, , "Microphone")
        } catch {
            try {
                SoundSetMute(-1)
            } catch {
                ; do nothing
            }
        }
    }
    
    UpdateMicState()
}

; --- 4. TOGGLE ON-SCREEN DISPLAY (OSD) HOTKEY ---
; Press Shift+F23 to toggle the visual overlay on/off
+F23::
{
    global showOSD := !showOSD
    if (!showOSD) {
        Gui_Mic.Hide()
    } else {
        UpdateMicState()
    }
}

; --- FUNCTIONS ---
UpdateMicState() {
    isMuted := false
    foundMic := false
    
    ; Search for your active microphone device to read its current state
    Loop 32 {
        try {
            isMuted := SoundGetMute("Microphone", A_Index)
            foundMic := true
            break
        }
    }
    
    ; Fallback to default recording device if name loop fails
    if (!foundMic) {
        try {
            isMuted := SoundGetMute(, "Microphone")
        } catch {
            try {
                isMuted := SoundGetMute()
            } catch {
                isMuted := false
            }
        }
    }
    
    ; Find the top-right corner of your primary screen
    MonitorGetWorkArea(, &MonLeft, &MonTop, &MonRight, &MonBottom)
    xPos := MonRight - 140
    yPos := MonTop + 10
    
    if (isMuted) {
        ; --- MIC IS OFF (MUTED) ---
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
        ; --- MIC IS LIVE (ACTIVE) ---
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
