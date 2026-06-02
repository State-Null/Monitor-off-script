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
global primaryMicId := ""
global backupMicId := ""
global isFallbackMode := false
global isMuted := false

; --- INITIALIZE MIC STATE ---
InitializeMicDevices()

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
; Press F23 to toggle physical microphone state by switching default devices (or system mute fallback)
F23::
{
    global isMuted, primaryMicId, backupMicId, isFallbackMode
    
    isMuted := !isMuted
    if (isFallbackMode) {
        SetDefaultMicMuteFallback(isMuted ? 1 : 0)
    } else {
        try {
            IPolicyConfig := ComObject("{870AF99C-171D-4F9E-AF0D-E63DF40C2BC9}", "{F8679F50-850A-41CF-9C72-430F290290C8}")
            targetId := isMuted ? backupMicId : primaryMicId
            
            ; Set default for Console (0) and Communications (2)
            ComCall(13, IPolicyConfig, "Str", targetId, "Int", 0)
            ComCall(13, IPolicyConfig, "Str", targetId, "Int", 2)
        } catch {
            ; Fallback just in case COM call fails
            SetDefaultMicMuteFallback(isMuted ? 1 : 0)
        }
    }
    
    UpdateMicState()
}

; --- FUNCTIONS ---
InitializeMicDevices() {
    global primaryMicId, backupMicId, isFallbackMode, isMuted
    
    try {
        deviceEnumerator := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
        
        ; 1. Get current default communications recording device ID
        defaultDevice := 0
        hr := ComCall(4, deviceEnumerator, "Int", 1, "Int", 2, "UPtr*", &defaultDevice := 0) ; Role 2 = eCommunications
        if (hr != 0 || !defaultDevice) {
            hr := ComCall(4, deviceEnumerator, "Int", 1, "Int", 0, "UPtr*", &defaultDevice := 0) ; Role 0 = eConsole
        }
        
        if (defaultDevice) {
            pstrId := 0
            hr2 := ComCall(5, defaultDevice, "UPtr*", &pstrId := 0)
            if (hr2 == 0 && pstrId) {
                primaryMicId := StrGet(pstrId, "UTF-16")
                DllCall("ole32\CoTaskMemFree", "UPtr", pstrId)
            }
            ObjRelease(defaultDevice)
        }
        
        ; 2. Enumerate all active capture devices to find a backup (silent fallback)
        deviceCollection := 0
        hr := ComCall(3, deviceEnumerator, "Int", 1, "UInt", 1, "UPtr*", &deviceCollection := 0) ; 1 = eCapture, 1 = DEVICE_STATE_ACTIVE
        if (hr == 0 && deviceCollection) {
            count := 0
            ComCall(3, deviceCollection, "UInt*", &count := 0)
            loop count {
                device := 0
                ComCall(4, deviceCollection, "UInt", A_Index - 1, "UPtr*", &device := 0)
                if (device) {
                    pstrId := 0
                    ComCall(5, device, "UPtr*", &pstrId := 0)
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
            currentDefaultId := ""
            defaultDevice := 0
            hr := ComCall(4, deviceEnumerator, "Int", 1, "Int", 2, "UPtr*", &defaultDevice := 0)
            if (hr == 0 && defaultDevice) {
                pstrId := 0
                ComCall(5, defaultDevice, "UPtr*", &pstrId := 0)
                currentDefaultId := StrGet(pstrId, "UTF-16")
                DllCall("ole32\CoTaskMemFree", "UPtr", pstrId)
                ObjRelease(defaultDevice)
            }
            isMuted := (currentDefaultId = backupMicId)
        } catch {
            isMuted := false
        }
    }
}

GetDefaultMicMuteFallback() {
    try {
        deviceEnumerator := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
        defaultDevice := 0
        hr := ComCall(4, deviceEnumerator, "Int", 1, "Int", 2, "UPtr*", &defaultDevice := 0)
        if (hr != 0 || !defaultDevice) {
            hr := ComCall(4, deviceEnumerator, "Int", 1, "Int", 0, "UPtr*", &defaultDevice := 0)
        }
        if (!defaultDevice)
            return false
            
        iid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "WStr", "{5CDF2C82-841E-4546-9722-0CF74078229A}", "UPtr", iid.ptr)
        endpointVolume := 0
        ComCall(3, defaultDevice, "UPtr", iid.ptr, "UInt", 23, "UPtr", 0, "UPtr*", &endpointVolume := 0)
        ObjRelease(defaultDevice)
        
        if (!endpointVolume)
            return false
            
        isMutedVal := 0
        ComCall(15, endpointVolume, "Int*", &isMutedVal := 0)
        ObjRelease(endpointVolume)
        return isMutedVal
    } catch {
        return false
    }
}

SetDefaultMicMuteFallback(muteState) {
    try {
        deviceEnumerator := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
        if (!deviceEnumerator)
            return
            
        iid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "WStr", "{5CDF2C82-841E-4546-9722-0CF74078229A}", "UPtr", iid.ptr)
        
        for role in [0, 2] {
            defaultDevice := 0
            hr := ComCall(4, deviceEnumerator, "Int", 1, "Int", role, "UPtr*", &defaultDevice := 0)
            if (hr == 0 && defaultDevice) {
                endpointVolume := 0
                ComCall(3, defaultDevice, "UPtr", iid.ptr, "UInt", 23, "UPtr", 0, "UPtr*", &endpointVolume := 0)
                ObjRelease(defaultDevice)
                
                if (endpointVolume) {
                    ComCall(14, endpointVolume, "Int", muteState, "UPtr", 0)
                    ObjRelease(endpointVolume)
                }
            }
        }
    } catch {
        ; Ignore
    }
}

UpdateMicState() {
    global isMuted, showOSD
    
    ; Find the top-right corner of primary screen
    MonitorGetWorkArea(, &MonLeft, &MonTop, &MonRight, &MonBottom)
    xPos := MonRight - 140
    yPos := MonTop + 10
    
    if (isMuted) {
        ; --- MIC IS OFF (MUTED/BACKUP MIC) ---
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
        ; --- MIC IS LIVE (ACTIVE/PRIMARY MIC) ---
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
