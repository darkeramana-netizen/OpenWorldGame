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
3. **Weiterer Inhalt:** Felsen, Natur und Bewuchs in Zellen (heute ein Knoten je Art für die ganze Region).
4. **Spielstand je Zelle** für veränderliche Dinge.
5. **Fernmodelle** für Burg, Gravecrest und Gravemarch, danach auch diese in Zellen.
6. **Entscheidung** zusammenhängende Welt ja oder nein.

Budgets (siehe `03-messgrundlage.md`): kein Hänger über 33 ms an Zellgrenzen, Speicher für die ganze Welt ≤ 4 GB.
