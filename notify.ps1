[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('stop', 'notification')]
    [string]$Type
)

$ErrorActionPreference = 'SilentlyContinue'

# Paths
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir 'notify-config.json'
$IconsDir   = Join-Path $ScriptDir 'icons'
$LogPath    = Join-Path $ScriptDir 'notify.log'

function Write-Log {
    param([string]$Msg)
    try {
        $ts = Get-Date -Format 'HH:mm:ss.fff'
        Add-Content -Path $LogPath -Value "$ts [$Type] $Msg" -Encoding utf8
    } catch {}
}

$t0 = Get-Date
Write-Log "fired pid=$PID"

# ============================================================
# Defaults
# ============================================================
$Defaults = @{
    enabled = $true
    app = @{
        name  = 'Claude Code'
        icon  = '🤖'
        appId = 'ClaudeCode.Notify'
    }
    notification = @{
        emoji = '💬'; text = '답변이 필요해요~'; melodyPreset = 'doorbell'; customMelody = $null; showSummary = $true; playSound = $true
    }
    stop = @{
        emoji = '✨'; text = '작업이 완료됐어요!'; melodyPreset = 'triumph'; customMelody = $null; showSummary = $true; playSound = $true
    }
}

# ============================================================
# Melody presets (Notes + Waveform) — customizer와 동기화 필수
# ============================================================
$MelodyPresets = @{
    # --- Cute (sine) ---
    triumph        = @{ Wave='sine';     Notes=@(@(523,90), @(659,90), @(784,90), @(1047,180)) }
    doorbell       = @{ Wave='sine';     Notes=@(@(659,120), @(523,200), @(659,120), @(523,240)) }
    sparkle        = @{ Wave='sine';     Notes=@(@(784,80), @(988,80), @(1175,80), @(1568,180)) }
    chime          = @{ Wave='sine';     Notes=@(@(880,120), @(1047,120), @(1319,200)) }
    ping           = @{ Wave='sine';     Notes=@(@(659,100), @(784,200)) }
    twinkle        = @{ Wave='sine';     Notes=@(@(523,180), @(523,180), @(784,180), @(784,180)) }
    powerup        = @{ Wave='sine';     Notes=@(@(523,70), @(659,70), @(784,70), @(1047,70), @(1319,180)) }
    descend        = @{ Wave='sine';     Notes=@(@(784,120), @(659,120), @(523,240)) }
    single         = @{ Wave='sine';     Notes=@(@(800,300)) }
    soft           = @{ Wave='sine';     Notes=@(@(440,80), @(587,180)) }
    royal          = @{ Wave='sine';     Notes=@(@(523,150), @(659,150), @(784,150), @(659,150), @(1047,300)) }
    cute           = @{ Wave='sine';     Notes=@(@(880,80), @(1175,80), @(880,80), @(1318,160)) }

    # --- 8-bit / Classic Game SFX (square/triangle, 자체 신디사이즈) ---
    mario_coin     = @{ Wave='square';   Notes=@(@(988,80), @(1319,420)) }
    mario_1up      = @{ Wave='square';   Notes=@(@(659,125), @(784,125), @(1319,125), @(1047,125), @(1175,125), @(1568,280)) }
    mario_powerup  = @{ Wave='square';   Notes=@(@(523,60), @(784,80), @(523,60), @(1047,80), @(659,60), @(1319,80), @(880,100), @(1568,200)) }
    mario_jump     = @{ Wave='square';   Notes=@(@(523,40), @(659,40), @(784,40), @(988,40), @(1175,80)) }
    mario_pipe     = @{ Wave='square';   Notes=@(@(988,50), @(784,50), @(659,50), @(523,50), @(330,150)) }
    mario_clear    = @{ Wave='square';   Notes=@(@(659,100), @(784,100), @(880,100), @(988,250)) }
    zelda_secret   = @{ Wave='triangle'; Notes=@(@(587,160), @(880,160), @(740,160), @(587,160), @(659,160), @(988,160), @(1175,160), @(1568,400)) }
    zelda_item     = @{ Wave='triangle'; Notes=@(@(587,120), @(880,120), @(1175,120), @(1568,400)) }
    ff_victory     = @{ Wave='square';   Notes=@(@(659,150), @(659,150), @(659,150), @(659,400), @(523,200), @(587,200), @(659,200), @(587,200), @(659,500)) }
    sonic_ring     = @{ Wave='square';   Notes=@(@(1319,70), @(1976,200)) }
    pacman_eat     = @{ Wave='square';   Notes=@(@(440,50), @(587,50), @(440,50), @(587,50), @(440,50), @(587,120)) }
    tetris_clear   = @{ Wave='square';   Notes=@(@(880,60), @(988,60), @(1175,60), @(1319,250)) }
    pokemon_catch  = @{ Wave='square';   Notes=@(@(440,80), @(523,80), @(659,80), @(880,80), @(1047,300)) }
}

# ============================================================
# Stdin (훅 페이로드)
# ============================================================
$payload = $null; $transcriptPath = $null; $sessionId = $null
try {
    if ([Console]::IsInputRedirected) {
        $stdinText = [Console]::In.ReadToEnd()
        if ($stdinText) {
            $payload = $stdinText | ConvertFrom-Json -ErrorAction Stop
            if ($payload.session_id)      { $sessionId = "$($payload.session_id)" }
            if ($payload.transcript_path) { $transcriptPath = "$($payload.transcript_path)" }
        }
    }
} catch { Write-Log ("stdin err: " + $_.Exception.Message) }

# ============================================================
# Config 로드
# ============================================================
$config = $null
if (Test-Path $ConfigPath) {
    try { $config = Get-Content -Raw -Encoding utf8 $ConfigPath | ConvertFrom-Json -ErrorAction Stop }
    catch { Write-Log ("config err: " + $_.Exception.Message) }
}

$enabled = $true
if ($null -ne $config -and $null -ne $config.enabled) { $enabled = [bool]$config.enabled }
if (-not $enabled) { Write-Log "disabled"; exit 0 }

function Get-Setting {
    param([string]$Section, [string]$Key)
    if ($null -ne $config) {
        try {
            $val = $config.$Section.$Key
            if ($null -ne $val -and "$val" -ne '') { return $val }
        } catch {}
    }
    return $Defaults[$Section][$Key]
}
function Get-BoolSetting {
    param([string]$Section, [string]$Key)
    if ($null -ne $config) {
        try { $val = $config.$Section.$Key; if ($null -ne $val) { return [bool]$val } } catch {}
    }
    return [bool]$Defaults[$Section][$Key]
}

$appName  = Get-Setting -Section 'app' -Key 'name'
$appIcon  = Get-Setting -Section 'app' -Key 'icon'
$appId    = Get-Setting -Section 'app' -Key 'appId'

$emoji       = Get-Setting -Section $Type -Key 'emoji'
$text        = Get-Setting -Section $Type -Key 'text'
$presetName  = Get-Setting -Section $Type -Key 'melodyPreset'
$showSummary = Get-BoolSetting -Section $Type -Key 'showSummary'

