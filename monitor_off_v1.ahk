#NoEnv
#SingleInstance Force
#UseHook  ; Force keyboard hook to prevent other applications from hijacking hotkeys
SendMode Input
SetWorkingDir %A_ScriptDir%

; Force the script to run as Administrator.
; This is critical to capture keyboard shortcuts (like F23/F24) and manage device states when AVD is active.
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
targetMicID := ""
isMuted := false

; --- INITIALIZE MIC STATE ---
InitializeMicDevice()

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
; Press F23 to toggle physical microphone device state (disabling/enabling the PnP endpoint)
F23::
    if (targetMicID = "") {
        MsgBox, 16, Mute Script Error, No target microphone device initialized.
        return
    }
    
    isMuted := !isMuted
    if (isMuted) {
        ; Disable device (Status becomes "Error" / Disabled)
        cmdDisable := "powershell.exe -NoProfile -Command ""Disable-PnpDevice -InstanceId 'foo' -Confirm:$false"""
        cmdDisable := StrReplace(cmdDisable, "foo", targetMicID)
        Run, %cmdDisable%,, Hide
    } else {
        ; Enable device (Status becomes "OK")
        cmdEnable := "powershell.exe -NoProfile -Command ""Enable-PnpDevice -InstanceId 'foo' -Confirm:$false"""
        cmdEnable := StrReplace(cmdEnable, "foo", targetMicID)
        Run, %cmdEnable%,, Hide
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
        ; --- MIC IS OFF (DISABLED) ---
        ; 1. Update Tray Icon to Red X Circle
        Menu, Tray, Icon, shell32.dll, 132
        Menu, Tray, Tip, Mic is OFF (Disabled)
        
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
        ; --- MIC IS LIVE (ENABLED) ---
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

InitializeMicDevice() {
    global targetMicID, isMuted
    
    try {
        deviceEnumerator := ComObjCreate("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
        if (!deviceEnumerator)
            return
            
        defaultDevice := 0
        ; Try eCommunications (2) first, fall back to eConsole (0)
        hr := DllCall(NumGet(NumGet(deviceEnumerator+0)+4*A_PtrSize), "UPtr", deviceEnumerator, "Int", 1, "Int", 2, "UPtr*", defaultDevice)
        if (hr != 0 || !defaultDevice) {
            hr := DllCall(NumGet(NumGet(deviceEnumerator+0)+4*A_PtrSize), "UPtr", deviceEnumerator, "Int", 1, "Int", 0, "UPtr*", defaultDevice)
        }
        ObjRelease(deviceEnumerator)
        
        if (defaultDevice) {
            pstrId := 0
            hr2 := DllCall(NumGet(NumGet(defaultDevice+0)+5*A_PtrSize), "UPtr", defaultDevice, "UPtr*", pstrId)
            if (hr2 == 0 && pstrId) {
                strId := StrGet(pstrId, "UTF-16")
                targetMicID := "SWD\MMDEVAPI\" . strId
                DllCall("ole32\CoTaskMemFree", "UPtr", pstrId)
            }
            ObjRelease(defaultDevice)
        }
    } catch {
        ; Silent ignore COM failures
    }
    
    if (targetMicID = "")
        return
        
    ; Query current status from PowerShell to sync state
    try {
        shell := ComObjCreate("WScript.Shell")
        cmdCheck := "powershell.exe -NoProfile -Command ""(Get-PnpDevice -InstanceId 'foo').Status"""
        cmdCheck := StrReplace(cmdCheck, "foo", targetMicID)
        exec := shell.Exec(cmdCheck)
        status := exec.StdOut.ReadAll()
        
        ; Remove whitespace
        status := Trim(status)
        
        ; If status is not OK (e.g. "Error" or "Disabled"), set initial state to muted
        isMuted := (status != "OK")
    } catch {
        isMuted := false
    }
}
