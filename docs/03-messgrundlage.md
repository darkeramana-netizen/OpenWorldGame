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

## Plan

Die Reihenfolge der Technik-Arbeit; jeder Punkt in einem eigenen Branch, mit Tests und Messung auf dem Referenzrechner.

**Phase 1: Leistung der bestehenden Region**

1. ✔ Figuren: Detailstufen, Sichtweiten, Schatten, Animation in der Ferne (burg-ausbau-9); Grafik-Paket B,
   Schattenhülle, weiches Ausblenden (burg-ausbau-9/10)
2. ✔ Laden und Hänger nach dem Laden: Texturen mit 3D-Import, Baucache, Arbeit verteilt (burg-ausbau-10);
   Ladebildschirm (burg-ausbau-11)
3. ✔ Gelände: Terrain3D gegen das eigene Gelände gemessen, Gewinn 1 bis 2 %; eigenes Gelände bleibt, Terrain3D als
   Schalter (burg-ausbau-12/13)

**Phase 2: Welt in Zellen nachladen (Streaming)**

Statt ganzer Regionen mit Ladebildschirm werden Zellen um den Spieler nachgeladen. Grundlage sind die Verfahren aus
Sorrow-Engine (`docs/04-sorrow-engine-auswertung.md`, Abschnitte 1 bis 3), in GDScript nachgebaut:

- Ladeliste nach Abstand, nur bei Zellwechsel neu; Zeitbudget je Bild für Laden und Einhängen; Entladen mit Puffer
  hinter der Sichtweite, geprüft alle 0,2 s; Kollision ein paar Bilder nach dem Mesh; Vorrang und Entdoppeln der
  Aufträge.
- Hintergrund-Threads nur für Daten (`WorkerThreadPool`), Dateien und Knoten auf dem Hauptthread, Schnappschuss vor
  dem Start, Ergebnisse über eine gesperrte Warteschlange.
- Spielstand je Zelle: nur Änderungen gegenüber den Grunddaten (Türen, aufgehobene Dinge, Gegner), gespeichert beim
  Entladen, mit Versionsnummer.
- Messung: Hänger an Zellgrenzen (siehe Messwerte), Speicher für die ganze Welt ≤ 4 GB.

**Später**

- Wetter: Regen, Schnee und Sturm nach dem Vorbild von `weather_system.gd` aus Sorrow-Engine (Teilchen folgen der
  Kamera, weiche Übergänge), angepasst an Aussehen, Regionen, Spielzeit und Jahreszeit; kein Regen unter Dächern und
  in Innenräumen.
- Himmel und Jahreszeiten: `PhysicalSkyMaterial` mit Jahreszeiten (Sorrow-Engine, `physical_sky.gd`) gegen unseren
  Himmel (`szenen/welt/tageslicht.gd`) mit Fotos vergleichen.
- Für den Export: Shader Baker von Godot, damit die Shader-Varianten nicht beim ersten Laden entstehen.

## Phase 1: Fortschritt

### Figuren (burg-ausbau-9)

Änderungen in `szenen/figuren/figur.gd`: kleine Teile (Augen, Brauen, Gürtel, Armschienen, Hüte, Dinge in der Hand)
werfen keinen Schatten und blenden bis 35 m aus; Körper und Kleidung blenden weich bis 130 m aus (vorher hart bei
140 m); die zur Laufzeit gebauten Köpfe haben Detailstufen; die Animation läuft nah jedes Bild, ab 25 m jedes zweite,
ab 60 m jedes vierte, außerhalb der Sichtweite gar nicht. Schattenwerfer unter den Figurteilen: 858 statt 1.574.

Messung auf dem Referenzrechner unter gleichen Bedingungen (Ladezeit 14,8 s wie in der Ausgangsmessung; ein erster
Lauf mit 20,4 s Ladezeit lief unter Hintergrundlast und zählt nicht):
`docs/messungen/messung_drachenstein_nach_figuren_retest_2026-11-16T17-56-02.json`.

| Messfahrt | vorher | nach den Figuren |
|---|---|---|
| Frame p50 / p95 / p99 | 10,6 / 13,6 / 15,7 ms | 10,2 / 12,6 / 14,7 ms |
| fps im Mittel | 92 | 97 |
| Draw Calls p95 | 13.550 | 12.647 (−7 %) |
| Dreiecke je Bild p95 | 16,9 Mio. | 16,4 Mio. (−3 %) |
| Grafikkarte p50 / p95 | (nicht gemessen) | 9,9 / 11,5 ms |
| Render-CPU p50 / p95 | (nicht gemessen) | 3,8 / 5,5 ms |
| sichtbar hart aufploppend | (nicht gemessen) | 3.250 |

