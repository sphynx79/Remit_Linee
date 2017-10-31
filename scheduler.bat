@ECHO OFF

if "%b2eprogramfilename%"==""  (

	echo To see any results you need to convert this file into an exe
	pause
	goto :eof

)


:: variables
SET current_dir=%~dp0
SET transmission_folder=%current_dir%src\
SET conemu_exe=%CMDER_ROOT%\vendor\conemu-maximus5\ConEmu.exe
SET conemu_ico=%CMDER_ROOT%\icons\cmder.ico
SET conemu_cfgfile=%CMDER_ROOT%\config\ConEmu.xml
SET conemu_init=%CMDER_ROOT%\vendor\init.bat
SET ruby=C:\Ruby24_mappa\bin\ruby.exe
SET app= %transmission_folder%scheduler.rb
SET argv=%*


IF NOT EXIST "%transmission_folder%" (
    ECHO %~n0: file not found - %transmission_folder% >&2
    EXIT /B 1
)
START %conemu_exe% /icon %conemu_ico% /title "Transmission Sceduler"  /loadcfgfile %conemu_cfgfile% /cmd cmd /k "%conemu_init% && cd /D %transmission_folder% && %ruby% %app%"

