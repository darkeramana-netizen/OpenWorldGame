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
| M32 | 10_suedtor, 20_ordensvorwerk | 10 im dritten Rundgang wieder dunkel, 20 nur Laub | 10: unter einem Vordach ohne Kollision (die Sonde sah es nicht); 20: Kamera in Augenhöhe im Gebüsch vor dem Vorwerk | behoben: 10 von außen vor dem Tor (der Torweg führt nach Osten zum Küstenweg), 20 aus 17 m Höhe über die Büsche |
| M27 | 10_suedtor, 11_nordtor | Bilder fast schwarz (auch im zweiten Rundgang) | Kameras standen unter dem Gelände bzw. 15–20 m neben der Gasse **in Häusern** | behoben: Standpunkte per Sonde gesucht (mitten in der Gasse, freie Sicht aufs Tor); das Werkzeug warnt jetzt bei Kamera unter dem Gelände und bei Blick, der nach weniger als 6 m verdeckt ist |
| M28 | 19_uebungsplatz | Übungspuppe füllt das Bild, riesiges Namensschild | Kamera 2 m vor der Puppe; Namensschilder der Gegner ohne Sichtweite | behoben: Kamera höher; Namensschilder der Gegner wie bei Personen nur bis 14 m |
| M29 | 07_bergfried_dach | Brüstung verdeckt den Blick auf die Burg | Kamera knapp über dem Feuerbecken | behoben: Kamera 2 m höher |
| M31 | 07_bergfried_dach | riesiges Schild „Schwarzer Bergfried“ über dem Kopf | Ortsschild 76 m hoch, sichtbar bis 70 m, also auch auf dem Dach | behoben: erst ab 35 m Abstand sichtbar |
| M25 | 06_luft_abendlicht | Bild ist schon Nacht statt Abendlicht | Die Sonne geht um 18 Uhr unter, der Blickpunkt stand auf 18:30 | behoben: 17 Uhr |
| M26 | 10_suedtor | Torweg und Fassaden tagsüber fast schwarz | nicht die Beleuchtung, sondern M27 (Kamera im Haus) | behoben mit M27 |

## B. Welt, Meer und Fernsicht