**Erkenntnis:** Die Grafikkarte bestimmt die Bildzeit (9,9 ms von 10,2 ms im Median), nicht die CPU-Seite des
Renderns (3,8 ms). Weniger Draw Calls helfen deshalb wenig; es zählt, was die Grafikkarte rechnet: Dreiecke,
Schattenkaskaden (Sonne bis 500 m in vier Stufen), Effekte (SDFGI, SSAO, SSIL, MSAA, Nebel, Glow) und Überzeichnen.
Die Figuren waren nicht der Hauptposten. Hinweis: Ohne Grafik (im Container) liefert `get_aabb()` von MultiMeshes
leere Kästen; dort fehlt Aufploppen von Bewuchs, Felsen und Häusern in der Zählung. Gültig ist die Zählung mit Grafik.

### GPU-Aufschlüsselung (erste Messung)

Datei: `docs/messungen/messung_drachenstein_aufschluesselung_2026-11-16T18-06-39.json`. An zwei Blickpunkten wurde je
ein Effekt oder eine Objektgruppe abgeschaltet. Am Markt warf die Sonne zu Beginn noch keine Schatten (Spielstart um
6 Uhr, die Zeit lief); dort gilt die Schlussmessung (10,13 ms) als Bezug. Seither steht die Uhrzeit beim Messen fest
(Standard 10 Uhr), und Bezug ist das Mittel aus Anfangs- und Schlussmessung.

| abgeschaltet | spart Grafikkarte (Mittelburg / Markt) |
|---|---|
| Sonnenschatten | 2,54 / 2,72 ms (etwa 28 %); in der Mittelburg 5.240 der 7.327 Draw Calls |
| SDFGI | 1,75 / 1,72 ms (etwa 20 %) |
| Gelände | 1,21 / 1,75 ms |
| Häuser | 0,16 / 1,37 ms |
| MSAA | 0,47 / 0,90 ms |
| Bewuchs, Felsen | 0,36 / 0,64 ms und 0,38 / 0,54 ms |
| SSIL, Glow, SSAO, Nebel | je unter 0,6 ms |
| Figuren, Lampen | je unter 0,3 ms |
| Schatten nur bis 150 m statt 500 m | 0,29 / 0,11 ms |

**Erkenntnis:** Die Kosten der Sonnenschatten entstehen nah (viele kleine Schattenwerfer in den vorderen Stufen),
nicht in der Ferne. Zusammen mit SDFGI (6 Stufen, Zellen 0,3 m) und dem Gelände (volle Auflösung überall, aufwendiger
Shader) liegen hier die fehlenden etwa 3 ms. Die nächste Aufschlüsselung prüft deshalb Einstellungen statt nur an/aus:
Schattenkarte 4096 statt 8192, Schattenfilter niedrig, Sonnenschatten in 2 Stufen, SDFGI mit 4 Stufen oder doppelt
groben Zellen, kleine Dinge (unter 1 m) ohne Schatten; zu jeder Variante ein Vergleichsbild.

### GPU-Aufschlüsselung mit Einstellungs-Varianten (Uhrzeit 10, fest)

Datei: `docs/messungen/messung_drachenstein_aufschluesselung2_2026-11-16T18-18-04.json`. Drift klein (Markt 10,94 →
11,01 ms, Mittelburg 9,67 → 9,70 ms), die Werte sind verlässlich.

