::[Bat To Exe Converter]
::
::YAwzoRdxOk+EWAjk
::fBw5plQjdCyDJHi0xG4MCRZESRa+Dm63D6Ej5OH16u+7sV8eaPAqepaV07eBQA==
::YAwzuBVtJxjWCl3EqQJgSA==
::ZR4luwNxJguZRRnk
::Yhs/ulQjdF+5
::cxAkpRVqdFKZSzk=
::cBs/ulQjdF+5
::ZR41oxFsdFKZSDk=
::eBoioBt6dFKZSDk=
::cRo6pxp7LAbNWATEpCI=
::egkzugNsPRvcWATEpCI=
::dAsiuh18IRvcCxnZtBJQ
::cRYluBh/LU+EWAnk
::YxY4rhs+aU+JeA==
::cxY6rQJ7JhzQF1fEqQJQ
::ZQ05rAF9IBncCkqN+0xwdVs0
::ZQ05rAF9IAHYFVzEqQJQ
::eg0/rx1wNQPfEVWB+kM9LVsJDGQ=
::fBEirQZwNQPfEVWB+kM9LVsJDGQ=
::cRolqwZ3JBvQF1fEqQJQ
::dhA7uBVwLU+EWDk=
::YQ03rBFzNR3SWATElA==
::dhAmsQZ3MwfNWATElA==
::ZQ0/vhVqMQ3MEVWAtB9wSA==
::Zg8zqx1/OA3MEVWAtB9wSA==
::dhA7pRFwIByZRRnk
::Zh4grVQjdCyDJGyX8VAjFB5aHlPXaTiGIrAP4/z0/9a1p0AUQN0zcYHe34idMuMvy1fnfZ8733sUndMJbA==
::YB416Ek+ZG8=
::
::
::978f952a14a936cc963da21a135fa983
@ECHO OFF

if "%b2eprogramfilename%"==""  (
	echo To see any results you need to convert this file into an exe
	pause
	goto :eof
)

:: variables
SET remit_linee_folder=%~dp0
SET conemu_exe=%CMDER_ROOT%\vendor\conemu-maximus5\ConEmu.exe
SET conemu_ico=%CMDER_ROOT%\icons\cmder.ico
SET conemu_cfgfile=%CMDER_ROOT%\config\ConEmu.xml
SET conemu_init=%CMDER_ROOT%\vendor\init.bat
SET ruby=C:\Ruby\bin\ruby.exe
SET app= %remit_linee_folder%main.rb
SET argv=%*


IF NOT EXIST "%remit_linee_folder%" (
    ECHO %~n0: file not found - %remit_linee_folder% >&2
    EXIT /B 1
)

IF NOT EXIST "%ruby%" (
    %extd% /messagebox Error "File %ruby% non trovato installare ruby" 16
    EXIT /B 1
)


START %conemu_exe% /icon %conemu_ico% /title "Archivia Remit Linee"  /loadcfgfile %conemu_cfgfile% /cmd cmd /k "%conemu_init% && cd /D %remit_linee_folder% && %ruby% %app% --enviroment=production archivia"