| Nr. | Foto | Befund | Ursache | Stand |
|---|---|---|---|---|
| M1 | 03, 04 | Weltrand: Das Meer endet, dahinter brauner Abgrund | Meeresfläche nur 2800×1800 m | bestätigt behoben: Fernmeer 16 km bis zum Horizont. Nachgebessert: gepunktete Naht (beide Flächen gleich hoch; das Fernmeer liegt jetzt 0,5 m tiefer und überlappt) und brauner Streifen am Horizont hinter der Sichtweite (Himmel unter dem Horizont jetzt meerfarben) |
| M2 | 01–05 | Meer mit regelmäßigen schrägen Streifen | Farbe aus einer einzigen Sinuswelle | behoben: Wellen aus vier Rauschlagen in verschiedenen Richtungen, große weiche Farbflecken statt Bänder |
| M9 | 04 | großer weißer Sonnenfleck auf glattem Wasser | glatte Fläche, Rauheit 0,12 | behoben: gekräuselte Oberfläche, die Sonne glitzert als Bahn |
| M3 | 01–05 | milchiger, beiger Dunst, flaue Farben (Hoch genauso wie Episch) | Tiefennebel 0,0006 und Höhennebel 0,0008, nicht der Lichtnebel von Episch | behoben: halbiert (0,00025 / 0,0004); im Rundgang bestätigen |
| M5 | 01–04 | Gebirgsrahmen wirkt wie senkrechte Kulissenwände mit Schneekante | Geländeerzeuger: gerades Band von 130–230 m, darin der Anstieg auf eine fast flache Hochfläche (120–210 m); am Kartenrand brach der Nordzug ab, dahinter leerer Himmel | behoben: Fuß unregelmäßig (springt bis 90 m zurück), Vorberge, dahinter Bergstöcke mit geschwungenen Graten und Tälern (Gratrauschen mit verzerrten Koordinaten), volle Höhe erst am Rand der Region, steile Hänge per Erosion abgetragen (über 45°); Sättel an beiden Pässen; der Nordzug taucht im Osten ins Meer ab. Neu: **Fernberge** (`szenen/welt/fernberge.gd`) bis 3,5 km hinter dem Rand, nach außen höher (bis 600 m), Kamera-Sichtweite 8 km; Schnee erst ab 190 m (Fernberge ab 380 m). Vorher/nachher (Probeszene nur mit Gelände, ohne SDFGI): `docs/bilder/gebirge-2026-11-19/` |
| M6 | 01–05 | Landschaft gleichförmig grün, wenige kegelförmige Bäume | einfache Baummodelle, kaum Wiesen-, Feld- und Bodenunterschiede | Bäume behoben (siehe M20). Felder behoben: Streifenflur an den Landstraßen und um das Ordensvorwerk (`werkzeuge/bau/teil_flur.py`, Flurkarte `daten/gelaende/flur.png`): 31 Blöcke mit 128 Streifen aus Acker (Furchen in Farbe und Normale), Getreide (goldene, hohe Halme), Weide (kurz) und Wiese (einzelne gelbe und weiße Blüten in Nestern, aus der Ferne nur als Schimmer); Getreide ungleich reif. Die Blöcke bleiben frei von Bäumen und Büschen (`baumfrei_vielecke`), Halme wachsen dort weiter. Bild: `docs/bilder/landschaft-2026-11-21/` |
| M8 | 01–04 | Küste als glatte Kante mit Sandstreifen | Ostküste fiel über 110 m flach zum Wasser ab, das Ufer der Bucht als 14 m breiter Abhang; Sand allein nach der Höhe | behoben: Ostküste fern vom Küstenweg als Klippe (Land 8–17 m über dem Wasser, ausgefranste Kante, kleine Strandbuchten), Ufer der Bucht steil und fern der Wege um 3–9 m angehoben; Sand nur noch auf flachem Ufer; die Fels-Haut aus Klippenscans steht jetzt auch an den Klippen der übrigen Küste. An den Landstraßen am Westufer der Bucht bleibt ein flaches Ufer. Bilder: `docs/bilder/kueste-2026-11-20/` |

## C. Stadt

| Nr. | Foto | Befund | Ursache | Stand |
|---|---|---|---|---|
| M4 | 01–04 | Dächer blass beige und gleichförmig | Die Ziegeltextur mittelt sich (helle Fugen und Flechten) aus der Ferne zu Beige; die Stadt baute nur Ziegel (`nur_ziegel`) | behoben: Ziegel kräftiger rotbraun in drei Tönungen je Hausvariante (rotbraun, dunkel gealtert, heller orange), die Stadt mit Schiefer im Wechsel (wie die Hausform es vorsieht, etwa ein Viertel); auch die Burgbauten (`material/dach.tres`) wärmer |
| M12 | 08, 21 | grauer Hügel mitten auf der Marktstraße | Geländebuckel von 1,5 m bei (143, 141): Der Erzeuger zog das feine Rauschen je Gasse erneut ab, an Kreuzungen mehrfach | behoben: in der Stadt nur einmal geglättet, Gelände neu erzeugt (Gassen bis 1,6 m tiefer bzw. 1,1 m höher); der Baucache prüft jetzt auch die Geländedaten |
| M13 | 09_st_marien | Haus und Kirche stehen auf Gras, Sockel ungleich hoch | Pflasterfläche reicht nicht bis St. Marien | behoben mit M37: zwischen Häusern und Kirche Pflaster bzw. festgetretene Erde; die Sockel stehen gleichmäßig auf (geprüft im Bild an St. Marien, `docs/bilder/stadt-2026-11-21/s2_st_marien_vorher_nachher.jpg`) |
| M14 | 08, 09 | große leere Fachwerkflächen, Giebelseiten ohne Fenster | Hausbau setzt Fenster nur an die Traufseiten; an den Schmalseiten nur Ständer und Rähm | behoben: Fachwerk rundum mit Riegeln, Streben, Kopfbändern, Andreaskreuze in jeder zweiten Brüstung; Fenster im Giebeldreieck (eines, bei breiten Giebeln zwei). `stadthaeuser.gd` baut die Seiten nach ±x mit denselben Funktionen, um 90° gedreht (`_quer`) |
| M15 | 08, 12 | Tauben und Möwen als flache Klötze | einfache Platzhaltermodelle | behoben: runde Formen (`szenen/figuren/vogelform.gd`): Körper und Kopf als Ellipsoid, Schnabel als Kegel, Flügel und Schwanz als Federflächen, Beine; Möwen mit schwarzen Flügelspitzen |
| M16 | 08 | dunkler Fleck auf dem Marktpflaster | eine Pfütze (Ausstattung Art 30): drei kreisrunde, fast schwarze, undurchsichtige Scheiben, die Schatten warfen | behoben (`ausstattung.gd`): unregelmäßige Flecken mit feuchtem Rand, halb durchsichtig (das Pflaster scheint durch), spiegelnd, ohne Schattenwurf |

