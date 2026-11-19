# Mängelliste Burgfeste Drachenstein

Grundlage: Foto-Rundgang vom 19.11.2026 (21 Blickpunkte, je einmal **Hoch** und **Episch**, 1280×720, Referenzrechner)
und die Messung `docs/messungen/messung_drachenstein_episch_2026-11-19T16-45-32.txt`. Bilder der Luftansichten:
`docs/bilder/rundgang-2026-11-19/`. Blickpunkte: `werkzeuge/rundgang/drachenstein.json`.

Stand: **behoben** (im Code geändert, im nächsten Rundgang zu bestätigen), **offen**, **prüfen** (Ursache unklar).

## Zuerst: Hoch und Episch sehen fast gleich aus

Episch läuft mit 89 fps (Grafikkarte 10,4 statt 5,0 ms, Draw Calls +77 %, Grafikspeicher +390 MB). Auf den Fotos ist
der Unterschied zu Hoch trotzdem kaum zu sehen: etwas weichere Schatten, sonst nichts. Der Engpass ist also nicht die
Einstellung, sondern der **Inhalt**: Modelle, Materialien, Gelände und Belebung. Daraus folgt die Reihenfolge unten:
erst Fehler, dann Welt und Fernsicht, dann Modelle und Materialien.

## A. Werkzeug und Blickpunkte

| Nr. | Foto | Befund | Ursache | Stand |
|---|---|---|---|---|
| M11 | alle | Entwickler-Einblendung („Ort … Blick …“) unten links in jedem Foto | Rundgang blendete nur das HUD aus | behoben: alle Bildschirmebenen aus |
| M27 | 11_nordtor | Bild fast schwarz | Kamera 0,6 m **unter** dem Gelände (Kamera −9,5, Boden −8,9) | behoben: Kamera auf −7,2; das Werkzeug warnt jetzt, wenn eine Kamera unter dem Gelände steht |
| M28 | 19_uebungsplatz | Übungspuppe füllt das Bild, riesiges Namensschild | Kamera 2 m vor der Puppe; Namensschilder der Gegner ohne Sichtweite | behoben: Kamera höher; Namensschilder der Gegner wie bei Personen nur bis 14 m |
| M29 | 07_bergfried_dach | Brüstung verdeckt den Blick auf die Burg | Kamera knapp über dem Feuerbecken | behoben: Kamera 2 m höher |
| M25 | 06_luft_abendlicht | Bild ist schon Nacht statt Abendlicht | Die Sonne geht um 18 Uhr unter, der Blickpunkt stand auf 18:30 | behoben: 17 Uhr |
| M26 | 10_suedtor | Torweg und Fassaden tagsüber fast schwarz | Gegenlicht im Schatten; möglicherweise hatte sich die globale Beleuchtung (SDFGI) nach dem Kamerasprung noch nicht gesetzt | prüfen: Rundgang wartet jetzt 90 statt 45 Bilder |

## B. Welt, Meer und Fernsicht

| Nr. | Foto | Befund | Ursache | Stand |
|---|---|---|---|---|
| M1 | 03, 04 | Weltrand: Das Meer endet, dahinter brauner Abgrund | Meeresfläche nur 2800×1800 m | behoben: Fernmeer 16 km bis zum Horizont (spart die nahe Fläche aus, die Wellen laufen zum Rand hin aus) |
| M2 | 01–05 | Meer mit regelmäßigen schrägen Streifen | Farbe aus einer einzigen Sinuswelle | behoben: Wellen aus vier Rauschlagen in verschiedenen Richtungen, große weiche Farbflecken statt Bänder |
| M9 | 04 | großer weißer Sonnenfleck auf glattem Wasser | glatte Fläche, Rauheit 0,12 | behoben: gekräuselte Oberfläche, die Sonne glitzert als Bahn |
| M3 | 01–05 | milchiger, beiger Dunst, flaue Farben (Hoch genauso wie Episch) | Tiefennebel 0,0006 und Höhennebel 0,0008, nicht der Lichtnebel von Episch | behoben: halbiert (0,00025 / 0,0004); im Rundgang bestätigen |
| M5 | 01–04 | Gebirgsrahmen wirkt wie senkrechte Kulissenwände mit Schneekante | Felsmassiv als steile Wand ohne Vorberge und Staffelung | offen |
| M6 | 01–05 | Landschaft gleichförmig grün, wenige kegelförmige Bäume | einfache Baummodelle, kaum Wiesen-, Feld- und Bodenunterschiede | offen |
| M8 | 01–04 | Küste als glatte Kante mit Sandstreifen | im Referenzbild Felsküste und Klippen | offen |

