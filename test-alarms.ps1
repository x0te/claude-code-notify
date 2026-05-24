#requires -version 5
[CmdletBinding()]
param()

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$NotifyPs1 = Join-Path $ScriptDir 'notify.ps1'

function Get-LatestTranscript {
    $tx = Get-ChildItem "$env:USERPROFILE\.claude\projects" -Recurse -Filter '*.jsonl' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($tx) { return $tx.FullName }
    return $null
}

function Make-Transcript {
    param([string]$Content)
    $tmp = "$env:TEMP\test-alarm-$([Guid]::NewGuid().ToString('N').Substring(0,8)).jsonl"
    Set-Content -Path $tmp -Value $Content -Encoding utf8
    return $tmp
}

function Make-AskUserQuestion {
    param([int]$OptionCount, [string]$QuestionText, [bool]$IncludeDesc = $true)
    $opts = @()
    for ($i = 1; $i -le $OptionCount; $i++) {
        $o = @{ label = "옵션 $i" }
        if ($IncludeDesc) { $o.description = "이 선택지의 설명입니다 (옵션 $i — 키 $i 입력)" }
        $opts += $o
    }
    $q = @{ questions = @( @{ question = $QuestionText; header = "Test"; multiSelect = $false; options = $opts } ) }
    $msg = @{ type = "assistant"; message = @{ role = "assistant"; content = @( @{ type = "text"; text = "테스트" }, @{ type = "tool_use"; id = "test"; name = "AskUserQuestion"; input = $q } ) } }
    return ($msg | ConvertTo-Json -Depth 20 -Compress)
}