## D. Burg

| Nr. | Foto | Befund | Ursache | Stand |
|---|---|---|---|---|
| M7 | 01–05 | Fels zwischen den Burgmauern wirkt wie grauer Kies | Felsmassiv: 1-m-Netz aus kantigen Felsbänken | in Arbeit: 2400 Brocken aus Fotoscans vor den Stufen (siehe M18), bis 450 m sichtbar |
| M17 | 14, 15 | glatte, graue Felsflächen am Sockel unter den Hofmauern | Felssockel: erzeugte Wand mit großen flachen Dreiecken | offen: Die Fels-Haut aus Felswand-Scans (rock_face_02) ist abgeschaltet (26.11.2026). Sie lag hinter den Blöcken der Wand, nur Kanten ragten als helle, waagrechte Bretter heraus („Pilze“ am Hang, auch auf dem Foto vom 21.11.); weiter vorn gesetzt standen die Stücke wie Regalbretter ab. Neuer Ansatz nötig |
| M18 | 14_fuss_der_rampe | Felsen grob facettiert, flächig | Felsmassiv: Stufen zwischen den Felsbänken als große Dreiecke | in Arbeit: Brocken aus Fotoscans (boulder_01, rock_07, zwei Namaqualand-Findlinge; entsättigt) halb eingegraben vor den Stufen, kleinere auf den Absätzen |
| M19 | 14_fuss_der_rampe | Stützmauer: Textur gestreckt und verwaschen | `stein.gdshader` projizierte entlang der Weltachsen: Auf schräg stehenden Mauern wurde der Stein gestreckt und doppelt überblendet | behoben: Wände werden entlang der Wand projiziert (waagrecht die Wandrichtung, senkrecht die Höhe), für alle Mauern der Burg |
| M20 | 15, 20 | Laubbäume als Low-Poly-Klumpen | einfache Baummodelle (Kegel und verbeulte Kugeln aus bewuchs.gd) | behoben: Bäume aus Fotoscans von Poly Haven (Tanne, junge Tanne, drei Laubbäume; `modelle/baeume/`), aufbereitet mit `werkzeuge/baum_laden.py`: Holz vereinfacht, Laub als Karten mit einem Atlas aus den echten Blättern; nah 3700–5500 Dreiecke, ab 160 m eine leichte Fassung (ein Material); Büsche aus der Krone eines Laubbaums. Wind: `szenen/welt/baum.gdshader` (der Baum wiegt sich mit der Höhe, das Laub flattert, gegen die Sonne scheint es durch). Bilder: `docs/bilder/baeume-2026-11-20/` |
| M21 | 16, 17, 18 | Höfe groß und leer | Belebung fehlt; alle Werkplätze standen am Hofrand, die Mitten waren leer | behoben (erste Runde): neun neue Stücke (`ausstattung.gd` 40–48: Werkbank, Sägebock mit Stamm, Zielscheibe, Gemüsebeet, Bank, Tisch mit Bänken, Hackklotz, Steinmetzplatz, Rüstungsständer). Vorburg: Hackplatz; Mittelburg: Zimmerplatz in der Hofmitte; Oberburg: Küchengarten, Steinmetz, zwei Marktstände in der Mitte; Palas: Übungsplatz der Knappen in der Mitte; in jedem Hof eine Bank und unter der Hoflinde ein Tisch. Dazu 15 Leute: Holzhacker, Zimmermann mit Lehrling, Gärtnerin, Steinmetz, Händlerin mit Kundin, zwei Knappen, sechs Leute bei der Rast (`teil_burgleben.py`). `werkplatz()` sucht jetzt auch frei im Hof (`mitte=True`: zuerst dort). Zweite Runde: Leiterwagen (Art 49) mit Zugpferd, Ladung und halb zurückgeschlagener Plane mitten in Vorburg, Mittelburg und Oberburg, je ein Fuhrmann dabei und Knechte, die vom Wagen zur nächsten Haustür tragen; Hühner picken am Wagen; im Palashof zwei Reitpferde am Anbindebalken mit Pferdeknecht und ein Wachtisch mit zwei würfelnden Wachen. Gruppen „frei im Hof“ suchen zuerst nahe der Hofmitte; die Blickpunkte des Foto-Rundgangs bleiben 8 × 8 m frei |

