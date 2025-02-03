@echo off

echo Building inc files and worklist for %inputbase%...

powershell -NoLogo -ExecutionPolicy Bypass -Command "bin\process_shaders.ps1 -Version 30 'compile_shader_list.txt'"

echo Done!
echo.