# 멜로디 + 파형 결정
$melodyNotes = $null
$melodyWave  = 'sine'
$customMelody = $null
if ($null -ne $config) { try { $customMelody = $config.$Type.customMelody } catch {} }
if ($null -ne $customMelody -and $customMelody.Count -gt 0) {
    $melodyNotes = foreach ($note in $customMelody) { ,@([int]$note[0], [int]$note[1]) }
    $melodyWave  = 'square'
} elseif ($MelodyPresets.ContainsKey($presetName)) {
    $p = $MelodyPresets[$presetName]
    $melodyNotes = $p.Notes
    $melodyWave  = $p.Wave
} else {
    $melodyNotes = $MelodyPresets[$Defaults[$Type].melodyPreset].Notes
    $melodyWave  = $MelodyPresets[$Defaults[$Type].melodyPreset].Wave
}

# ============================================================
# AppUserModelID 등록 + 프로세스 ID 설정 (토스트 "Windows PowerShell" → "Claude Code")
# ============================================================
$appIcoPath = Join-Path $IconsDir 'claude.ico'
try {
    if (-not [string]::IsNullOrEmpty($appId)) {
        # 레지스트리 등록 (HKCU — admin 불필요)
        $regPath = "HKCU:\Software\Classes\AppUserModelId\$appId"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $regPath -Name 'DisplayName' -Value $appName -Type String -ErrorAction Stop
        if (Test-Path $appIcoPath) {
            Set-ItemProperty -Path $regPath -Name 'IconUri' -Value $appIcoPath -Type String -ErrorAction Stop
        }
        Set-ItemProperty -Path $regPath -Name 'IconBackgroundColor' -Value 'FFD97757' -Type String -ErrorAction Stop

        Add-Type -ErrorAction Stop -Namespace ClaudeNotify -Name AppIdSet -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("shell32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode)]
public static extern int SetCurrentProcessExplicitAppUserModelID([System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.LPWStr)] string AppID);
'@
        [void][ClaudeNotify.AppIdSet]::SetCurrentProcessExplicitAppUserModelID($appId)
    }
} catch { Write-Log ("appId err: " + $_.Exception.Message) }

# ============================================================
# WAV 생성 (파형 지원: sine/square/triangle/sawtooth)
# ============================================================
function New-MelodyWav {
    param([array]$Notes, [string]$Wave = 'sine', [int]$SampleRate = 22050)

    $ampScale = switch ($Wave) {
        'sine'     { 0.85 }
        'square'   { 0.42 }
        'triangle' { 0.95 }
        'sawtooth' { 0.55 }
        default    { 0.85 }
    }
    $amplitude = 32000 * $ampScale

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $ms
    $totalSamples = 0
    foreach ($n in $Notes) { $totalSamples += [int](($n[1] / 1000.0) * $SampleRate) }
    $dataSize = $totalSamples * 2

    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
    $bw.Write([uint32](36 + $dataSize))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('WAVE'))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('fmt '))
    $bw.Write([uint32]16); $bw.Write([uint16]1); $bw.Write([uint16]1)
    $bw.Write([uint32]$SampleRate); $bw.Write([uint32]($SampleRate * 2))
    $bw.Write([uint16]2); $bw.Write([uint16]16)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
    $bw.Write([uint32]$dataSize)

    foreach ($n in $Notes) {
        $freq = [double]$n[0]
        $dur  = [int](($n[1] / 1000.0) * $SampleRate)
        $fade = [Math]::Max(40, [int]($dur * 0.06))
        for ($i = 0; $i -lt $dur; $i++) {
            $env = 1.0
            if ($i -lt $fade) { $env = $i / [double]$fade }
            elseif ($i -gt ($dur - $fade)) { $env = ($dur - $i) / [double]$fade }
            $t = $i / [double]$SampleRate
            $phase = 2.0 * [Math]::PI * $freq * $t
            switch ($Wave) {
                'sine'     { $val = [Math]::Sin($phase) * 0.9 + [Math]::Sin($phase * 3) * 0.08 }
                'square'   { $val = if ([Math]::Sin($phase) -ge 0) { 0.9 } else { -0.9 } }
                'triangle' {
                    $c = ($freq * $t) % 1.0
                    if ($c -lt 0.5) { $val = ($c * 4.0 - 1.0) } else { $val = (3.0 - $c * 4.0) }
                }
                'sawtooth' {
                    $c = ($freq * $t) % 1.0
                    $val = ($c * 2.0 - 1.0)
                }
                default { $val = [Math]::Sin($phase) }
            }
            $sample = [int]($val * $amplitude * $env)
            if ($sample -gt 32767) { $sample = 32767 } elseif ($sample -lt -32768) { $sample = -32768 }
            $bw.Write([int16]$sample)
        }
    }
    $bw.Flush()
    $b = $ms.ToArray(); $ms.Dispose()
    return $b
}

# ============================================================
# 사운드 — 비동기 재생 (playSound 토글로 ON/OFF)
# ============================================================
$playSound = Get-BoolSetting -Section $Type -Key 'playSound'
$script:soundPlayer = $null
if ($playSound) {
    try {
        $wavBytes = New-MelodyWav -Notes $melodyNotes -Wave $melodyWave
        $msWav = New-Object System.IO.MemoryStream (,$wavBytes)
        $script:soundPlayer = New-Object System.Media.SoundPlayer
        $script:soundPlayer.Stream = $msWav
        $script:soundPlayer.LoadAsync()  # preload, don't play yet — 토스트 뜰 때 재생
        Write-Log ("sound prepared wave=" + $melodyWave)
    } catch {
        Write-Log ("wav err: " + $_.Exception.Message)
    }
} else {
    Write-Log "sound off"
}

# ============================================================
# 부모 터미널 hwnd — NtQueryInformationProcess (CIM보다 ~100배 빠름)
# ============================================================
Add-Type -ErrorAction SilentlyContinue -Namespace ClaudeNotify -Name PProc -MemberDefinition @'
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct PBI {
    public System.IntPtr R1;
    public System.IntPtr Peb;
    public System.IntPtr R20;
    public System.IntPtr R21;
    public System.IntPtr Pid;
    public System.IntPtr ParentPid;
}
[System.Runtime.InteropServices.DllImport("ntdll.dll")]
public static extern int NtQueryInformationProcess(System.IntPtr h, int c, ref PBI pbi, int size, ref int ret);
'@

function Get-ParentPid {
    param([int]$ProcessId)
    try {
        $proc = [System.Diagnostics.Process]::GetProcessById($ProcessId)
        $pbi = New-Object ClaudeNotify.PProc+PBI
        $ret = 0
        $size = [System.Runtime.InteropServices.Marshal]::SizeOf($pbi)
        $null = [ClaudeNotify.PProc]::NtQueryInformationProcess($proc.Handle, 0, [ref]$pbi, $size, [ref]$ret)
        return $pbi.ParentPid.ToInt32()
    } catch { return 0 }
}

