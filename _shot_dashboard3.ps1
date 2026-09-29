# Chup dashboard Render THAT - ban chac chan (deterministic).
#   powershell -ExecutionPolicy Bypass -File _shot_dashboard3.ps1
#
# Khac ban cu: CHI chup khi tieu de cua so Chrome chua dung ten service
# "day12-agent" (tuc la trang service da load xong) VA cua so do dang o
# tien (GetForegroundWindow == hwnd). Neu khong dat, khong ghi file.
$ErrorActionPreference = "Continue"

$url   = "https://dashboard.render.com/web/srv-datjb6hsrm7s738uhmvg"
$need  = "day12-agent"
$out   = Join-Path $PSScriptRoot "screenshots\dashboard.png"
$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chrome)) {
    $chrome = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class W4 {
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int n);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();

    public static List<string> List() {
        List<string> o = new List<string>();
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            if (!IsWindowVisible(h)) return true;
            StringBuilder sb = new StringBuilder(1024);
            GetWindowTextW(h, sb, 1024);
            string t = sb.ToString();
            if (t.Length == 0) return true;
            uint pid; GetWindowThreadProcessId(h, out pid);
            o.Add(h.ToInt64().ToString() + "|" + pid.ToString() + "|" + t);
            return true;
        }, IntPtr.Zero);
        return o;
    }

    public static bool ForceForeground(IntPtr h) {
        ShowWindow(h, 3);
        IntPtr fgw = GetForegroundWindow();
        uint dummy = 0, myThread = GetCurrentThreadId();
        uint fgThread = GetWindowThreadProcessId(fgw, out dummy);
        uint tgtThread = GetWindowThreadProcessId(h, out dummy);
        if (fgThread != myThread) AttachThreadInput(fgThread, myThread, true);
        if (tgtThread != myThread) AttachThreadInput(tgtThread, myThread, true);
        BringWindowToTop(h);
        bool ok = SetForegroundWindow(h);
        if (tgtThread != myThread) AttachThreadInput(tgtThread, myThread, false);
        if (fgThread != myThread) AttachThreadInput(fgThread, myThread, false);
        return ok;
    }

    public static long Foreground() { return GetForegroundWindow().ToInt64(); }
}
'@

Write-Host "Mo service page..."
Start-Process -FilePath $chrome -ArgumentList "--new-window", $url
Start-Sleep -Seconds 20

$shot = $false
for ($i = 1; $i -le 20; $i++) {
    $cand = $null
    foreach ($w in [W4]::List()) {
        $p = $w -split '\|', 3
        if ($p.Count -lt 3) { continue }
        if ($p[2] -match 'Chrome' -and $p[2].ToLower().Contains($need.ToLower())) {
            $cand = @{ hwnd = [IntPtr][int64]$p[0]; pid = $p[1]; title = $p[2] }
            break
        }
    }
    if (-not $cand) {
        Write-Host ("[{0}] tieu de chua chua '{1}' - cho tiep..." -f $i, $need)
        Start-Sleep -Seconds 3
        continue
    }

    [W4]::ForceForeground($cand.hwnd) | Out-Null
    Start-Sleep -Milliseconds 900
    $fg = [W4]::Foreground()
    $match = ($fg -eq $cand.hwnd.ToInt64())
    Write-Host ("[{0}] pid={1} hwnd={2} fg={3} match={4}" -f $i, $cand.pid, $cand.hwnd.ToInt64(), $fg, $match)
    Write-Host ("    title={0}" -f $cand.title)

    if ($match) {
        # Chrome tro viec render cua so o hau canh -> phai dua len truoc,
        # roi moi cho du lau de dashboard tai xong (khong duoc chup skeleton).
        Start-Sleep -Seconds 25
        $fg2 = [W4]::Foreground()
        if ($fg2 -ne $cand.hwnd.ToInt64()) {
            Write-Host ("[{0}] mat foreground trong luc cho ({1}) - thu lai." -f $i, $fg2)
            Start-Sleep -Seconds 2
            continue
        }
        $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
        $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $bmp.Dispose()
        Write-Host ("DA CHUP -> {0}  ({1}x{2})" -f $out, $b.Width, $b.Height)
        Write-Host ("  bang chung: tieu de chua '{0}' + cua so dang o tien" -f $need)
        $shot = $true
        break
    }
    Start-Sleep -Seconds 2
}

if (-not $shot) { Write-Host "THAT BAI: khong xac minh duoc trang service. Khong ghi file nao." }