| Variante | spart Grafikkarte Markt / Mittelburg | spart Render-CPU | Bild |
|---|---|---|---|
| Sonnenschatten aus | 3,48 / 3,20 ms | 1,2 / 1,5 ms | (keine Lösung) |
| SDFGI aus | 1,46 / 1,66 ms | 0,1 / 0,2 ms | (keine Lösung) |
| Gelände aus | 1,64 / 1,39 ms | – | (Gelände-Entscheidung) |
| Häuser aus | 1,90 / 0,36 ms | 1,1 / 0,2 ms | |
| **Schattenkarte 4096 statt 8192** | **1,16 / 1,11 ms** | – | kein Unterschied erkennbar |
| **Sonnenschatten in 2 Stufen** | **0,92 / 0,85 ms** | 0,7 / 0,8 ms | nahe Schatten prüfen |
| MSAA aus | 0,77 / 0,51 ms | – | Kanten flimmern |
| Schatten nur bis 150 m | 0,33 / 0,69 ms | 0,4 / 0,6 ms | |
| **SDFGI mit 4 statt 6 Stufen** | **0,41 / 0,39 ms** | 0,1 ms | Ferne prüfen |
| Kleines (unter 1 m) ohne Schatten | 0,10 / 0,30 ms | 0,2 / 0,7 ms | |
| SDFGI-Zellen doppelt | 0,15 / 0,18 ms | – | |
| Schattenfilter niedrig | −0,20 / 0,11 ms | – | bringt nichts |
| SSAO, Nebel, Glow, Figuren, Lampen | je unter 0,35 ms | | |

### Übernommen: Grafik-Paket B

Nach der Aufschlüsselung mit Vergleichsbildern übernommen (alle Regionen, `werkzeuge/bau/grundlage.py` und die
Regionsszenen, `project.godot`): Schattenkarte 4096 statt 8192, Sonnenschatten in 2 statt 4 Stufen (erste Stufe bis
30 m), SDFGI mit 4 statt 6 Stufen, Dinge unter 1 m ohne Sonnenschatten (`region.gd`, `ohne_schatten_unter`, gilt auch
für alles, was später in die Region kommt). Erwartete Ersparnis auf der Grafikkarte etwa 2,5 ms.

Messfahrt auf dem Referenzrechner (`docs/messungen/messung_drachenstein_paket_b_2026-11-16T19-07-15.json`, Ladezeit
14,8 s wie in den Vergleichsläufen):

| Messfahrt | Ausgangsmessung | nach den Figuren | nach Paket B | Budget |
|---|---|---|---|---|
| fps im Mittel | 92 | 97 | **124** | |
| Frame p50 / p95 / p99 | 10,6 / 13,6 / 15,7 ms | 10,2 / 12,6 / 14,7 ms | **7,8 / 10,5 / 12,5 ms** | p95 ≤ 8,3 ms |
| Grafikkarte p50 / p95 | – | 9,9 / 11,5 ms | **7,5 / 9,1 ms** | |
| Render-CPU p50 / p95 | – | 3,8 / 5,5 ms | **2,7 / 3,6 ms** | |
| Draw Calls p95 | 13.550 | 12.647 | **5.969** | ≤ 3.000 |
| Dreiecke je Bild p95 | 16,9 Mio. | 16,4 Mio. | **9,2 Mio.** | ≤ 6 Mio. |
| Grafikspeicher | 1,79 GB | 1,79 GB | **1,53 GB** | ≤ 3 GB |
| Hänger über 33 ms (Fahrt) | 2 | 2 | **0** | ≤ 1 je Minute |
| sichtbar hart aufploppend | – | 3.250 | 3.209 | 0 näher als 50 m |

Die Grafikkarte spart wie erwartet 2,4 ms im Median, Draw Calls und Dreiecke halbieren sich (die Schattenstufen zeichnen
alles mehrfach). Offen bis zum Budget: Frame p95 um etwa 2,2 ms, Draw Calls um die Hälfte, Dreiecke um ein Drittel,
dazu Ladezeit (14,8 s statt 8 s), der Anlauf-Hänger (3,1 s) und das harte Aufploppen von Bewuchs, Felsen und Häusern.

### Schattenhülle, größere Natur-Kacheln, weiches Ausblenden

Schattenhülle (`szenen/welt/schattenhuelle.gd`) für Burgbauten und Häuser: im Sonnenschatten eine Oberfläche je Bau
statt eine je Material (Vergleichsfotos vorher/nachher: höchstens 0,46 % der Pixel verschieden, fast nur Rauch). Natur
und Pflanzen am Fels in größeren Kacheln (128 m und 96 m statt 64 m und 48 m), Natur, Ausstattung und Vögel blenden weich
aus, Möwen nur bis 120 m. Messung: `docs/messungen/messung_drachenstein_schattenhuelle_2026-11-17T16-19-15.json`.

