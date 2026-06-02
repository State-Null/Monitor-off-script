# Microphone Mute Hotkey Setup Notes (F23)

These notes summarize the setup for adding a hardware-agnostic physical mute button toggle that works with Azure Virtual Desktop (AVD) using AutoHotkey and Corsair iCUE.

## The Problem
conferencing tools like Microsoft Teams running inside an AVD session struggle to sync with physical USB mute button lights/statuses unless they are Teams-certified and WebRTC media optimization is active.

## The Solution
Instead of syncing with the AVD session client directly, we mute/unmute the **default microphone input on the local home PC** at the system level. 
* This completely cuts off your high-end microphone audio before it reaches the AVD remote session.
* Visual indicators (tray icons and an on-screen overlay) run on the local home PC to let you know your real status at a glance.

---

## 1. Hotkey Map
* **F24:** Turns off local monitors (delaying 500ms first so keys can release).
* **F23:** Toggles the default microphone mute state on the home PC.

---

## 2. Visual Indicators Added
The script updates your local UI dynamically whenever **F23** is pressed:
1. **System Tray Icon (Shell32.dll):**
   * **Mic Live (On):** Green Check Circle (`shell32.dll, 144`)
   * **Mic Off (Muted):** Red X Circle (`shell32.dll, 132`)
2. **On-Screen Display (OSD) Overlay:**
   * A borderless, glassmorphic dark box in the top-right corner of the screen.
   * Stays visible showing **"MIC OFF"** (in red) persistently while muted.
   * Briefly flashes **"MIC LIVE"** (in green) and fades after 1 second when unmuted.
   * Fully **click-through** (`+E0x20`) so it doesn't block screen elements.

---

## 3. Configuration
At the top of the script, you can toggle the visual screen overlay:
```autohotkey
showOSD := true  ; Set to true to show the on-screen overlay, false to hide it
```
Set this to `false` to disable the visual overlay while keeping the dynamic system tray icons active.

---

## 4. Corsair iCUE / Nexus Setup
1. Open the Corsair iCUE software on your home PC.
2. Under your Corsair Nexus Touchscreen (or keyboard/mouse), bind a key/button to a **Keystroke Assignment**.
3. Record the key as **F23** (for mic mute) or **F24** (for monitor power off).
4. Tap the button to toggle your microphone and see the status change on your desktop.

---

## 5. Notepad++ AutoHotkey Setup
To get syntax highlighting for these scripts inside Notepad++:
1. Place `userDefineLang_AHK.xml` in `%AppData%\Notepad++\userDefineLangs\`.
2. Restart Notepad++ and select **AutoHotkey** from the **Language** menu.