## E. Hafen

| Nr. | Foto | Befund | Ursache | Stand |
|---|---|---|---|---|
| M10 | 01–04 | Schiffe und Kräne aus der Luft nicht zu sehen | Ausstattung blendet nach 220 m aus, Zellen laden ab 240 m | behoben: Koggen bis 1400 m, Kräne und Prahme bis 900 m sichtbar, immer geladen |
| M22 | 12_drachenkai, 01–05 | Hafenwasser hell türkis wie ein Schwimmbecken, auch das offene Meer | Grundfarbe des Wassers ein helles Cyan, von der Sonne aufgehellt; keine Tiefe, keine Durchsicht, kein Ufersaum | behoben (`wasser.gdshader`): dunkles Blaugrün, Wassertiefe aus der Höhenkarte des Geländes (die Bildschirm-Tiefenkarte war im Fotoskript leer, deshalb nicht genutzt): flach durchsichtig und grünlich über dem Grund, tief fast schwarz, Gischt am Ufer; Hafenbecken, Kanal und Untergrundhafen trüb grünlich-grau und ruhiger. Bilder: `docs/bilder/hafen-2026-11-20/` |
| M23 | 12, 13 | Schiffe kastenförmig, Segel fehlen | einfache Modelle | behoben (`ausstattung.gd`): Rumpf mit geraden, schrägen Steven und Klinkerplanken (glatte Außenhaut), Barghölzer, Kiel, durchgesteckte Decksbalken; Kastelle als Plattformen mit Brüstung, Pfosten und Handlauf, Tür im Achterkastell; Heckruder mit Pinne; Mastkorb, Wanten mit Webeleinen, Stagen, Brassen, Schoten; gestreifte Segel (Leinen und Rotbraun): in der Bucht voll gebläht, im Hafen aufgetucht mit Zeisingen oder lose zum Trocknen gesetzt (neue Art 39). Auch Ruderboote und Prahme haben den neuen Rumpf |
| M24 | 12 | Kai sandfarben und glatt | Die Kaikante ist die 4 m breite Krone der Kaimauer, mit Bruchstein im 2-m-Raster, von oben wie Sand | behoben: `stein.gdshader` kann Oberseiten mit eigenen Steinen belegen (`mit_deckel`); die Kaikrone trägt große Steinplatten, weniger Moos (`material/kai.tres`, erzeugt von `werkzeuge/texturen_erzeugen.py`, `DECKEL`) |


