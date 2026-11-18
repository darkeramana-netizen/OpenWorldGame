# Standard für eine fertige Burg

Stand 18.11.2026. Die Burgfeste Drachenstein wird zuerst vollständig fertig gebaut; was dabei entsteht (Bauskripte,
Prüfungen, Rundgang, Messung), ist der Maßstab für die anderen Burgen und die übrige Welt. Eine Burg gilt als fertig,
wenn jeder Punkt unten erfüllt und **geprüft** ist. Wo es geht, prüft ein Test; was nur das Auge beurteilen kann,
prüft der Foto-Rundgang.

## A. Plan und Maßstab

- Höfe, Mauern, Türme, Tore, Wege und Höhen folgen dem Grundriss (für Drachenstein Grundriss 3).
- Die Gesamtansicht entspricht dem Referenzbild: Staffelung der Burgen den Felsgrat hinauf, Stadt und Hafen davor,
  Meer auf drei Seiten.
- „Wege schrumpfen, Orte bleiben groß“ (Spielkonzept): Burgen etwa 1:3 bis 1:5, Türme fast in echter Höhe.

## B. Geschlossener Bau

- Jede Mauer endet an einem Turm, einer anderen Mauer, einem Gebäude oder am Fels. Es gibt keine Lücke, keinen
  Stummel und kein Mauerstück, das ins Leere ragt.
- Kein Bauteil ist doppelt (Zinnenkranz, Pfeiler, Turm), nichts steht übrig oder schwebt.
- Dächer, Böden und Decken schließen; man sieht nirgends durch den Bau in den Himmel oder ins Leere.
- Offene Türme (Schalentürme) sind als solche erkennbar: mit Boden, ohne Schacht ins Nichts.

## C. Begehbarkeit

- Alle Tore, Wege, Rampen, Treppen und Brücken sind begehbar, auch nachts mit der richtigen Erlaubnis.
- Jeder Wehrgang ist durchgehend begehbar, mit Zugang über Treppen oder Türme an logischen Stellen. Jede Treppe
  führt irgendwohin.
- Begehbare Türme und Gebäude haben Türen, Treppen und Böden in allen Geschossen.
- Der Spieler kommt nirgends dorthin, wo er nicht hin soll: keine Abkürzung über Mauern, kein Weg aus der Welt.

## D. Innenräume

- Jedes Gebäude mit Tür hat einen Innenraum, eingerichtet nach seinem Zweck (Wohnhaus, Stall, Zeughaus, Kapelle,
  Saal, Küche, Lager).
- Licht innen, abends Fensterlicht von außen.

## E. Platzierung

- Kein Gegenstand steckt im Boden, schwebt, steckt in einer Wand oder in einem anderen Gegenstand.
- Alles steht dort, wo es hingehört: Wäsche am Rand, Vorplätze und Wege frei, Werkzeug bei der Werkstatt, Tiere im
  Pferch oder Stall, kein Kram vor Türen.

## F. Leben

- Personen haben einen Tagesablauf an sinnvollen Orten: Wachen auf Mauern und an Toren, Handwerker in Werkstätten,
  Gesinde in Küche und Stall, Markt am Vormittag, Stille in der Nacht.
- Jeder Hof hat Arbeit, Kleinvieh und Hausrat, die zu ihm passen.

## G. Material und Detail

- Verwitterung, Moos und Feuchte dort, wo sie hingehören (Mauerfuß, Nordseiten, Fugen); abgenutzte Wege und Stufen.
- Fenster mit Läden oder Glas, Türen mit Beschlägen, Dächer mit Firsten und Schornsteinen.
- Fels und Gelände ohne Zacken, Streifen oder schwarze Stellen.

## Grafik: realistisch und detailreich

Die Burg wird so realistisch und detailreich gebaut, wie Godot es hergibt. Dafür gibt es Grafikstufen
(`autoload/grafik.gd`, Menü „Grafik“, Startargument `--grafik niedrig|mittel|hoch|episch`):

| | Niedrig | Mittel | Hoch | Episch |
|---|---|---|---|---|
| Kantenglättung | FXAA | MSAA 2× | MSAA 2× | MSAA 4× |
| Globale Beleuchtung (SDFGI) | aus | aus | 4 Stufen | 6 Stufen, 64 Strahlen |
| SSAO / SSIL | aus | SSAO | beide | beide in höchster Qualität |
| Sonnenschatten | 2048, bis 200 m | 4096, bis 300 m | 4096, 2 Stufen, bis 500 m | 8192, 4 Stufen, bis 800 m |
| Schatten kleiner Dinge | ab 2 m | ab 1 m | ab 1 m | alle |
| Spiegelungen (SSR), Lichtnebel | – | – | – | an |

- **Hoch** ist der Stand der Szenen; für Hoch gilt das Budget aus `docs/03-messgrundlage.md` (60 fps auf der
  Zielhardware).
- **Episch** hat kein Budget, soll auf dem Referenzrechner aber mindestens 30 fps halten. Das ist der Maßstab für „so
  gut, wie es geht“.
- Grenzen von Godot 4.7: keine virtuelle Geometrie (wie Nanite), kein Raytracing auf der Grafikkarte, keine
  Tessellation. Feine Details entstehen über Normalen- und Höhenkarten (Parallax), Decals, Detailstufen je Mesh und
  viele gleiche Exemplare.
- Der größere Hebel sind die Modelle: Figuren (Gesichter, Kleidung nach Stand, Animationen für Arbeit, Sitzen,
  Gesten), Tiere, Gegenstände aus Fotoscans (CC0), Mauerwerk mit sichtbaren Steinkanten, Verwitterung als Decals.
  Alles nur mit freien Lizenzen (CC0 oder gleichwertig).

## H. Technik

- Bauten aus dem Baucache, Einrichtung, Ausstattung und Natur in Zellen (`docs/05-phase2-zellen.md`).
- Budgets auf dem Referenzrechner (`docs/03-messgrundlage.md`): Ladezeit bis spielbar ≤ 8 s, kein Bild über 100 ms
  nach dem Ladebildschirm, keine Hänger in der Messfahrt, kein hartes Aufploppen näher als 50 m.

## Abnahme

1. Alle Testreihen grün (Begehbarkeit, Platzierung, Zellen, Baucache).
2. Foto-Rundgang mit festen Blickpunkten (Gesamtansicht wie Referenzbild, jedes Tor, jeder Hof, Wehrgänge, Türme,
   Innenräume, Hafen), ohne offene Mängel. Werkzeug: `werkzeuge/rundgang/rundgang.gd`, Blickpunkte je Burg in
   `werkzeuge/rundgang/<region>.json` (Kamera, Ziel, Uhrzeit). Aufruf mit Grafik:
   `godot --path . --script res://werkzeuge/rundgang/rundgang.gd -- --grafik episch` (Fotos und `inhalt.txt` unter
   `user://rundgang/`; `--nur 08` für einzelne Blickpunkte). Im Container lässt sich nicht fotografieren (ohne
   Grafikkarte dauern schon die ersten Bilder eine Viertelstunde), der Rundgang läuft auf dem Referenzrechner.
3. Messung auf dem Referenzrechner innerhalb der Budgets.
4. Begehung durch dich im Spiel, ohne offene Mängel.

Offene Mängel stehen in der Mängelliste der Burg (`docs/maengel-<burg>.md`), jeder mit Bild, Ursache und Stand.