function Find-TerminalHwnd {
    # 1. 부모 체인 walk — 가시 윈도우 찾기
    $p = $PID
    for ($i = 0; $i -lt 12; $i++) {
        $parentId = Get-ParentPid -ProcessId $p
        if ($parentId -le 4) { break }
        $parent = $null
        try { $parent = [System.Diagnostics.Process]::GetProcessById($parentId) } catch { break }
        if (-not $parent) { break }
        if ($parent.MainWindowHandle -ne [IntPtr]::Zero -and -not [string]::IsNullOrWhiteSpace($parent.MainWindowTitle)) {
            Write-Log ("hwnd via parent chain: " + $parent.ProcessName)
            return $parent.MainWindowHandle
        }
        $p = $parentId
    }

    # 2. 폴백: 가시 WindowsTerminal/conhost/wt/cmd 중 가장 최근 것
    try {
        $cands = Get-Process | Where-Object {
            $_.MainWindowHandle -ne [IntPtr]::Zero -and
            -not [string]::IsNullOrWhiteSpace($_.MainWindowTitle) -and
            ($_.ProcessName -eq 'WindowsTerminal' -or $_.ProcessName -eq 'conhost' -or $_.ProcessName -eq 'wt' -or $_.ProcessName -eq 'cmd')
        }
        if ($cands) {
            $best = $cands | Sort-Object -Property StartTime -Descending | Select-Object -First 1
            Write-Log ("hwnd via fallback: " + $best.ProcessName + " title=" + $best.MainWindowTitle.Substring(0, [Math]::Min(40, $best.MainWindowTitle.Length)))
            return $best.MainWindowHandle
        }
    } catch { Write-Log ("fallback hwnd err: " + $_.Exception.Message) }

    return [IntPtr]::Zero
}

$targetHwnd = Find-TerminalHwnd
Write-Log ("hwnd lookup +" + ((Get-Date) - $t0).TotalMilliseconds + "ms hwnd=" + $targetHwnd.ToInt64())

Add-Type -ErrorAction SilentlyContinue -Namespace ClaudeNotify -Name KeySender -MemberDefinition @'
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public System.IntPtr dwExtraInfo; }
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Explicit)]
public struct INPUT { [System.Runtime.InteropServices.FieldOffset(0)] public uint type; [System.Runtime.InteropServices.FieldOffset(8)] public KEYBDINPUT ki; }
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
public static extern uint SendInput(uint cInputs, INPUT[] pInputs, int cbSize);
public static void SendUnicodeChar(char c) {
    INPUT[] inputs = new INPUT[2];
    inputs[0].type = 1; inputs[0].ki.wScan = (ushort)c; inputs[0].ki.dwFlags = 0x0004;
    inputs[1].type = 1; inputs[1].ki.wScan = (ushort)c; inputs[1].ki.dwFlags = 0x0006;
    SendInput((uint)inputs.Length, inputs, System.Runtime.InteropServices.Marshal.SizeOf(typeof(INPUT)));
}
public static void SendVKey(ushort vk) {
    INPUT[] inputs = new INPUT[2];
    inputs[0].type = 1; inputs[0].ki.wVk = vk;
    inputs[1].type = 1; inputs[1].ki.wVk = vk; inputs[1].ki.dwFlags = 0x0002;
    SendInput((uint)inputs.Length, inputs, System.Runtime.InteropServices.Marshal.SizeOf(typeof(INPUT)));
}
'@

Add-Type -Namespace ClaudeNotify -Name Win32 -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetForegroundWindow(System.IntPtr hWnd);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool ShowWindowAsync(System.IntPtr hWnd, int nCmdShow);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool IsIconic(System.IntPtr hWnd);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern System.IntPtr GetForegroundWindow();
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint lpdwProcessId);
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern uint GetCurrentThreadId();
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool BringWindowToTop(System.IntPtr hWnd);
'@ -ErrorAction SilentlyContinue

function Focus-TargetWindow {
    param([IntPtr]$Hwnd)
    if ($Hwnd -eq [IntPtr]::Zero) { return }
    try {
        if ([ClaudeNotify.Win32]::IsIconic($Hwnd)) {
            [ClaudeNotify.Win32]::ShowWindowAsync($Hwnd, 9) | Out-Null
        }
        $fg = [ClaudeNotify.Win32]::GetForegroundWindow()
        $myTid = [ClaudeNotify.Win32]::GetCurrentThreadId()
        $dummy = [uint32]0
        $fgTid = [ClaudeNotify.Win32]::GetWindowThreadProcessId($fg, [ref]$dummy)
        $tgtTid = [ClaudeNotify.Win32]::GetWindowThreadProcessId($Hwnd, [ref]$dummy)
        $a1 = $false; $a2 = $false
        if ($fgTid -ne $myTid) { $a1 = [ClaudeNotify.Win32]::AttachThreadInput($fgTid, $myTid, $true) }
        if ($tgtTid -ne $myTid -and $tgtTid -ne $fgTid) { $a2 = [ClaudeNotify.Win32]::AttachThreadInput($tgtTid, $myTid, $true) }
        [ClaudeNotify.Win32]::BringWindowToTop($Hwnd) | Out-Null
        [ClaudeNotify.Win32]::SetForegroundWindow($Hwnd) | Out-Null
        if ($a1) { [ClaudeNotify.Win32]::AttachThreadInput($fgTid, $myTid, $false) | Out-Null }
        if ($a2) { [ClaudeNotify.Win32]::AttachThreadInput($tgtTid, $myTid, $false) | Out-Null }
    } catch {}
}

# ============================================================
# 토스트 슬롯 관리 (다중 알람 세로 스택)
# ============================================================
$ToastSlotsFile = Join-Path $env:TEMP 'claude-toast-slots.txt'

function Register-ToastSlot {
    # 등록 순서대로 PID만 append. 위치는 alive 필터 후 line 순서로 결정.
    try { Add-Content -Path $ToastSlotsFile -Value "$PID" -ErrorAction SilentlyContinue } catch {}
}

function Unregister-ToastSlot {
    if (-not (Test-Path $ToastSlotsFile)) { return }
    try {
        $lines = @(Get-Content $ToastSlotsFile -ErrorAction SilentlyContinue)
        $kept = @($lines | Where-Object { $_ -ne "$PID" })
        Set-Content -Path $ToastSlotsFile -Value $kept -ErrorAction SilentlyContinue
    } catch {}
}

function Get-MyToastPosition {
    # 살아있는 PID들 중 내 위치 (0 = 맨 아래, 1 = 그 위, ...)
    if (-not (Test-Path $ToastSlotsFile)) { return 0 }
    try {
        $lines = @(Get-Content $ToastSlotsFile -ErrorAction SilentlyContinue)
        $aliveIdx = 0
        foreach ($ln in $lines) {
            $linePid = 0
            if (-not [int]::TryParse($ln, [ref]$linePid)) { continue }
            if ($linePid -le 0) { continue }
            $alive = $false
            try { Get-Process -Id $linePid -ErrorAction Stop | Out-Null; $alive = $true } catch {}
            if (-not $alive) { continue }
            if ($linePid -eq $PID) { return $aliveIdx }
            $aliveIdx++
        }
    } catch {}
    return 0
}

