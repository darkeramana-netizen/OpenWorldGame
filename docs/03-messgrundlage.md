# Messgrundlage und Budgets (Phase 0)

Bevor an der Technik der Welt etwas umgebaut wird (Backen, Kacheln und Streaming, Gelände), legt diese Phase fest, **was
gemessen wird, wie, und welche Werte gelten**. Jede spätere Phase wird an diesen Zahlen gemessen: Sie muss die Werte
verbessern oder darf sie zumindest nicht verschlechtern, und die Tests bleiben grün.

## Das Messwerkzeug

`werkzeuge/messen/messung.gd` misst eine Region, ohne am Spiel etwas zu ändern. Aufruf aus dem Projektordner:

```
godot --path . --script res://werkzeuge/messen/messung.gd -- --name mein_rechner
```

- **Mit Grafik starten** (ohne `--headless`), sonst bleiben Draw Calls, Dreiecke je Bild und Grafikspeicher 0. Das
  Werkzeug schaltet VSync aus und hebt die Bildratenbremse auf, damit die echte Frametime gemessen wird.
- Weitere Angaben nach `--`: `--region drachenstein`, `--strecke stadt_palas` (Standard) oder `kurz` oder `keine`,
  `--aufloesung 1920x1080`, `--ausgabe <Ordner>`.
