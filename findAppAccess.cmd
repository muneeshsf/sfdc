@echo off
setlocal enabledelayedexpansion

REM === CONFIG ===
set "APP_NAME=FB_Work_Lightning"
set "METADATA_DIR=C:\Muneesh\SFDXSetup\MBMeta\force-app\main\default\permissionsets"
set "OUTPUT_FILE=AppMon_PermissionSet_Report.csv"

REM === Pull metadata ===
echo Pulling metadata from org...
rem sfdx force:source:retrieve -m "PermissionSet,CustomApplication"

REM === Initialize CSV ===
echo PermissionSet,GrantsAccessToApp > "%OUTPUT_FILE%"

REM === Loop through PermissionSets ===
for /R "%METADATA_DIR%" %%f in (*.permissionset-meta.xml) do (
    set "FOUND=No"
    findstr /I /C:"<application>%APP_NAME%</application>" "%%f" >nul && set "FOUND=Yes"

    REM Extract base file name without extension
    set "FILENAME=%%~nf"
    set "FILENAME=!FILENAME:.permissionset=!"
    
    echo !FILENAME!,!FOUND! >> "%OUTPUT_FILE%"
)

echo.
echo ✅ Report generated: %OUTPUT_FILE%
pause
