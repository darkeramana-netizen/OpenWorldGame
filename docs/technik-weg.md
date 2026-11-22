# Technikweg: eigene Engine Schritt für Schritt auf Godot

Beschlossen am 22.11.2026.

## Grundsatz

Godot 4.7.2 bleibt die Grundlage (Renderer, Physik, Editor, Plattformen). Darauf entsteht nach und nach eine eigene
Technikschicht aus GDExtension-Modulen in C++. Über die Zeit wird diese Schicht unsere Engine, wiederverwendbar für
andere Projekte, so wie Studios eine fremde Engine nehmen und Teil für Teil durch eigene ersetzen.

## Regeln

1. **Erst messen, dann ersetzen.** Ein Teil wird nur dann ein C++-Modul, wenn eine Messung (Messwerkzeug,
   `docs/03-messgrundlage.md`) eine echte Grenze in GDScript zeigt: zu langsam, zu viel Speicher, nicht machbar.
2. **GDExtension, kein eigener Godot-Build.** Module sind Bibliotheken, die das unveränderte Godot lädt (wie Terrain3D).
   Ein eigener Build von Godot (z. B. für Eingriffe in den Renderer) bleibt ausgeschlossen, bis eine Messung zeigt,
   dass es ohne nicht geht; das entscheidet der Projektinhaber.
3. **Eigenes Repository.** Module, die für andere Projekte taugen, kommen in ein eigenes Repository mit eigenen
   Tests; dieses Spiel bindet sie als fertige Bibliotheken ein (mindestens Windows und Linux).
4. **Gleiche Schnittstelle.** Ein Modul ersetzt eine bestehende GDScript-Lösung mit derselben Schnittstelle, damit
   Bauskripte, Szenen und Tests weiterlaufen; die GDScript-Fassung bleibt als Rückfall, bis das Modul geprüft ist.
5. **Lizenz.** Nur eigener Code oder freie Bibliotheken mit passender Lizenz (CC0, MIT, BSD, zlib).

## Kandidaten (in der Reihenfolge, in der sie wahrscheinlich an Grenzen stoßen)

| Bereich | heute | wann ein Modul |
|---|---|---|
| Menschenmengen: KI, Tagesablauf, Animation in der Ferne | GDScript je Figur (`figur.gd`, `person.gd`) | wenn viele Menschen die Bildrate drücken |
| Stoff | Federknochen (`SpringBoneSimulator3D`) | wenn Hauptfiguren echte Tuchsimulation brauchen |
| Weltstreaming und Gelände | Zellwelt in GDScript, eigenes Gelände | bei größeren Regionen oder Hängern beim Nachladen |
| Menschen-Baukasten | Python (`werkzeuge/mensch_bauen.py`) | wenn Menschen zur Laufzeit erzeugt werden sollen |
| Prozedurales Bauen (Burgen, Städte, Flur) | Python-Bauskripte | wenn Orte zur Laufzeit entstehen sollen |
| Wegfindung für viele | Godot-Navigation | bei großen Mengen gleichzeitiger Wege |

## Stand

- **Messung 22.11.2026** (Ryzen 7 9800X3D, RTX 5060 Ti, Drachenstein): realistische Menschen kosten bei der Bildrate
  kaum etwas (Hoch 110 statt 103 fps, Episch 56,8 statt 58,7 fps); die Hänger beim Anlauf lagen am synchronen Laden und
  sind in GDScript behoben (Laden im Hintergrund). Menschenmengen brauchen vorerst kein Modul.
- **Erstes Modul: Stoff** (beschlossen am 22.11.2026). Echte Tuchsimulation (Positionsdynamik: jede Stoffecke einzeln,
  mehrere Durchgänge je Bild, Kollision mit Beinen, Hüfte und Armen, Wind) ist in GDScript nicht machbar. Plan:
  1. C++-Modul als GDExtension, eigenes Repository, Linux und Windows.
  2. Echter Stoff nur nah (etwa bis 15 m), weiter weg die heutigen Federknochen als Rückfall.
  3. Prototyp mit einem Kittel und einem Kleid, Bildfolgen im Gang, Messung, wie viele Figuren gleichzeitig gehen.
- **Repository** `darkeramana-netizen/sorrowland-module` (eine Bibliothek `sorrowland` für alle Module, godot-cpp 4.5,
  Linux und Windows aus diesem Container gebaut). Im Spiel unter `addons/sorrowland_module/`.
- **Stand Stoff (22.11.2026)**: Klasse `Stoff` läuft im Spiel (Probe `tests/_stoff_foto.gd`): Kleid 625 Punkte,
  Kittel 396 Punkte, etwa 0,5 ms je Figur und Bild (Debug, ein Kern). Bild:
  `docs/bilder/figuren-2026-11-21/stoff_federknochen_gegen_echt.jpg` (Zeilen 1 und 3 Federknochen, 2 und 4 Stoff).
  Noch nicht in `figur.gd` eingebunden.
