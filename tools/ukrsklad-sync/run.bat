@echo off
rem UkrSkladSync: obmin UkrSklad <-> sait.
rem   run.bat           - pratsiuie bezperervno
rem   run.bat --check   - pereviryty zviazok, nichoho ne zminiuie
rem   run.bat --once    - odyn prokhid i vykhid
cd /d "%~dp0"
chcp 65001 >nul
java -Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -cp "UkrSkladSync.jar;lib\*" UkrSkladSync %*
pause
