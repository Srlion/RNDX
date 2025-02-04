@echo off
setlocal enabledelayedexpansion

set "File=compile_shader_list.txt"

set "validVersions=20b 30"
set "fallbackVersion=20b"

REM Open the file for reading
for /f "usebackq tokens=* delims=" %%A in ("%File%") do (
    set "line=%%A"

    REM Skip empty lines or lines starting with comments
    echo !line! | findstr /r /c:"^\s*$" >nul
    if !errorlevel! equ 0 (
        REM Skip the line
        continue
    )
    echo !line! | findstr /r /c:"^\s*//" >nul
    if !errorlevel! equ 0 (
        REM Skip the line
        continue
    )

    REM Trim whitespace from the line
    set "line=!line: =!"

    REM Extract all valid versions present in the line using the -v-(version) format
    set "versionsInLine="
    for %%V in (%validVersions%) do (
        echo !line! | findstr /r /c:"-v-%%V" >nul && set "versionsInLine=!versionsInLine! %%V"
    )

    REM If no valid versions are found, fallback to the default version
    if "!versionsInLine!"=="" (
        echo Warning: No valid version found in line: !line!. Falling back to version %fallbackVersion%.
        set "versionsInLine=%fallbackVersion%"
    )

    REM Strip all -v-(version) flags from the line
    set "cleanedLine=!line!"
    for %%V in (%validVersions%) do (
        set "cleanedLine=!cleanedLine:-v-%%V=! "
    )
    set "cleanedLine=!cleanedLine: =!"

    REM Compile for each valid version found in the line (or the fallback version)
    for %%V in (!versionsInLine!) do (
        set "compileArgs=/O 3 -ver %%V -shaderpath %CD%/src !cleanedLine!"

        echo Compiling '!cleanedLine!' with version '%%V'
        call "ShaderCompile.exe" !compileArgs!
    )
)

endlocal
exit /b 0