# ============================================================
# 트랜스크립트 요약 / AskUserQuestion 감지
# ============================================================
function Get-AssistantSummary {
    param([string]$Path, [int]$MaxChars = 70)
    if (-not $Path -or -not (Test-Path $Path)) { return $null }
    try { $lines = @(Get-Content $Path -Tail 80 -Encoding utf8) } catch { return $null }
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $ln = $lines[$i]
        if ($ln -notmatch '"role"\s*:\s*"assistant"') { continue }
        try { $obj = $ln | ConvertFrom-Json -ErrorAction Stop } catch { continue }
        $msg = $obj.message
        if ($null -eq $msg -or $msg.role -ne 'assistant') { continue }
        $parts = @()
        foreach ($block in $msg.content) {
            if ($block.type -eq 'text' -and $block.text) { $parts += [string]$block.text }
        }
        if ($parts.Count -eq 0) { continue }
        $raw = ($parts -join ' ').Trim() -replace '`+', '' -replace '\*+', '' -replace '\s+', ' '
        if (-not $raw) { continue }
        if ($raw.Length -le $MaxChars) { return $raw }
        $cut = $raw.Substring(0, $MaxChars)
        $b = -1
        foreach ($ch in @('. ', '! ', '? ', '。', '？', '！', '요. ', '요! ', '요? ', '요~ ')) {
            $idx = $cut.LastIndexOf($ch)
            if ($idx -gt $b -and $idx -gt 20) { $b = $idx + $ch.Length - 1 }
        }
        if ($b -gt 0) { return $cut.Substring(0, $b).Trim() }
        return ($cut.TrimEnd() + '…')
    }
    return $null
}

function Get-PendingToolUse {
    # 마지막 assistant 메시지에 tool_use가 있고 그 후 tool_result가 없으면 (= Claude 대기 중)
    param([string]$Path)
    if (-not $Path -or -not (Test-Path $Path)) { return $null }
    try { $lines = @(Get-Content $Path -Tail 100 -Encoding utf8) } catch { return $null }
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $ln = $lines[$i]
        if ($ln -notmatch '"role"\s*:\s*"assistant"') { continue }
        try { $obj = $ln | ConvertFrom-Json -ErrorAction Stop } catch { continue }
        $msg = $obj.message
        if ($null -eq $msg -or $msg.role -ne 'assistant') { continue }
        $lastTool = $null
        foreach ($b in $msg.content) {
            if ($b.type -eq 'tool_use') { $lastTool = $b }
        }
        if (-not $lastTool) { return $null }
        $toolId = "$($lastTool.id)"
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            $futLn = $lines[$j]
            if ($futLn -match '"type"\s*:\s*"tool_result"' -or
                ($toolId -and $futLn -match ('"tool_use_id"\s*:\s*"' + [regex]::Escape($toolId) + '"'))) {
                return $null
            }
        }
        return $lastTool
    }
    return $null
}

# 트랜스크립트 flush 대기 — Claude가 최신 메시지 쓸 시간 확보
Start-Sleep -Milliseconds 800

$summary = $null
if ($showSummary) {
    $summary = Get-AssistantSummary -Path $transcriptPath -MaxChars 800
    if ($summary) { Write-Log ("summary: " + $summary.Substring(0, [Math]::Min(40, $summary.Length))) }
}

# 다중 인스턴스 — 프로젝트명
$projectLabel = $null
try {
    $cwd = (Get-Location).Path
    if ($cwd) {
        $leaf = Split-Path -Leaf $cwd
        if ($leaf -and $leaf -notmatch '^[A-Z]:\\?$') { $projectLabel = $leaf }
    }
} catch {}

Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

