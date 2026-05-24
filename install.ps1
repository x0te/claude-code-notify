#requires -version 5
[CmdletBinding()]
param(
    [switch]$SkipShortcuts
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "═══ Claude Notify 설치 ═══" -ForegroundColor Yellow
Write-Host "  위치: $ScriptDir" -ForegroundColor DarkGray
Write-Host ""

# === 1. toast-helper.exe 컴파일 ===
$helperExe = Join-Path $ScriptDir 'toast-helper.exe'
$helperSrc = Join-Path $ScriptDir 'src\toast-helper.cs'

if (-not (Test-Path $helperExe)) {
    if (Test-Path $helperSrc) {
        Write-Host "[1/5] toast-helper.exe 컴파일..." -ForegroundColor Cyan
        $winRoot = [System.Environment]::GetFolderPath('Windows')
        $csc = Join-Path $winRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
        if (-not (Test-Path $csc)) { $csc = Join-Path $winRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
        if (-not (Test-Path $csc)) { throw "csc.exe 찾을 수 없음. .NET Framework 4.x 필요" }

        $fw = Split-Path $csc -Parent
        $winmds = @(
            (Join-Path $winRoot 'System32\WinMetadata\Windows.UI.winmd'),
            (Join-Path $winRoot 'System32\WinMetadata\Windows.Data.winmd'),
            (Join-Path $winRoot 'System32\WinMetadata\Windows.Foundation.winmd')
        )
        $dlls = @(
            (Join-Path $fw 'mscorlib.dll'),
            (Join-Path $fw 'System.dll'),
            (Join-Path $fw 'System.Runtime.dll'),
            (Join-Path $fw 'System.Runtime.InteropServices.WindowsRuntime.dll'),
            (Join-Path $fw 'System.Runtime.WindowsRuntime.dll')
        )
        $cscArgs = @('/target:exe', "/out:$helperExe", '/nologo', '/platform:anycpu', '/nostdlib+')
        foreach ($r in @($dlls + $winmds)) { $cscArgs += "/reference:$r" }
        $cscArgs += $helperSrc

        & $csc @cscArgs 2>&1 | Out-Null
        if (Test-Path $helperExe) {
            Write-Host "      ✓ toast-helper.exe ($((Get-Item $helperExe).Length) bytes)" -ForegroundColor Green
        } else {
            Write-Host "      ✗ 컴파일 실패 — toast 클릭 활성화 동작 안 함" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[1/5] toast-helper.exe 소스 없음, 스킵" -ForegroundColor DarkGray
    }
} else {
    Write-Host "[1/5] toast-helper.exe 이미 존재" -ForegroundColor DarkGray
}

# === 2. notify-config.json 기본값 (이미 있으면 건드리지 않음) ===
$configPath = Join-Path $ScriptDir 'notify-config.json'
if (-not (Test-Path $configPath)) {
    Write-Host "[2/5] 기본 notify-config.json 생성..." -ForegroundColor Cyan
    $defCfg = @'
{
  "version": 3,
  "enabled": true,
  "app": {
    "name": "Claude Code",
    "icon": "✱",
    "appId": "ClaudeCode.Notify"
  },
  "notification": {
    "emoji": "💬",
    "text": "답변이 필요해요~",
    "melodyPreset": "doorbell",
    "customMelody": null,
    "showSummary": true,
    "playSound": true
  },
  "stop": {
    "emoji": "✨",
    "text": "작업이 완료됐어요!",
    "melodyPreset": "triumph",
    "customMelody": null,
    "showSummary": true,
    "playSound": true
  }
}
'@
    [System.IO.File]::WriteAllText($configPath, $defCfg, [System.Text.UTF8Encoding]::new($false))
    Write-Host "      ✓ notify-config.json" -ForegroundColor Green
} else {
    Write-Host "[2/5] notify-config.json 이미 존재 (유지)" -ForegroundColor DarkGray
}

# === 3. AppUserModelID 등록 + claude.ico ===
Write-Host "[3/5] AppID 등록 + Claude 아이콘 생성..." -ForegroundColor Cyan
$cfg = Get-Content $configPath -Raw -Encoding utf8 | ConvertFrom-Json
$appId = $cfg.app.appId
$reg = "HKCU:\Software\Classes\AppUserModelId\$appId"
if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }
Set-ItemProperty -Path $reg -Name 'DisplayName' -Value $cfg.app.name -Type String
Set-ItemProperty -Path $reg -Name 'IconBackgroundColor' -Value 'FF1F1814' -Type String

$iconsDir = Join-Path $ScriptDir 'icons'
if (-not (Test-Path $iconsDir)) { New-Item -ItemType Directory -Path $iconsDir -Force | Out-Null }
$claudeIco = Join-Path $iconsDir 'claude.ico'

# Claude ico를 emoji에서 생성 (코럴 ✱)
if (-not (Test-Path $claudeIco)) {
    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Drawing -ErrorAction SilentlyContinue
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $cfg.app.icon
    $tb.FontFamily = New-Object System.Windows.Media.FontFamily 'Segoe UI Emoji'
    $tb.FontSize = 50; $tb.Width = 64; $tb.Height = 64
    $tb.TextAlignment = [System.Windows.TextAlignment]::Center
    $tb.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(217,119,87))
    $tb.FontWeight = [System.Windows.FontWeights]::Bold
    $tb.Measure([System.Windows.Size]::new(64.0,64.0)); $tb.Arrange([System.Windows.Rect]::new(0,0,64.0,64.0)); $tb.UpdateLayout()
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap (64,64,96.0,96.0,[System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($tb)
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $ms = New-Object System.IO.MemoryStream; $enc.Save($ms); $png = $ms.ToArray(); $ms.Dispose()
    $fs = [System.IO.File]::Open($claudeIco, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter $fs
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)
    $bw.Write([byte]64); $bw.Write([byte]64); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$png.Length); $bw.Write([uint32]22)
    $bw.Write($png); $bw.Close(); $fs.Close()
}
Set-ItemProperty -Path $reg -Name 'IconUri' -Value $claudeIco -Type String
Write-Host "      ✓ AppID 등록 ($appId)" -ForegroundColor Green

# === 4. ~/.claude/settings.json에 훅 등록 ===
Write-Host "[4/5] Claude Code 훅 등록..." -ForegroundColor Cyan
$settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
$settingsDir = Split-Path $settingsPath -Parent
if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null }

$notifyPs1 = Join-Path $ScriptDir 'notify.ps1'
$cmdBase = "powershell -Sta -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$notifyPs1`""

$existing = $null
if (Test-Path $settingsPath) {
    try { $existing = Get-Content $settingsPath -Raw -Encoding utf8 | ConvertFrom-Json } catch { $existing = $null }
}
if (-not $existing) { $existing = [pscustomobject]@{} }

# hooks 객체 보장
if (-not $existing.PSObject.Properties.Match('hooks').Count) {
    $existing | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) -Force
}

