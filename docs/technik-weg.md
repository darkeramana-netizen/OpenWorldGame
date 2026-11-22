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
- **Nachmessung 22.11.2026, 12:25** (Stand mit Laden im Hintergrund und geladenem Modul, DLL lädt auf Windows):
  | | Hoch alt | Hoch neu | Episch alt | Episch neu |
  |---|---|---|---|---|
  | Messfahrt fps | 112,0 | 109,9 | 46,5 | 56,8 |
  | Bild p99 ms | 15,1 | 15,5 | 25,2 | 24,0 |
  | Hänger > 50 ms (Fahrt) | 0 | 0 | 0 | 0 |
  | Hänger > 50 ms (Anlauf) | 3 | 4 | 3 | 4 |
  | spielbar nach ms | 9511 | 10398 | 9337 | 10289 |
  | Grafikspeicher MB | 1634 | 1786 | 2057 | 2230 |
  | größter Zellbau ms | 29,7 | 134,0 | 28,1 | 60,7 |

  Anlauf-Hänger von 18 auf 4 (alte Figuren 3), alle hinter dem Ladevorhang (größtes Bild danach 14 ms Hoch, 19 ms
  Episch). Der Rest liegt an neuen Shader-Pipelines (Haut, Haar) in den Bildern 2 bis 4 und kostet knapp 0,9 s bis
  spielbar. Episch alt ist in diesem Lauf ausgerissen (vorher 58,7 fps), also Streuung. Offen: der größte Zellbau
  (134 ms) mit Menschen, später Pipelines vorwärmen und Zellbau mit Menschen stückeln.
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
