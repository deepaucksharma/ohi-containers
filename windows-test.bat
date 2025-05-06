@echo off 
echo Testing on Windows environment 
echo Platform: Windows 
if exist lib\common.sh ( 
  echo [OK] Found common library 
  echo [WINDOWS TEST PASSED] 
) else ( 
  echo [ERROR] Missing common library 
  exit /b 1 
) 
