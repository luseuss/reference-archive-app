@echo off
REM 설치파일 만들기 - 다른 컴퓨터에 옮겨서 쓸 수 있는 설치 파일(.exe)을 만듭니다.
REM
REM "앱 만들기.bat"은 지금 쓰는 이 컴퓨터에 바로 설치하는 것이고,
REM 이 파일은 그 설치 파일 자체를 만들어서 다른 컴퓨터로 옮길 수 있게
REM 하는 것입니다. 다른 컴퓨터에는 Flutter나 Visual Studio를 깔 필요가
REM 전혀 없습니다 — 만들어진 설치 파일만 옮겨서 실행하면 됩니다.
REM
REM tools\installer.iss 에 설치 파일이 어떻게 만들어지는지 자세히
REM 적혀 있습니다.
chcp 65001 > nul
cd /d "%~dp0"

echo [1/3] 켜져 있는 앱이 있으면 닫습니다...
taskkill /IM reference_archive_app.exe /F > nul 2>&1

echo [2/3] 앱을 만듭니다. 몇 분 걸립니다...
call flutter build windows --release
if errorlevel 1 goto build_failed

echo [3/3] 설치 파일로 묶습니다...

REM Inno Setup(설치 파일을 만드는 무료 도구)이 컴퓨터마다 다른 자리에
REM 깔려있을 수 있어서, 있을 법한 자리를 순서대로 찾아봅니다.
set ISCC="%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
if exist %ISCC% goto found_iscc

set ISCC="%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if exist %ISCC% goto found_iscc

set ISCC="%ProgramFiles%\Inno Setup 6\ISCC.exe"
if exist %ISCC% goto found_iscc

goto iscc_missing

:found_iscc
%ISCC% "tools\installer.iss"
if errorlevel 1 goto compile_failed

echo.
echo 다 됐습니다. 아래 폴더에 설치 파일이 생겼습니다:
echo   %~dp0tools\output\
echo 이 exe 파일 하나만 다른 컴퓨터로 옮겨서 실행하면 설치됩니다.
pause
exit /b 0

:build_failed
echo.
echo 앱 만들기에 실패했습니다. 위쪽에서 error 로 시작하는 줄을 찾아보세요.
pause
exit /b 1

:iscc_missing
echo.
echo 설치 파일을 만드는 도구(Inno Setup)가 안 깔려 있습니다.
echo 아래 주소에서 받아 설치한 뒤(기본값 그대로 "다음"만 누르면 됩니다),
echo 이 파일을 다시 실행하세요.
echo   https://jrsoftware.org/isdl.php
pause
exit /b 1

:compile_failed
echo.
echo 설치 파일 묶기에 실패했습니다. 위쪽 내용을 확인하세요.
pause
exit /b 1