## E2. Neu aus dem Rundgang vom 20.11.2026 (Hoch)

| Nr. | Foto | Befund | Ursache | Stand |
|---|---|---|---|---|
| M33 | 10_suedtor, 15, 17 | Rundtürme (am Südtor, an den Höfen) mit senkrecht gestreckter, verschmierter Textur | Folge der M19-Korrektur: Die Koordinate „entlang der Wand“ ist rund um einen Zylinder überall gleich, die Steine wurden zu senkrechten Streifen | behoben (`stein.gdshader`): gekrümmte Flächen (Änderung der Normale je Meter) bekommen wieder die Projektion entlang der Weltachsen, gerade Mauern behalten die Wandprojektion. Bild: `docs/bilder/hafen-2026-11-20/t1_suedtor_vorher_nachher.jpg` |
| M34 | 14_fuss_der_rampe, 16_mittelburg | graue Felsbrocken stoßen durch die Zwingermauer und ragen über die Mauerkrone | Das Felsmassiv (`felsmassiv.gd`) hebt den Felsgrund mit Blöcken bis 4,5 m über das Gelände und kannte die Mauern nicht; die Mauer an der Rampe ist eine Brüstung (Futtermauer), kein Mauerring | behoben: Das Bauskript sammelt alle Mauerzüge und Brüstungen (`MAUERLINIEN`, 218 Stücke im Burgbezirk) und gibt sie dem Felsmassiv; daneben bleibt der Fels ein flacher Sockel (0,4 m an der Mauer, volle Höhe erst ab 7 m), keine Brocken näher als 4 m. Nachgebessert (Rundgang 21.11.): Auch die Burgwege (110 Stücke) begrenzen den Fels, auf 14 m Breite; am Hang unter der Rampe standen sonst noch mannshohe, kantige Felszacken. Bild: `docs/bilder/hafen-2026-11-20/z1_rampe_vorher_nachher.jpg` |
| M35 | 01, 03, 05 | kleine flache Sandinseln im Meer vor der Mole | Die Felsufer der Bucht (M8) hoben einen 40 m breiten Streifen außerhalb des Bucht-Vielecks um 3–9 m an; das Vieleck endet im Osten aber im offenen Meer: ein Wall von Nord nach Süd knapp unter dem Wasser, stellenweise darüber | behoben (`gelaende_erzeuger.gd`): angehoben wird nur, was schon über dem Wasser liegt; der Meeresboden fällt jetzt gleichmäßig von −24 auf −32 m. Bild: `docs/bilder/hafen-2026-11-20/d1_draufsicht_vorher_nachher.jpg` |
| M36 | 12_drachenkai | Möwen liegen wie weiße Fische auf dem Kai | Sitzende Möwen ohne Beine, waagrecht und halb im Boden, Kopf in Linie mit dem Körper; die gefalteten Flügel zeigten nach vorn zum Kopf statt nach hinten | behoben (`moewen.gd`): Sie stehen auf Beinen, der Körper vorn leicht angehoben, Kopf auf dem Hals, die grauen Flügel an der Schulter angesetzt und über dem Rücken nach hinten gelegt, die schwarzen Spitzen über dem Schwanz; im Flug Beine eingezogen und Flügel wieder voll lang (vorher blieben sie nach dem ersten Landen halb so lang) |
| M38 | 13_untergrundhafen | Wasser im Untergrundhafen schwarz-weiß gefleckt (seit dem neuen Wasser) | Unter der Burg liegt das Gelände über dem Wasserspiegel; der Shader hielt das für Strand und malte Gischt | behoben: Liegt das Gelände mehr als 0,6 m über dem Wasser, gilt das Wasser als tief (Gang oder Halle im Fels) |
| M39 | 02–05 | Meeresgrund schimmert durch: helle Streifen, Sandbänke, Kante zum Fernmeer in der Draufsicht | Der Meeresboden ist eine flache Platte in 4 m Tiefe mit einer senkrechten Stufe auf 12 m; das Wasser war bis dahin durchsichtig | behoben: Sichttiefe 1,4 m, ab 3 m Tiefe ganz undurchsichtig; der Grund ist nur an Stränden zu sehen. Die helle Linie in der Draufsicht war der Wall aus M35 |
| M40 | 20_ordensvorwerk | Kamera steckt im Laub; im Hof des Vorwerks stehen Bäume, die Kronen ragen über die Mauern | Das Vorwerk fehlte in den baumfreien Flächen des Bewuchses; die Bäume sind seit M20 höher | behoben: Vorwerk (mit 2 m Rand) baumfrei; Blickpunkt 20 aus 32 m Höhe von Südosten über die Baumkronen (`werkzeuge/rundgang/drachenstein.json`) |
| M41 | 13_untergrundhafen | eine Platte ragt aus den Prahmen | Die rechteckige Ladefläche (3,8 × 10 m) war breiter als der neue, spitz zulaufende Rumpf (M23); der Staken stand 3,5 m schräg in die Luft | behoben (`ausstattung.gd`): Ladung steht auf dem Deck des Rumpfs, Staken längs abgelegt |
| M37 | 11_nordtor | Gasse endet an Häusern in Wiese (Gras zwischen den Häusern in der Stadt) | In der Stadt war nur die Wegemaske gepflastert; zwischen den Häusern lag Gras mit ein paar Erdflecken | behoben (`gelaende_material.gdshaderinc`): zwischen den Häusern festgetretene Erde, in Flecken gepflasterte Höfe, Gras nur noch in einzelnen Gärten. Bilder: `docs/bilder/stadt-2026-11-21/` |

