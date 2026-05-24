# Claude Notify

Windows 데스크톱 토스트 알림 시스템 for **Claude Code**.
Claude가 작업을 끝내거나 응답이 필요할 때 우하단에 알람 + 사운드로 알려줍니다.

## ✨ 기능

- 🔔 **Stop / Notification 훅** — Claude 응답 종료 / 입력 대기 시 자동 알람
- 🎨 **WPF 토스트 UI** — Claude 코럴 톤, 클릭하면 터미널 포커스
- 🎵 **칩튠 SFX 24종** — Mario, Zelda, FF, Sonic, Pac-Man 등 (직접 합성, 저작권 안전)
- 📝 **작업 요약 표시** — 마지막 assistant 메시지를 토스트 본문에 (최대 800자)
- 🔐 **권한 요청 안내** — Bash/Edit/Write/AskUserQuestion 대기 시 상세 사유 표시
- 📚 **세로 스택** — 다중 알람 자동 정렬, 위에거 닫히면 즉시 내려옴
- 🪟 **다중 Claude Code 대응** — 프로젝트별 식별 표시, 알람 클릭 시 해당 터미널로
- 🎨 **커스터마이저 GUI** — 앱 이름/아이콘/멜로디/텍스트 모두 GUI에서 변경
- 🧪 **테스트 메뉴** — 다양한 알람 시나리오 즉시 발사

## 📦 요구사항

- Windows 10 / 11
- PowerShell 5.1+
- .NET Framework 4.x (보통 기본 설치)
- [Claude Code](https://claude.com/claude-code) 설치됨

## 🚀 설치

```powershell
git clone <repo-url> claude-notify
cd claude-notify
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

설치 스크립트가 자동으로:
1. `toast-helper.exe` 컴파일
2. `~/.claude/settings.json`에 Stop/Notification 훅 등록
3. HKCU에 AppUserModelID 등록
4. 데스크톱 + 시작 메뉴 바로가기 생성

설치 후 Claude Code에서 `/hooks` 한 번 입력하면 즉시 적용.

## 🎮 사용

### 알람 받기
설치만 하면 끝. Claude Code 사용하면 자동으로 알람 옴.

### 커스터마이즈
- 데스크톱의 **"Claude 알림 설정"** 바로가기 더블클릭
- 앱 이름/아이콘/멜로디/텍스트/표시 옵션 변경 가능

### 테스트
- 데스크톱의 **"Claude 알람 테스트"** 바로가기로 다양한 시나리오 발사

## 📁 구조

```
claude-notify/
├── notify.ps1                  # 메인 알람 스크립트 (훅 진입점)
├── notify-customizer.ps1       # WPF 설정 GUI
├── notify-customizer.bat       # 더블클릭 실행
├── notify-config.json          # 사용자 설정 (기본값 포함)
├── test-alarms.ps1             # 테스트 메뉴
├── test-alarms.bat             # 더블클릭 실행
├── toast-helper.exe            # WinRT Toast 클릭 활성화 (자동 컴파일)
├── src/toast-helper.cs         # 위 exe의 C# 소스
├── icons/                      # 아이콘들 (커스터마이저가 emoji에서 생성)
├── install.ps1                 # 설치
└── uninstall.ps1               # 제거
```

## 🛠 제거

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

훅, 레지스트리, 바로가기 모두 제거. 클론 폴더는 수동 삭제.

## 📝 라이선스

MIT
