@echo off
REM 앱 만들기 - 평소에 쓸 "진짜 앱"을 만들고 바탕화면에 바로가기를 놓습니다.
REM
REM 한 번 만들어두면 그 뒤로는 바탕화면 아이콘만 더블클릭하면 됩니다.
REM 터미널도 안 뜨고, 끌 때는 그냥 창을 닫으면 됩니다.
REM 코드를 고친 뒤에는 이 파일을 다시 실행해야 바뀐 내용이 반영됩니다.
chcp 65001 > nul
cd /d "%~dp0"

echo [1/3] 켜져 있는 앱이 있으면 닫습니다...
REM 안 닫으면 앱이 WebView2Loader.dll 을 붙잡고 있어서 빌드가 실패합니다.
taskkill /IM reference_archive_app.exe /F > nul 2>&1

echo [2/3] 앱을 만듭니다. 몇 분 걸립니다...
call flutter build windows
if errorlevel 1 goto build_failed

echo [3/3] 바탕화면에 바로가기를 놓습니다...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\make_shortcut.ps1"
REM 바로가기 만들기가 실패했는데 "다 됐습니다"라고 하면 안 됩니다.
REM 실제로 그렇게 실수해서, 안 만들어졌는데 성공한 줄 알았습니다.
if errorlevel 1 goto shortcut_failed

echo.
echo 다 됐습니다. 바탕화면의 "레퍼런스 아카이브"를 더블클릭하세요.
pause
exit /b 0

:build_failed
echo.
echo 앱 만들기에 실패했습니다. 위쪽에서 error 로 시작하는 줄을 찾아보세요.
echo 자주 있는 원인 두 가지:
echo   1. nuget 이 없음   -^> winget install Microsoft.NuGet 실행 후 새 창에서 다시
echo   2. 앱이 켜져 있음  -^> 앱을 완전히 닫고 다시
pause
exit /b 1

:shortcut_failed
echo.
echo 앱은 만들어졌지만 바탕화면 바로가기를 못 놓았습니다.
echo 앱 자체는 아래 파일을 직접 열면 실행됩니다:
echo   %~dp0build\windows\x64\runner\Release\reference_archive_app.exe
pause
exit /b 1
