# pointer-hook.ps1 - global mouse position via WH_MOUSE_LL hook
# outputs "X Y" on stdout only when position changes; event-driven, no polling

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Diagnostics;

public class PointerHook {
    [StructLayout(LayoutKind.Sequential)]
    struct POINT { public int x; public int y; }

    [StructLayout(LayoutKind.Sequential)]
    struct MSLLHOOKSTRUCT {
        public POINT pt;
        public uint mouseData, flags, time;
        public IntPtr dwExtraInfo;
    }

    delegate IntPtr LowLevelMouseProc(int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(
        int id, LowLevelMouseProc fn, IntPtr hMod, uint tid);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(
        IntPtr h, int n, IntPtr w, IntPtr l);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string m);

    const int WH_MOUSE_LL = 14;
    const int WM_MOUSEMOVE = 0x0200;

    static IntPtr _hook;
    static LowLevelMouseProc _proc;  // static ref prevents GC during Run()
    static int _lastX = int.MinValue, _lastY = int.MinValue;

    static IntPtr Callback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && (int)wParam == WM_MOUSEMOVE) {
            MSLLHOOKSTRUCT s = (MSLLHOOKSTRUCT)Marshal.PtrToStructure(
                lParam, typeof(MSLLHOOKSTRUCT));
            if (s.pt.x != _lastX || s.pt.y != _lastY) {
                _lastX = s.pt.x;
                _lastY = s.pt.y;
                Console.WriteLine(s.pt.x + " " + s.pt.y);
                Console.Out.Flush();
            }
        }
        return CallNextHookEx(_hook, nCode, wParam, lParam);
    }

    public static void Run() {
        _proc = Callback;
        using (Process proc = Process.GetCurrentProcess())
        using (ProcessModule mod = proc.MainModule)
            _hook = SetWindowsHookEx(WH_MOUSE_LL, _proc,
                GetModuleHandle(mod.ModuleName), 0);
        if (_hook == IntPtr.Zero) {
            Console.Error.WriteLine("pointer-hook: SetWindowsHookEx failed");
            return;
        }
        Application.Run();
        UnhookWindowsHookEx(_hook);
    }
}
'@ -ReferencedAssemblies 'System.Windows.Forms'

[PointerHook]::Run()
