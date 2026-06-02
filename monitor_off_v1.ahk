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
            Run *RunAs "%A_AhkPath%" "%A_ScriptFullPath%"
    }
    ExitApp
}

; --- CONFIGURATION ---
showOSD := true  ; Set to true to show the on-screen overlay, false to hide it
primaryMicId := ""
backupMicId := ""
isFallbackMode := false
isMuted := false

; --- INITIALIZE MIC STATE ---
InitializeMicDevices()

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
; Press F23 to toggle physical microphone state by switching default devices (or system mute fallback)
F23::
    isMuted := !isMuted
    if (isFallbackMode) {
        SetDefaultMicMuteFallback(isMuted)
    } else {
        try {
            IPolicyConfig := ComObjCreate("{870AF99C-171D-4F9E-AF0D-E63DF40C2BC9}", "{F8679F50-850A-41CF-9C72-430F290290C8}")
            targetId := isMuted ? backupMicId : primaryMicId
            
            ; Set default for Console (0) and Communications (2)
            DllCall(NumGet(NumGet(IPolicyConfig+0)+13*A_PtrSize), "UPtr", IPolicyConfig+0, "WStr", targetId, "Int", 0)
            DllCall(NumGet(NumGet(IPolicyConfig+0)+13*A_PtrSize), "UPtr", IPolicyConfig+0, "WStr", targetId, "Int", 2)
            ObjRelease(IPolicyConfig)
        } catch {
            ; Fallback just in case COM call fails
            SetDefaultMicMuteFallback(isMuted)
        }
    }
    
    GoSub, UpdateMicState
return

