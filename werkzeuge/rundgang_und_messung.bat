@echo off
rem Foto-Rundgang und Messung, jeweils in den Grafikstufen Hoch und Episch (Doppelklick genuegt).
rem Beim ersten Start fragt das Skript nach der Godot-Datei (Godot_v4.7.2-stable_win64_console.exe) und merkt sie sich
rem in werkzeuge\godot_pfad.txt (nicht im Repository).
setlocal
cd /d "%~dp0.."
if exist "werkzeuge\godot_pfad.txt" set /p GODOT=<"werkzeuge\godot_pfad.txt"
if not defined GODOT (
  echo Bitte die Datei Godot_v4.7.2-stable_win64_console.exe in dieses Fenster ziehen und Enter druecken:
  set /p GODOT=
)
set GODOT=%GODOT:"=%
if not exist "%GODOT%" (
  echo Godot nicht gefunden: %GODOT%
  if exist "werkzeuge\godot_pfad.txt" del "werkzeuge\godot_pfad.txt"
  pause
  exit /b 1
)
echo %GODOT%>"werkzeuge\godot_pfad.txt"

echo === Neuesten Stand holen
git checkout main && git pull
echo === Geaenderte Dateien importieren (z. B. Texturen nach neuen Importeinstellungen)
"%GODOT%" --headless --path . --import

echo === Rundgang Hoch
"%GODOT%" --path . --script res://werkzeuge/rundgang/rundgang.gd -- --grafik hoch --aufloesung 1280x720
echo === Rundgang Episch
"%GODOT%" --path . --script res://werkzeuge/rundgang/rundgang.gd -- --grafik episch --aufloesung 1280x720
echo === Messung Hoch
"%GODOT%" --path . --script res://werkzeuge/messen/messung.gd -- --name hoch --grafik hoch --aufloesung 1280x720
echo === Messung Episch
"%GODOT%" --path . --script res://werkzeuge/messen/messung.gd -- --name episch --grafik episch --aufloesung 1280x720

echo === Fertig. Fotos unter rundgang\, Messungen unter messungen\
explorer "%APPDATA%\Godot\app_userdata\Sorrowland_ In Silentio"
pause
