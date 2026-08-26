@echo off
REM 개발용 실행 - 코드를 고친 뒤 확인할 때 씁니다.
REM 이 파일을 더블클릭하면 앱이 뜹니다. 터미널에서 q 를 누르면 꺼집니다.
chcp 65001 > nul
cd /d "%~dp0"

REM 이미 켜져 있는 앱을 먼저 닫습니다.
REM 안 닫으면 WebView2Loader.dll 을 붙잡고 있어서 빌드가 실패합니다.
REM (유튜브 웹뷰가 들어오면서 생긴 제약입니다)
echo [1/2] 켜져 있는 앱이 있으면 닫습니다...
taskkill /IM reference_archive_app.exe /F > /dev/null 2>&1

echo [2/2] 앱을 빌드해서 실행합니다. 처음에는 몇 분 걸립니다.
echo       끄려면 이 창에서 q 를 누르세요.
echo.
flutter run -d windows

REM 오류로 끝났을 때 창이 바로 닫히면 무엇이 문제였는지 못 봅니다.
if errorlevel 1 pause
