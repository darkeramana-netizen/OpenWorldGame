# Sorrowland: In Silentio

> *In silentio vigilamus. Aber wenn die Stille endet, handeln wir.*

Ein Open-World-Rollenspiel im Sorrowland des Jahres 1750: Du trittst als Vertriebener an die Schwelle des Ordo Custodum und steigst vom Anwärter zum Wächter auf, während die 620 Jahre alte Stille zu zerbrechen droht.

- Lore: [`docs/01-lore-bibel.md`](docs/01-lore-bibel.md)
- Spielkonzept und Fahrplan: [`docs/02-spielkonzept.md`](docs/02-spielkonzept.md)
- Karten: [`docs/bilder/`](docs/bilder/)

![Die Region Drachenstein](docs/bilder/region-uebersicht.png)

## Stand

### Stufe 4: Kampf, Ansehen, Akte und Verfahren, Alarmstufen

**Kampf (selten und gefährlich, Bewaffnung nach der Lore):**
- **F** zieht die Waffe, **Q** wechselt zwischen Säbel und Steinschlossmuskete.
- **Säbel:** Mit der linken Maustaste schlägst du, mit der rechten blockst du. Ein Block fängt drei Viertel eines Hiebs von vorn ab, gegen Kugeln hilft er nicht.
- **Muskete:** Ein Schuss über das Fadenkreuz, danach ist sie leer. Mit **R** lädst du nach. Das dauert acht Sekunden, und solange bist du langsam. Ungeladen stößt du mit dem Bajonett zu.
- **Gegner kündigen sich an:** Wer ausholt oder anlegt, braucht einen Moment. In der Zeit kannst du zurückweichen oder blocken.
- **Verwundung:** Wer zu Boden geht, stirbt nicht. Wächter bergen dich und bringen dich in die Heilstube, ein halber Tag vergeht, und die Verwundung steht in der Akte.
- **Übungsplatz** mit zwei Puppen in der Oberer Burg.
- **Erster Auftrag mit Kampf:** Die Bezirkswache von Erlengrund an der Südstraße schickt dich gegen ein Lager von Gesetzlosen im Wald. Zwei haben Säbel, einer hat eine Muskete. Besiegte bleiben liegen, auch nach dem Laden.

**Ansehen** bei sechs Gruppen: Treue, Zweifler, Rufer, Dörfer, Riverlock und die Stadt Drachenstein.
- Es ändert sich durch Antworten und Taten:
  - Haltung gegenüber Zollherr Falk
  - was du der Dorfvorsteherin über die Rufer sagst
  - der Auftrag gegen die Gesetzlosen
  - eine Waffe gegen Unbeteiligte
- In der Akte (Tab) stehen alle Werte. Dialoge können darauf reagieren (`ansehen_doerfer>=10`).

**Akte und Verfahren (Disziplin 3.7):**
- Drei Verweise führen zu einer Anzeige.
- Eine Waffe gegen Ordensleute bringt jedes Mal einen Verweis.
- Eine Waffe gegen Dorfbewohner bringt beim ersten Mal eine Anzeige, beim zweiten Mal eine Anzeige auf **Ausstoßung**.
- Ein offenes Verfahren steht in der Akte und als Ziel oben links.
- Beim Kammerhüter läuft es wie in der Lore: Vorprüfung, Zeugen, Urteil. Der Bürge wird mitverhandelt.
- Die Urteile:
  - Degradierung um einen Rang
  - Strafversetzung
  - Ausstoßung: Der Namensstein wird geschlagen, das Spiel endet.
  - Verbannung über Riverlock: Das Spiel endet.

**Alarmstufen 0–3:** Stille, Wachsamkeit, Ende der Stille, Die letzte Linie. 1750 gilt Stufe 1. Die Stufe steht oben rechts.
- **Ab Stufe 2** brennt auf allen Signaltürmen das Feuer (Ring der Feuer), mit einer Blende.
  - Die Händlerin verlässt den Markt.
  - Die Lotsin fährt nicht mehr: Die Kette liegt über der Valn.
  - Die Bezirkswachen räumen nach den Dorfbüchern.
- **Stufe 3:** Die Dörfer an den Straßen sind geräumt.
- Im Entwicklermenü (F10) lässt sich die Stufe umschalten. Dialoge setzen sie mit `"alarm": 2`.

### Die Landwege: einmal um das Wächtermeer

Die drei Straßen aus der Lore sind jetzt begehbare Strecken. Jede ist eine eigene, lange Region im Maßstab **1:100** (1 km = 10 m):

| Straße | Verbindung | Lore | im Spiel | Reisezeit |
|---|---|---|---|---|
| **Nordstraße** | Drachenstein – Riverlock, nördlich um das Meer | 225 km | 2,25 km | 9 Tage |
| **Südstraße** | Ashenveil – Riverlock, südlich um das Meer | 185 km | 1,85 km | 7 Tage |
| **Küstenweg** | Drachenstein – Ashenveil, an der Westküste | 70 km | 0,7 km | 3 Tage |

- **Anschlüsse:**
  - Drachenstein hat zwei neue Tore in der Ringmauer: das **Nordtor** (Nordstraße) und das **Südtor** (Küstenweg). Hinter beiden führt die Straße über einen **Pass** durchs Gebirge.
  - In Riverlock geht die Nordstraße nach Westen ab, die Südstraße nach Süden.
  - In Ashenveil beginnt der Küstenweg am Ende des Damms, die Südstraße am Ostpfad.
  - Wer am Ende eines Weges weitergeht, ist in der nächsten Region.