$notifHook = [pscustomobject]@{
    hooks = @([pscustomobject]@{
        type = 'command'
        command = "$cmdBase -Type notification"
        async = $true
        timeout = 10
    })
}
$stopHook = [pscustomobject]@{
    hooks = @([pscustomobject]@{
        type = 'command'
        command = "$cmdBase -Type stop"
        async = $true
        timeout = 10
    })
}

$existing.hooks | Add-Member -NotePropertyName Notification -NotePropertyValue @($notifHook) -Force
$existing.hooks | Add-Member -NotePropertyName Stop -NotePropertyValue @($stopHook) -Force

$existing | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8
Write-Host "      ✓ Notification + Stop 훅 등록" -ForegroundColor Green

# === 5. 바로가기 ===
if (-not $SkipShortcuts) {
    Write-Host "[5/5] 바로가기 생성..." -ForegroundColor Cyan
    $customIco = Join-Path $iconsDir 'customizer.ico'
    if (-not (Test-Path $customIco)) {
        # 폴백: claude.ico 사용
        Copy-Item $claudeIco $customIco -ErrorAction SilentlyContinue
    }

    $wsh = New-Object -ComObject WScript.Shell
    $desktop = [Environment]::GetFolderPath('Desktop')

    foreach ($pair in @(
        @{ Name = 'Claude 알림 설정'; File = 'notify-customizer.ps1'; Desc = '알림 커스터마이저' }
        @{ Name = 'Claude 알람 테스트'; File = 'test-alarms.ps1'; Desc = '알람 테스트 메뉴' }
    )) {
        $lnk = Join-Path $desktop ($pair.Name + '.lnk')
        $sc = $wsh.CreateShortcut($lnk)
        $sc.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
        $sc.Arguments = "-Sta -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $ScriptDir $pair.File)`""
        $sc.WorkingDirectory = $ScriptDir
        $sc.IconLocation = $customIco
        $sc.Description = $pair.Desc
        $sc.WindowStyle = 7
        $sc.Save()
        Write-Host ("      ✓ " + $pair.Name) -ForegroundColor Green
    }
} else {
    Write-Host "[5/5] 바로가기 스킵 (-SkipShortcuts)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "✨ 설치 완료!" -ForegroundColor Green
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Yellow
Write-Host "  1. Claude Code에서 ` /hooks ` 입력 (훅 reload)"
Write-Host "  2. 데스크톱 '` Claude 알림 설정 `'에서 커스터마이즈"
Write-Host "  3. '` Claude 알람 테스트 `'로 다양한 알람 시나리오 확인"
Write-Host ""