| Messfahrt | nach Paket B | mit Schattenhülle | Budget |
|---|---|---|---|
| fps im Mittel | 124 | 122 | |
| Frame p50 / p95 / p99 | 7,8 / 10,5 / 12,5 ms | 8,0 / 10,9 / 13,0 ms | p95 ≤ 8,3 ms |
| Grafikkarte p50 / p95 | 7,5 / 9,1 ms | 7,6 / 9,4 ms | |
| Render-CPU p50 / p95 | 2,7 / 3,6 ms | 2,4 / 3,1 ms | |
| Draw Calls p50 / p95 | 3.365 / 5.969 | **2.052 / 3.437** | ≤ 3.000 |
| Dreiecke je Bild p95 | 9,2 Mio. | 8,6 Mio. | ≤ 6 Mio. |
| hart aufploppend | 3.209 | **37** | 0 näher als 50 m |
| Laden bis spielbar | 14,8 s | 16,2 s | ≤ 8 s |

**Erkenntnis:** Draw Calls fast halbiert und Aufploppen praktisch weg; die CPU-Seite des Renderns wird leichter. Die
Grafikkarte wird dadurch aber nicht schneller (eher 0,1 bis 0,3 ms langsamer): Draw Calls kosten vor allem CPU, und
das weiche Ausblenden zeichnet die Dinge im Übergang durchsichtig. Das Bauen der Hüllen kostet beim Laden etwa 0,5 bis
1 s (fällt mit dem Backen weg). Die nächste Aufschlüsselung misst, was Überblendung und Hülle auf der Grafikkarte kosten.

**Nachgemessen** (`docs/messungen/messung_drachenstein_aufschluesselung3_2026-11-17T16-42-28.json`, Drift unter 0,03 ms):
Die Überblendung kostet auf der Grafikkarte nichts (ohne sie −0,06 / −0,02 ms, also im Rauschen). Die Schattenhülle
spart (ohne sie +0,15 / +0,05 ms Grafikkarte, +0,38 / +0,21 ms Render-CPU, 3.266 / 3.367 statt 1.735 / 2.436 Draw
Calls). Beides bleibt. Die Grafikkarte braucht an den Blickpunkten jetzt 8,4 ms (Markt) und 7,5 ms (Mittelburg); die
größten Posten sind Gelände (1,40 / 1,05 ms), Sonnenschatten (1,29 / 1,26 ms), SDFGI (1,19 / 1,46 ms), Häuser am Markt
(0,98 ms) und MSAA (0,69 / 0,47 ms).

### Punkt 2: Laden und Hänger nach dem Laden (burg-ausbau-10)

Ursachen (gemessen im Container, je Schritt mit Zeitstempeln):

1. **Texturen ohne 3D-Import.** Alle Texturen unter `texturen/` und `modelle/` waren verlustfrei und ohne Mipmaps
   importiert. Godot erkennt 3D-Texturen sonst erst, wenn der Editor sie in einem 3D-Material sieht; unsere Materialien
   entstehen aber im Code. Folgen: Jede Textur wird beim Laden auf der CPU entpackt (96 % der Felsen-Bauzeit), liegt
   unkomprimiert im Grafikspeicher (2k: 16 MB statt 2,7 bis 5,6 MB) und wird ohne Mipmaps auch in der Ferne in voller
   Auflösung gelesen (langsamer, flimmert). `werkzeuge/texturen_3d.py` stellt 158 Texturen auf VRAM-Kompression mit
   Mipmaps um (Normalen- und Höhenkarten in hoher Qualität, BC7). Daten-Texturen (Höhenkarten und Masken unter `daten/`,
   Karte) und der Wolkenhimmel bleiben, wie sie sind. **Nach dem Umstellen muss Godot neu importieren** (Editor einmal
   öffnen oder `godot --headless --path . --import`).
2. **Burgbauten und Häuser werden bei jedem Start in GDScript gebaut** (574.000 Vierecke, 95.000 Quader; 6,8 s auf dem
   Referenzrechner). Das Ergebnis hängt nur von Code und Daten ab. Der **Baucache** (`szenen/welt/baucache.gd`)
   speichert es nach dem ersten Bau unter `user://baucache/` (35 MB) und lädt es danach nur noch. Schlüssel: Godot-
   Version, alle Skripte, die Szenendatei, der Knotenpfad und die Eigenschaften des Baus; ändert sich etwas davon, wird
   neu gebaut. Im Editor und mit `--ohne-baucache` wird immer gebaut. Test: `tests/test_baucache.gd` (frisch gebaut und
   geladen gleichen sich Knoten für Knoten, gemeinsame Materialien, Schlüssel, Abschalten).
