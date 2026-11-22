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

Noch kein Modul. Die erste Bildratenmessung mit vielen realistischen Menschen entscheidet, ob die Menschenmengen das
erste werden.
