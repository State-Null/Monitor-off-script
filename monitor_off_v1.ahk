#NoEnv
#SingleInstance Force
#UseHook  ; Force keyboard hook to prevent other applications from hijacking hotkeys
SendMode Input
SetWorkingDir %A_ScriptDir%

; Force the script to run as Administrator.
; This is critical to capture keyboard shortcuts (like F23/F24) when Remote Desktop or AVD is active.
if not A_IsAdmin
{
    try {
        if A_IsCompiled
            Run *RunAs "%A_ScriptFullPath%"
        else
            Run *RunAs "%A_ScriptFullPath%"
    }
    ExitApp
}

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
    currentMute := GetDefaultMicMute()
    if (currentMute != -1) {
        ; Toggle it
        SetDefaultMicMute(!currentMute)
    }
    GoSub, UpdateMicState
return

; --- SUBROUTINES ---
UpdateMicState:
    isMutedVal := GetDefaultMicMute()
    
    ; Find the top-right corner of your primary screen
    SysGet, Mon, MonitorWorkArea
    xPos := MonRight - 140
    yPos := MonTop + 10
    
    if (isMutedVal = 1) {
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

; --- CORE AUDIO COM FUNCTIONS ---
GetDefaultMicMute() {
    ; CLSID_MMDeviceEnumerator: {BCDE0395-E52F-467C-8E3D-C4579291692E}
    ; IID_IMMDeviceEnumerator: {A95664D2-9614-4F35-A746-DE8DB63617E6}
    ; IID_IAudioEndpointVolume: {5CDF2C82-841E-4546-9722-0CF74078229A}
    
    deviceEnumerator := ComObjCreate("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
    if (!deviceEnumerator)
        return -1
    
    ; Try eCommunications (2) first, fall back to eConsole (0)
    defaultDevice := 0
    hr := DllCall(NumGet(NumGet(deviceEnumerator+0)+4*A_PtrSize), "UPtr", deviceEnumerator, "Int", 1, "Int", 2, "UPtr*", defaultDevice)
    if (hr != 0 || !defaultDevice) {
        hr := DllCall(NumGet(NumGet(deviceEnumerator+0)+4*A_PtrSize), "UPtr", deviceEnumerator, "Int", 1, "Int", 0, "UPtr*", defaultDevice)
    }
    ObjRelease(deviceEnumerator)
    
    if (!defaultDevice)
        return -1
        
    ; Activate defaultDevice to get IAudioEndpointVolume
    VarSetCapacity(iid, 16)
    DllCall("ole32\CLSIDFromString", "WStr", "{5CDF2C82-841E-4546-9722-0CF74078229A}", "UPtr", &iid)
    endpointVolume := 0
    DllCall(NumGet(NumGet(defaultDevice+0)+3*A_PtrSize), "UPtr", defaultDevice, "UPtr", &iid, "UInt", 23, "UPtr", 0, "UPtr*", endpointVolume)
    ObjRelease(defaultDevice)
    
    if (!endpointVolume)
        return -1
        
    ; GetMute (Vtable index 15)
    isMuted := 0
    DllCall(NumGet(NumGet(endpointVolume+0)+15*A_PtrSize), "UPtr", endpointVolume, "Int*", isMuted)
    ObjRelease(endpointVolume)
    
    return isMuted
}

SetDefaultMicMute(muteState) {
    ; CLSID_MMDeviceEnumerator: {BCDE0395-E52F-467C-8E3D-C4579291692E}
    ; IID_IMMDeviceEnumerator: {A95664D2-9614-4F35-A746-DE8DB63617E6}
    ; IID_IAudioEndpointVolume: {5CDF2C82-841E-4546-9722-0CF74078229A}
    
    deviceEnumerator := ComObjCreate("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
    if (!deviceEnumerator)
        return false
    
    success := false
    VarSetCapacity(iid, 16)
    DllCall("ole32\CLSIDFromString", "WStr", "{5CDF2C82-841E-4546-9722-0CF74078229A}", "UPtr", &iid)
    
    ; Loop roles: 0 (Console), 2 (Communications)
    for each, role in [0, 2] {
        defaultDevice := 0
        hr := DllCall(NumGet(NumGet(deviceEnumerator+0)+4*A_PtrSize), "UPtr", deviceEnumerator, "Int", 1, "Int", role, "UPtr*", defaultDevice)
        if (hr == 0 && defaultDevice) {
            endpointVolume := 0
            DllCall(NumGet(NumGet(defaultDevice+0)+3*A_PtrSize), "UPtr", defaultDevice, "UPtr", &iid, "UInt", 23, "UPtr", 0, "UPtr*", endpointVolume)
            ObjRelease(defaultDevice)
            
            if (endpointVolume) {
                DllCall(NumGet(NumGet(endpointVolume+0)+14*A_PtrSize), "UPtr", endpointVolume, "Int", muteState, "UPtr", 0)
                ObjRelease(endpointVolume)
                success := true
            }
        }
    }
    ObjRelease(deviceEnumerator)
    
    return success
}