3. **Natur und Hafenausstattung bauten im ersten Bild alles neu**, nur um Stücke auf den Boden zu setzen. Jetzt bauen sie
   beim Laden und setzen danach nur die betroffenen Stücke in der Höhe nach (Lagen geprüft: 2.888 von 2.888 gleich).
4. **125 Figuren bauten sich im selben Bild auf.** Jetzt über eine Warteschlange mit 4 ms je Bild, die nächsten zuerst.

| Laden (Container, ohne Grafik) | vorher | Texturen | + Baucache (2. Start) |
|---|---|---|---|
| bis 5 Bilder | 31,3 s | 21,1 s | **9,5 s** |
| davon Burgbau | 12,2 s | 11,5 s | 1,9 s |
| Felsen | 3,5 s | 0,3 s | 0,3 s |
| Stadthäuser | 3,1 s | 2,7 s | 0,6 s |
| erstes Bild nach dem Laden | 3,4 s | 1,1 s | |

Der erste Start nach einer Code-Änderung baut wie bisher (und speichert dabei, etwa 2 s mehr). Das Messwerkzeug schreibt
jetzt die ersten 12 Bilder nach dem Laden einzeln mit (Dauer, Render-CPU, Grafikkarte, neu kompilierte Pipelines), damit
sich auf dem Referenzrechner zeigt, ob der Rest des Hängers Shader-Kompilierung ist.

**Gemessen auf dem Referenzrechner** (`docs/messungen/messung_drachenstein_punkt2_2026-11-17T18-35-16.json`; der Lauf
`punkt2_erster` lud den Cache schon, beide gleichen sich auf wenige Hundertstel):

| | mit Schattenhülle | Punkt 2 | Budget |
|---|---|---|---|
| Laden bis 5 Bilder | 16,0 s | **7,6 s** | ≤ 8 s ✔ |
| davon Einhängen und _ready | 12,0 s | 4,5 s | |
| Burgbau / Stadthäuser (_ready) | 6,8 / 2,2 s | 1,1 / 0,3 s | |
| größtes Bild nach dem Laden | 2.974 ms | 2.123 ms | ≤ 100 ms ✘ |
| Messfahrt fps im Mittel | 122 | 128 | |
| Frame p50 / p95 / p99 | 8,0 / 10,9 / 13,0 ms | 7,6 / 10,4 / 12,3 ms | p95 ≤ 8,3 ms |
| Grafikkarte p50 / p95 | 7,6 / 9,4 ms | 7,2 / 9,1 ms | |
| Arbeitsspeicher max | 1.527 MB | **598 MB** | ≤ 4 GB ✔ |
| Grafikspeicher max | 1.580 MB | 1.531 MB | ≤ 3 GB ✔ |

Die ersten Bilder nach dem Laden: 2.123 ms (273 neue Pipelines), 178 ms (48), 86 ms, 35 ms (20), danach 10 ms. Der
Hänger fällt also mit dem Erzeugen der Render-Pipelines (Shader-Varianten) zusammen und ist in beiden Läufen gleich
groß, der Pipeline-Cache von Godot und Treiber nimmt ihn offenbar nicht weg. Die Render-CPU zählt davon nur 65 ms; das
Messwerkzeug teilt die ersten Bilder deshalb jetzt in Skripte, Zeichnen und Physik/Rest auf.

### Ladebildschirm (burg-ausbau-11)

Der Hänger im ersten Bild (gut 2 s für 273 Render-Pipelines) lässt sich in Godot 4.7 ohne Export nicht vorab wegbacken
(den Shader Baker gibt es nur beim Export). Wie in den meisten Spielen fällt er deshalb hinter einen **Ladebildschirm**
(`autoload/ladevorhang.gd`, Autoload `Ladevorhang`), der bei jedem Wechsel in eine Region steht (neues Spiel, Laden,
Reisen; nicht im Hauptmenü):