- Ergebnis: `messung_<region>_<name>_<zeit>.json` (alle Werte) und `.txt` (Zusammenfassung) in `user://messungen/`,
  unter Windows `%APPDATA%\Godot\app_userdata\Sorrowland_ In Silentio\messungen\`. Der Pfad steht am Ende der Ausgabe.
- Ablauf: Laden (mit Zeit je `_ready()`), 10 s Anlauf, Sprung an den Start der Strecke, Messfahrt (die Spielfigur
  rennt mit echter Physik die Strecke von `test_region` vom Markt durch Stadt, Vorburg, Mittelburg, Zwinger und
  Oberburg in den Palas, mit Eid, damit die Torwachen öffnen), am Ende 8 s Rundblick.
- `tests/test_messung.gd` prüft das Werkzeug mit der kurzen Strecke.

## Die Messwerte

| Messwert | Woher | Bedeutung |
|---|---|---|
| **Ladezeit** | eigene Zeitmessung | Datei lesen, Instanziieren, Einhängen mit allen `_ready()`, bis 5 Bilder gezeichnet sind; dazu die Zeit je Bauart (Skript), über das `ready`-Signal jedes Knotens |
| **Anlauf** | Frame-Werte der ersten 10 s | Bewuchs und Ausstattung setzen sich erst nach dem ersten Physikschritt; Shader werden beim ersten Zeichnen kompiliert. Ein langes erstes Bild zählt hier, nicht in der Fahrt |
| **Speicher** | `MEMORY_STATIC`, `RENDER_VIDEO_MEM_USED` | Arbeitsspeicher der Engine (Höchstwert) und Grafikspeicher (nur mit Grafik) |
| **CPU** | eigene Frametime je Bild | Ohne Grafik ist die Frametime die CPU-Zeit des Hauptthreads (Skripte, Physik, Szenenverwaltung). Godots `TIME_PROCESS` und `TIME_PHYSICS_PROCESS` sind die Spitze der letzten Sekunde, nicht der Wert je Bild; sie stehen als `prozess_spitze_ms` und `physik_spitze_ms` in der Datei |
| **Draw Calls** | `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` | je Bild, mit Schattenpässen (nur mit Grafik). Statische Obergrenze: Zahl der Mesh-Oberflächen in der Szene |
| **Dreiecke** | `RENDER_TOTAL_PRIMITIVES_IN_FRAME` | je Bild, mit Schattenpässen (nur mit Grafik). Dazu die Dreiecke der ganzen Szene je Herkunft (Bauart) |
| **LOD-Wechsel** | Auswertung der Kamerafahrt | Wie oft ein Knoten mit Sichtweite (`visibility_range`) entlang der Fahrt ein- oder ausgeblendet wird, je Sekunde, und wie oft näher als 50 m (sichtbares Aufploppen). Echte Mesh-Detailstufen gibt es heute nicht |
| **Hänger** | Frametime je Bild | Bilder über 33 ms (unter 30 fps) und über 50 ms, getrennt für Anlauf, Fahrt und Rundblick. Mit Streaming (Phase 2) kommen die Hänger an Kachelgrenzen hinzu |

Alle Frame-Werte stehen als p50 (Median), p95, p99 und Höchstwert in der Datei.

## Ausgangswerte: Drachenstein (ohne Grafik)

Gemessen im Entwicklungscontainer (Linux, 4 Kerne Xeon 2,1 GHz, keine Grafikkarte, `--headless`), Stand
burg-ausbau-8. Ohne Grafik fehlen Draw Calls, Dreiecke je Bild und Grafikspeicher, und das Laden enthält weder das
Hochladen der Texturen noch das Kompilieren der Shader.

Datei: `docs/messungen/messung_drachenstein_container_headless_2026-11-16T09-26-57.json` (Strecke Markt → Palas,
69 von 69 Wegpunkten in 113 s).

**Laden** (bis spielbar etwa 28 s):

| Schritt | Zeit |
|---|---|
| Datei lesen (`region_drachenstein.tscn`, 600 KB) | 4,2 s |
| Instanziieren | 0,02 s |
| Einhängen mit allen `_ready()` | 20,0 s |
| bis 5 Bilder gezeichnet sind (Bewuchs und Ausstattung setzen sich) | 28,3 s ab Beginn |

`_ready()` je Bauart: `burgbau` 9,9 s (64 Knoten; davon allein die Einrichtung der Fachwerkhäuser,
`HofhausEinrichtung`, 6,1 s), `felsen` 3,2 s, `stadthaeuser` 2,7 s, `felsmassiv` 2,6 s, `gelaende` 0,9 s,
`felssockel` 0,4 s, `turm` 0,2 s; 122 Personen zusammen 7 ms, 19 Tiere 14 ms.

**Szene**:

| Messwert | Wert |
|---|---|
| Knoten | 12.798 |
| Meshes / Oberflächen (Obergrenze Draw Calls) | 3.388 / 4.452 |
| Dreiecke in Meshes | 5,84 Mio., davon Personenfiguren 3,35 Mio. (1.574 Meshes, rund 27.000 Dreiecke je Figur, ohne Detailstufen), Bauten `burgbau` 1,24 Mio., Gelände 1,03 Mio. |
| MultiMesh / Exemplare | 2.348 / 24.163 (Bewuchs 17.435, Felsen 6.179, Ausstattung 293, Stadthäuser 256) mit zusammen 13,1 Mio. Dreiecken |
| Lichter | 373, keins mit Schatten (`burgbau` 124, Stadthäuser 107, Türme 64, Laternen und Feuer 77) |
| Kollisionskörper | 367 |
| Knoten mit Sichtweite | 5.335 |
| Arbeitsspeicher | 2,08 GB |

**Frame-Werte** (ohne Grafik = CPU-Zeit des Hauptthreads):

| Phase | Bilder | p50 | p95 | p99 | Max | über 33 ms | über 50 ms |
|---|---|---|---|---|---|---|---|
| Anlauf (10 s nach dem Laden) | 855 | 6,9 ms | 9,1 ms | 10,4 ms | 3.904 ms | 2 | 2 |
| Messfahrt (113 s) | 16.114 | 6,9 ms | 9,5 ms | 11,3 ms | 90 ms | 12 | 2 |
| Rundblick im Palas | 1.159 | 6,9 ms | 9,1 ms | 9,8 ms | 11 ms | 0 | 0 |

Godots Prozess-Spitze je Sekunde liegt in der Fahrt im Median bei 19 ms, die Physik-Spitze bei 4 ms: Einzelne Bilder
je Sekunde brauchen deutlich länger als der Median (vermutlich KI, Gras um den Spieler, Personen; in Phase 1 genauer
messen).

**Sichtweiten-Wechsel** entlang der Fahrt: 9.734 Wechsel (89 je Sekunde), davon 49 näher als 50 m.

## Ausgangswerte mit Grafik

Diese Werte fehlen noch: Sie entstehen auf dem Rechner, auf dem das Spiel laufen soll (Aufruf oben, mit `--name` und
der Zielauflösung). Die Datei kommt nach `docs/messungen/`, damit spätere Phasen dagegen vergleichen.

## Budgets (Vorschlag)

Ziel 60 fps auf der Zielhardware. Die Zahlen sind Vorschläge; sie werden nach der ersten Messung mit Grafik auf der
Zielhardware festgelegt.

| Messwert | Budget |
|---|---|
| Ladezeit | bis spielbar ≤ 15 s (Ziel 10 s) von SSD; Kachelwechsel ohne Ladebildschirm |
| Anlauf | kein Bild über 250 ms nach dem Laden (heute: ein Bild von etwa 4 s, Bewuchs und Ausstattung) |
| Speicher | RAM ≤ 4 GB, Grafikspeicher ≤ 3 GB im Standard-Preset |
| CPU | Hauptthread ≤ 8 ms (p95) in der Fahrt; Physik ≤ 2 ms; Skripte und KI ≤ 3 ms |
| Draw Calls | Burg und Stadt ≤ 3.000 (p95), Landschaft ≤ 1.500 |
| Dreiecke | ≤ 8 Mio. je Bild (p95, mit Schatten) |
| LOD-Wechsel | keine Wechsel näher als 50 m; Fernmodelle erst ab etwa 150 m, mit Überblendung |
| Hänger | in der Fahrt 0 Bilder über 50 ms, höchstens 1 je Minute über 33 ms |

## Was welche Maßnahme bewirkt

Backen allein macht das Laden schneller, sonst nichts. Die Zahlen der übrigen Messwerte ändern erst die Maßnahmen
dahinter:

| Maßnahme | wirkt auf |
|---|---|
| Backen (offline bauen, nur laden) | Ladezeit, CPU beim Laden |
| Kacheln und Streaming | Speicher, Ladezeit beim Start |
| Detailstufen je Mesh (LOD) | Dreiecke in Mittel- und Ferndistanz |
| Fernmodelle (HLOD), zusammengeführte Meshes, Materialatlanten | Draw Calls, Dreiecke in der Ferne |
| Verdeckung (Occluder) | Draw Calls und Dreiecke in Burg und Stadt |
| Licht-Budget, Sichtweite an Lichtern | GPU-Zeit |
| Arbeit nach dem Laden verteilen (Bewuchs, Ausstattung) | Anlauf-Hänger |

## Erkenntnisse aus der Ausgangsmessung

1. **Laden:** 20 s von 28 s sind `_ready()` der Bauskripte, also Geometrie, die bei jedem Start neu entsteht. Genau
   das spart das Backen. Größter Einzelposten ist die Einrichtung der Fachwerkhäuser (6,1 s), danach Felsen (3,2 s),
   Stadthäuser (2,7 s) und Felsmassiv (2,6 s). Auch das Lesen der Szenendatei (4,2 s) zählt: Sie enthält alle Daten
   als Text.
2. **Anlauf-Hänger:** Ein Bild von fast 4 s direkt nach dem Laden (Bewuchs und Ausstattung setzen sich im ersten
   Physikschritt). Das gehört verteilt oder gebacken.
3. **Dreiecke:** Die größte Last sind nicht die Burgen, sondern die Personenfiguren: 3,35 Mio. Dreiecke ohne
   Detailstufen. Detailstufen für Figuren (und Sichtweiten) bringen mehr als jede Maßnahme an den Bauten.
4. **Wiederholungen:** Bewuchs und Felsen sind schon MultiMesh, aber in 2.348 einzelnen Knoten mit im Schnitt nur
   10 Exemplaren; jeder ist ein eigener Draw Call. Zusammenfassen je Kachel und Art spart Draw Calls.
5. **Sichtweiten:** Bei 89 Wechseln je Sekunde und 49 Wechseln näher als 50 m ploppen Dinge sichtbar auf. Die
   Sichtweiten brauchen Überblendung (`visibility_range_fade_mode`) und größere Abstände für sichtbare Dinge.
6. **CPU:** Im Mittel (7 ms je Bild ohne Grafik) ist Spielraum, aber die Spitzen (Prozess-Spitze 19 ms je Sekunde,
   12 Bilder über 33 ms in der Fahrt) müssen in Phase 1 nach Ursache aufgeschlüsselt werden.
7. **Offen:** Draw Calls, Dreiecke je Bild und Grafikspeicher kann nur eine Messung mit Grafik zeigen.