; --- SUBROUTINES / FUNCTIONS ---
UpdateMicState:
    ; Find the top-right corner of primary screen
    SysGet, Mon, MonitorWorkArea
    xPos := MonRight - 140
    yPos := MonTop + 10
    
    if (isMuted) {
        ; --- MIC IS OFF (MUTED/BACKUP MIC) ---
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
        ; --- MIC IS LIVE (ACTIVE/PRIMARY MIC) ---
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

InitializeMicDevices() {
    global primaryMicId, backupMicId, isFallbackMode, isMuted
    
    try {
        deviceEnumerator := ComObjCreate("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
        
        ; 1. Get current default communications recording device ID
        defaultDevice := 0
        hr := DllCall(NumGet(NumGet(deviceEnumerator+0)+4*A_PtrSize), "UPtr", deviceEnumerator, "Int", 1, "Int", 2, "UPtr*", defaultDevice)
        if (hr != 0 || !defaultDevice) {
            hr := DllCall(NumGet(NumGet(deviceEnumerator+0)+4*A_PtrSize), "UPtr", deviceEnumerator, "Int", 1, "Int", 0, "UPtr*", defaultDevice)
        }
        
        if (defaultDevice) {
            pstrId := 0
            hr2 := DllCall(NumGet(NumGet(defaultDevice+0)+5*A_PtrSize), "UPtr", defaultDevice, "UPtr*", pstrId)
            if (hr2 == 0 && pstrId) {
                primaryMicId := StrGet(pstrId, "UTF-16")
                DllCall("ole32\CoTaskMemFree", "UPtr", pstrId)
            }
            ObjRelease(defaultDevice)
        }
        
        ; 2. Enumerate all active capture devices to find a backup (silent fallback)
        deviceCollection := 0
        hr := DllCall(NumGet(NumGet(deviceEnumerator+0)+3*A_PtrSize), "UPtr", deviceEnumerator, "Int", 1, "UInt", 1, "UPtr*", deviceCollection)
        if (hr == 0 && deviceCollection) {
            count := 0
            DllCall(NumGet(NumGet(deviceCollection+0)+3*A_PtrSize), "UPtr", deviceCollection, "UInt*", count)
            loop %count% {
                device := 0
                DllCall(NumGet(NumGet(deviceCollection+0)+4*A_PtrSize), "UPtr", deviceCollection, "UInt", A_Index - 1, "UPtr*", device)
                if (device) {
                    pstrId := 0
                    DllCall(NumGet(NumGet(device+0)+5*A_PtrSize), "UPtr", device, "UPtr*", pstrId)
                    id := StrGet(pstrId, "UTF-16")
                    DllCall("ole32\CoTaskMemFree", "UPtr", pstrId)
                    
                    if (id != primaryMicId && backupMicId == "") {
                        backupMicId := id
                    }
                    ObjRelease(device)
                }
            }
            ObjRelease(deviceCollection)
        }
        ObjRelease(deviceEnumerator)
    } catch {
        ; Ignore COM errors, fallback mode will be enabled
    }
    
    if (primaryMicId = "" || backupMicId = "") {
        isFallbackMode := true
        isMuted := GetDefaultMicMuteFallback()
    } else {
        isFallbackMode := false
        ; Check if current default communications device is backupMicId (meaning we started muted)
        try {
            deviceEnumerator := ComObjCreate("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
            currentDefaultId := ""
            defaultDevice := 0
            hr := DllCall(NumGet(NumGet(deviceEnumerator+0)+4*A_PtrSize), "UPtr", deviceEnumerator, "Int", 1, "Int", 2, "UPtr*", defaultDevice)
            if (hr == 0 && defaultDevice) {
                pstrId := 0
                DllCall(NumGet(NumGet(defaultDevice+0)+5*A_PtrSize), "UPtr", defaultDevice, "UPtr*", pstrId)
                currentDefaultId := StrGet(pstrId, "UTF-16")
                DllCall("ole32\CoTaskMemFree", "UPtr", pstrId)
                ObjRelease(defaultDevice)
            }
            ObjRelease(deviceEnumerator)
            isMuted := (currentDefaultId = backupMicId)
        } catch {
            isMuted := false
        }
    }
}

GetDefaultMicMuteFallback() {
    try {
        deviceEnumerator := ComObjCreate("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
        defaultDevice := 0
        hr := DllCall(NumGet(NumGet(deviceEnumerator+0)+4*A_PtrSize), "UPtr", deviceEnumerator, "Int", 1, "Int", 2, "UPtr*", defaultDevice)
        if (hr != 0 || !defaultDevice) {
            hr := DllCall(NumGet(NumGet(deviceEnumerator+0)+4*A_PtrSize), "UPtr", deviceEnumerator, "Int", 1, "Int", 0, "UPtr*", defaultDevice)
        }
        ObjRelease(deviceEnumerator)
        if (!defaultDevice)
            return false
            
        VarSetCapacity(iid, 16)
        DllCall("ole32\CLSIDFromString", "WStr", "{5CDF2C82-841E-4546-9722-0CF74078229A}", "UPtr", &iid)
        endpointVolume := 0
        DllCall(NumGet(NumGet(defaultDevice+0)+3*A_PtrSize), "UPtr", defaultDevice, "UPtr", &iid, "UInt", 23, "UPtr", 0, "UPtr*", endpointVolume)
        ObjRelease(defaultDevice)
        
        if (!endpointVolume)
            return false
            
        isMutedVal := 0
        DllCall(NumGet(NumGet(endpointVolume+0)+15*A_PtrSize), "UPtr", endpointVolume, "Int*", isMutedVal)
        ObjRelease(endpointVolume)
        return isMutedVal
    } catch {
        return false
    }
}

SetDefaultMicMuteFallback(muteState) {
    try {
        deviceEnumerator := ComObjCreate("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
        if (!deviceEnumerator)
            return
            
        VarSetCapacity(iid, 16)
        DllCall("ole32\CLSIDFromString", "WStr", "{5CDF2C82-841E-4546-9722-0CF74078229A}", "UPtr", &iid)
        
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
                }
            }
        }
        ObjRelease(deviceEnumerator)
    } catch {
        ; Ignore
    }
}
