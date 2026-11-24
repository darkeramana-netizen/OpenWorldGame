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
- **Lagen und Flicken (22.11.2026, Zweig `stoff-5`)**:
  - Stoff gegen Stoff:
    - Mit `unterlage_setzen` bleibt eine Schürze, ein Wappenrock oder der Kettenhemd-Schoß vor dem Stoff darunter
      (`STOFF_LAGEN` in `figur.gd`).
    - Bei der Einrichtung bekommt jeder freie Punkt den nächsten Punkt der Unterlage als Partner (höchstens 10 cm).
      In jedem Unterschritt hält er 1,2 cm Abstand vor ihm, entlang der Normalen der Unterlage, auf der Seite wie
      am Körper.
    - Die Unterlage wird mit ihrem Stand aus dem letzten Bild im Hauptstrang gelesen, damit beide gleichzeitig auf
      verschiedenen Kernen rechnen können.
  - Flicken: `anhaengen` hängt kleine Meshes an den Stoff. Jede Ecke merkt sich ihr nächstes Dreieck, ihre Lage
    darin und ihre Höhe über der Fläche. Die Flicken auf dem Rock gehen so mit dem echten Stoff mit.
  - Bilder: `docs/bilder/figuren-2026-11-22/stoff_lagen_vorher_nachher.jpg` (oben vorher, unten mit Lagen) und
    `stoff_flicken.jpg`.
  - Nachmessung 22.11.2026, 17:08 (Windows, mit echtem Stoff):
    - Messfahrt: Hoch 112,5 / 109,2 fps (alt/neu), Episch 58,1 / 57,4 fps, Bild p99 15,1 / 15,5 und
      22,9 / 23,7 ms, keine Hänger über 50 ms.
    - Anlauf: Die ersten Bilder nach dem Laden kosteten 8 bis 16 ms mehr. Das größte Bild nach dem Vorhang war
      20,6 statt 11,9 ms (Hoch) und 30,7 statt 20,4 ms (Episch).
    - Grafikspeicher: rund 280 MB mehr als mit alten Figuren (vorher 150 MB).
    - Ursache: Der Stoff wurde für alle 138 Figuren schon beim Bau eingerichtet, auch für ferne. Eine Einrichtung
      dauerte im Container 6 bis 14 ms, und der größte Teil davon steckte in der Haftung, die GDScript für jede
      Ecke einzeln ausrechnete.
    - Behoben:
      - Der Stoff wird erst eingerichtet, wenn eine Figur zum ersten Mal nah kommt, höchstens 2 Figuren je Bild.
      - Haftung nach Höhe im Modul (`einrichten_huefte`), mit Zwischenspeicher je Quelle: Ist das Modell schon
        bekannt, kostet die Einrichtung 0,6 ms (höchstens 1,1).
      - Die erste Figur je Modell richtet den Stoff schon beim Bau ein, meist noch hinter dem Ladevorhang.
      - Die beidseitige Materialkopie gibt es nur einmal je Ausgangsmaterial (`material_setzen`); vorher
        überschrieb `figur.gd` sie beim Umschalten mit dem einseitigen Material.
  - Nachmessung 22.11.2026, 18:05 (nach „erst nah einrichten"):
    - Anlauf unverändert: Ab Bild 5 kostete jedes Bild 8 ms (Hoch) bis 16 ms (Episch) mehr.
    - Grafikspeicher: rund 400 MB mehr als mit alten Figuren.
    - Eigentliche Ursache: Das schnelle Hochladen griff nie. Godot legt die Ecken in Blöcken ab: erst alle Orte
      (12 Byte je Ecke), dann alle Normalen mit Tangenten (8 Byte je Ecke). Die Prüfung erwartete eine verschachtelte
      Anordnung und brach stumm ab. Dadurch baute jeder nahe Stoff sein Mesh jedes Bild neu, mit Arbeit im
      Hauptstrang und neuem Grafikspeicher, den Godot erst verzögert freigibt.
    - Behoben:
      - Beide Anordnungen werden unterstützt: Schrittweite der Orte und der Normalen getrennt, vom RenderingServer
        erfragt.
      - Die Flicken nehmen denselben Weg.
      - Jeder Abbruch meldet sich jetzt mit einer Warnung, und `schnell_aktiv()` zeigt den Stand je Stoff.
    - Container mit 40 Menschen, mehrere Kerne: Hochladen 0,9 statt 4,4 ms, insgesamt 7,2 statt 10,5 ms je Bild.
  - Nachmessung 22.11.2026, 18:52 (mit schnellem Hochladen): Der Anlauf ist auf Windows weiter 8 ms (Hoch) bzw.
    16 ms (Episch) teurer, im Wechsel mit Bildern ohne Mehrkosten. Der Grafikspeicher liegt weiter 400 MB höher.
    - Messung ohne Grafik im Container: Im Anlauf rechnet der Stoff 1 bis 3 nahe Stoffe in etwa 0,5 ms je Bild.
      Läuft der Stoff, wird aber nie nah, kostet der Anlauf so viel wie ganz ohne Stoff. Die Mehrkosten entstehen
      also erst, wenn Figuren nah umschalten. Wiederholungen streuen im Container allerdings um bis zu 5 ms, daher
      ist das kein Beweis.
    - Verdacht: Der Takt hat auf Godots Thread-Pool gewartet. Der ist im Anlauf mit Shadern und Hintergrund-Laden
      voll, und der Hauptstrang wartete, bis der Pool überhaupt zum Stoff kam.
    - Geändert:
      - Der Hauptstrang rechnet selbst mit und nimmt sich jeden Stoff, den noch kein Helfer angefangen hat. Er
        wartet nur auf Stoffe, die gerade in Arbeit sind.
      - Helfer, die später drankommen, finden nichts mehr vor. Ihre Gruppen werden im nächsten Bild aufgeräumt.
    - Zum Gegenprüfen misst `werkzeuge\messung_figuren.bat` jetzt zusätzlich `hoch_figuren_neu_ohne_stoff`
      (`STOFF_AUS=1`). `STOFF_STATISTIK=1` gibt alle 60 Bilder Anzahl und Zeit des Stoffs aus.
  - Offen bleibt der Kittelstreifen unter dem Kettenhemd: Er legt sich wie ein Schlauch um den Oberschenkel. Das
    lässt sich im Bauskript beheben (breiter oder weglassen) und war mit Federknochen genauso.

## Verdeckungsprüfung (Occlusion Culling), 23.11.2026

Was hinter Mauern und Häusern liegt, wird nicht mehr gezeichnet. Godot bringt das mit (`project.godot`:
`rendering/occlusion_culling/use_occlusion_culling`), dafür ist kein Modul nötig. Die Verdecker baut
`szenen/welt/verdecker.gd`:

- **Mauern** (`burgbau.gd`): Jedes Mauerstück wird ein Quader vom Fuß bis knapp unter den Wehrgang, ohne Zinnen.
  Frei bleibt er an Toren und Nachbartoren, Tortürmen und Türmen, denn dort kann man hindurch- oder hineinsehen.
- **Häuser** (`stadthaeuser.gd`): je Haus ein Quader innerhalb der Mauern, vom Erdgeschoss bis unter die Traufe.
  Begehbare Häuser bekommen keinen, damit man von innen durch die Fenster hinaussieht.
- Grundsatz: Ein Verdecker ist immer etwas kleiner als der Bau. Er darf nie mehr verdecken als der Bau selbst.
- `VERDECKUNG_AUS=1` schaltet die Verdeckung zum Vergleich ab (`autoload/grafik.gd`).

Probe `tests/_verdeckung_probe.gd`: 10 feste Blickpunkte in Drachenstein, je mit und ohne Verdeckung.

| Blickpunkt | Objekte | Draw Calls | Dreiecke |
|---|---|---|---|
| Markt | 2836 → 2643 | 2110 → 1917 | 9,07 → 8,16 Mio. |
| Nordtor | 2397 → 1814 | 1793 → 1210 | 7,78 → 6,78 Mio. |
| Südtor | 5235 → 4066 | 4583 → 3444 | 11,29 → 9,98 Mio. |
| Vorburg | 5277 → 4405 | 4494 → 3702 | 9,56 → 9,06 Mio. |
| Mittelburg | 3972 → 2451 | 3370 → 1855 | 5,74 → 4,20 Mio. |
| Oberburg | 2803 → 2535 | 2162 → 1918 | 4,51 → 4,11 Mio. |
| Stadt aus der Luft | 5192 → 5184 | 4588 → 4580 | 11,41 → 11,41 Mio. |
| Summe (10 Punkte) | −15 % | −17 % | −8 % |

Die Bildpaare unterscheiden sich nur durch bewegte Menschen, Tiere, Bäume, Namensschilder und Schattenkanten.
Es fehlt nichts, was man sehen müsste. Aus der Luft verdeckt erwartungsgemäß nichts.

Noch nicht verdeckt und als Nächstes lohnend:
- das Gelände (Burgberg und Hügel verdecken ganze Stadtteile);
- die massiven unteren Teile von Türmen und Burggebäuden;
- Bewuchs als Ganzes: Ein MultiMesh wird nur als Ganzes verdeckt, nicht je Baum.

## Stoff: Warten auf die Grafikkarte (24.11.2026)

Messung 24.11.2026, 16:31 (Windows, mit Verdeckung), Anlauf auf Hoch, Bild 6 bis 12:

| | Bildzeit | davon nach dem Zeichnen |
|---|---|---|
| alte Figuren | 10 bis 12 ms | 5 ms |
| neue Figuren mit Stoff | 19 bis 21 ms | 12 bis 13 ms |
| neue Figuren ohne Stoff (`STOFF_AUS=1`) | 11 bis 13 ms | 5 ms |

- Der teurere Anlauf kommt vom Stoff. Er kostet etwa eine Bildzeit der Grafikkarte (Hoch etwa 9 ms, Episch etwa
  17 ms): Der Prozessor wartet auf die Grafikkarte.
- Im Anlauf wird gar kein Stoff gerechnet. Die Messung weist jetzt `stoff_ms` mit `stoffe_max` je Abschnitt aus.
  Ursache ist das Einrichten: `surface_get_arrays` und `mesh_get_surface` lesen die Mesh-Daten von der Grafikkarte
  zurück. Godot 4 hält sie nicht im Arbeitsspeicher und wartet dafür, bis die Grafikkarte alles Bisherige fertig hat.
  Das Vorwärmen je Modell beim Bau tat das mehrfach je Figur, ebenso jede Figur, die nah kam, und jeder Flicken.
  Im Software-Renderer des Containers kostet das nichts, deshalb war es dort nicht zu sehen.
- Behoben:
  - Mesh-Daten und Anordnung des Eckpuffers werden je Quelle nur einmal gelesen und zwischengespeichert. Neue
    Meshes entstehen aus den eigenen Daten statt aus Rücklesungen.
  - Dreifache Pufferung: Je Stoff und Flicken gibt es drei Meshes. Beschrieben wird immer das, das die Grafikkarte
    seit zwei Bildern nicht mehr liest.
  - Einrichten mit bekanntem Modell: 0,3 ms je Mensch.
- Grafikspeicher: Mit und ohne Stoff gleich (2017 MB gegen 1633 MB mit alten Figuren). Die rund 380 MB kommen von
  den neuen Figuren selbst, nicht vom Stoff. Die Modelldateien sind seit der Messung vom 22.11. (+150 MB) gleich
  groß; der Zuwachs ist noch offen.
- Verdeckungsprüfung auf der Messfahrt Hoch: Draw Calls 2410 → 1608 (−33 %), Grafikkarte 8,2 → 7,7 ms.

## Grafikspeicher der neuen Figuren (24.11.2026)

Die rund 380 MB mehr Grafikspeicher mit realistischen Menschen kamen nicht vom Stoff (Messung mit `STOFF_AUS=1`:
gleich viel). Ursache waren die Texturen. Alle 130 Bilder der Menschen und 39 der Ausstattung waren verlustfrei
ohne Mipmaps importiert (`compress/mode=0`, `mipmaps/generate=false`). Godot stellt Bilder neben einem glTF erst im
geöffneten Editor auf komprimiert um (`detect_3d`). Ohne Editor blieben sie unkomprimiert, und ohne Mipmaps
flimmerten feine Muster in der Ferne.

- Behoben:
  - Alle diese Importe sind jetzt VRAM-komprimiert mit Mipmaps, Normalmaps als Normalmap.
  - `werkzeuge/textur_import.py` setzt das nach jedem Bau (`menschen_vorrat.py`, `modell_laden.py`).
  - Gelände-Daten (Höhen) bleiben bewusst verlustfrei.
- Probe `tests/_grafikspeicher_modelle.gd` (alle 17 Menschenmodelle je einmal): 415 → 126 MB.
- Je Exemplar (`tests/_grafikspeicher.gd`) kostet ein Mensch nur etwa 0,6 MB; davon gehen 0,13 MB auf die
  Fern-Fassungen.
- Bildvergleich: Gesichter, Haare und Leder sehen gleich aus, Stoffe flimmern nicht mehr (kein Moiré).
