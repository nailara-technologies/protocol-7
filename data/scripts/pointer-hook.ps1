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
    [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT pt);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string m);

    const int WH_MOUSE_LL = 14;
    const int WM_MOUSEMOVE = 0x0200;

    static IntPtr _hook;
    static IntPtr _modHandle;
    static LowLevelMouseProc _proc;  // static ref prevents GC during Run()

    static int _lastX    = int.MinValue;
    static int _lastY    = int.MinValue;
    static int _pendingX = int.MinValue;  // int.MinValue = nothing pending
    static int _pendingY;

    static IntPtr Callback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && (int)wParam == WM_MOUSEMOVE) {
            MSLLHOOKSTRUCT s = (MSLLHOOKSTRUCT)Marshal.PtrToStructure(
                lParam, typeof(MSLLHOOKSTRUCT));
            if (s.pt.x != _lastX || s.pt.y != _lastY) {
                _lastX    = s.pt.x;
                _lastY    = s.pt.y;
                _pendingX = s.pt.x;  // flush timer writes to stdout; never block here
                _pendingY = s.pt.y;
            }
        }
        return CallNextHookEx(_hook, nCode, wParam, lParam);
    }

    static IntPtr InstallHook() {
        return SetWindowsHookEx(WH_MOUSE_LL, _proc, _modHandle, 0);
    }

    static void SeedCurrentPos() {
        POINT pt;
        if (GetCursorPos(out pt)) {
            _lastX    = pt.x;
            _lastY    = pt.y;
            _pendingX = pt.x;
            _pendingY = pt.y;
        }
    }

    public static void Run() {
        _proc = Callback;
        using (Process proc = Process.GetCurrentProcess())
        using (ProcessModule mod = proc.MainModule)
            _modHandle = GetModuleHandle(mod.ModuleName);

        _hook = InstallHook();
        if (_hook == IntPtr.Zero) {
            Console.Error.WriteLine("pointer-hook: SetWindowsHookEx failed");
            return;
        }
        SeedCurrentPos();  // seed SHM immediately — don't wait for first move

        // flush timer : write latest pending coord at ~60fps from the UI thread
        // [ hook callback must never block on I/O : Windows silently removes any
        //   low-level hook whose callback exceeds LowLevelHooksTimeout (~300ms) ;
        //   decoupling the flush from the callback eliminates that risk entirely ]
        var flushTimer = new System.Windows.Forms.Timer();
        flushTimer.Interval = 16;
        flushTimer.Tick += (s, e) => {
            if (_pendingX != int.MinValue) {
                Console.WriteLine(_pendingX + " " + _pendingY);
                Console.Out.Flush();
                _pendingX = int.MinValue;
            }
        };
        flushTimer.Start();

        // keepalive : reinstall hook every 4s in case Windows silently removed it
        // [ happens during compositor-managed window drags when WSLg holds input
        //   capture and the message loop is briefly starved of pump time ;
        //   reinstalling from the UI thread is safe and cheap ]
        var keepalive = new System.Windows.Forms.Timer();
        keepalive.Interval = 4000;
        keepalive.Tick += (s, e) => {
            IntPtr newHook = InstallHook();
            if (newHook != IntPtr.Zero) {
                IntPtr old = _hook;
                _hook = newHook;
                if (old != IntPtr.Zero)
                    UnhookWindowsHookEx(old);
                SeedCurrentPos();  // re-seed position after hook reinstall
            } else {
                Console.Error.WriteLine("pointer-hook: keepalive rehook failed");
            }
        };
        keepalive.Start();

        Application.Run();

        flushTimer.Dispose();
        keepalive.Dispose();
        if (_hook != IntPtr.Zero)
            UnhookWindowsHookEx(_hook);
    }
}
'@ -ReferencedAssemblies 'System.Windows.Forms'

[PointerHook]::Run()
