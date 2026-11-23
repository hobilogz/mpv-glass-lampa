-- bring-to-front.lua
-- Fix for MPV launched from Lampa / background:
-- 1. Forces WS_EX_APPWINDOW extended style so the window always appears in the Windows Taskbar.
-- 2. Bypasses Windows LockSetForegroundWindow policy to pop MPV in front of Lampa and steal focus.

local ffi = require("ffi")

ffi.cdef[[
    typedef void* HWND;
    typedef void* HANDLE;
    typedef int BOOL;
    typedef unsigned long DWORD;
    typedef intptr_t LONG_PTR;
    typedef unsigned int UINT;
    typedef unsigned char BYTE;

    HWND GetAncestor(HWND hWnd, UINT gaFlags);
    HWND GetParent(HWND hWnd);
    HWND GetForegroundWindow(void);
    DWORD GetWindowThreadProcessId(HWND hWnd, DWORD* lpdwProcessId);
    DWORD GetCurrentThreadId(void);
    BOOL AttachThreadInput(DWORD idAttach, DWORD idAttachTo, BOOL fAttach);
    LONG_PTR GetWindowLongPtrW(HWND hWnd, int nIndex);
    LONG_PTR SetWindowLongPtrW(HWND hWnd, int nIndex, LONG_PTR dwNewLong);
    BOOL SetWindowPos(HWND hWnd, HWND hWndInsertAfter, int X, int Y, int cx, int cy, UINT uFlags);
    BOOL ShowWindow(HWND hWnd, int nCmdShow);
    BOOL SetForegroundWindow(HWND hWnd);
    BOOL BringWindowToTop(HWND hWnd);
    void SwitchToThisWindow(HWND hWnd, BOOL fAltTab);
    void keybd_event(BYTE bVk, BYTE bScan, DWORD dwFlags, DWORD dwExtraInfo);
]]

local user32 = ffi.load("user32")
local kernel32 = ffi.load("kernel32")

local GA_ROOT = 2
local GA_ROOTOWNER = 3
local GWL_EXSTYLE = -20
local WS_EX_APPWINDOW = 0x00040000
local WS_EX_TOOLWINDOW = 0x00000080
local SWP_NOSIZE = 0x0001
local SWP_NOMOVE = 0x0002
local SWP_FRAMECHANGED = 0x0020
local SWP_SHOWWINDOW = 0x0040
local HWND_TOP = ffi.cast("HWND", 0)
local HWND_TOPMOST = ffi.cast("HWND", -1)
local HWND_NOTOPMOST = ffi.cast("HWND", -2)
local VK_MENU = 0x12
local KEYEVENTF_KEYUP = 0x0002

local function apply_bring_to_front()
    local wid = mp.get_property_number("window-id")
    if not wid or wid <= 0 then return end

    local hwnd = ffi.cast("HWND", wid)
    local root = user32.GetAncestor(hwnd, GA_ROOT)
    if root == nil or root == ffi.cast("HWND", 0) then
        root = hwnd
    end

    local targets = { hwnd }
    if root ~= hwnd then
        table.insert(targets, root)
    end

    -- 1. Ensure Taskbar icon is visible (WS_EX_APPWINDOW, strip WS_EX_TOOLWINDOW)
    for _, target in ipairs(targets) do
        local exStyle = tonumber(user32.GetWindowLongPtrW(target, GWL_EXSTYLE))
        if exStyle then
            local newExStyle = bit.bor(bit.band(exStyle, bit.bnot(WS_EX_TOOLWINDOW)), WS_EX_APPWINDOW)
            if newExStyle ~= exStyle then
                user32.SetWindowLongPtrW(target, GWL_EXSTYLE, ffi.cast("LONG_PTR", newExStyle))
                user32.SetWindowPos(target, HWND_TOP, 0, 0, 0, 0, bit.bor(SWP_NOMOVE, SWP_NOSIZE, SWP_FRAMECHANGED, SWP_SHOWWINDOW))
            end
        end
    end

    -- 2. Steal Foreground Focus from background / Lampa
    local fg_wnd = user32.GetForegroundWindow()
    local fg_thread = user32.GetWindowThreadProcessId(fg_wnd, nil)
    local cur_thread = kernel32.GetCurrentThreadId()

    if fg_thread ~= cur_thread and fg_thread ~= 0 then
        user32.AttachThreadInput(cur_thread, fg_thread, 1)
    end

    -- Simulate Alt tap to clear foreground lockout timer
    user32.keybd_event(VK_MENU, 0, 0, 0)
    user32.keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0)

    -- Bring window to front
    user32.SetWindowPos(root, HWND_TOPMOST, 0, 0, 0, 0, bit.bor(SWP_NOMOVE, SWP_NOSIZE, SWP_SHOWWINDOW))
    user32.BringWindowToTop(root)
    user32.SetForegroundWindow(root)
    user32.SwitchToThisWindow(root, 1)

    -- Revert topmost if ontop is not explicitly set in mpv
    local ontop = mp.get_property_bool("ontop", false)
    if not ontop then
        user32.SetWindowPos(root, HWND_NOTOPMOST, 0, 0, 0, 0, bit.bor(SWP_NOMOVE, SWP_NOSIZE, SWP_SHOWWINDOW))
    end

    if fg_thread ~= cur_thread and fg_thread ~= 0 then
        user32.AttachThreadInput(cur_thread, fg_thread, 0)
    end
end

mp.observe_property("window-id", "number", function(name, val)
    if val and val > 0 then
        apply_bring_to_front()
        mp.add_timeout(0.1, apply_bring_to_front)
        mp.add_timeout(0.3, apply_bring_to_front)
        mp.add_timeout(0.8, apply_bring_to_front)
    end
end)

mp.register_event("file-loaded", function()
    apply_bring_to_front()
end)
