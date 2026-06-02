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
    currentMute := GetDefaultMicMute()
    if (currentMute != -1) {
        SetDefaultMicMute(currentMute ? 0 : 1)
    }
    UpdateMicState()
}

; --- FUNCTIONS ---
UpdateMicState() {
    isMuted := GetDefaultMicMute()
    
    ; Find the top-right corner of your primary screen
    MonitorGetWorkArea(, &MonLeft, &MonTop, &MonRight, &MonBottom)
    xPos := MonRight - 140
    yPos := MonTop + 10
    
    if (isMuted = 1) {
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

; --- CORE AUDIO COM FUNCTIONS ---
GetDefaultMicMute() {
    deviceEnumerator := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
    if (!deviceEnumerator)
        return -1
        
    defaultDevice := 0
    DllCall(NumGet(NumGet(deviceEnumerator.ptr, "UPtr") + 4 * A_PtrSize, "UPtr"), "UPtr", deviceEnumerator.ptr, "Int", 1, "Int", 0, "UPtr*", &defaultDevice)
    
    if (!defaultDevice)
        return -1
        
    iid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "WStr", "{5CDF2C82-841E-4546-9722-0CF74078229A}", "UPtr", iid.ptr)
    endpointVolume := 0
    DllCall(NumGet(NumGet(defaultDevice, "UPtr") + 3 * A_PtrSize, "UPtr"), "UPtr", defaultDevice, "UPtr", iid.ptr, "UInt", 23, "UPtr", 0, "UPtr*", &endpointVolume)
    ObjRelease(defaultDevice)
    
    if (!endpointVolume)
        return -1
        
    isMuted := 0
    DllCall(NumGet(NumGet(endpointVolume, "UPtr") + 15 * A_PtrSize, "UPtr"), "UPtr", endpointVolume, "Int*", &isMuted)
    ObjRelease(endpointVolume)
    
    return isMuted
}

SetDefaultMicMute(muteState) {
    deviceEnumerator := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
    if (!deviceEnumerator)
        return false
        
    defaultDevice := 0
    DllCall(NumGet(NumGet(deviceEnumerator.ptr, "UPtr") + 4 * A_PtrSize, "UPtr"), "UPtr", deviceEnumerator.ptr, "Int", 1, "Int", 0, "UPtr*", &defaultDevice)
    
    if (!defaultDevice)
        return false
        
    iid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "WStr", "{5CDF2C82-841E-4546-9722-0CF74078229A}", "UPtr", iid.ptr)
    endpointVolume := 0
    DllCall(NumGet(NumGet(defaultDevice, "UPtr") + 3 * A_PtrSize, "UPtr"), "UPtr", defaultDevice, "UPtr", iid.ptr, "UInt", 23, "UPtr", 0, "UPtr*", &endpointVolume)
    ObjRelease(defaultDevice)
    
    if (!endpointVolume)
        return false
        
    DllCall(NumGet(NumGet(endpointVolume, "UPtr") + 14 * A_PtrSize, "UPtr"), "UPtr", endpointVolume, "Int", muteState, "UPtr", 0)
    ObjRelease(endpointVolume)
    
    return true
}