## F. Figuren und Tiere

| Nr. | Foto | Befund | Ursache | Stand |
|---|---|---|---|---|
| M30 | 15, 16, 18 | Pferde einfarbig braun, Figuren aus der Nähe einfach | Modelle aus Detailstufe 3 | teilweise: Pferde mit sechs Fellfarben je nach Platz (Brauner, Fuchs, Rappe, Schimmel, Falbe, Dunkelbrauner; `tier.gd`); bessere Modelle für Figuren offen. Ausstattung: erste Stücke aus Fotoscans (Fass, Kisten, Korb, Werkzeug, Schild, Laterne, neu Eimer, Waschzuber und Hocker; `werkzeuge/modell_laden.py`, `docs/grafik-richtung.md`) |

## G. Echtheit (Runde vom 26.11.2026: „wie eine echte Burg“, Maßstab Kingdom Come 2)

| Nr. | Foto | Befund | Ursache | Stand |
|---|---|---|---|---|
| M42 | 16, 17, 18 (Hofbilder vom 21.11.) | Höfe als große, völlig gleichmäßige Pflasterflächen | Geländeshader: Burghof = Pflaster überall | behoben (`gelaende_material.gdshaderinc`): am Hofrand (Maske ringsum in 2,5 m abgetastet) Erde, Feuchte und Unkraut in Büscheln; ausgetretene Bahnen, kleine Erdlücken zwischen den Steinen, Matschflecken mit Pfützen (glatt und spiegelnd), Strohhalme im Dreck (nur nah) |
| M43 | 14–18 | Mauern glatt und überall gleich | Steinshader ohne Spuren der Bauzeit | behoben (`stein.gdshader`): Rüstlöcher in Reihen (Gerüstlagen alle 1,32 m, etwa jede dritte Stelle, ganze Lagen ohne), darunter helle Laufspuren; Flickstellen (spätere Ausbesserungen in hellerem Stein). Nur Mauer, Bruchstein und Basalt, nicht die hellen Gewände |
| M44 | 16, 17, 18 | an den Hofmauern nur Häuser, keine einfachen Holzbauten | – | behoben (`ausstattung.gd`, Art 53/54): Mauerschuppen mit Schindeldach auf Mauerlatte und Kragsteinen, Pfosten auf Steinsockeln mit Kopfbändern, Bretterwände; darin Brennholz, Fässer, Wagenrad, Werkzeug. Fünf Stück in Oberburg und Palashof (an den übrigen Mauern stehen schon Häuser) |
| M45 | 16 | nichts zeigt, dass an der Burg gebaut wird | – | behoben (Art 55): Baugerüst vor der Hofmauer der Mittelburg (Standbäume, Streichstangen, Netzriegel in den Rüstlöchern, Flechtwerk, Streben, Leiter, oben frische Quader, am Fuß Quader, Mörteltrog, Eimer) |
| M46 | 12, 15–19 | Wachen barfuß, Kettenhemd endet mitten am Oberschenkel, Eisenhut wie Chrom-Plastik | Füße des Grundkörpers mit Zehen; Kettenhemd-Schoß kurz; Hut aus Kugel und Zylinder | behoben (`docs/grafik-richtung.md`, fünfte Runde): Wendeschuhe, Haubert bis zum Knie, Kesselhut mit Nieten und Polsterhaube |
| M47 | alle | kein Ton: kein Wind, keine Schritte, kein Hämmern, keine Glocken | Das Spiel hatte bisher keine Geräusche | behoben (erste Runde, `docs/technik-weg.md` „Geräusche“): Wind, Vögel, Brandung, Feuer, Amboss, Glocken, Schritte, Tore, Türen, Kampf. Ton-Regler im Menü. Offen: Tiere, Markt, Hall |
| M48 | 18, 19 | Palashof und Übungsplatz: riesige leere Pflasterflächen | Werkplätze stehen am Rand, die Mitte bleibt frei | behoben (erste Runde): Misthaufen mit Forke und Jauchepfütze (Art 56) und Karren in Vorburg und Mittelburg, Kräutergärten im Flechtzaun aus Weidenruten (Art 57) mit zwei Beeten in Oberburg und Palashof (dort zwei), Fässerlager in Mittelburg, Oberburg und Palashof |
| M49 | – | Rundgang-Fotos im Container: Stücke und Leute fehlten auf den ersten Bildern | Die Ausstattung meldet ihre Zellen erst an, wenn alles auf dem Boden steht; die Körper der realistischen Menschen laden im Hintergrund | behoben (`rundgang.gd`): wartet auf die Ausstattung und auf die Körper der Figuren nahe der Kamera (bis 40 s je Blickpunkt) |

