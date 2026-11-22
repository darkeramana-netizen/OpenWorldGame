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
- **Stoff im Spiel (22.11.2026, Zweig `stoff-2`)**:
  - Feinschliff: Der Stoff wird beidseitig gezeichnet (Falten zeigen die Innenseite, vorher Löcher). Er haftet oben
    bis über die Hüfte (12 cm fest, 12 cm Übergang). Ruhigere Standardwerte: Biegung 0,0003, Dämpfung 0,05,
    Mitnahme 0,97, vier Durchgänge.
  - Heller Streifen an der Taille des Kleids: Die Ursache lag im Bauskript, nicht in der Physik. Die oberste
    Rockreihe folgte zu gut der Hälfte den Beinen und riss beim Gehen unter dem Gürtel auf, und unter dem Kleid
    fehlten Hüfte und Gesäß. Behoben: Der Anteil der Beine wächst erst zur Hüfte hin, und das Oberteil reicht beim
    Kleid über die Hüfte.
  - Eingebunden in `figur.gd` (`stoff_echt_einrichten`, `_stoff_umschalten`):
    - Bis 12 m echter Stoff (zurück erst ab 14 m), die Federknochen sind dann aus.
    - Weiter weg wie bisher Federknochen, ab 20 m die vereinfachte Fassung.
    - Ohne Bibliothek (`ClassDB.class_exists("Stoff")`) und bei Überkleidung (Schürzen, Wappenrock) bleibt alles
      bei den Federknochen.
  - Rechenzeit: 6 Figuren nah zusammen 3,3 ms je Bild (Debug-Bibliothek, ein Kern, Container).
  - Bilder: `docs/bilder/figuren-2026-11-22/stoff_vorher_nachher.jpg` und `stoff_nah_fern_umschalten.jpg`.
  - Probe: `tests/_figur_stoff.gd`.
  - Nächste Schritte: Schürzen und Wappenröcke als echter Stoff, Rechnung auf mehrere Kerne, Messung mit vielen
    Figuren.
- **Überkleidung als Stoff (22.11.2026, Zweig `stoff-3`)**:
  - Teile: Schürze, Lederschürze, Wappenrock (vorn und hinten) und der Kettenhemd-Schoß laufen nah ebenfalls als
    Stoff (`STOFF_TEILE` in `figur.gd`).
  - Werte je Teil: Biegung, Dämpfung, Beinkapseln und Bewegungsraum. Bahnen bekommen dickere Kapseln, weil der Rock
    dazwischen liegt, und nur 6 bis 7 cm Bewegungsraum, weil sie flach sind. Leder und Kettengeflecht sind steifer.
  - Modul:
    - Ein Punkt im Bein wird zu der Seite geschoben, auf der sein Platz am Körper liegt, nicht einfach von der
      Achse weg. Sonst rutschte die Schürze beim Schritt hinter den Oberschenkel.
    - Die Beine werden am Ende jedes Unterschritts noch einmal geprüft und haben Vorrang vor dem Bewegungsraum.
  - Bauskript: Unter Bahnen hat der Rock für die Federknochen eine Aussparung. Mit echtem Stoff klaffte sie auf.
    Deshalb gibt es zusätzlich `Kittelrock_voll` ohne Aussparung, unsichtbar und nur Quelle des Stoffs.
  - Rock-Flicken hängen an den Rockknochen und werden nah ausgeblendet.
  - Bilder: `docs/bilder/figuren-2026-11-22/ueberkleidung_stoff_seite.jpg` (Koch, Schmied, Magd, Wache) und
    `ueberkleidung_aussparung_gegen_voll.jpg` (oben mit Aussparung, unten voller Rock).
  - Offen:
    - Der graue Kittelstreifen unter dem Kettenhemd legt sich wie ein Schlauch um den Oberschenkel (auch mit
      Federknochen).
    - Am Saum der Schürze sticht der Rock stellenweise durch; dagegen hilft Kollision Stoff gegen Stoff.
    - Flicken in den Stoff übernehmen.
- **Stoff auf mehreren Kernen (22.11.2026, Zweig `stoff-4`)**:
  - Aufbau:
    - Jeder Stoffschritt ist dreigeteilt: `vorbereiten` (Hauptstrang, liest Knochen), `rechnen` (beliebiger Strang,
      nur eigene Daten) und `hochladen` (Hauptstrang).
    - Die Figuren melden ihre Stoffe mit `vormerken(delta)` an. Der Knoten `StoffTakt` (unter der Wurzel, von
      `figur.gd` angelegt) rechnet am Ende des Bildes alle gemeinsam, verteilt über Godots `WorkerThreadPool`.
    - Hochladen schreibt nur noch den Eckpuffer (Ort, Normale), statt das Mesh jedes Bild neu aufzubauen. Beim
      ersten Mal wird das eigene Format gegen Godots Puffer geprüft; passt es nicht, gibt es eine Warnung und den
      alten Weg.
  - Statt 6 Unterschritten mit 4 Durchgängen jetzt 8 Unterschritte mit 1 Durchgang. Das Rechnen kostet die Hälfte,
    und im Bild ist kaum ein Unterschied zu sehen. Die Beine werden nur noch am Ende jedes Unterschritts geprüft.
  - Messung im Container (4 Kerne, Software-Renderer, `tests/_stoff_last.gd`), alle Menschen gehen nah mit
    echtem Stoff:

    | Menschen | Stoffe | Punkte | ein Kern | mehrere Kerne |
    |---|---|---|---|---|
    | 10 | 16 | 5 267 | 5,7 ms | 3,2 ms |
    | 20 | 28 | 10 153 | 10,6 ms | 5,6 ms |
    | 40 | 58 | 20 787 | 21,6 ms | 10,5 ms |

    Vorher (6×4, ein Kern, ganzes Mesh neu) kosteten 40 Menschen 44,8 ms. Bei mehreren Kernen entfallen gut 40 %
    aufs Hochladen (Hauptstrang). Auf einem Ryzen 7 9800X3D mit 16 Strängen ist deutlich weniger zu erwarten;
    nachmessen mit `tests/_stoff_last.gd`.
