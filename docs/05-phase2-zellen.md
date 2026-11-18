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

1. **Zellwelt-Kern** mit Test, unabhängig vom Inhalt: Raster, Ladeabstände mit Puffer, Reihenfolge nach Abstand,
   Zeitbudget, Vorladen im Hintergrund.
2. **Erster Inhalt:** Einrichtung der Fachwerkhäuser (`HofhausEinrichtung`, von außen nicht zu sehen) und Ausstattung.
   Messen: Ladezeit, Speicher, Hänger beim Gehen durch die Stadt.
3. **Weiterer Inhalt:** Felsen, Natur und Bewuchs in Zellen (heute ein Knoten je Art für die ganze Region).
4. **Spielstand je Zelle** für veränderliche Dinge.
5. **Fernmodelle** für Burg, Gravecrest und Gravemarch, danach auch diese in Zellen.
6. **Entscheidung** zusammenhängende Welt ja oder nein.

Budgets (siehe `03-messgrundlage.md`): kein Hänger über 33 ms an Zellgrenzen, Speicher für die ganze Welt ≤ 4 GB.
