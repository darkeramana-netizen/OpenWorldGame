# Phase 2: Welt in Zellen nachladen

Stand 18.11.2026. Entscheidung: **erst Drachenstein in Zellen nachladen und messen**, danach anhand der Zahlen
entscheiden, ob die Regionen zu einer zusammenhängenden Welt (Spielkonzept, 1:50, ca. 5,5 × 4 km) zusammenwachsen.
Grundlage sind die Verfahren aus Sorrow-Engine (`docs/04-sorrow-engine-auswertung.md`).

## Was Zellen bringen und was nicht

Die Sichtweiten (Phase 1) sorgen schon dafür, dass ferne Dinge nicht gezeichnet werden. Zellen bringen darüber hinaus:

- **Ladezeit:** Beim Start wird nur gebaut, was nah ist. Heute baut Drachenstein alles (bis spielbar 9,1 s).
- **Speicher und CPU:** Was fern ist, liegt nicht im Szenenbaum (keine Knoten, keine Physik, kein `_process`).
- **Wachstum:** Erst damit kann die Welt größer werden als eine Region.

Nicht lösen Zellen: Dinge, die von weit her sichtbar sind (Burg, Bergfried, Gravecrest, Türme, Felsmassiv). Die dürfen
erst nachgeladen werden, wenn es für sie **Fernmodelle** gibt (vereinfachte Gesamtform). Bis dahin bleiben sie
immer geladen.

## Aufbau

- **Raster:** Zellen von 128 × 128 m (Welt-x/z). Eine Zelle ist geladen, wenn ihr Mittelpunkt näher als ihr
  Ladeabstand am Spieler liegt; entladen wird erst bei Ladeabstand + Puffer (gegen Hin und Her an der Grenze).
- **Zellinhalt:** Ein Bauknoten (Burgbau, Stadthäuser, Ausstattung, Felsen, Bewuchs) bleibt als leerer Knoten im Baum
  und baut seinen Inhalt erst, wenn seine Zelle geladen wird; beim Entladen gibt er ihn wieder frei. Der Inhalt kommt
  aus dem Baucache (schnell), nicht aus einem Neubau. Jeder Inhalt hat einen eigenen Ladeabstand (Einrichtung eines
  Hauses 60 m, Felsen 300 m usw.), passend zu seiner Sichtweite.
- **Nachlader (`Zellwelt`):** Ladeliste nach Abstand, nur bei Zellwechsel neu sortiert; Aufbau mit **Zeitbudget je
  Bild** (wie die Figuren-Warteschlange); Dateien des Baucaches im Hintergrund vorladen
  (`ResourceLoader.load_threaded_request`), eingehängt wird auf dem Hauptthread; Prüfung alle 0,2 s.
- **Immer geladen:** Fern sichtbare Bauten, Gelände, Kollision des Geländes, Personen und Tiere (ihr Tagesablauf läuft
  auch fern weiter), Spieler, Oberfläche.
- **Ladebildschirm:** wartet, bis die Zellen um den Startpunkt gebaut sind.
- **Spielstand je Zelle:** nur Änderungen gegenüber den Grunddaten; kommt mit dem ersten Inhalt, der sich verändern
  lässt (Türen, aufgehobene Dinge).

## Schritte

1. ✔ **Zellwelt-Kern** mit Test, unabhängig vom Inhalt: Ladeabstände mit Puffer, Reihenfolge nach Abstand,
   Zeitbudget, Vorladen im Hintergrund (`autoload/zellwelt.gd`, `tests/test_zellwelt.gd`); der Ladebildschirm
   wartet auf die nahen Zellen.
