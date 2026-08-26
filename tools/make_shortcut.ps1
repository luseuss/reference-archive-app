# 바탕화면에 앱 바로가기를 놓는 스크립트입니다.
#
# "앱 만들기.bat"이 마지막에 이 파일을 부릅니다. 직접 실행할 일은 없습니다.
#
# ── 왜 .bat 안에 안 넣고 파일을 나눴나 ──
# 배치 파일 안에서 PowerShell 명령을 쓰려면 따옴표를 여러 겹 겹쳐야 하는데,
# 하나만 어긋나도 알아보기 힘든 오류가 납니다. 파일을 나누면 그냥 평범한
# PowerShell 코드가 되어 읽기도 고치기도 쉽습니다.

# $PSScriptRoot = 이 스크립트가 있는 폴더(tools). 그 위가 프로젝트 폴더입니다.
$projectRoot = Split-Path -Parent $PSScriptRoot

$exePath = Join-Path $projectRoot 'build\windows\x64\runner\Release\reference_archive_app.exe'

if (-not (Test-Path $exePath)) {
    Write-Host "앱 파일을 못 찾았습니다: $exePath"
    Write-Host "먼저 앱 만들기가 성공했는지 확인하세요."
    exit 1
}

$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) '레퍼런스 아카이브.lnk'

# WScript.Shell = 윈도우가 원래 갖고 있는 도구입니다. 따로 설치할 것이 없습니다.
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $exePath

# 앱이 실행될 때의 기준 폴더입니다. 이걸 안 정해주면 앱이 옆에 있는
# 부속 파일(DLL 등)을 못 찾는 경우가 있습니다.
$shortcut.WorkingDirectory = Split-Path -Parent $exePath
$shortcut.Description = '레퍼런스 아카이브'
$shortcut.Save()

Write-Host "바탕화면에 바로가기를 놓았습니다: $shortcutPath"
