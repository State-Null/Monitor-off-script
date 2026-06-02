#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook  ; Force keyboard hook to prevent other applications from hijacking hotkeys

; Force the script to run as Administrator.
; This is critical to capture keyboard shortcuts (like F23/F24) and manage device states when AVD is active.
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
global targetMicID := ""
global isMuted := false

; --- INITIALIZE MIC STATE ---
InitializeMicDevice()

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
; Press F23 to toggle physical microphone device state (disabling/enabling the PnP endpoint)
F23::
{
    global isMuted, targetMicID
    if (targetMicID = "") {
        MsgBox("No target microphone device initialized.", "Mute Script Error", "Iconx")
        return
    }
    
    isMuted := !isMuted
    if (isMuted) {
        ; Disable device (Status becomes "Error" / Disabled)
        cmdDisable := 'powershell.exe -NoProfile -Command "Disable-PnpDevice -InstanceId `'foo`' -Confirm:$false"'
        cmdDisable := StrReplace(cmdDisable, "foo", targetMicID)
        Run(cmdDisable,, "Hide")
    } else {
        ; Enable device (Status becomes "OK")
        cmdEnable := 'powershell.exe -NoProfile -Command "Enable-PnpDevice -InstanceId `'foo`' -Confirm:$false"'
        cmdEnable := StrReplace(cmdEnable, "foo", targetMicID)
        Run(cmdEnable,, "Hide")
    }
    
    UpdateMicState()
}

; --- FUNCTIONS ---
InitializeMicDevice() {
    global targetMicID, isMuted
    try {
        deviceEnumerator := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
        
        defaultDevice := 0
        ; Try eCommunications (2) first, fall back to eConsole (0)
        hr := ComCall(4, deviceEnumerator, "Int", 1, "Int", 2, "UPtr*", &defaultDevice := 0)
        if (hr != 0 || !defaultDevice) {
            hr := ComCall(4, deviceEnumerator, "Int", 1, "Int", 0, "UPtr*", &defaultDevice := 0)
        }
        
        if (defaultDevice) {
            pstrId := 0
            hr2 := ComCall(5, defaultDevice, "UPtr*", &pstrId := 0)
            if (hr2 == 0 && pstrId) {
                strId := StrGet(pstrId, "UTF-16")
                targetMicID := "SWD\MMDEVAPI\" . strId
                DllCall("ole32\CoTaskMemFree", "UPtr", pstrId)
            }
            ObjRelease(defaultDevice)
        }
    } catch {
        ; Fallback / Silent Ignore if COM fails
    }
    
    if (targetMicID = "") {
        return
    }
    
    ; Query current status from PowerShell to sync state
    try {
        shell := ComObject("WScript.Shell")
        cmdCheck := 'powershell.exe -NoProfile -Command "(Get-PnpDevice -InstanceId `'foo`').Status"'
        cmdCheck := StrReplace(cmdCheck, "foo", targetMicID)
        exec := shell.Exec(cmdCheck)
        status := Trim(exec.StdOut.ReadAll())
        
        ; If status is not OK (e.g. "Error" or "Disabled"), set initial state to muted
        isMuted := (status != "OK")
    } catch {
        isMuted := false
    }
}

UpdateMicState() {
    global isMuted, showOSD
    
    ; Find the top-right corner of primary screen
    MonitorGetWorkArea(, &MonLeft, &MonTop, &MonRight, &MonBottom)
    xPos := MonRight - 140
    yPos := MonTop + 10
    
    if (isMuted) {
        ; --- MIC IS OFF (DISABLED) ---
        ; 1. Update Tray Icon to Red X Circle
        TraySetIcon("shell32.dll", 132)
        A_IconTip := "Mic is OFF (Disabled)"
        
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
        ; --- MIC IS LIVE (ENABLED) ---
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
