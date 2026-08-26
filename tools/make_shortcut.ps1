# 바탕화면에 앱 바로가기를 놓는 스크립트입니다.
#
# "앱 만들기.bat"이 마지막에 이 파일을 부릅니다. 직접 실행할 일은 없습니다.
#
# ── 이 파일은 반드시 "BOM 있는 UTF-8"로 저장해야 합니다 ──
# Windows PowerShell 5.1은 .ps1 파일 맨 앞에 BOM(파일이 UTF-8이라는 표시)이
# 없으면 **한글을 949 코드페이지로 잘못 읽습니다.** 그러면 아래 '레퍼런스
# 아카이브.lnk' 가 깨진 글자가 되어 바로가기를 못 만듭니다.
# (실제로 그렇게 실패했습니다. 오류는 "저장할 수 없습니다"로만 나와서
#  글자 문제인 줄 알아채기 어렵습니다)
#
# 편집기에서 다시 저장할 때 인코딩을 "UTF-8 with BOM"으로 두세요.

# 오류가 나면 조용히 넘어가지 말고 멈춥니다.
# 안 그러면 실패했는데도 배치 파일이 "다 됐습니다"라고 합니다.
$ErrorActionPreference = 'Stop'

try {
    # $PSScriptRoot = 이 스크립트가 있는 폴더(tools). 그 위가 프로젝트 폴더입니다.
    $projectRoot = Split-Path -Parent $PSScriptRoot

    $exePath = Join-Path $projectRoot 'build\windows\x64\runner\Release\reference_archive_app.exe'

    if (-not (Test-Path $exePath)) {
        Write-Host "앱 파일을 못 찾았습니다: $exePath"
        Write-Host "먼저 앱 만들기가 성공했는지 확인하세요."
        exit 1
    }

    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktop '레퍼런스 아카이브.lnk'

    # WScript.Shell = 윈도우가 원래 갖고 있는 도구입니다. 따로 설치할 것이 없습니다.
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $exePath

    # 앱이 실행될 때의 기준 폴더입니다. 이걸 안 정해주면 앱이 옆에 있는
    # 부속 파일(DLL 등)을 못 찾는 경우가 있습니다.
    $shortcut.WorkingDirectory = Split-Path -Parent $exePath
    $shortcut.Description = '레퍼런스 아카이브'
    $shortcut.Save()

    # 정말 만들어졌는지 확인합니다. Save()가 조용히 실패하는 경우가 있습니다.
    if (-not (Test-Path $shortcutPath)) {
        Write-Host "바로가기를 만들지 못했습니다: $shortcutPath"
        exit 1
    }

    Write-Host "바탕화면에 바로가기를 놓았습니다."
    exit 0
}
catch {
    Write-Host "바로가기를 만들다가 오류가 났습니다:"
    Write-Host $_.Exception.Message
    exit 1
}