1. Der Vorhang deckt das Bild ab (Titel, Name der Region, ein Bedienhinweis, Fortschrittsbalken), die Eingabe ist gesperrt.
2. Die Szene lädt im Hintergrund (`load_threaded_request`, Balken bis 30 %), dann wird sie aufgebaut.
3. Die Welt läuft hinter dem Vorhang schon. Er bleibt, bis 5 Bilder in Folge keine neuen Pipelines brachten, schneller als
   50 ms waren und alle Figuren gebaut sind (mindestens 5 Bilder, höchstens 15 s). Dann blendet er in 0,6 s aus und gibt
   die Eingabe frei; erst danach kommt die Ankunftsblende der Reise.

Der Spieler sieht so nach dem Laden nur noch flüssige Bilder. `Ladevorhang.aus = true` schaltet ihn ab (Tests, die den
Spielablauf direkt nach dem Wechsel prüfen); `tests/test_ladevorhang.gd` prüft ihn selbst. Das Messwerkzeug wendet
dieselbe Regel auf die ersten Bilder an und meldet, nach wie vielen Bildern der Vorhang fiele, wann das Spiel damit
spielbar wäre und wie groß das größte Bild danach ist (Budget: kein Bild über 100 ms, nachdem der Spieler übernimmt).

Außerdem: Ohne Grafik (Testläufe) lassen sich die Lagen in MultiMeshes nicht auslesen. Ein so angelegter Baucache hatte
alle Stadthäuser im Ursprung. Die Bauten legen die Lagen deshalb zusätzlich in den Daten ab (Meta `lagen`), der Cache
stellt sie beim Laden wieder her (Baucache-Version 2, geprüft in `tests/test_baucache.gd`).

**Gemessen auf dem Referenzrechner** (`docs/messungen/messung_drachenstein_vorhang_2026-11-18T16-13-45.json`, Strecke
kurz): Der Vorhang fiele nach 10 Bildern, das Spiel ist nach **8,4 s** spielbar, das größte Bild danach dauert
**11,5 ms** (Budget kein Bild über 100 ms nach dem Laden: ✔). Das Laden selbst liegt bei 7,7 s.

Aufteilung der ersten Bilder (hinter dem Vorhang):

| Bild | Dauer | Skripte | Zeichnen | Physik/Rest | neue Pipelines |
|---|---|---|---|---|---|
| 1 | 2.143 ms | 165 | 1.425 | 553 | 273 |
| 2 | 181 ms | 160 | 11 | 10 | 48 |
| 3 | 85 ms | 2 | 5 | 78 | 0 |
| 4 | 34 ms | 1 | 5 | 28 | 20 |
| ab 5 | 9 bis 13 ms | 1 | 4 bis 7 | 4 bis 6 | 0 bis 2 |

Das Zeichnen im ersten Bild ist die Pipeline-Erzeugung. Die übrigen gut 0,9 s (Skripte in Bild 1 und 2, Physik/Rest in
Bild 1, 3 und 4) verlängern nur die Zeit hinter dem Vorhang; wer die Zeit bis spielbar unter 8 s drücken will, findet
sie dort.

### Punkt 3: Gelände – Terrain3D im Vergleich (burg-ausbau-12)

Das eigene Gelände (`szenen/welt/gelaende.gd`) zeichnet alle 881 × 581 Rasterpunkte (2,5 m Abstand) in voller
Auflösung: 140 Kacheln mit zusammen gut 1 Mio. Dreiecken, auch weit hinten und ohne Detailstufen. **Terrain3D 1.1.0**
(`addons/terrain_3d`, MIT, läuft mit Godot 4.5 bis 4.8, kein eigener Engine-Build) zeichnet stattdessen ein Gitter um
die Kamera, das nach außen gröber wird (Clipmap, Übergänge stufenlos auf der Grafikkarte); die Höhen liegen als
Texturen auf der Grafikkarte.

Eingebaut zum Vergleich, ohne das eigene Gelände anzutasten:

- `gelaende.gd` hat die Einstellung `darstellung` ("eigen" oder "terrain3d"), Standard bleibt "eigen". Die
  Startargumente `--terrain3d` und `--eigenes-gelaende` gehen vor, auch beim Messwerkzeug.
- Nur die Fläche zeichnet Terrain3D (`szenen/welt/gelaende_terrain3d.gd`). Kollision, `hoehe_bei()` und die Löcher
  (Tunnel) baut weiter `gelaende.gd`, damit Personen, Tiere und alles, was auf den Boden gesetzt wird, genau wie bisher
  funktionieren. Außerhalb der Daten ist in Terrain3D Loch (sonst stünde dort Gelände auf Höhe 0).