## H. Rückmeldung aus dem Spiel (26.11.2026, Bilder vom Referenzrechner)

| Nr. | Befund | Ursache | Stand |
|---|---|---|---|
| M50 | schwarze Quadrate auf den Mauern | Rüstlöcher (M43) zu dunkel und zu viele | behoben: abgeschaltet |
| M51 | Glockenton zu basslastig | Unterton so laut wie die Nominale, Glocke in G3 | behoben: Unterton leise, Nominale und obere Teiltöne tragen, D4/D5 |
| M52 | Schritte zu leise, passen nicht zur Bewegung | Schritte nach zurückgelegter Strecke | behoben: Schritte, wenn ein Fuß aufsetzt (Fußknochen der Animation), 3 dB lauter |
| M53 | Sprint hängt, die Figur gleitet | Tempo je Bild gemessen: bei mehr Bildern als Physikschritten sprang es zwischen 0 und dem Doppelten, die Animation wechselte ständig | behoben: Tempo nur bei Lageänderung, Spielraum an den Grenzen |
| M54 | Stoff zittert statt zu schwingen | Schrittweite des Stoffs mit der Bildzeit schwankend | behoben (Modul): feste Schrittweite, Ruck im Stand 0,11 statt 0,63 mm; Dämpfung verdoppelt |
| M55 | Füße verschwinden fast im Boden | Netz des Geländes liegt an Hängen höher als seine Kollision | behoben: Figuren 2,5 cm höher (im Spiel prüfen) |
| M56 | Bäume schweben teils | Stamm an einem Punkt auf den Hang gesetzt | behoben: so tief eingesunken wie der tiefste Punkt im Umkreis, dazu 10 cm |
| M57 | Menschen merkwürdig gebaut | Frauen 1,86 m (größer als Männer), aus der Skalierung aufs Becken der Animation | behoben: 1,62 / 1,74 m; weitere Proportionen offen |
| M58 | Männer mit grauen Bärten | Haarfarbe als sRGB in den linearen Farbfaktor | behoben: lineare Farbe |
| M59 | Hüte schweben oder stecken im Kopf | Hut 12 cm über dem Kopfknochen, die Köpfe sind aber verschieden hoch | behoben: auf dem Scheitel des Modells |
| M60 | Marktbrunnen zu einfach | drei Zylinder | behoben: Stockbrunnen (`marktbrunnen.gd`) mit Stufen, Becken, Säule, Röhren, Strahlen, Plätschern |
| M61 | Wasser wie ein blauer Boden | keine Spiegelung | behoben: Himmelsspiegelung nach Fresnel, feine Kräuselung nah |
| M62 | Holzfässer mit verbuggter Textur | grobe Vereinfachung (simplify_sloppy) zerriss die UV-Nähte | behoben: nahe Fassung ohne grobe Vereinfachung, 3475 statt 884 Dreiecke |
| M63 | Dach schwebt (von vorn) | Giebeldreieck endete 0,5 m unter dem Dach | behoben: Giebelwand bis an die Dachunterseite |
| M64 | Mauerstücke am Tor der Mittelburg | Brüstung der Rampe als waagrechte Stufenblöcke | behoben: Brüstung mit schräger Krone und Abdeckplatte |
| M65 | Platten statt Stoff an manchen Menschen | starre Schürzen, Wappenröcke und Talare für Berufe ohne eigenes Modell | behoben: nur noch Kleidung aus Stoff; neues Modell `wache_frau` |
| M66 | letzter Burghof: alles auf einem Haufen in der Mitte | Gruppen frei im Hof suchten alle die Mitte | behoben: Abstand zu den anderen Gruppen |
| M67 | KI der Leute zu einfach | – | erste Runde: Gruß je Tageszeit, Umschauen, Reaktion auf gezogene Waffen. Zweite Runde: Werkzeug in der Hand bei der Arbeit (Axt, Hammer, Hacke, Forke, Besen, Kochlöffel, Buch, Netz; nach Name und Beruf), Gespräche mit Inhalt (`szenen/figuren/gespraechsthemen.gd`: Wortwechsel nach Tageszeit, Alarmstufe, Beruf und Markt, als Zuruf über dem Sprecher bis 12 m, schleichend nah auch unten im Bild), Lärm (Schuss bis 60 m, Kampf bis 18 m): Bürger schreien und laufen fort, Wachen ziehen und eilen hin, danach geht jeder an seinen Platz zurück. Offen: Wetter, Tätigkeiten mit Ablauf (Wasser holen, Holz tragen), Schlafen und Essen |
| M68 | Grafik und Detail insgesamt | – | laufend |

## Nächste Schritte

1. Neuer Rundgang (Hoch und Episch) zur Bestätigung von M1–M3, M9, M11, M22, M25–M29.
2. Fehler im Bau: M12, M13, M17, M16.
3. Fernsicht: M10, M5, M8, M6/M20, M7, M4.
4. Modelle und Materialien: M18, M19, M14, M15, M23, M24, M30.