# ============================================================
# AskUserQuestion Picker (Notification + AskUserQuestion → 즉시 선택 UI)
# ============================================================
function Show-AskUserQuestionPicker {
    param([object]$AskInput, [IntPtr]$TargetHwnd, [string]$ProjectLabel, [string]$AppName)
    if (-not $AskInput) { return $false }
    $questions = $AskInput.questions
    if (-not $questions -or $questions.Count -eq 0) { return $false }
    $q = $questions[0]
    $options = $q.options
    if (-not $options -or $options.Count -eq 0) { return $false }
    if ($options.Count -gt 9) { Write-Log "picker: too many options"; return $false }

    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase -ErrorAction Stop

    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Claude · 빠른 선택" SizeToContent="Height" Width="520"
        Background="Transparent" WindowStyle="None" AllowsTransparency="True"
        ResizeMode="NoResize" WindowStartupLocation="CenterScreen"
        ShowInTaskbar="False" Topmost="True" FontFamily="Segoe UI" Foreground="#F4F4F8">
    <Border x:Name="PickerBorder" Background="#FAF6F0" CornerRadius="14" Padding="20" BorderBrush="#E0D5C8" BorderThickness="1" Cursor="Hand">
        <Border.Effect>
            <DropShadowEffect BlurRadius="24" Direction="270" ShadowDepth="6" Opacity="0.45" Color="Black"/>
        </Border.Effect>
        <StackPanel>
            <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                <TextBlock x:Name="HeaderEmoji" Text="🤖" FontSize="18" FontFamily="Segoe UI Emoji" Margin="0,0,8,0"/>
                <TextBlock x:Name="HeaderText" Text="Claude" FontSize="13" Foreground="#9D9DB0" VerticalAlignment="Center"/>
                <TextBlock Text=" · " Foreground="#C8BCAA" VerticalAlignment="Center" Margin="6,0"/>
                <TextBlock Text="빠른 선택" FontSize="11" Foreground="#D97757" VerticalAlignment="Center"/>
            </StackPanel>
            <TextBlock x:Name="QuestionText" FontSize="15" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,0,0,14"/>
            <StackPanel x:Name="OptionsPanel"/>
            <Grid Margin="0,12,0,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="버튼 누르면 터미널에 자동 입력 (숫자+Enter)" Foreground="#5F606F" FontSize="11" VerticalAlignment="Center"/>
                <Button Grid.Column="1" x:Name="OtherBtn" Content="✏️ 직접 입력" Background="#2C2D38" Foreground="#F4F4F8" BorderThickness="0" Padding="12,7" Margin="0,0,8,0" Cursor="Hand">
                    <Button.Template><ControlTemplate TargetType="Button"><Border Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border></ControlTemplate></Button.Template>
                </Button>
                <Button Grid.Column="2" x:Name="CancelBtn" Content="✕" Background="#2C2D38" Foreground="#F4F4F8" BorderThickness="0" Padding="10,7" Cursor="Hand">
                    <Button.Template><ControlTemplate TargetType="Button"><Border Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border></ControlTemplate></Button.Template>
                </Button>
            </Grid>
        </StackPanel>
    </Border>
</Window>
'@
    $pwin = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

    $headerName = if ($ProjectLabel) { "$AppName · $ProjectLabel" } else { $AppName }
    $pwin.FindName('HeaderText').Text = $headerName
    $pwin.FindName('HeaderEmoji').Text = (Get-Setting -Section 'app' -Key 'icon')
    $pwin.FindName('QuestionText').Text = "$($q.question)"
    $optPanel = $pwin.FindName('OptionsPanel')

    $script:_pickedIdx = $null; $script:_pickedOther = $false
    $accent = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(123, 97, 255))
    $cardBg = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(38, 39, 48))
    $sub    = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(150, 150, 170))
    $idx = 1
    foreach ($opt in $options) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Background = $cardBg
        $btn.BorderThickness = New-Object System.Windows.Thickness 0
        $btn.Padding = New-Object System.Windows.Thickness 14, 12, 14, 12
        $btn.Margin = New-Object System.Windows.Thickness 0, 0, 0, 8
        $btn.Cursor = [System.Windows.Input.Cursors]::Hand
        $btn.HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Stretch
        $btn.Template = [Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate TargetType="Button" xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
        <ContentPresenter HorizontalAlignment="Stretch" VerticalAlignment="Center"/>
    </Border>
    <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#3E3F52"/></Trigger>
    </ControlTemplate.Triggers>
</ControlTemplate>
'@)
        $grid = New-Object System.Windows.Controls.Grid
        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
        $c2 = New-Object System.Windows.Controls.ColumnDefinition
        $c2.Width = New-Object System.Windows.GridLength 1.0, ([System.Windows.GridUnitType]::Star)
        $grid.ColumnDefinitions.Add($c1) | Out-Null
        $grid.ColumnDefinitions.Add($c2) | Out-Null

        $numB = New-Object System.Windows.Controls.Border
        $numB.Background = $accent; $numB.CornerRadius = New-Object System.Windows.CornerRadius 6
        $numB.Width = 24; $numB.Height = 24
        $numB.Margin = New-Object System.Windows.Thickness 0, 0, 12, 0
        $numB.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
        $nt = New-Object System.Windows.Controls.TextBlock
        $nt.Text = "$idx"; $nt.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(255, 251, 245))
        $nt.FontWeight = [System.Windows.FontWeights]::Bold; $nt.FontSize = 12
        $nt.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $nt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $numB.Child = $nt
        [System.Windows.Controls.Grid]::SetColumn($numB, 0)
        $grid.Children.Add($numB) | Out-Null

        $stk = New-Object System.Windows.Controls.StackPanel
        $lt = New-Object System.Windows.Controls.TextBlock
        $lt.Text = "$($opt.label)"; $lt.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(47, 38, 32))
        $lt.FontSize = 13; $lt.FontWeight = [System.Windows.FontWeights]::SemiBold
        $lt.TextWrapping = [System.Windows.TextWrapping]::Wrap
        $stk.Children.Add($lt) | Out-Null
        if ($opt.description) {
            $dt = New-Object System.Windows.Controls.TextBlock
            $dt.Text = "$($opt.description)"; $dt.Foreground = $sub; $dt.FontSize = 11
            $dt.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $dt.Margin = New-Object System.Windows.Thickness 0, 3, 0, 0
            $stk.Children.Add($dt) | Out-Null
        }
        [System.Windows.Controls.Grid]::SetColumn($stk, 1)
        $grid.Children.Add($stk) | Out-Null

        $btn.Content = $grid
        $keyValue = if ($null -ne $opt.sendKey) { "$($opt.sendKey)" } else { "$idx" }
        $btn.Tag = $keyValue
        $btn.Add_Click({
            param($s, $e)
            $script:_pickedKey = "$($s.Tag)"
            $script:_pickedIdx = $true
            Write-Log ("picker btn click: key='" + $script:_pickedKey + "'")
            $pwin.DialogResult = $true
            $pwin.Close()
        })
        $optPanel.Children.Add($btn) | Out-Null
        $idx++
    }

    $pwin.FindName('OtherBtn').Add_Click({ $script:_pickedOther = $true; $pwin.DialogResult = $true; $pwin.Close() })
    $pwin.FindName('CancelBtn').Add_Click({ $pwin.DialogResult = $false; $pwin.Close() })
    $pwin.Add_KeyDown({ param($s,$e) if ($e.Key -eq [System.Windows.Input.Key]::Escape) { $pwin.DialogResult = $false; $pwin.Close() } })

    $result = $pwin.ShowDialog()
    if ($result -eq $true -and ($null -ne $script:_pickedIdx -or $script:_pickedOther)) {
        Focus-TargetWindow -Hwnd $TargetHwnd
        Start-Sleep -Milliseconds 250
        if ($script:_pickedOther) { Write-Log "picker: other (focus only)" }
        else {
            try {
                [System.Windows.Forms.SendKeys]::SendWait("$($script:_pickedIdx)")
                Start-Sleep -Milliseconds 100
                [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
                Write-Log ("SendKeys " + $script:_pickedIdx + "+ENTER")
            } catch { Write-Log ("SendKeys err: " + $_.Exception.Message) }
        }
        return $true
    }
    return $false
}

# ============================================================
# Toast (일반 케이스) — 파란 i 제거, 커스텀 앱 아이콘
# ============================================================
function Show-ModernToast {
    param([string]$AppId, [string]$Title, [string]$Body, [string]$IconPath, [IntPtr]$TargetHwnd)
    try {
        [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime]
        [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime]
    } catch {
        Write-Log ("WinRT load err: " + $_.Exception.Message)
        return $false
    }

    $imageTag = ''
    if ($IconPath -and (Test-Path $IconPath)) {
        $iconUri = 'file:///' + ($IconPath -replace '\\', '/')
        $imageTag = "<image placement=`"appLogoOverride`" hint-crop=`"circle`" src=`"$iconUri`"/>"
    }
    $tEsc = [System.Security.SecurityElement]::Escape($Title)
    $bodyLines = $Body -split "`n"
    $textTags = ($bodyLines | ForEach-Object { '<text>' + [System.Security.SecurityElement]::Escape($_) + '</text>' }) -join ''

    $xmlText = "<toast launch='action=focus' activationType='foreground' duration='short'><visual><binding template='ToastGeneric'>$imageTag<text>$tEsc</text>$textTags</binding></visual><audio silent='true'/></toast>"

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($xmlText)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml

    # Activated 이벤트 구독 — Register-ObjectEvent로 (WinRT TypedEventHandler 호환)
    $hasHandler = $false
    $script:_toastClicked = $false
    $subId = "ClaudeToastAct_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    try {
        $null = Register-ObjectEvent -InputObject $toast -EventName Activated -SourceIdentifier $subId -Action {
            Set-Variable -Name '_toastClicked' -Value $true -Scope Script
        } -ErrorAction Stop
        $hasHandler = $true
        Write-Log "toast event handler registered"
    } catch {
        Write-Log ("Register-ObjectEvent err: " + $_.Exception.Message)
    }

    try {
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)
        $notifier.Show($toast)
    } catch {
        Write-Log ("toast show err: " + $_.Exception.Message)
        return $false
    }

    if ($hasHandler) {
        $end = (Get-Date).AddSeconds(8)
        while ((Get-Date) -lt $end -and -not $script:_toastClicked) {
            Start-Sleep -Milliseconds 80
        }
        if ($script:_toastClicked) {
            Focus-TargetWindow -Hwnd $TargetHwnd
            Write-Log "toast clicked → focused terminal"
        }
        Unregister-Event -SourceIdentifier $subId -ErrorAction SilentlyContinue
    } else {
        Start-Sleep -Seconds 4
    }
    return $true
}