- Beide zeichnen mit demselben Geländematerial: Es steht jetzt in `szenen/welt/gelaende_material.gdshaderinc` und wird
  von `gelaende.gdshader` (eigen) und `gelaende_t3d.gdshader` (Terrain3D) eingebunden. Den Terrain3D-Shader erzeugt
  `werkzeuge/gelaende_t3d_shader.gd` aus dem Shader von Terrain3D (Gitter, Detailstufen, Löcher, Normalen aus den
  Höhen) und unserem Material; nach einem Update von Terrain3D neu erzeugen.
- Das Messwerkzeug schreibt mit, welches Gelände gemessen wurde (`Gelände eigen` / `Gelände terrain3d`).
- `tests/test_terrain3d.gd` (16 Punkte): Standard bleibt eigen; mit Terrain3D gleiche Höhen an 4.000 Rasterpunkten,
  gleiche Löcher, Rand, Kollision, das Gitter folgt der Kamera.

| Container, ohne Grafik, je 2 Läufe | eigenes Gelände | Terrain3D |
|---|---|---|
| `_ready` des Geländes | 1.247 / 1.369 ms | **357 / 255 ms** |
| Dreiecke in Gelände-Meshes | 1,02 Mio. | 0 (Gitter auf der Grafikkarte) |

Was auf dem Referenzrechner zählt (Grafikkarte, Draw Calls, Dreiecke je Bild, Aufploppen am Horizont), zeigen nur
Messungen mit Grafik: einmal mit `--eigenes-gelaende`, einmal mit `--terrain3d`.

**Erste Messung auf dem Referenzrechner** (1280 × 720, beide Läufe gleich eingestellt;
`docs/messungen/messung_drachenstein_eigen_2026-11-18T17-08-28.json` und `…_t3d_2026-11-18T17-11-15.json`):

| Messfahrt Markt → Palas | eigenes Gelände | Terrain3D |
|---|---|---|
| fps im Mittel | 167 | 168 |
| Frame p50 / p95 / p99 | 5,8 / 7,5 / 9,6 ms | 5,8 / 7,5 / 9,5 ms |
| Grafikkarte p50 / p95 | 5,1 / 6,1 ms | 4,9 / 5,9 ms |
| Dreiecke je Bild p95 | 8,58 Mio. | 8,19 Mio. |
| Draw Calls p95 | 3.425 | 3.374 |
| Rundblick: Grafikkarte p50 / p95 | 5,3 / 6,8 ms | 4,9 / 6,5 ms |
| `_ready` des Geländes | 658 ms | 267 ms |
| erstes Bild nach dem Laden | 2.824 ms (273 Pipelines) | 3.303 ms (284 Pipelines) |
| spielbar nach | 9,1 s | 9,1 s |
| Arbeits- / Grafikspeicher | 603 / 1.351 MB | 623 / 1.363 MB |

**Fehler in diesem Lauf:** Mit Terrain3D lag ein Karomuster auf dem Boden. Terrain3D schaltet es als Platzhalter
ein, solange seine eigene Texturliste leer ist, und legt es auch über einen eigenen Shader. Behoben mit einer
winzigen Platzhaltertextur in der Liste (`gelaende_terrain3d.gd`), geprüft in `test_terrain3d.gd`. Weil das Muster
die Farbe unseres Materials ersetzte, hat die Grafikkarte dabei vermutlich einen Teil unseres Materials gar nicht
gerechnet; die Zahlen für Terrain3D sind daher eher zu günstig und werden mit dem behobenen Stand wiederholt.

**Zwischenstand:** Auf der Grafikkarte bringt Terrain3D hier nur 3 bis 7 %, die Bildzeit bleibt gleich. Das
Gelände von Drachenstein war nie der Engpass (2,2 × 1,45 km, Kacheln außerhalb des Blickfelds fallen schon weg). Was
beim Laden im Gelände gespart wird (0,4 s), kostet das erste Bild wieder (11 Pipelines mehr). Für die heutige Region
lohnt der Umstieg nicht; interessant wird Terrain3D erst bei einer viel größeren Welt (Phase 2).

**Nachmessung mit behobenem Material** (`docs/messungen/messung_drachenstein_t3d2_2026-11-18T17-20-06.json`, Boden
sieht aus wie beim eigenen Gelände):

