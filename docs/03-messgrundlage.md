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

## Ausgangswerte mit Grafik (Referenzrechner)

Datei: `docs/messungen/messung_drachenstein_mein_rechner_2026-11-16T16-25-03.json`. Rechner: AMD Ryzen 7 9800X3D
(8 Kerne, 16 Threads), NVIDIA GeForce RTX 5060 Ti, Windows, 1920×1080, Forward+, VSync aus. Strecke vollständig
(69 von 69 Wegpunkten in 113 s).

**Laden:** bis spielbar 14,9 s (Datei 0,8 s, `_ready()` 10,7 s, davon `burgbau` 6,2 s und allein die Einrichtung der
Fachwerkhäuser 3,7 s; Stadthäuser 1,5 s, Felsmassiv 1,5 s). Direkt danach ein Bild von 3,1 s (Anlauf-Hänger).

| Phase | fps | Frame p50 / p95 / p99 / Max | Draw Calls p50 / p95 / Max | Dreiecke je Bild p50 / p95 / Max | Objekte p95 | Hänger >33 / >50 ms |
|---|---|---|---|---|---|---|
| Anlauf | 82 | 8,2 / 9,2 / 9,8 / 3.092 ms | 3.517 | 4,7 Mio. | 4.231 | 2 / 2 |
| Messfahrt | 92 | 10,6 / 13,6 / 15,7 / 38,6 ms | 7.370 / 13.550 / 14.825 | 12,3 / 16,9 / 18,7 Mio. | 14.627 | 2 / 0 |
| Rundblick im Palas | 88 | 11,5 / 13,1 / 14,5 / 15,8 ms | 9.261 / 12.148 / 12.239 | 13,4 / 15,0 / 15,1 Mio. | 12.944 | 0 / 0 |

Speicher 1,53 GB, Grafikspeicher 1,79 GB. Sichtweiten-Wechsel 90 je Sekunde, davon 45 näher als 50 m.

**Einordnung:** Auf einem sehr schnellen Rechner läuft eine einzige Region mit 92 fps im Mittel und 74 fps im p95.
Draw Calls (p95 13.550) liegen beim Viereinhalbfachen, Dreiecke je Bild (p95 16,9 Mio.) beim Doppelten des
vorgeschlagenen Budgets. Für die ganze Welt und für schwächere Rechner reicht das nicht. Ob die Grafikkarte oder die
CPU-Seite des Renderns bremst, zeigt die nächste Messung: Das Werkzeug misst seit dieser Auswertung auch die
Renderzeit auf der CPU und auf der Grafikkarte (`render_cpu_ms`, `gpu_ms`).

**Woher die Last kommt** (aus der Szenenzählung): Objekte je Bild (p95 14.627) entsprechen fast den Draw Calls; viele
kleine Objekte, mehrfach gezeichnet (Schattenkaskaden der Sonne). Die größten Posten sind die 122 Personenfiguren
(3,35 Mio. Dreiecke in 1.574 Meshes ohne Detailstufen), 2.348 MultiMesh-Knoten mit im Schnitt 10 Exemplaren und
1.157 Meshes für Tauben, Möwen und Hühner (je ein Mesh pro Körperteil).

## Budgets (Vorschlag)

Zielhardware für 60 fps: ein Mittelklasse-Rechner (etwa RTX 3060 oder RX 6600, sechs Kerne der Klasse Ryzen 5 3600)
in 1920×1080 mit hohen Einstellungen. Gemessen wird auf dem Referenzrechner oben; damit dort genug Reserve für die
Zielhardware bleibt, gelten auf dem Referenzrechner die doppelten Bildraten (120 fps im p95).

| Messwert | Budget auf dem Referenzrechner | heute |
|---|---|---|
| Ladezeit bis spielbar | ≤ 8 s | 14,9 s |
| Anlauf nach dem Laden | kein Bild über 100 ms | 3.092 ms |
| Frame (Fahrt und Rundblick) | p95 ≤ 8,3 ms (120 fps), p99 ≤ 11 ms | p95 13,6 ms, p99 15,7 ms |
| Hänger in der Fahrt | 0 über 50 ms, höchstens 1 je Minute über 33 ms | 0 / 2 |
| Draw Calls | p95 ≤ 3.000 | 13.550 |
| Dreiecke je Bild (mit Schatten) | p95 ≤ 6 Mio. | 16,9 Mio. |
| Arbeitsspeicher | ≤ 4 GB (ganze Welt mit Streaming) | 1,5 GB (eine Region) |
| Grafikspeicher | ≤ 3 GB (Zielhardware hat 8 GB) | 1,8 GB |
| Sichtweiten-Wechsel | 0 näher als 50 m, Fernmodelle mit Überblendung | 45 näher als 50 m |

Die Budgets gelten für die Strecke Markt → Palas als härtesten Fall (Stadt, Burg, viele Personen). Für jede neue
Region kommt eine eigene Messstrecke dazu.

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
7. **Mit Grafik** (Referenzrechner, siehe oben): Draw Calls und Dreiecke je Bild sind die größten Abweichungen vom
   Budget. Die wirksamsten Hebel nach der Zählung: Detailstufen und Sichtweiten für die Figuren, die vielen kleinen
   MultiMesh-Knoten zusammenfassen, Tiere als ein Mesh statt eines pro Körperteil, kleine Dinge ohne Schatten.
