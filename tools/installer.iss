; 레퍼런스 아카이브를 다른 컴퓨터에 설치할 수 있는 설치 파일(.exe)을
; 만드는 Inno Setup 스크립트입니다.
;
; 이 파일 하나로 "다음, 다음, 설치" 하는 익숙한 설치 마법사가 만들어집니다.
; 다른 컴퓨터에 Flutter나 Visual Studio를 깔 필요가 전혀 없습니다 — 이미
; 빌드된 실행 파일(build\windows\x64\runner\Release)을 그대로 담아서
; 옮기는 것뿐입니다.
;
; ── 쓰는 법 ──
; 1. 먼저 이 컴퓨터에서 "flutter build windows --release"로 앱을 빌드합니다.
;    (또는 "앱 만들기.bat"을 실행하면 이 단계까지 자동으로 됩니다)
; 2. 이 파일(installer.iss)을 Inno Setup으로 엽니다(더블클릭하거나,
;    Inno Setup Compiler로 열기).
; 3. "Compile"(컴파일)을 누르면 tools\output\ 안에 설치 파일이 생깁니다.
;
; ── Inno Setup이 없다면 ──
; https://jrsoftware.org/isdl.php 에서 받아 설치하세요. (무료입니다)

#define MyAppName "레퍼런스 아카이브"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "luseuss"
#define MyAppExeName "reference_archive_app.exe"

; ProjectRoot = 이 스크립트가 있는 tools 폴더의 한 단계 위(프로젝트 폴더).
#define ProjectRoot "..\"

[Setup]
; AppId는 이 앱을 구분하는 고유 번호입니다. 나중에 앱을 업데이트할 때도
; 같은 번호를 써야 "새로 설치"가 아니라 "업데이트"로 인식됩니다.
; (한 번 정하면 절대 바꾸지 마세요)
AppId={{B4A8F4C2-6E7E-4A6E-9C6F-2B7B5F8E8B1A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
; 시작 메뉴 폴더 이름도 앱 이름과 같게 둡니다.
DefaultGroupName={#MyAppName}
; 관리자 권한 없이도 설치할 수 있게 합니다(사용자 폴더 안에 설치) —
; 의뢰인이 회사·학교 컴퓨터처럼 관리자 권한이 없는 환경에서도 설치할 수
; 있어야 하기 때문입니다.
PrivilegesRequired=lowest
OutputDir=output
OutputBaseFilename=레퍼런스아카이브_설치
SetupIconFile={#ProjectRoot}windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; 한글이 깨지지 않도록 유니코드 설치 프로그램으로 만듭니다.
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
; 설치 마법사 화면에서 "바탕화면에 바로가기 만들기"를 고를 수 있게 합니다.
; 기본으로 체크돼 있습니다.
Name: "desktopicon"; Description: "바탕화면에 바로가기 만들기"; GroupDescription: "추가 아이콘:"; Flags: checkedonce

[Files]
; 빌드된 실행 파일 폴더(Release) 안의 모든 것을 통째로 담습니다.
; recursesubdirs로 data 폴더(유튜브 재생용 웹 자료 등) 안까지 전부 포함합니다.
;
; ── *.exe.WebView2 폴더는 뺍니다 ──
; 이 폴더는 앱 코드가 아니라, 이 컴퓨터에서 앱을 실행해볼 때 웹뷰
; 부품(유튜브 재생용)이 알아서 만들어둔 캐시입니다. 빼도 문제없습니다 —
; 설치한 컴퓨터에서 처음 실행하면 똑같은 폴더가 새로 생깁니다. 안 빼면
; 설치 파일 용량만 쓸데없이 20MB 가까이 커집니다.
Source: "{#ProjectRoot}build\windows\x64\runner\Release\*"; DestDir: "{app}"; Excludes: "*.exe.WebView2\*"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; 시작 메뉴 바로가기 (항상 만듭니다)
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
; 시작 메뉴의 "제거" 항목
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
; 바탕화면 바로가기 (위 [Tasks]에서 고른 경우에만)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; 설치가 끝나면 "지금 실행하기" 체크박스를 보여줍니다.
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