2. ✔ **Erster Inhalt:** Einrichtung der Fachwerkhäuser (`HofhausEinrichtung`, 10 Zellen à 64 m, Ladeabstand 90 m)
   und Ausstattung von Stadt und Burg (64 m, Ladeabstand 240 m, über der Sichtweite der Stücke von 220 m).
   - `burgbau.gd`: `zellgroesse` trennt Geometrie, Lichter und Kollision nach Zellen (Knoten `Zelle_x_z`);
     `zell_laden_ab` lässt sie nachladen. Der Baucache legt jede Zelle in eine eigene Datei
     (`<schlüssel>.Zelle_x_z.res`), die im Hintergrund vorgeladen wird. Lesen ist bei der Einrichtung gut 60 % der
     Ladezeit (62 ms Datei, 38 ms Instanziieren, gemessen).
   - `ausstattung.gd`: dieselben Einstellungen; die Zellen werden bei Bedarf aus den Daten gebaut, lebende Tiere
     bleiben immer da.
   - `szenen/welt/zellteil.gd`: Platzhalter je Zelle (Inhalt aus Datei, frisch gebaut oder über eine Funktion).
   - Tests: `tests/test_zellen_bau.gd` (12 Punkte: in Zellen dasselbe wie am Stück, frisch und aus dem Baucache,
     nah geladen, fern frei), `test_baucache` baut alle Zellen sofort und vergleicht sie.
   - Messwerkzeug: Zeile „Zellen“ (gebaut, freigegeben, längster Aufbau); Vergleich mit `--ohne-zellen`.
     Behoben dabei: Das Messwerkzeug lud den Ladebildschirm per `preload`, dadurch lief er in Messungen ohne Skript.

   Container, ohne Grafik, nur mit der Einrichtung (Stadtstrecke Markt → Palas): Speicher 834 statt 855 MB,
   6,40 statt 6,64 Mio. Dreiecke beim Start, längster Aufbau einer Zelle 9,7 ms, 11 Zellen gebaut und 4 freigegeben
   auf der Strecke; Ladezeit und Hänger im Rauschen. Der Gewinn wächst mit dem Inhalt (Schritt 3).

   **Referenzrechner** (1280 × 720, `docs/messungen/messung_drachenstein_zellen_2026-11-18T19-04-45.json` und
   `…_ohne_zellen_2026-11-18T19-07-32.json`), Stadtstrecke Markt → Palas:

   | | ohne Zellen | mit Zellen |
   |---|---|---|
   | spielbar nach | 8,3 s | 8,1 s |
   | Draw Calls p95 Fahrt / Rundblick | 3.902 / 4.166 | 3.709 / 4.072 |
   | Objekte p95 Fahrt | 4.767 | 4.577 |
   | Knoten in der Szene | 12.040 | 11.619 |
   | Frame p95, Grafikkarte p50 | 7,6 / 5,0 ms | 7,5 / 5,0 ms |
   | Hänger in der Fahrt | 0 | 0 |
   | längster Aufbau einer Zelle | – | 144,5 ms (im Anlauf, hinter dem Ladebildschirm) |

   Beim Spielen keine Fehler gesehen. Die 144,5 ms kamen daher, dass die Ausstattung die Form einer Art erst in der
   ersten Zelle baute, die sie braucht; mitten im Spiel wäre das ein Hänger gewesen. Jetzt baut sie alle Formen beim
   Laden.
3. ✔ **Weiterer Inhalt:** gemessen, wofür die Zeit draufgeht (Container): Natur 342 ms Aufbau mit 2.836 Stücken,
   742 MultiMeshes und 205 Kollisionsformen; Klippenfelsen 236 ms mit 195 Stücken und 15 Formen; Bäume 386 ms für
   das Pflanzen über Strahlen und 1.807 Stammzylinder.
   - **Natur** (`felsen.gd`, Sichtweite 300 m) ganz in Zellen: 40 Zellen à 128 m, Ladeabstand 364 m. Ebenso die
     Pflanzen auf dem Felsmassiv (96 m, Ladeabstand 320 m). Die Modelle werden einmal beim Laden vorbereitet, je
     Zelle entstehen nur MultiMeshes und Kollision; die Höhen nach dem Nachsetzen auf den Boden gelten auch für
     Zellen, die erst später gebaut werden.
   - **Klippenfelsen** bleiben, wie sie sind: 2,5 km Sichtweite, kaum Kollision.
   - **Bäume** bleiben immer sichtbar; nur ihre **Stammkollision** liegt in 53 Zellen à 128 m (Ladeabstand 150 m).
     Am Ursprung haben 43 von 1.807 Stämmen Kollision.
   - `tests/test_zellen_bau.gd` jetzt 17 Punkte (Natur, Stämme dazu).
   - Offen: Das Pflanzen der Bäume (386 ms über Strahlen) ist immer gleich und könnte in den Baucache.
4. **Spielstand je Zelle** für veränderliche Dinge.
5. **Fernmodelle** für Burg, Gravecrest und Gravemarch, danach auch diese in Zellen.
6. **Entscheidung** zusammenhängende Welt ja oder nein.

Budgets (siehe `03-messgrundlage.md`): kein Hänger über 33 ms an Zellgrenzen, Speicher für die ganze Welt ≤ 4 GB.