- **Zeit:** Die Reisetage vergehen erst, wenn du am anderen Ende ankommst, und es folgt eine Blende. Wer umkehrt, verliert keine Tage.
- **Unterwegs:**
  - **Signaltürme** wie in der Lore alle 15 km zwischen Straße und Meer
  - **Meilensteine** mit den echten Entfernungen
  - **Bezirksfestungen**, Dörfer und Wald; links und rechts das Meer und das Gebirge
- **Leute an der Straße:**
  - Dorfvorsteherin Berit Haag in Hollmar (erzählt von den Rufern)
  - Feuerwart Tobias Wern an einem Signalturm
  - Torfstecherin Mara Lind in Torfwinkel
  - je eine Bezirkswache
- **Als Anwärter** kommst du nicht aus der Burgfeste hinaus. Erst als Wächter lassen dich die Pässe durch.
- **Karte (M):** Der Pfeil wandert die Straße entlang.
- Schiff (Lotsin) und Pferd (Reiterin) bleiben die schnelle Abkürzung.

| Nordstraße mit Dorf und Signaltürmen | Südstraße am Meer | Pass im Norden von Drachenstein |
|---|---|---|
| ![Nordstraße](docs/bilder/landweg-nordstrasse.png) | ![Südstraße](docs/bilder/landweg-suedstrasse.png) | ![Pass](docs/bilder/landweg-pass.png) |

### Ashenveil: die dritte Region

Ashenveil, die Reiter- und Rüstburg im **Nebelmoor**, ist eine eigene Region mit dichtem Nebel. Gebaut ist sie nach deinem Grundriss, ohne Drehung.

- **Hinkommen:**
  - Vor dem Vorburgtor von Drachenstein wartet die **Reiterin Ilka Sand** aus Ashenveil. Sie nimmt Wächter über den Küstenweg mit: anderthalb Tage Spielzeit, dann eine Blende. Zurück geht es ebenso mit ihr. Anwärter nimmt sie nicht mit.
  - Du kommst am Anfang des Damms an.
- **Nur ein Weg:** Der Damm führt durch den Sumpf zur Zugbrücke am Haupttor. Wer ihn verlässt und in einen Tümpel gerät, wird zurückgesetzt: „Der Morast verschluckt jeden, der den Weg verlässt.“
- **Die Burg nach Plan:**
  - Ecktürme 27–30 und die Offenen Gänge entlang der Mauern
  - Torhaus (14) mit Fallgitter, das nur für Wächter oben ist
  - Westtrakt: Große Reithalle (1) und Marstall (2) mit Pferden, beide begehbar; dazu Futterkammern (3–5) und Heuboden (6)
  - Nordreihe: Sattlerei, Waffen- und Zeugkammer, Waffenschmiede (7–9, 19)
  - Mitte: der Überdachte Große Innenhof (10)
  - Osttrakt: Rüstkammern (11, 20), Schmieden (16, 21), Mannschaftsunterkünfte (22) und Kernspeicher (23)
  - Südtrakt: Küche (12), Vorratslager (13) und Waffenlager (15)
- **Nebeneingang im Osten:** Er hat eine Zugbrücke, ist aber verriegelt. Zwei Wachen aus zwei verschiedenen Wachgruppen stehen dort, eine Lehre aus dem Verrat von 1065.
- **Unterirdisch:**
  - Vom Innenhof führt eine Rampe hinunter zur **Kapelle der Stille (A)**. Dort steht ein Gedenkstein für den Verrat von 1065.
  - Von der Kapelle läuft der **Fluchttunnel (B)** unter Mauer und Graben hindurch bis zu einem verdeckten Ausgang im Moor.
- **Personen:** Komtur Arvid Rask im Innenhof (erzählt von 1065 und den Lehren daraus), Wachführer Henk Brask am Haupttor, die beiden Wachen am Nebeneingang und die Reiterin.

| Ashenveil vom Damm | Von oben (Norden oben) | Fluchttunnel |
|---|---|---|
| ![Ashenveil](docs/bilder/region-ashenveil.png) | ![Draufsicht](docs/bilder/ashenveil-draufsicht.png) | ![Fluchttunnel](docs/bilder/ashenveil-fluchttunnel.png) |

### Riverlock: die zweite Region

Riverlock liegt laut Karte rund 190 km Seeweg entfernt am Ostrand von Sorrowland. Deshalb ist es eine **eigene Region** mit eigenem Gelände, der **Valnschlucht**. Die Valn fließt von Norden nach Süden, dahinter steigen die Felswände an. Gebaut ist Riverlock nach deinem Grundriss, ohne Drehung.

- **Hinkommen:** Als Wächter (nach Akt I) bringt dich die **Lotsin Wenna Kroll** vom Südkai in Drachenkai nach Riverlock. Die Fahrt dauert gut zwei Tage Spielzeit, und am Ende kommt eine Blende. Zurück geht es ebenso mit ihr. Als Anwärter nimmt sie dich nicht mit.
- **Westburg (A) und Ostburg (C):**
  - Ringmauern mit runden Türmen, Äußere Toranlagen (1, 23) und Vorwerke (5, 27) zum Mittelbau.
  - In beiden Burgen: Bergfried, Großer Saal, Küchen, Kapelle, Innere Wache, Ställe, Waffenhof und Torhof.
  - Von der Ostburg geht die Straße nach Valdrenn ab.
- **Mittelbau über der Valn (B), drei Geschosse, alle begehbar, über Rampen verbunden:**
  - **unten die Hafenhalle (16):** Hier kommst du an. Kais, Stege und Boote, die Schiffsdurchfahrt durch fünf Bögen (15).
  - **in der Mitte Zoll und Kontrolle:** Lager, Wachstube und Zoll, durch sie führt der Weg vom Westlichen zum Östlichen Tor (14, 22).
  - **oben der Große Saal (20)** mit dem Ratstisch, rundum der Wehrgang (21).
  - Kettensperren von den Tortürmen zu den Ufern.
