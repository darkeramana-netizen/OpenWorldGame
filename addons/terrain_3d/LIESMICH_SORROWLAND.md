# Terrain3D im Projekt

Terrain3D 1.1.0 (MIT, https://github.com/TokisanGames/Terrain3D), läuft mit Godot 4.5 bis 4.8.
Übernommen aus dem Release `Terrain3D_v1.1.0-stable.zip`, gekürzt auf das, was das Spiel braucht:

- Binärdateien nur für Windows und Linux (x86_64, debug und release); C#-Teil und Pinsel des Editor-Werkzeugs entfernt.
- Das Editor-Plugin ist nicht eingeschaltet: Das Gelände entsteht beim Laden aus `daten/<gelaende>/hoehen.r32`
  (`szenen/welt/gelaende_terrain3d.gd`), nicht durch Malen im Editor.

Nach dem Einspielen den Editor einmal öffnen (oder `godot --headless --path . --import`), damit Godot die Erweiterung
in `.godot/extension_list.cfg` einträgt.