# 폴백: 구식 NotifyIcon BalloonTip (Modern Toast 실패 시)
function Show-FallbackToast {
    param([string]$Title, [string]$Body, [string]$IconPath, [IntPtr]$TargetHwnd)
    try {
        $ni = New-Object System.Windows.Forms.NotifyIcon
        $iconOK = $false
        if ($IconPath -and (Test-Path $IconPath)) {
            try { $ni.Icon = New-Object System.Drawing.Icon $IconPath; $iconOK = $true } catch {}
        }
        if (-not $iconOK -and (Test-Path $appIcoPath)) {
            try { $ni.Icon = New-Object System.Drawing.Icon $appIcoPath; $iconOK = $true } catch {}
        }
        if (-not $iconOK) { $ni.Icon = [System.Drawing.SystemIcons]::Information }
        $ni.BalloonTipTitle = $Title
        $ni.BalloonTipText  = $Body
        $ni.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]::None
        $ni.Text = $appName + $(if ($projectLabel) { " · $projectLabel" } else { '' })
        $ni.Visible = $true
        $script:_tClicked = $false
        $ni.add_BalloonTipClicked({ $script:_tClicked = $true; Focus-TargetWindow -Hwnd $TargetHwnd })
        $ni.add_Click({ $script:_tClicked = $true; Focus-TargetWindow -Hwnd $TargetHwnd })
        $ni.ShowBalloonTip(5000)
        $end = (Get-Date).AddSeconds(5)
        while ((Get-Date) -lt $end -and -not $script:_tClicked) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 50
        }
        $ni.Visible = $false; $ni.Dispose()
    } catch { Write-Log ("fallback toast err: " + $_.Exception.Message) }
}

function Show-WpfToast {
    param([string]$Title, [string]$Body, [IntPtr]$TargetHwnd, [int]$DurationSec = 10)

    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase -ErrorAction SilentlyContinue

    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Claude" SizeToContent="Height" Width="420"
        Background="Transparent" WindowStyle="None" AllowsTransparency="True"
        ResizeMode="NoResize" WindowStartupLocation="Manual"
        ShowInTaskbar="False" Topmost="True"
        FontFamily="Segoe UI" Foreground="#F4F4F8">
    <Border x:Name="MainBorder" Background="#FAF6F0" CornerRadius="14" Padding="16" BorderBrush="#E0D5C8" BorderThickness="1" Cursor="Hand">
        <Border.Effect>
            <DropShadowEffect BlurRadius="20" Direction="270" ShadowDepth="4" Opacity="0.55" Color="Black"/>
        </Border.Effect>
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="#F0E8DC" CornerRadius="10" Width="44" Height="44" Margin="0,0,12,0" VerticalAlignment="Top">
                <TextBlock x:Name="HeaderEmoji" Text="🤖" FontSize="24" FontFamily="Segoe UI Emoji" Foreground="#D97757" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                <TextBlock x:Name="HeaderText" Text="Claude Code" FontSize="12" Foreground="#D97757" FontWeight="SemiBold" Margin="0,0,0,3"/>
                <TextBlock x:Name="BodyText" FontSize="13" FontWeight="SemiBold" TextWrapping="Wrap" Foreground="#2F2620" Margin="0,0,0,2"/>
                <TextBlock x:Name="SubText" FontSize="11" TextWrapping="Wrap" Foreground="#8C7E70" Visibility="Collapsed" Margin="0,4,0,0"/>
            </StackPanel>
            <Button x:Name="CloseBtn" Grid.Column="2" Content="✕" Background="Transparent" Foreground="#B0A294" BorderThickness="0" Padding="6,2" Cursor="Hand" FontSize="11" VerticalAlignment="Top">
                <Button.Template><ControlTemplate TargetType="Button" xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><Border Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border></ControlTemplate></Button.Template>
            </Button>
        </Grid>
    </Border>
</Window>
'@
    $pwin = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

    $pwin.FindName('HeaderText').Text  = $Title
    $pwin.FindName('HeaderEmoji').Text = $appIcon

    # 본문에 줄바꿈 있으면 첫 줄 = BodyText, 나머지 = SubText
    $lines = $Body -split "`n", 2
    $pwin.FindName('BodyText').Text = $lines[0]
    if ($lines.Count -gt 1 -and $lines[1].Trim()) {
        $sub = $pwin.FindName('SubText')
        $sub.Text = $lines[1].Trim()
        $sub.Visibility = [System.Windows.Visibility]::Visible
    }

    $script:_toastClicked = $false
    $border = $pwin.FindName('MainBorder')
    $border.Add_MouseLeftButtonUp({ $script:_toastClicked = $true; $pwin.Close() })
    $pwin.FindName('CloseBtn').Add_Click({ $pwin.Close() })

    # 우하단 — 슬롯 등록 + 동적 위치
    Register-ToastSlot
    $pwin.Add_SourceInitialized({
        $wa = [System.Windows.SystemParameters]::WorkArea
        $h = $pwin.ActualHeight
        $myPos = Get-MyToastPosition
        $pwin.Left = $wa.Right - $pwin.ActualWidth - 16
        $pwin.Top  = $wa.Bottom - ($h + 12) * ($myPos + 1) - 4
    })

    # 위치 재계산 타이머 — 아래 토스트 닫히면 내려옴 (이징)
    $reposTimer = New-Object System.Windows.Threading.DispatcherTimer
    $reposTimer.Interval = [TimeSpan]::FromMilliseconds(80)
    $reposTimer.Add_Tick({
        try {
            $wa2 = [System.Windows.SystemParameters]::WorkArea
            $h2 = $pwin.ActualHeight
            $myPos2 = Get-MyToastPosition
            $targetTop = $wa2.Bottom - ($h2 + 12) * ($myPos2 + 1) - 4
            if ($pwin.Top -ne $targetTop) { $pwin.Top = $targetTop }
        } catch {}
    })
    $reposTimer.Start()

    # 자동 닫힘
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds($DurationSec)
    $timer.Add_Tick({ $timer.Stop(); $pwin.Close() })
    $timer.Start()

    # 사운드를 토스트 표시 직전에 재생 (UI와 동기)
    if ($script:soundPlayer) { try { $script:soundPlayer.Play() } catch {} }

    [void]$pwin.ShowDialog()
    $timer.Stop()
    $reposTimer.Stop()
    Unregister-ToastSlot

    if ($script:_toastClicked) {
        Focus-TargetWindow -Hwnd $TargetHwnd
        Write-Log "wpf toast clicked → focused"
    }
}