- **Personen:**
  - **Zollherr Hendrik Falk** (aus der Lore) und der **Beobachter des Ordens** im Großen Saal.
  - eine Zöllnerin im Mittelgeschoss, ein Torwächter an der Westburg, die Lotsin in der Hafenhalle.
- **Karte (M):** Der Pfeil steht in Riverlock auf Riverlock.

| Riverlock von Süden | Von oben (Norden oben) | Hafenhalle |
|---|---|---|
| ![Riverlock](docs/bilder/region-riverlock.png) | ![Draufsicht](docs/bilder/riverlock-draufsicht.png) | ![Hafenhalle](docs/bilder/riverlock-hafenhalle.png) |

### Gravemarch nach Grundriss

Gebaut nach deinem Grundriss der Talburg, um 180° gedreht: Das **Äußere Torhaus (A)** zeigt nach Nordosten zum Weg aus Drachenstein, die **Kernburg (G)** liegt im Süden.

- **Aufbau:** ein aufgeschütteter Hügel im Sumpf mit Wassergraben an drei Seiten. An der Seite der Kernburg gibt es keinen Graben, wie im Plan.
- **Zugang:** Über die **Brückenpforte (2)** und die Brücke kommt man zum Torhaus.
- **Drei Ringe:**
  - die Hauptmauer mit Nordost-Bastei,
  - die **Alte Mauer (M)** mit einem Tor am **Zwinger (5)**,
  - der **Innere Wehrgang (F)** mit dem **Geknickten Tor (6)**. Hinter diesem Tor steht eine Prallwand, an der man abbiegen muss.
- **Kein gerader Weg:** Vom Torhaus geht es an der Mauer entlang durch die enge Gasse am Zwinger. Danach führt der Weg am Kapellenbezirk vorbei zum geknickten Tor und in den Burghof.
- **Viertel und Bauten:**
  - Vorburg (B), Handwerkergasse (7), Mittlerer Hof (D) mit Brunnen, Schmiedegasse (11)
  - Alter Markt (C), Mühle mit Wasserrad (22), Wachhaus (8), Speicherhof (10)
  - Kapelle St. Alriks (16), Wasserwerk (K), Zisternenhof (21), Alter Wehrturm (4)
- **Kernburg:**
  - **begehbarer Donjon (18)**, 22 m hoch, mit vier Ebenen
  - Palas mit Großer Halle (14, 15), Treppenturm (12), offene Halle im Vorhof (3)
  - **Bibliothek (17)** mit der Archivarin Ysolde Brack, die die fünf Bauphasen aus deinem Plan erzählt
- **Täuschungen:**
  - Das **unechte Südtor (23)** steht prächtig auf einer Insel im Graben, dahinter ist nur Stein.
  - Das **Tor in der Alten Mauer** am Mittleren Hof ist zugemauert.
  - Das **Südliche Vorwerk (I)** führt zu einem vermauerten Tor.
  - Die **Verborgene Pforte (19)** hinter dem Palas ist verriegelt.
  - Der **Verfallene Vorhof (L)** liegt als Ruine vor der Ostmauer.

| Gravemarch von Nordosten | Von oben (Norden oben) |
|---|---|
| ![Gravemarch](docs/bilder/region-gravemarch.png) | ![Draufsicht](docs/bilder/gravemarch-draufsicht.png) |

Deine Grundrisse liegen in [`docs/bilder/`](docs/bilder/) (`grundriss-*.webp`), auch die von Riverlock und Ashenveil.

### Burgfeste Drachenstein nach Grundriss

Gebaut nach deinem Grundriss, **gedreht**: Der Süden des Plans liegt jetzt im Osten, der Hafen öffnet sich zum Wächtermeer.

- **Mittlere Burg:** der Hof aus Akt I, unverändert.
- **Oberer Burg (Drachenhorst)** im Westen, auf Höhe der Hofmauerkrone (8 m), mit eigener Ringmauer, Tor im Süden, Urkern, Aussichtsplattform, Palas, Kapelle und Zeughaus. Von der Hofmauer führt ein Durchlass hinüber.
- **Stadt:** Die Ringmauer (Löwenward) umschließt alles, mit dem **Vorburgtor** am Weg nach Gravemarch und dem **Ölturm** an der Nordspitze. Darin liegen gut 50 Stadthäuser, die **Terrassengärten** an der Ringmauer im Süden, der **Marktplatz** mit Brunnen und Ständen, die **Kirche St. Georg** und das **Rathaus** am Hafen.
- **Drachenkai:** Hafenbecken mit Kaimauern zwischen Nord- und Südmole, an den Molenköpfen **Hafentor** und **Schiffstor**. Dazu Zollhaus, Dockspeicher und drei Schiffe.
- **Zum Bergfried:** Von der Südmole führen drei Brücken über zwei Inseln zum Tor des Bergfrieds.

Der Weg vom Hoftor führt den Hang hinunter über den Markt bis an den Kai.

| Drachenstein vom Meer | Von oben (Norden oben) |
|---|---|
| ![Drachenstein vom Meer](docs/bilder/region-drachenstein.png) | ![Draufsicht](docs/bilder/drachenstein-draufsicht.png) |

### Innenräume: Schwarzer Bergfried und Gravecrest

Gebaut nach deinen Grundrissen und Schnitten.

**Schwarzer Bergfried:** achteckiger Turm, 40 m breit. Die Mauern sind unten 10 m dick, im Schaft 5 m und an der Krone 3 m. Der Turm verjüngt sich nach oben und wird an der Krone wieder breiter. Alle 13 Ebenen sind begehbar, über eine **Wendelrampe um die Mittelsäule** im zentralen Treppenhaus:

