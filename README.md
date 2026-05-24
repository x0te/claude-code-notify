# Claude Notify

> Windows 데스크톱 토스트 알림 시스템 for **[Claude Code](https://claude.com/claude-code)**
> Claude가 작업을 끝내거나 응답이 필요할 때 우하단에 알람 + 사운드로 알려줍니다.

![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows) ![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white) ![License](https://img.shields.io/badge/license-MIT-D97757)

---

## ✨ 주요 기능

| | |
|---|---|
| 🔔 **자동 알람** | Claude 응답 종료(Stop) / 입력 대기(Notification) 훅 자동 트리거 |
| 🎨 **WPF 토스트** | Claude 코럴 톤 UI · 우하단 위치 · 클릭 시 터미널 포커스 |
| 🎵 **칩튠 SFX 24종** | Mario / Zelda / FF / Sonic / Pac-Man 등 (직접 합성, 저작권 안전) |
| 📝 **작업 요약** | 마지막 assistant 메시지를 토스트 본문에 (최대 800자) |
| 🔐 **권한 안내** | Bash / Edit / Write / AskUserQuestion 대기 시 "왜 멈췄는지" 상세 표시 |
| 📚 **세로 스택** | 다중 알람 자동 정렬 · 위에거 닫으면 즉시 내려옴 |
| 🪟 **다중 인스턴스** | 프로젝트별 라벨 + 알람 클릭 시 **해당** 터미널로 포커스 |
| 🎨 **커스터마이저** | 앱 이름 / 아이콘 / 멜로디 / 텍스트 전부 GUI에서 변경 |

---

## 📦 요구사항

- **Windows 10 / 11**
- **PowerShell 5.1+** (Windows 기본 설치)
- **.NET Framework 4.x** (Windows 10/11 기본 설치)
- **[Claude Code](https://claude.com/claude-code)** 설치 & 로그인됨

---

## 🚀 빠른 설치

```powershell
git clone https://github.com/x0te/claude-code-notify.git
cd claude-code-notify
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

그 다음 Claude Code 채팅창에서:
```
/hooks
```
한 번 입력하면 즉시 활성화 (다이얼로그가 뜨면 그냥 닫아도 OK — 여는 행위가 reload 트리거).

---

## 📘 단계별 가이드

### 1단계 — 클론

원하는 위치에 클론하세요. `C:\PJ\` 같은 안정적인 폴더 추천 (Desktop 등 자주 이동하는 곳 X):

```powershell
cd C:\PJ
git clone https://github.com/x0te/claude-code-notify.git
```

### 2단계 — 설치 스크립트 실행

```powershell
cd claude-code-notify
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

설치 스크립트가 자동으로:

| 단계 | 작업 |
|---|---|
| 1 | `toast-helper.exe` 컴파일 (.NET csc로 빌드) |
| 2 | `notify-config.json` 기본값 생성 (이미 있으면 유지) |
| 3 | HKCU 레지스트리에 AppUserModelID `ClaudeCode.Notify` 등록 |
| 4 | `%USERPROFILE%\.claude\settings.json`에 Stop/Notification 훅 추가 |
| 5 | 데스크톱 + 시작 메뉴에 **"Claude 알림 설정"** · **"Claude 알람 테스트"** 바로가기 생성 |

### 3단계 — Claude Code 훅 reload

Claude Code의 어떤 세션이든 채팅창에:
```
/hooks
```

다이얼로그 뜨면 그냥 `Esc`로 닫아도 됩니다. 다이얼로그를 여는 동작 자체가 settings.json reload를 일으켜요. (또는 Claude Code 완전 재시작)

### 4단계 — 동작 확인

데스크톱의 **🎯 Claude 알람 테스트** 바로가기를 더블클릭하면 메뉴:

```
1. Stop 알람 (기본 토스트)
2. Notification 알람
3-5. Picker (2/3/5 옵션) — 더는 안 보임. AskUserQuestion 전용
6. Picker — 긴 라벨/질문 (높이 확장 확인)
7. 스택 테스트 — Stop 3개 동시
8. 스택 테스트 — Stop 5개 동시
9. 혼합 — Stop + Picker 동시
0. 종료
```

번호 입력해서 시나리오 발사 가능.

---

## 🎨 커스터마이즈

데스크톱의 **✱ Claude 알림 설정** 바로가기 더블클릭. GUI에서:

- **앱 이름** — 알람 헤더에 표시될 이름 (기본: `Claude Code`)
- **앱 아이콘** — Anthropic asterisk(`✱`) 외에 50+ 큐레이트 이모지 선택 가능
- **응답 필요 (Notification)** — 이모지 / 텍스트 / 멜로디 / 요약 표시 / 사운드 ON-OFF
- **작업 완료 (Stop)** — 동일
- **▶ 미리듣기** — 각 멜로디 즉시 청취
- **💾 저장** — `notify-config.json` 저장 + 레지스트리 갱신

저장한 변경사항은 **다음 알람부터** 반영됩니다.

---

## 🎵 멜로디 프리셋

| 카테고리 | 프리셋 |
|---|---|
| Cute (sine) | triumph · doorbell · sparkle · chime · ping · twinkle · powerup · descend · single · soft · royal · cute |
| 8-bit (chiptune) | mario_coin · mario_1up · mario_powerup · mario_jump · mario_pipe · mario_clear · zelda_secret · zelda_item · ff_victory · sonic_ring · pacman_eat · tetris_clear · pokemon_catch |

모두 직접 합성 (sine / square / triangle 파형) — 저작권 무관.

---

## 🛠 트러블슈팅

<details>
<summary><b>알람이 안 나옴 / 사운드 안 들림</b></summary>

1. `notify.log` 확인:
   ```powershell
   Get-Content "C:\PJ\claude-code-notify\notify.log" -Tail 10
   ```
   - 로그가 비어있다 → 훅이 한 번도 안 돈 거. Claude Code에서 `/hooks` 입력 후 재시도.
   - `fired` 라인은 있는데 소리 X → 시스템 → 사운드 → 앱 볼륨에서 `powershell.exe` 0이 아닌지 확인.

2. `~/.claude/settings.json`에 훅이 등록됐는지:
   ```powershell
   Get-Content "$env:USERPROFILE\.claude\settings.json" | Select-String "notify.ps1"
   ```
</details>

<details>
<summary><b>토스트 클릭해도 터미널로 포커스 안 감</b></summary>

`toast-helper.exe`가 컴파일 안 됐을 가능성. 다시 설치:
```powershell
Remove-Item "C:\PJ\claude-code-notify\toast-helper.exe" -Force
powershell -ExecutionPolicy Bypass -File "C:\PJ\claude-code-notify\install.ps1"
```
</details>

<details>
<summary><b>한글 입력으로 'y' 대신 'ㅛ' 들어감</b></summary>

이미 fix됨 (SendInput KEYEVENTF_UNICODE 사용). 최신 버전으로 업데이트:
```powershell
cd C:\PJ\claude-code-notify
git pull
```
</details>

<details>
<summary><b>토스트가 'Windows PowerShell' 이름으로 뜸</b></summary>

AppUserModelID 등록 안 됨. 다시 설치하거나 수동 등록:
```powershell
$reg = "HKCU:\Software\Classes\AppUserModelId\ClaudeCode.Notify"
New-Item -Path $reg -Force | Out-Null
Set-ItemProperty -Path $reg -Name 'DisplayName' -Value 'Claude Code'
Set-ItemProperty -Path $reg -Name 'IconUri' -Value "C:\PJ\claude-code-notify\icons\claude.ico"
```
</details>

<details>
<summary><b>여러 인스턴스 알람이 헷갈림</b></summary>

토스트 제목에 프로젝트명이 자동으로 표시됩니다 (`Claude Code · opencalendar`). 각 알람 클릭 시 그 알람을 띄운 터미널로 포커스 이동.
별도 윈도우는 OK, 같은 WT의 다른 탭은 윈도우는 활성화되지만 특정 탭 전환은 X (WT 제약).
</details>

---

## 📁 폴더 구조

```
claude-code-notify/
├── notify.ps1                  # 메인 알람 스크립트 (훅 진입점)
├── notify-customizer.ps1       # WPF 설정 GUI
├── notify-customizer.bat       # 더블클릭 실행
├── notify-config.json          # 사용자 설정
├── test-alarms.ps1             # 테스트 메뉴
├── test-alarms.bat             # 더블클릭 실행
├── toast-helper.exe            # WinRT Toast 클릭 활성화 (install.ps1이 빌드)
├── src/toast-helper.cs         # 위 exe의 C# 소스
├── icons/                      # 동적 생성 아이콘
├── install.ps1                 # 설치
├── uninstall.ps1               # 제거
├── LICENSE                     # MIT
└── README.md                   # 이 파일
```

---

## 🗑 제거

```powershell
cd C:\PJ\claude-code-notify
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

훅 / 레지스트리 / 바로가기 모두 제거. 클론 폴더는 수동으로 삭제.

---

## 📝 라이선스

[MIT](LICENSE)