| Messfahrt Markt → Palas | eigenes Gelände | Terrain3D (behoben) |
|---|---|---|
| fps im Mittel | 167 | 168 |
| Frame p50 / p95 / p99 | 5,8 / 7,5 / 9,6 ms | 5,8 / 7,5 / 9,5 ms |
| Grafikkarte p50 / p95 | 5,05 / 6,07 ms | 5,00 / 5,99 ms |
| Rundblick: Grafikkarte p50 / p95 | 5,26 / 6,76 ms | 5,16 / 6,68 ms |
| `_ready` des Geländes | 658 ms | 179 ms |
| erstes Bild nach dem Laden | 2.824 ms | 3.069 ms |
| spielbar nach | 9,1 s | 8,7 s |

**Entscheidung (18.11.2026):** Die Grafikkarte spart mit Terrain3D 1 bis 2 %, die Bildzeit bleibt gleich. Das
Gelände bleibt das eigene; Terrain3D bleibt als Schalter (`--terrain3d`) mit Test im Projekt und wird wieder geprüft,
wenn die Welt in Phase 2 deutlich größer wird. Punkt 3 ist damit abgeschlossen.

### Grafikstufe Episch (burg-ausbau-18)

Referenzrechner, 1280×720, Strecke stadt_palas, Zellen an
(`docs/messungen/messung_drachenstein_episch_2026-11-19T16-45-32.txt`):

| | Hoch (Zellen Schritt 3) | Episch |
|---|---|---|
| Messfahrt fps | – | 89,0 |
| Frame p50 / p95 | – | 10,9 / 15,4 ms |
| Grafikkarte p50 / p95 | etwa 5,0 / 6,0 ms | 10,4 / 14,6 ms |
| Draw Calls p95 | 3708 | 6566 |
| Dreiecke p95 | – | 14,8 Mio. |
| Grafikspeicher max | etwa 1380 MB | 1770 MB |
| Spielbar nach | 8,0 s | 8,0 s |
| Hänger > 33 ms | 0 | 0 |

Episch hält das Ziel von 30 fps mit großem Abstand. Auf den Fotos des Rundgangs ist der Unterschied zu Hoch aber klein:
Der Engpass für „realistisch und detailreich“ ist der Inhalt, nicht die Einstellung (`docs/maengel-drachenstein.md`).

### Felsen, Gebirge, Küste und Bäume (burg-ausbau-19 bis -22)

Referenzrechner, 1280×720, Strecke stadt_palas
(`docs/messungen/messung_drachenstein_hoch_2026-11-20T18-24-54.txt`, `…_episch_2026-11-20T18-27-15.txt`):

| | Hoch 18.11. | Hoch 20.11. | Episch 19.11. | Episch 20.11. |
|---|---|---|---|---|
| Messfahrt fps | 166 | 70 | 89 | 36 |
| Grafikkarte p50 / p95 | 5,0 / 6,0 ms | 13,7 / 23,1 ms | 10,4 / 14,6 ms | 28,6 / 43,9 ms |
| Draw Calls p95 | 3708 | 3973 | 6566 | 7205 |
| Dreiecke in MultiMeshes (Szene) | 9,7 Mio. | 73,3 Mio. | 9,7 Mio. | 73,3 Mio. |
| Hänger > 33 ms | 0 | 18 | 0 | 1296 |

Die Render-CPU und die Draw Calls sind kaum gestiegen, die Grafikkarte trägt die Last. Ursachen und Abhilfe (burg-ausbau-23):

- **Brocken `boulder_01` war nie vereinfacht** (56.548 Dreiecke, die Kollisionsform ebenso): rund 600 Brocken dieser
  Art allein über 30 Mio. Dreiecke. Jetzt 2.773 (Kollision 497). `werkzeuge/fels_vereinfachen.py` legt gröber nach,
  wenn die genaue Vereinfachung an Nähten stecken bleibt.
- **Fels-Haut `rock_face_02`**: 20.000 Dreiecke je 2,7-m-Stück, rund 800 Stück am Sockel. Jetzt 4.000.
- **Ferne Bäume** warfen in allen Schattenstufen Schatten (Laubkarten): jetzt nur in Episch (`fern_schatten` in
  `autoload/grafik.gd`), die nahen Bäume (bis 160 m) behalten ihre Schatten.

Nächste Messung: zeigt, wie viel davon zurückkommt; danach, falls nötig, die Laubkarten verkleinern (Überzeichnung).
