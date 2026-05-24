using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using Windows.UI.Notifications;
using Windows.Data.Xml.Dom;

class ToastHelper
{
    [DllImport("user32.dll")]
    static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")]
    static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", SetLastError = true)]
    static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("kernel32.dll")]
    static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")]
    static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")]
    static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")]
    static extern bool AllowSetForegroundWindow(int processId);

    static void ForceForeground(IntPtr hWnd)
    {
        try
        {
            if (IsIconic(hWnd)) ShowWindowAsync(hWnd, 9);

            IntPtr fg = GetForegroundWindow();
            uint myTid = GetCurrentThreadId();
            uint dummy;
            uint fgTid = GetWindowThreadProcessId(fg, out dummy);
            uint targetTid = GetWindowThreadProcessId(hWnd, out dummy);

            bool attached1 = false, attached2 = false;
            if (fgTid != myTid) attached1 = AttachThreadInput(fgTid, myTid, true);
            if (targetTid != myTid && targetTid != fgTid) attached2 = AttachThreadInput(targetTid, myTid, true);

            BringWindowToTop(hWnd);
            SetForegroundWindow(hWnd);

            if (attached1) AttachThreadInput(fgTid, myTid, false);
            if (attached2) AttachThreadInput(targetTid, myTid, false);
        }
        catch { }
    }

    static volatile bool clicked = false;
    static IntPtr targetHwnd = IntPtr.Zero;
    static string resultPath = null;

    static int Main(string[] args)
    {
        try
        {
            if (args.Length < 3)
            {
                Console.Error.WriteLine("Usage: toast-helper.exe <appId> <hwnd> <xmlPath> [resultPath]");
                return 2;
            }
            string appId = args[0];
            long hwndLong;
            if (!long.TryParse(args[1], out hwndLong))
            {
                Console.Error.WriteLine("Invalid hwnd");
                return 3;
            }
            targetHwnd = new IntPtr(hwndLong);
            if (args.Length >= 4) resultPath = args[3];

            string xmlText = File.ReadAllText(args[2]);

            XmlDocument xml = new XmlDocument();
            xml.LoadXml(xmlText);

            ToastNotification toast = new ToastNotification(xml);
            toast.Activated += OnActivated;
            toast.Dismissed += OnDismissed;
            toast.Failed += OnFailed;

            ToastNotificationManager.CreateToastNotifier(appId).Show(toast);

            DateTime end = DateTime.Now.AddSeconds(8);
            while (DateTime.Now < end && !clicked)
            {
                Thread.Sleep(80);
            }
            return clicked ? 0 : 1;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("err: " + ex.Message);
            return 4;
        }
    }

    static void OnActivated(ToastNotification sender, object args)
    {
        var tea = args as Windows.UI.Notifications.ToastActivatedEventArgs;
        string arg = tea == null ? "" : (tea.Arguments ?? "");
        Console.Error.WriteLine("ACTIVATED at " + DateTime.Now.ToString("HH:mm:ss.fff") + " arguments=[" + arg + "]");
        clicked = true;
        if (resultPath != null)
        {
            try { File.WriteAllText(resultPath, arg); }
            catch (Exception ex) { Console.Error.WriteLine("resultPath write err: " + ex.Message); }
        }
        if (targetHwnd != IntPtr.Zero)
        {
            ForceForeground(targetHwnd);
        }
    }

    static void OnDismissed(ToastNotification sender, ToastDismissedEventArgs args)
    {
        Console.Error.WriteLine("DISMISSED at " + DateTime.Now.ToString("HH:mm:ss.fff") + " reason=" + args.Reason);
    }

    static void OnFailed(ToastNotification sender, ToastFailedEventArgs args)
    {
        Console.Error.WriteLine("FAILED at " + DateTime.Now.ToString("HH:mm:ss.fff") + " err=0x" + args.ErrorCode.HResult.ToString("X"));
    }
}