## C. Stadt

| Nr. | Foto | Befund | Ursache | Stand |
|---|---|---|---|---|
| M4 | 01–04 | Dächer blass beige und gleichförmig | im Referenzbild warme rotbraune Ziegel und Schiefer im Wechsel | offen |
| M12 | 08, 21 | grauer Hügel mitten auf der Marktstraße | Geländebuckel von 1,5 m bei (143, 141): Der Erzeuger zog das feine Rauschen je Gasse erneut ab, an Kreuzungen mehrfach | behoben: in der Stadt nur einmal geglättet, Gelände neu erzeugt (Gassen bis 1,6 m tiefer bzw. 1,1 m höher); der Baucache prüft jetzt auch die Geländedaten |
| M13 | 09_st_marien | Haus und Kirche stehen auf Gras, Sockel ungleich hoch | Pflasterfläche reicht nicht bis St. Marien | offen |
| M14 | 08, 09 | große leere Fachwerkflächen, Giebelseiten ohne Fenster | Hausbau setzt Fenster nur an die Traufseiten | offen |
| M15 | 08, 12 | Tauben und Möwen als flache Klötze | einfache Platzhaltermodelle | offen |
| M16 | 08 | dunkler Fleck auf dem Marktpflaster | unbekannt (Schatten, Loch oder Decal) | prüfen |

## D. Burg

| Nr. | Foto | Befund | Ursache | Stand |
|---|---|---|---|---|
| M7 | 01–05 | Fels zwischen den Burgmauern wirkt wie grauer Kies | Felsen und Bewuchs am Burgberg aus der Ferne zu kleinteilig und grau | offen |
| M17 | 15_vorburg | graue Felsflächen über der Mauer am Tor Vorburg → Mittelburg | Felssockel ragt dort bis 5 m über den Mauerfuß (Treffer bei (23–37, 3–5, 113–122)) | offen |
| M18 | 14_fuss_der_rampe | Felsen grob facettiert, flächig | wenige große Dreiecke, Textur 6 m | offen: Felsmodelle aus Fotoscans (CC0) |
| M19 | 14_fuss_der_rampe | Stützmauer: Textur gestreckt und verwaschen | Abwicklung der Mauerkrone und Seiten | offen |
| M20 | 15, 20 | Laubbäume als Low-Poly-Klumpen | einfache Baummodelle | offen (mit M6) |
| M21 | 16, 17, 18 | Höfe groß und leer | Belebung fehlt | offen: Aufgabe „Höfe beleben“ |

## E. Hafen

| Nr. | Foto | Befund | Ursache | Stand |
|---|---|---|---|---|
| M10 | 01–04 | Schiffe und Kräne aus der Luft nicht zu sehen | Ausstattung blendet nach 220 m aus, Zellen laden ab 240 m | behoben: Koggen bis 1400 m, Kräne und Prahme bis 900 m sichtbar, immer geladen |
| M22 | 12_drachenkai | Hafenwasser hell türkis wie ein Schwimmbecken | Himmelsspiegelung auf glatter Fläche | prüfen nach dem neuen Wasser |
| M23 | 12, 13 | Schiffe kastenförmig, Segel fehlen | einfache Modelle | offen |
| M24 | 12 | Kai sandfarben und glatt | Material der Kaifläche | offen |

## F. Figuren und Tiere

| Nr. | Foto | Befund | Ursache | Stand |
|---|---|---|---|---|
| M30 | 15, 16, 18 | Pferde einfarbig braun, Figuren aus der Nähe einfach | Modelle aus Detailstufe 3 | offen: bessere CC0-Modelle |

## Nächste Schritte

1. Neuer Rundgang (Hoch und Episch) zur Bestätigung von M1–M3, M9, M11, M22, M25–M29.
2. Fehler im Bau: M12, M13, M17, M16.
3. Fernsicht: M10, M5, M8, M6/M20, M7, M4.
4. Modelle und Materialien: M18, M19, M14, M15, M23, M24, M30.