function Show-Toast {
    param([string]$Title, [string]$Body, [string]$IconPath, [IntPtr]$TargetHwnd)
    Show-WpfToast -Title $Title -Body $Body -TargetHwnd $TargetHwnd
}

# ============================================================
# 디스패치
# ============================================================
$pending = Get-PendingToolUse -Path $transcriptPath
if ($pending) { Write-Log ("pending: " + $pending.name) }

Write-Log ("dispatch +" + ((Get-Date) - $t0).TotalMilliseconds + "ms")

function Show-PickerToast {
    param([object]$AskInput, [IntPtr]$TargetHwnd)
    $questions = $AskInput.questions
    if (-not $questions -or $questions.Count -eq 0) { return $false }
    $q = $questions[0]
    $options = $q.options
    if (-not $options -or $options.Count -eq 0) { return $false }

    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase -ErrorAction SilentlyContinue

    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Claude · 빠른 선택" SizeToContent="Height" Width="420"
        Background="Transparent" WindowStyle="None" AllowsTransparency="True"
        ResizeMode="NoResize" WindowStartupLocation="Manual"
        ShowInTaskbar="False" Topmost="True"
        FontFamily="Segoe UI" Foreground="#F4F4F8">
    <Border x:Name="PickerBorder" Background="#FAF6F0" CornerRadius="14" Padding="16" BorderBrush="#E0D5C8" BorderThickness="1" Cursor="Hand">
        <Border.Effect>
            <DropShadowEffect BlurRadius="20" Direction="270" ShadowDepth="4" Opacity="0.55" Color="Black"/>
        </Border.Effect>
        <StackPanel>
            <Grid Margin="0,0,0,10">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock x:Name="HeaderEmoji" Grid.Column="0" Text="🤖" FontSize="16" FontFamily="Segoe UI Emoji" Foreground="#D97757" FontWeight="Bold" VerticalAlignment="Center" Margin="0,0,8,0"/>
                <TextBlock x:Name="HeaderText" Grid.Column="1" Text="Claude Code" FontSize="12" FontWeight="SemiBold" Foreground="#D97757" VerticalAlignment="Center"/>
                <Button x:Name="CancelBtn" Grid.Column="2" Content="✕" Background="Transparent" Foreground="#B0A294" BorderThickness="0" Padding="6,2" Cursor="Hand" FontSize="11">
                    <Button.Template><ControlTemplate TargetType="Button" xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><Border Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border></ControlTemplate></Button.Template>
                </Button>
            </Grid>
            <TextBlock x:Name="QuestionText" FontSize="13" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,0,0,12" Foreground="#2F2620"/>
            <StackPanel x:Name="OptionsPanel"/>
        </StackPanel>
    </Border>
</Window>
'@
    $pwin = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

    $headerName = "$appName" + $(if ($projectLabel) { " · $projectLabel" } else { '' })
    $pwin.FindName('HeaderText').Text = $headerName
    $pwin.FindName('HeaderEmoji').Text = $appIcon
    $pwin.FindName('QuestionText').Text = "$($q.question)"
    $optPanel = $pwin.FindName('OptionsPanel')

    $script:_pickedIdx = $null
    $accent = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(217, 119, 87))
    $cardBg = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(255, 251, 245))
    $sub    = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(140, 126, 112))

    $idx = 1
    foreach ($opt in $options) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Background = $cardBg
        $btn.BorderThickness = New-Object System.Windows.Thickness 0
        $btn.Padding = New-Object System.Windows.Thickness 12, 10, 12, 10
        $btn.Margin = New-Object System.Windows.Thickness 0, 0, 0, 6
        $btn.Cursor = [System.Windows.Input.Cursors]::Hand
        $btn.HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Stretch
        $btn.Template = [Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate TargetType="Button" xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
        <ContentPresenter HorizontalAlignment="Stretch" VerticalAlignment="Center"/>
    </Border>
    <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#F0E8DC"/></Trigger>
    </ControlTemplate.Triggers>
</ControlTemplate>
'@)

        $grid = New-Object System.Windows.Controls.Grid
        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
        $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = New-Object System.Windows.GridLength 1.0, ([System.Windows.GridUnitType]::Star)
        $grid.ColumnDefinitions.Add($c1) | Out-Null
        $grid.ColumnDefinitions.Add($c2) | Out-Null

        $numB = New-Object System.Windows.Controls.Border
        $numB.Background = $accent; $numB.CornerRadius = New-Object System.Windows.CornerRadius 5
        $numB.Width = 22; $numB.Height = 22
        $numB.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
        $numB.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
        $nt = New-Object System.Windows.Controls.TextBlock
        $nt.Text = "$idx"; $nt.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(255, 251, 245))
        $nt.FontWeight = [System.Windows.FontWeights]::Bold; $nt.FontSize = 11
        $nt.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $nt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $numB.Child = $nt
        [System.Windows.Controls.Grid]::SetColumn($numB, 0)
        $grid.Children.Add($numB) | Out-Null

        $stk = New-Object System.Windows.Controls.StackPanel
        $lt = New-Object System.Windows.Controls.TextBlock
        $lt.Text = "$($opt.label)"; $lt.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(47, 38, 32))
        $lt.FontSize = 12; $lt.FontWeight = [System.Windows.FontWeights]::SemiBold
        $lt.TextWrapping = [System.Windows.TextWrapping]::Wrap
        $stk.Children.Add($lt) | Out-Null
        if ($opt.description) {
            $dt = New-Object System.Windows.Controls.TextBlock
            $dt.Text = "$($opt.description)"; $dt.Foreground = $sub; $dt.FontSize = 10
            $dt.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $dt.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0
            $stk.Children.Add($dt) | Out-Null
        }
        [System.Windows.Controls.Grid]::SetColumn($stk, 1)
        $grid.Children.Add($stk) | Out-Null

        $btn.Content = $grid
        $keyValue = if ($null -ne $opt.sendKey) { "$($opt.sendKey)" } else { "$idx" }
        $btn.Tag = $keyValue
        $btn.Add_Click({
            param($s, $e)
            $script:_pickedKey = "$($s.Tag)"
            $script:_pickedIdx = $true
            Write-Log ("picker btn click: key='" + $script:_pickedKey + "'")
            $pwin.DialogResult = $true
            $pwin.Close()
        })
        $optPanel.Children.Add($btn) | Out-Null
        $idx++
    }

    $pwin.FindName('CancelBtn').Add_Click({ $pwin.DialogResult = $false; $pwin.Close() })
    $pwin.Add_KeyDown({ param($s,$e) if ($e.Key -eq [System.Windows.Input.Key]::Escape) { $pwin.DialogResult = $false; $pwin.Close() } })

    # 배경(버튼 외 영역) 클릭 → 터미널 포커스 (OriginalSource가 버튼 안이면 무시)
    $script:_bgClicked = $false
    $pwin.FindName('PickerBorder').Add_MouseLeftButtonUp({
        param($s, $e)
        $src = $e.OriginalSource
        while ($null -ne $src) {
            if ($src -is [System.Windows.Controls.Button]) { return }
            if ($src -is [System.Windows.DependencyObject]) {
                $src = [System.Windows.Media.VisualTreeHelper]::GetParent($src)
            } else { break }
        }
        if ($null -eq $script:_pickedIdx) {
            $script:_bgClicked = $true
            $pwin.DialogResult = $false
            $pwin.Close()
        }
    })

    # 옵션 클릭 후 복귀할 이전 foreground 저장
    $prevFg = [IntPtr]::Zero
    try { $prevFg = [ClaudeNotify.Win32]::GetForegroundWindow() } catch {}

    # 우하단 — 슬롯 등록 + 동적 위치
    Register-ToastSlot
    $pwin.Add_SourceInitialized({
        $wa = [System.Windows.SystemParameters]::WorkArea
        $h = $pwin.ActualHeight
        $myPos = Get-MyToastPosition
        $pwin.Left = $wa.Right - $pwin.ActualWidth - 16
        $pwin.Top  = $wa.Bottom - ($h + 12) * ($myPos + 1) - 4
    })

    # 위치 재계산 타이머
    $reposTimer = New-Object System.Windows.Threading.DispatcherTimer
    $reposTimer.Interval = [TimeSpan]::FromMilliseconds(80)
    $reposTimer.Add_Tick({
        try {
            $wa2 = [System.Windows.SystemParameters]::WorkArea
            $h2 = $pwin.ActualHeight
            $myPos2 = Get-MyToastPosition
            $targetTop = $wa2.Bottom - ($h2 + 12) * ($myPos2 + 1) - 4
            if ($pwin.Top -ne $targetTop) { $pwin.Top = $targetTop }
        } catch {}
    })
    $reposTimer.Start()

    # 사운드 동기 재생
    if ($script:soundPlayer) { try { $script:soundPlayer.Play() } catch {} }

    $result = $pwin.ShowDialog()
    $reposTimer.Stop()
    Unregister-ToastSlot

    if ($null -ne $script:_pickedIdx) {
        $k = "$($script:_pickedKey)"
        if ($k -eq '__focus__') {
            # 직접 입력 — 터미널만 포커스 (키 전송 X, 복귀 X)
            Focus-TargetWindow -Hwnd $TargetHwnd
            Write-Log "picker → terminal focus only (custom input)"
            return $true
        }
        # 옵션 선택 → 터미널 포커스 + 입력 + 이전 창으로 복귀
        Focus-TargetWindow -Hwnd $TargetHwnd
        Start-Sleep -Milliseconds 250
        try {
            if ($k -eq '') {
                # Enter만
                [ClaudeNotify.KeySender]::SendVKey([uint16]0x0D)
                Write-Log "picker → Enter only"
            } elseif ($k -match '^\d+$') {
                # 옵션 번호 (AskUserQuestion 같은 UI) → 화살표 Down N-1번 + Enter
                $n = [int]$k - 1
                for ($z = 0; $z -lt $n; $z++) {
                    [ClaudeNotify.KeySender]::SendVKey([uint16]0x28)
                    Start-Sleep -Milliseconds 60
                }
                Start-Sleep -Milliseconds 120
                [ClaudeNotify.KeySender]::SendVKey([uint16]0x0D)
                Write-Log ("picker → Down x$n + Enter (idx=$k)")
            } else {
                # 문자 (y/n, 텍스트 등) — IME 우회 SendInput
                foreach ($ch in $k.ToCharArray()) {
                    [ClaudeNotify.KeySender]::SendUnicodeChar($ch)
                    Start-Sleep -Milliseconds 25
                }
                Start-Sleep -Milliseconds 80
                [ClaudeNotify.KeySender]::SendVKey([uint16]0x0D)
                Write-Log ("picker → chars '$k' + Enter")
            }
        } catch { Write-Log ("SendInput err: " + $_.Exception.Message) }
        if ($prevFg -ne [IntPtr]::Zero) {
            Start-Sleep -Milliseconds 100
            Focus-TargetWindow -Hwnd $prevFg
        }
        return $true
    } elseif ($script:_bgClicked) {
        # 배경 클릭 → 터미널로 영구 이동
        Focus-TargetWindow -Hwnd $TargetHwnd
        Write-Log "picker bg clicked → terminal focused"
        return $true
    }
    return $false
}

