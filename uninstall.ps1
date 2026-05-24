#requires -version 5
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

Write-Host ""
Write-Host "═══ Claude Notify 제거 ═══" -ForegroundColor Yellow
Write-Host ""

# 훅 제거
$settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
if (Test-Path $settingsPath) {
    try {
        $s = Get-Content $settingsPath -Raw -Encoding utf8 | ConvertFrom-Json
        if ($s.hooks) {
            $s.hooks.PSObject.Properties.Remove('Notification') | Out-Null
            $s.hooks.PSObject.Properties.Remove('Stop') | Out-Null
        }
        $s | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8
        Write-Host "✓ Claude Code 훅 제거" -ForegroundColor Green
    } catch {
        Write-Host "! settings.json 처리 실패: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 레지스트리
$reg = 'HKCU:\Software\Classes\AppUserModelId\ClaudeCode.Notify'
if (Test-Path $reg) {
    Remove-Item -Path $reg -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✓ AppUserModelID 레지스트리 제거" -ForegroundColor Green
}

# 바로가기
$desktop = [Environment]::GetFolderPath('Desktop')
foreach ($name in @('Claude 알림 설정.lnk', 'Claude 알람 테스트.lnk')) {
    $lnk = Join-Path $desktop $name
    if (Test-Path $lnk) {
        Remove-Item $lnk -Force -ErrorAction SilentlyContinue
        Write-Host "✓ 바로가기 제거: $name" -ForegroundColor Green
    }
}
$startMenu = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
foreach ($name in @('Claude 알림 설정.lnk', 'Claude 알람 테스트.lnk')) {
    $lnk = Join-Path $startMenu $name
    if (Test-Path $lnk) {
        Remove-Item $lnk -Force -ErrorAction SilentlyContinue
        Write-Host "✓ 시작메뉴 바로가기 제거: $name" -ForegroundColor Green
    }
}

# 슬롯/로그 파일
Remove-Item "$env:TEMP\claude-toast-slots.txt" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\claude-toast-*.xml" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\claude-result-*.txt" -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "✨ 제거 완료. 클론 폴더는 수동으로 삭제해주세요." -ForegroundColor Green
Write-Host "   Claude Code에서 /hooks 입력해 훅 reload 부탁드려요." -ForegroundColor Yellow
Write-Host ""