| Ebene | Raum | Ebene | Raum |
|---|---|---|---|
| −4 | Sonderzellen | 3 | Ausbildung |
| −3 | Zellentrakt | 4 | **Archive** mit dem **Namensbuch** und **Hüterin der Stille Leofa Marsh** |
| −2 | Zisternen | 5 | **Stillebene**, vollständig leer |
| −1 | Interne Sicherung | 6 | Thronsaal, bewusst schlicht |
| 0 | Schwelle (Eingang von der Brücke) | 7 | Vorbereitung |
| 1 | Wachring | 8 | Observatorium |
| 2 | Unterkünfte | Dach | Zinnen und das **Feuerbecken des ersten Feuers** |

Der Unterbau liegt unter dem Meeresspiegel. Das Tor öffnet der Bergwächter erst nach dem Haupteid, dann darfst du deinen Namen im Namensbuch suchen.

**Gravecrest:** nach dem Grundriss, alle nummerierten Räume begehbar:
- **Palas-Block** mit Kaisersaal, Imperialen Gemächern, Audienzsaal, Bibliothek, Schreibstube, Garderobe, Speisesaal und der Kapelle des Sorrow, verbunden über eine Halle.
- **Oberer und Unterer Hof** mit Schmieden, Apotheken, Wachräumen, Kaserne, Akademie, Badehaus, Speichern, Ställen und Brunnenhäusern.
- Der **achteckige Donjon** trennt die Höfe. Man geht durch ihn hindurch und kann über die Wendelrampe zur Signalfeuerplattform steigen.
- **Torhaus** mit Fallgatter und Zugbrücke über den Abgrund, Flaschenzug an der Westseite.
- Im Audienzsaal sitzt **Komtur Torben Wick**.
- Das Fallgatter zieht der Kammbrecher an der Brücke erst für Wächter hoch.

| Wendelrampe im Bergfried | Archive mit Namensbuch |
|---|---|
| ![Wendelrampe](docs/bilder/innen-wendelrampe.png) | ![Archive](docs/bilder/innen-archiv.png) |
| **Der Schwarze Bergfried** | **Gravecrest von oben** |
| ![Bergfried](docs/bilder/innen-bergfried-aussen.png) | ![Gravecrest](docs/bilder/innen-gravecrest-grundriss.png) |

### Die Region Drachenstein

Die erste begehbare Region, gebaut nach deiner Karte im Maßstab **1:50** (1 km = 20 m). Gebäude sind noch Platzhalter aus einfachen Formen.

| Ort | Was dort steht |
|---|---|
| **Burgfeste Drachenstein** | nach Grundriss (siehe oben): Hof, Oberer Burg, Stadt mit Markt, Kirche und Rathaus, Ringmauer mit Vorburgtor und Ölturm |
| **Drachenkai** | Hafenbecken im Osten, Molen mit Hafentor und Schiffstor, Zollhaus, Schiffe, Lotsin aus Riverlock |
| **Brücken zum Bergfried** | drei Brücken von der Südmole über zwei Inseln |
| **Schwarzer Bergfried** | 100 m hoher achteckiger Turm mit Krone und äußerer Mauer, Bergwächter am Tor |
| **Gravemarch** | nach Grundriss (siehe oben): Talburg im Sumpf mit Wassergraben, drei Ringen, Scheintoren und begehbarem Donjon |
| **Gravecrest** | auf dem eisigen Felssporn (Höhe 70), Weg hinauf, Zugbrücke über den Abgrund, Torhaus, achteckiger Donjon, Palas |
| **Eisgrat** | Gebirge ringsum, Signaltürme an der Küste |

Dazu kommen:
- **Ortsnamen**, die beim Betreten groß eingeblendet werden.
- **Karte auf M** (deine Sorrowland-Karte, mit Pfeil für Position und Blickrichtung).
- **Schutz vor Meer und Rand:** Wer ins Wächtermeer fällt oder über den Rand will, wird zurückgesetzt.
- Fünf neue Personen in der Region.

| Drachenstein und Hafen | Gravecrest auf dem Felssporn |
|---|---|
| ![Drachenstein](docs/bilder/region-drachenstein.png) | ![Gravecrest](docs/bilder/region-gravecrest.png) |
| **Brücken zum Schwarzen Bergfried** | **Karte (M)** |
| ![Bergfried](docs/bilder/region-bergfried.png) | ![Karte](docs/bilder/region-karte.png) |

### Akt I – „Die Schwelle“ ist durchspielbar

Akt I spielt im Hof der Burgfeste Drachenstein und führt in etwa drei Spieljahren (1750 bis 1753) vom Bewerber bis zum Haupteid:

| Rang | Was du tust | Bei wem |
|---|---|---|
| Bewerber → **Anwärter** | Vorgespräch und Gelöbnis an der Schwelle | Kammerhüter Wendel Groth (am Tor) |
| Anwärter | Bruchsteine aus dem Bauhof, Küchendienst beim Mittagsmahl (12–13 Uhr) | Hüterin Maren Sell, Verwalterin Ilse Dorn |
| | *Das Probejahr vergeht* | |
| Knappenprüfung | **Lesen:** drei Fragen zur Ordensregel | Schreiber Odo Hesse (Schreibstube) |
| | **Handwerk:** Eckstein an der Werkbank behauen (tagsüber) | Werkmeisterin Hedda Brunn (Bauhof) |
| | **Nachtwache** neben einem Hüter bis zum Morgengrauen | Hüter Anselm Kray (Wehrgang) |
| → **Knappe** | Eid des Knappen, *zwei Lehrjahre vergehen* | Maren Sell |
| | **Torwache**, zwei Stunden, bis die Ablösung kommt | Wachführer Ivo Grend (Tor) |
| → **Geselle** | Eid des Gesellen | Maren Sell |
| | **Fenn** wirbt für die Rufer: melden, schweigen oder die Nebenpforte öffnen | Fenn, Kammerhüter |
| | **Nachtwache allein auf dem Turm**, Zustimmung von Hüterin und Wachführer | Wachturm, Maren Sell, Ivo Grend |
| → **Wächter** | Haupteid, dein Name kommt als Stein in die Ordenswand | Komtur Aldric Hayn (Ordenswand) |

