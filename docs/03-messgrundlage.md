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

AUSGANGSWERTE

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

ERKENNTNISSE
