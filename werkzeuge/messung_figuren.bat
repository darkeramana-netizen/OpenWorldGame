@echo off
rem Messung alte gegen realistische Figuren (Doppelklick genuegt), jeweils in Hoch und Episch, dazu ein Foto-Rundgang
rem mit den realistischen Figuren. Nutzt dieselbe Godot-Datei wie rundgang_und_messung.bat (werkzeuge\godot_pfad.txt).
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

echo === Messung Hoch, alte Figuren
set FIGUREN_REALISTISCH=
"%GODOT%" --path . --script res://werkzeuge/messen/messung.gd -- --name hoch_figuren_alt --grafik hoch --aufloesung 1280x720
echo === Messung Episch, alte Figuren
"%GODOT%" --path . --script res://werkzeuge/messen/messung.gd -- --name episch_figuren_alt --grafik episch --aufloesung 1280x720

echo === Messung Hoch, realistische Figuren
set FIGUREN_REALISTISCH=1
"%GODOT%" --path . --script res://werkzeuge/messen/messung.gd -- --name hoch_figuren_neu --grafik hoch --aufloesung 1280x720
echo === Messung Episch, realistische Figuren
"%GODOT%" --path . --script res://werkzeuge/messen/messung.gd -- --name episch_figuren_neu --grafik episch --aufloesung 1280x720
echo === Messung Hoch, realistische Figuren ohne echten Stoff (Vergleich)
set STOFF_AUS=1
"%GODOT%" --path . --script res://werkzeuge/messen/messung.gd -- --name hoch_figuren_neu_ohne_stoff --grafik hoch --aufloesung 1280x720
set STOFF_AUS=
echo === Rundgang Hoch, realistische Figuren
"%GODOT%" --path . --script res://werkzeuge/rundgang/rundgang.gd -- --grafik hoch --aufloesung 1280x720
set FIGUREN_REALISTISCH=

echo === Fertig. Messungen unter messungen\ (Namen mit _figuren_alt und _figuren_neu), Fotos unter rundgang\
explorer "%APPDATA%\Godot\app_userdata\Sorrowland_ In Silentio"
pause