Dazu kommen diese Systeme:

- **Tageszyklus** nach dem Alltag des Ordens mit Mondlicht in der Nacht. Um 19 Uhr beginnt die **Stille-Stunde**: Wer dann spricht, wird ermahnt und bekommt danach einen Verweis.
- **Dienstakte** (Tab) mit Rang, Kordel, Bürge und allen Einträgen. Verweise färben sie rot, und bei Beförderungen zögert dann die Versammlung.
- **Wachposten:** Wer einen Posten vor der Ablösung verlässt, bekommt einen Verweis („Nicht früher, nicht später.“).
- **Ziel-Anzeige** oben links, damit du immer weißt, was als Nächstes kommt.
- **Kordel am Kragen** der Spielfigur je nach Rang: keine, schwarz, grau oder golden.
- **Drei Ausgänge für Fenn:** Wer meldet, bleibt sauber. Wer schweigt, bekommt einen Verweis, und der Bürge wird mitverhandelt. Wer die Pforte öffnet, wird verbannt, und das Spiel endet.
- **Speichern und Laden** (siehe unten).

![Der eigene Stein in der Ordenswand](docs/bilder/akt1-eigener-stein.png)

## Starten

1. **Godot 4.7** (oder neuer) herunterladen: <https://godotengine.org/download>
   Die **Standardversion** nehmen, nicht die .NET-Version. Godot muss nicht installiert werden, die Datei einfach entpacken und starten.
2. Im Projektmanager auf **Importieren** klicken und die Datei `project.godot` aus diesem Ordner wählen.
3. Im Editor oben rechts auf **▶ (Projekt starten)** klicken oder **F5** drücken. Das Spiel beginnt im Hauptmenü.

## Steuerung

| Taste | Aktion |
|---|---|
| W A S D | gehen |
| Umschalt | rennen |
| Leertaste | springen |
| Maus | Kamera |
| E | sprechen, aufheben, arbeiten, im Gespräch weiter |
| 1–9 | Antwort wählen (oder mit der Maus klicken) |
| Tab | Dienstakte ein/aus |
| M | Karte ein/aus |
| T | eine Stunde vorspulen (praktisch für Nachtwachen) |
| Esc | Pausemenü: Speichern, Laden, Hauptmenü |
| F5 / F9 | schnell speichern / schnell laden (im laufenden Spiel) |
| F | Waffe ziehen / wegstecken |
| Q | Säbel oder Muskete |
| linke Maustaste | Hieb, Schuss, ungeladen Bajonett |
| rechte Maustaste | blocken (Säbel) |
| R | Muskete nachladen (acht Sekunden) |
| F10 | Entwicklermenü (nur beim Start aus dem Editor): zu Orten springen, Uhrzeit, in eine andere Region reisen, Alarmstufe, alle Tore öffnen, Akt I überspringen |

Den Wehrgang erreichst du über die Holzrampe an der Südmauer, westlich vom Tor. Von dort führt die Westmauer zur zweiten Rampe hinauf auf den Wachturm in der Nordwestecke.

Wege durch die Region: Vom Tor des Hofs führt der Weg nach Osten über den Marktplatz zum Drachenkai und von der Südmole über die Brücken zum Bergfried. Ein zweiter Weg steigt nach Westen zum Tor der Oberer Burg. Der Weg nach Westen führt aus dem Vorburgtor ins Tal bis zur Brückenpforte von Gravemarch. Kurz vor Gravemarch zweigt der Weg nach Norden ab und steigt auf den Felssporn nach Gravecrest.

## Speichern und Laden

- **Hauptmenü:** Fortsetzen (neuester Spielstand), Neues Spiel (mit deinem Namen), Laden, Beenden.
- **Pausemenü (Esc):** drei Speicherplätze, Laden aus allen Plätzen.
- **Automatisch** wird nach jedem Rangwechsel und jedem Zeitsprung gespeichert.
- **Schnellspeichern** mit F5, schnell laden mit F9.
- Gespeichert werden Name, Rang, Akte, Flags, Zähler, Ziel, Uhrzeit und Jahr, die Region, Position und Blickrichtung sowie aufgehobene Gegenstände.
- Die Dateien liegen als lesbares JSON im Godot-Benutzerordner unter `speicher/`. Unter Windows ist das `%APPDATA%\Godot\app_userdata\Sorrowland_ In Silentio\speicher\`. In Godot öffnest du den Ordner über **Projekt → Benutzerdatenordner öffnen**.

## Projektaufbau

```
project.godot              Projekteinstellungen, Tastenbelegung, Autoloads
autoload/                  immer geladene Spielsysteme
  spielzeit.gd             Uhrzeit, Jahr, Tagesabschnitte, Stille-Stunde, Zeitsprünge
  spielstand.gd            Name, Rang, Akte, Verweise, Flags, Zähler, Ziel, Bedingungen
  dialog.gd                liest und führt die Gespräche aus daten/dialoge/
  speicher.gd              Speichern, Laden, neues Spiel, Reisen zwischen Regionen