function Fire-Alarm {
    param([string]$Type, [string]$TranscriptPath)
    if (-not $TranscriptPath) { $TranscriptPath = Get-LatestTranscript }
    if (-not $TranscriptPath) { Write-Host "트랜스크립트 못 찾음" -ForegroundColor Red; return }

    $event = if ($Type -eq 'stop') { 'Stop' } else { 'Notification' }
    $payload = '{"session_id":"test-' + (Get-Date -Format 'HHmmss') + '","hook_event_name":"' + $event + '","transcript_path":' + ($TranscriptPath | ConvertTo-Json) + '}'

    $pInfo = New-Object System.Diagnostics.ProcessStartInfo
    $pInfo.FileName = 'powershell'
    $pInfo.Arguments = "-Sta -NoProfile -ExecutionPolicy Bypass -File `"$NotifyPs1`" -Type $Type"
    $pInfo.WorkingDirectory = 'C:\PJ'
    $pInfo.UseShellExecute = $false; $pInfo.RedirectStandardInput = $true
    $p = [System.Diagnostics.Process]::Start($pInfo)
    $p.StandardInput.Write($payload); $p.StandardInput.Close()
    Write-Host "  → fired (PID $($p.Id))" -ForegroundColor DarkGray
}

while ($true) {
    Write-Host ""
    Write-Host "═══ 🎯 Claude 알람 테스트 메뉴 ═══" -ForegroundColor Yellow
    Write-Host "  1. Stop 알람 (기본 토스트)"
    Write-Host "  2. Notification 알람 (AskUserQuestion 없음)"
    Write-Host "  3. Picker — 2 옵션 (Yes/No 스타일)"
    Write-Host "  4. Picker — 3 옵션"
    Write-Host "  5. Picker — 5 옵션 (최대)"
    Write-Host "  6. Picker — 긴 라벨 (높이 확장 확인)"
    Write-Host "  7. 스택 테스트 — Stop 3개 동시"
    Write-Host "  8. 스택 테스트 — Stop 5개 동시"
    Write-Host "  9. 혼합 — Stop + Picker 동시"
    Write-Host "  0. 종료" -ForegroundColor DarkGray
    Write-Host "──────────────────────────────"
    $c = Read-Host "선택"

    switch ($c) {
        '1' { Write-Host "Stop 알람" -ForegroundColor Cyan; Fire-Alarm -Type stop }
        '2' { Write-Host "Notification 일반 토스트" -ForegroundColor Cyan; Fire-Alarm -Type notification }
        '3' {
            Write-Host "Picker 2옵션" -ForegroundColor Cyan
            $tx = Make-Transcript (Make-AskUserQuestion -OptionCount 2 -QuestionText "이 작업을 진행할까요?")
            Fire-Alarm -Type notification -TranscriptPath $tx
        }
        '4' {
            Write-Host "Picker 3옵션" -ForegroundColor Cyan
            $tx = Make-Transcript (Make-AskUserQuestion -OptionCount 3 -QuestionText "어떤 옵션을 선택하시겠어요?")
            Fire-Alarm -Type notification -TranscriptPath $tx
        }
        '5' {
            Write-Host "Picker 5옵션" -ForegroundColor Cyan
            $tx = Make-Transcript (Make-AskUserQuestion -OptionCount 5 -QuestionText "5개 중 하나를 골라주세요")
            Fire-Alarm -Type notification -TranscriptPath $tx
        }
        '6' {
            Write-Host "Picker 긴 라벨/질문" -ForegroundColor Cyan
            $longQ = "이건 좀 긴 질문입니다 — 알람 창이 내용에 맞게 세로로 늘어나는지 확인하기 위한 테스트 시나리오입니다. 라벨과 설명이 길어도 잘 보이나요?"
            $opts = @(
                @{ label = "첫 번째 옵션 — 길고 자세한 라벨"; description = "이 옵션의 설명도 꽤 길어서 여러 줄로 표시될 가능성이 있는 텍스트입니다" }
                @{ label = "두 번째 옵션"; description = "짧은 설명" }
                @{ label = "세 번째 — 또 다른 긴 라벨로 너비/높이 확인"; description = "이 옵션도 마찬가지로 긴 설명을 갖고 있어요" }
            )
            $q = @{ questions = @( @{ question = $longQ; header = "Test"; multiSelect = $false; options = $opts } ) }
            $msg = @{ type = "assistant"; message = @{ role = "assistant"; content = @( @{ type = "text"; text = "긴 테스트" }, @{ type = "tool_use"; id = "test"; name = "AskUserQuestion"; input = $q } ) } }
            $tx = Make-Transcript ($msg | ConvertTo-Json -Depth 20 -Compress)
            Fire-Alarm -Type notification -TranscriptPath $tx
        }
        '7' {
            Write-Host "Stop 3개 스택" -ForegroundColor Cyan
            Remove-Item "$env:TEMP\claude-toast-slots.txt" -ErrorAction SilentlyContinue
            1..3 | ForEach-Object { Fire-Alarm -Type stop; Start-Sleep -Milliseconds 300 }
        }
        '8' {
            Write-Host "Stop 5개 스택" -ForegroundColor Cyan
            Remove-Item "$env:TEMP\claude-toast-slots.txt" -ErrorAction SilentlyContinue
            1..5 | ForEach-Object { Fire-Alarm -Type stop; Start-Sleep -Milliseconds 300 }
        }
        '9' {
            Write-Host "Stop + Picker 혼합" -ForegroundColor Cyan
            Remove-Item "$env:TEMP\claude-toast-slots.txt" -ErrorAction SilentlyContinue
            Fire-Alarm -Type stop
            Start-Sleep -Milliseconds 400
            $tx = Make-Transcript (Make-AskUserQuestion -OptionCount 3 -QuestionText "스택 중 picker가 잘 뜨나요?")
            Fire-Alarm -Type notification -TranscriptPath $tx
            Start-Sleep -Milliseconds 400
            Fire-Alarm -Type stop
        }
        '0' { Write-Host "종료" -ForegroundColor DarkGray; return }
        default { Write-Host "알 수 없는 입력: $c" -ForegroundColor Red }
    }
}