# Picker 제거 — 항상 토스트. pending tool_use는 본문에 이유로 표시
$pendingInfo = $null
if ($pending) {
    switch ($pending.name) {
        'AskUserQuestion' {
            $qFirst = "$($pending.input.questions[0].question)"
            $pendingInfo = "❓ 질문이 있어요`n$qFirst"
        }
        'ExitPlanMode' {
            $planPrev = "$($pending.input.plan)"
            if ($planPrev.Length -gt 300) { $planPrev = $planPrev.Substring(0,300) + '…' }
            $pendingInfo = "📋 Plan 검토 대기 중`n$planPrev"
        }
        'Bash' {
            $cmd = "$($pending.input.command)"
            if ($cmd.Length -gt 240) { $cmd = $cmd.Substring(0,240) + '…' }
            $pendingInfo = "🔐 Bash 실행 권한이 필요해요`n$cmd"
        }
        'Edit'         { $pendingInfo = "🔐 파일 수정 권한이 필요해요`n$($pending.input.file_path)" }
        'Write'        { $pendingInfo = "🔐 파일 생성 권한이 필요해요`n$($pending.input.file_path)" }
        'PowerShell'   { $cmd = "$($pending.input.command)"; if ($cmd.Length -gt 240) { $cmd = $cmd.Substring(0,240) + '…' }; $pendingInfo = "🔐 PowerShell 권한이 필요해요`n$cmd" }
        'WebFetch'     { $pendingInfo = "🔐 웹 페이지 접근 권한이 필요해요`n$($pending.input.url)" }
        'WebSearch'    { $pendingInfo = "🔐 웹 검색 권한이 필요해요`n$($pending.input.query)" }
        default {
            $pendingInfo = "🔐 권한이 필요해요`n$($pending.name) 사용 대기 중"
        }
    }
    Write-Log ("pending toast: " + $pending.name)
}

$title = $appName
if ($projectLabel) { $title = "$appName · $projectLabel" }
if ($pendingInfo) {
    $body = $pendingInfo
} else {
    $bodyMain = "$emoji  $text"
    $body = $bodyMain
    if ($summary) {
        $prefix = if ($Type -eq 'stop') { '📝' } else { '👉' }
        $body = "$bodyMain`n$prefix  $summary"
    }
}
$iconPath = Join-Path $IconsDir "$Type.ico"
Show-Toast -Title $title -Body $body -IconPath $iconPath -TargetHwnd $targetHwnd

# 사운드 마저 끝나도록 잠깐 대기 (이미 5초 토스트 끝나서 보통 충분)
if ($soundPlayer) {
    try { Start-Sleep -Milliseconds 200 } catch {}
}

Write-Log ("done +" + ((Get-Date) - $t0).TotalMilliseconds + "ms")