szenen/
  oberflaeche/hauptmenue.tscn  Startszene
  oberflaeche/pausemenue.tscn  Esc-Menü
  oberflaeche/hud.tscn     Uhr, Ziel, Hinweise, Gesprächsfenster, Akte, Blenden
  welt/region_drachenstein.tscn  Region Drachenstein: Gelände, Meer, Burgen, Brücken, Orte, Personen
  welt/region_riverlock.tscn     Region Riverlock: Valnschlucht, Westburg, Mittelbau, Ostburg
  welt/region_ashenveil.tscn     Region Ashenveil: Nebelmoor, Burg, Kapelle der Stille, Fluchttunnel
  welt/region_nordstrasse.tscn, region_suedstrasse.tscn, region_kuestenweg.tscn  die Landstraßen
  welt/uebergang.gd        Übergang am Ende eines Weges in die nächste Region
  welt/bedingt_sichtbar.gd sichtbar unter einer Bedingung, z. B. Signalfeuer ab Alarmstufe 2
  welt/wasserdicht.gd      Bereich unter dem Wasserspiegel, in dem niemand zurückgesetzt wird (Keller, Tunnel)
  welt/region.gd           Wurzel einer Region: Wasser, Rand, Lage auf der Karte
  welt/gelaende.gd         baut Gelände und Kollision aus daten/gelaende*/
  welt/burg_hof.tscn       der Hof aus Akt I mit seinen Personen und Posten
  welt/gelaende.gdshader   Farben des Geländes: Strand, Gras, Fels, Schnee, Wege, Sumpf
  welt/wasser.gdshader     das Wächtermeer
  welt/auf_gelaende.gd     setzt Häuser und Personen auf die Geländehöhe
  welt/ort.gd              benannter Ort, zeigt beim Betreten den Namen
  welt/haus.tscn           Stadthaus
  welt/turm.gd             begehbarer achteckiger Turm: Ebenen, Wendelrampe, Türen, Zinnen
  welt/tor.gd              Tor, das sich erst unter einer Bedingung öffnet
  welt/lesbar.gd           Gegenstand zum Lesen oder Ansehen (Namensbuch, Feuerbecken)
  oberflaeche/entwickler.tscn  Entwicklermenü (F10)
  welt/tageslicht.gd       Sonne, Mond, Himmel und Nebel nach Uhrzeit
  welt/ordenswand.gd       Namenssteine, nach dem Haupteid auch deiner
  welt/posten.gd           Wachposten (Torwache, Nachtwachen)
  spieler/                 Spielfigur und Kamera, spieler/kampf.gd: Waffen, Leben, Verwundung
  figuren/gegner.tscn      Gegner (Gesetzlose mit Säbel oder Muskete, Übungspuppe)
  figuren/person.tscn      ansprechbare Person
  figuren/bruchstein.tscn  Gegenstand zum Aufheben
  figuren/werkbank.tscn    Arbeitsstelle (kostet Spielzeit)
daten/dialoge/             Gespräche als JSON-Dateien
daten/gelaende/            Höhen (hoehen.r32), Wege und Sumpf (maske.png), Vorschau der Region Drachenstein
daten/gelaende_riverlock/  dasselbe für Riverlock
daten/gelaende_ashenveil/  dasselbe für Ashenveil
daten/gelaende_<straße>/   dasselbe für Nordstraße, Südstraße und Küstenweg
daten/karten/              die Karte von Sorrowland für die Taste M
werkzeuge/                 Gelände-Generatoren (in Godot ausführbar)
werkzeuge/bau/             Bauskripte (Python), aus denen die Regionsszenen entstehen
tests/                     automatische Tests
docs/                      Lore-Bibel, Spielkonzept, Karten, Bilder (von Godot ignoriert)
```

## Eine neue Person hinzufügen

1. `szenen/welt/region_drachenstein.tscn` öffnen (für den Hof: `szenen/welt/burg_hof.tscn`).
2. `szenen/figuren/person.tscn` aus dem Dateisystem-Dock in die Szene ziehen. In der Region unter **Personen/PersonenAmBoden** setzt sie sich von selbst auf die Geländehöhe.
3. Im Inspektor ausfüllen:
   - **Anzeige Name**
   - **Dialog Id** (Dateiname ohne `.json`)
   - **Kordel** (Rang)
   - **Tracht** (Farbe)
   - optional **Sichtbar Wenn**, eine Bedingung, solange die Person da ist
4. Eine Datei `daten/dialoge/<dialog_id>.json` anlegen (siehe unten).

Die Regionsszenen werden aus den Bauskripten erzeugt (siehe „Die Regionsszenen neu bauen“). Eine Person, die du dort im Editor hinzufügst, bleibt nur bis zum nächsten Neubau. Soll sie dauerhaft bleiben, gehört sie in das Bauskript der Region.

## Das Gelände verändern

Das Gelände von Drachenstein wird aus `werkzeuge/gelaende_erzeuger.gd` erzeugt, das von Riverlock aus `werkzeuge/gelaende_riverlock.gd`, das von Ashenveil aus `werkzeuge/gelaende_ashenveil.gd`, die drei Straßen aus `werkzeuge/gelaende_strasse.gd`. `werkzeuge/gelaende_erzeugen.gd` erzeugt alle. Dort stehen die Lage der Orte, die Wege, das Gebirge, der Felssporn, die Küste und die Inseln, jeweils mit Kommentar.

1. Werte im Erzeuger ändern, z. B. einen Weg oder die Höhe des Felssporns.
2. `werkzeuge/gelaende_erzeugen.gd` öffnen und **Datei → Ausführen** wählen (Strg+Umschalt+X).
3. Die Szene `region_drachenstein.tscn` neu öffnen.

`daten/gelaende/vorschau.png` (und `daten/gelaende_riverlock/vorschau.png`) zeigt das Ergebnis von oben. Signaltürme und Personen unter einem Knoten mit `auf_gelaende.gd` (Signaltuerme, PersonenAmBoden) folgen der neuen Geländehöhe von selbst. Die Bauten von Drachenstein (Ringmauer, Stadthäuser, Kirche) haben feste Höhen, die beim Bau der Szene aus dem Gelände gelesen wurden. Wer das Gelände um Drachenstein ändert, verschiebt sie im Editor mit oder baut die Szene neu (siehe unten).

## Die Regionsszenen neu bauen

Die großen Bauten (Burgen nach Grundriss, Ringmauern, Stadthäuser, Mittelbau) entstehen nicht von Hand, sondern aus Python-Skripten in `werkzeuge/bau/`. Sie schreiben die Szenendateien neu:

```
python3 werkzeuge/bau/region_drachenstein.py   # schreibt szenen/welt/region_drachenstein.tscn
python3 werkzeuge/bau/region_riverlock.py      # schreibt szenen/welt/region_riverlock.tscn
python3 werkzeuge/bau/region_ashenveil.py      # schreibt szenen/welt/region_ashenveil.tscn
python3 werkzeuge/bau/region_strasse.py        # schreibt die drei Landstraßen
```

Dafür braucht es Python 3 mit `numpy`. `grundlage.py` enthält die gemeinsamen Bausteine (Mauerzug, Tor, Raum, Rampe ...), die `teil_*.py` die einzelnen Burgen. Die Skripte lesen die Geländehöhen, also zuerst das Gelände erzeugen, dann bauen. **Achtung:** Was du in diesen Szenen im Editor änderst, ist nach dem Neubau weg. Größere Änderungen gehören deshalb in die Skripte.

## Einen Turm bauen

`szenen/welt/turm.gd` baut aus einer Liste von Ebenen einen begehbaren achteckigen Turm, auch im Editor. Im Inspektor einstellen:

| Wert | Bedeutung |
|---|---|
| Ebenen Nummern / Namen | z. B. −4 bis 8, „Archive“, „Stillebene“ |
| Boden Hoehen | Höhe jedes Bodens, ein Eintrag mehr als Ebenen (der letzte ist das Dach) |
| Aussen Radien / Wandstaerken | je Ebene, so entstehen Verjüngung und Krone |
| Eingaenge | Türen in der Außenmauer: (Ebene, Winkel) |
| Treppen Winkel | Richtung der Türen zum Treppenhaus |
| Wasserdicht | Turm reicht unter den Meeresspiegel (keine Rettung aus dem Wasser innen) |

Jede Ebene bekommt automatisch Licht und ein Schild „Ebene X · Name“. Vorlagen sind der Bergfried und der Donjon von Gravecrest. Die Rampe bleibt flacher als 35°, wenn die Mittelsäule dick genug ist (Bergfried 1,9 m, Donjon 1,4 m).

## Einen Wachposten hinzufügen

Einen `Area3D`-Knoten mit dem Skript `szenen/welt/posten.gd` und einer `CollisionShape3D` anlegen. Im Inspektor einstellen:
- **Bedingung:** wann der Posten zählt
- **Erledigt Flag:** welches Flag am Ende gesetzt wird
- **Dauer Minuten** oder **Bis Abschnitt** (z. B. `morgengrauen`)
- die Texte für Beginn, Mitte und Ende

Vorlagen sind die drei Posten unter **Posten** im Hof.

## Dialoge schreiben

Jede Datei hat Knoten. Begonnen wird beim Knoten `start`, außer ein Eintrag in `einstieg` passt. Diese werden von oben nach unten geprüft, der erste passende gewinnt. Deshalb gehören die späten Spielabschnitte nach oben.

```json
{
	"einstieg": [
		{ "bedingung": "geloebnis", "knoten": "danach" }
	],
	"knoten": {
		"start": {
			"text": "Was die Person sagt. {name} wird durch den Namen des Spielers ersetzt.",
			"optionen": [
				{ "text": "Antwort 1", "weiter": "zweiter_knoten" },
				{ "text": "Antwort 2", "bedingung": "fenn_fragte,!fenn_gemeldet", "setze": ["neues_flag"] }
			]
		},
		"zweiter_knoten": {
			"text": "Ohne Antworten geht es mit E weiter oder das Gespräch endet.",
			"ziel": "Neues Ziel für die Anzeige oben links.",
			"weiter": "danach"
		},
		"danach": { "text": "Wach gut." }
	}
}
```

**Felder in Knoten und Antworten:**

| Feld | Wirkung |
|---|---|
| `text` | gesprochener Text. `{name}` und `{buerge}` werden ersetzt |
| `sprecher` | anderer Sprechername als die Person (nur Knoten) |
| `weiter` | nächster Knoten. Fehlt er, endet das Gespräch |
| `bedingung` | nur bei Antworten und Einstiegen: wann sie sichtbar oder gültig sind |
| `setze` | Liste von Flags, die gesetzt werden |
| `akte` | Eintrag in die Dienstakte |
| `verweis` | Verweis (Stufe 1) in die Akte, zählt `verweise` hoch |
| `zaehler` | Zähler ändern, z. B. `{ "bruchsteine": -3 }` |
| `rang` | Rang setzen (0 Bewerber, 1 Anwärter, 2 Knappe, 3 Geselle, 4 Wächter …) |
| `ziel` | neues Ziel oben links |
| `meldung` | kurze Einblendung oben im Bild |
| `zeitsprung` | `{ "jahre": 2, "text": "Zwei Jahre vergehen." }` mit schwarzer Blende |
| `blende` | schwarze Blende mit Text, danach geht es weiter |
| `akt_ende` | lange Blende zum Ende eines Akts |
| `spielende` | Blende, danach zurück ins Hauptmenü |
| `ansehen` | Ansehen ändern, z. B. `{ "doerfer": 10, "treue": -3 }` (treue, zweifler, rufer, doerfer, riverlock, stadt) |
| `alarm` | Alarmstufe setzen (0–3) |
| `anzeige` | `{ "stufe": 2, "grund": "..." }`: Anzeige beim Kammerhüter (2 Degradierung bis 5 Verbannung) |
| `urteil` | `true`: das Urteil im laufenden Verfahren vollstrecken (nur beim Kammerhüter) |
| `reise` | `{ "ziel": "riverlock", "ankunft": "von_drachenstein", "stunden": 54, "text": "..." }`: Am Ende des Gesprächs geht es in die andere Region, an den Marker mit diesem Namen (Gruppe `ankunft`), die Zeit läuft weiter, dann kommt die Blende mit dem Text |

**Bedingungen:** `flag` (gesetzt), `!flag` (nicht gesetzt), `zaehler>=3`, `zaehler<3`, `rang>=2`, `alarm>=2`, `ansehen_rufer>=10`, `verfahren_stufe>=4`, `abschnitt=mittag` (morgengrauen, vormittag, mittag, nachmittag, stille_stunde, nacht), `region=riverlock` (die Region, in der man gerade ist: drachenstein, riverlock, ashenveil, nordstrasse, suedstrasse, kuestenweg). Mehrere werden durch Komma getrennt und müssen alle gelten.

## Testen

Acht automatische Tests, alle mit eigenem Speicherordner, sodass deine Spielstände unberührt bleiben:

| Test | Prüft |
|---|---|
| `tests/test_akt1.gd` | Akt I komplett, 42 Punkte: falsche Antworten, zu früh verlassener Posten, Speichern und Laden, alle drei Ausgänge des Fenn-Strangs |
| `tests/test_eingabe.gd` | echte Tastendrücke: E zum Ansprechen und Aufheben, Zifferntasten im Gespräch |
| `tests/test_innen.gd` | die Innenräume, 25 Punkte, mit echtem Gehen: Bergfried-Tor zu und auf, Wendelrampe hinauf aufs Dach und hinunter bis Ebene −4, Namensbuch, Hüterin, Feuerbecken, Fallgatter, Torhaus, durch den Donjon und hinauf, Torben Wick, Entwicklermenü, in Gravemarch Donjon, Archivarin und Scheintore |
| `tests/test_stufe4.gd` | Stufe 4, 28 Punkte: Alarmstufe 1 zu Beginn, Ansehen durch Antworten, Auftrag und Kampf gegen die Gesetzlosen (Treffer, Block, Sieg, bleiben nach dem Laden liegen), Verwundung, Ring der Feuer und leere Märkte, keine Boote bei Alarm, Säbel, Schuss, Bajonett, Nachladen, Verweise und Verfahren bis zur Degradierung, Waffe gegen die Händlerin bis zur Ausstoßung |
| `tests/test_landwege.gd` | die Landwege, 26 Punkte: Anwärter bleiben drin, durch das Nordtor, einmal um das Meer (Nordstraße, Südstraße, Küstenweg) mit den richtigen Reisetagen, Umkehren kostet nichts, Karte, Wald, Personen an der Straße, Speichern und Laden unterwegs, über den Pass und durch das Südtor zurück in die Stadt |
| `tests/test_ashenveil.gd` | Ashenveil, 24 Punkte: Reiterin lehnt Anwärter ab, Ritt hin und zurück mit Zeitverlust, Morast, über den Damm und durch das Fallgitter, Rampe hinunter in die Kapelle, Gedenkstein, durch den Fluchttunnel ins Moor, Personen, verriegelter Nebeneingang, Speichern und Laden |
| `tests/test_riverlock.gd` | Riverlock und das Reisen, 21 Punkte: Lotsin lehnt Anwärter ab, Überfahrt hin und zurück mit Zeitverlust, Rampen durch alle drei Geschosse des Mittelbaus, Zollherr in der Akte, Personen, Wege durch beide Burgen bis vor die Tore, Wasser, Speichern und Laden in Riverlock, Reise über das Entwicklermenü |
| `tests/test_region.gd` | die Region, 30 Punkte: Gelände, Gehen durch das Tor und über Rampen und Brücken, die Wege zur Oberer Burg, zum Kai und durchs Vorburgtor, durch das Labyrinth von Gravemarch, Ortsnamen, Meer und Rand, alle fünf neuen Personen, Karte, Speichern und Laden, Umzug alter Spielstände |

```
godot --headless --path . --script res://tests/test_akt1.gd
godot --headless --path . --script res://tests/test_eingabe.gd
godot --headless --path . --script res://tests/test_region.gd
godot --headless --path . --script res://tests/test_innen.gd
godot --headless --path . --script res://tests/test_riverlock.gd
godot --headless --path . --script res://tests/test_ashenveil.gd
godot --headless --path . --script res://tests/test_landwege.gd
godot --headless --path . --script res://tests/test_stufe4.gd
```

Am Ende steht jeweils `Fehler: 0`, wenn alles stimmt.

## Nächste Schritte

Siehe Fahrplan in [`docs/02-spielkonzept.md`](docs/02-spielkonzept.md), Abschnitt 8. Alle Burgen aus deinen Grundrissen stehen, die Landwege verbinden sie, und die Systeme aus Stufe 4 laufen. Offen sind echte Modelle statt Klötzen (Stufe 3), die Heimlichkeit (Beobachten, Belauschen, Berichte), Sold und Bürgschaft für andere, und dann die Geschichte von Akt II.
