# Grafikrichtung: realistisch statt Platzhalter

Stand 21.11.2026. Frage: Sollen wir gleich realistisch bauen, statt jetzt vieles einfach zu bauen und später alles
auszutauschen?

## Bestand

| Bereich | heute | realistisch? |
|---|---|---|
| Gelände, Fels, Klippen | eigener Shader mit Fotoscans (Poly Haven), Parallax | ja |
| Mauern, Burgen, Häuser | Geometrie aus Bauskripten, Fotoscan-Materialien, Verwitterung | weitgehend; Form gut, Details ausbaufähig |
| Bäume, Büsche, Felsen, Pflanzen | Fotoscans (Poly Haven), eigene LOD-Werkzeuge | ja |
| Wasser | eigener Shader (Tiefe, Gischt) | ja |
| Ausstattung (Fässer, Kisten, Werkbank, Wagen, Schiffe …) | 53 Arten; Fass, Kisten, Eimer, Zuber, Hocker, Laterne, Werkzeug, Schild und Korb aus Fotoscans (`SCANS` in `ausstattung.gd`), der Rest aus Klötzen und Zylindern im Skript | teilweise |
| Figuren | Quaternius (CC0), Low-Poly, comicartig | nein |
| Tiere | Quaternius (CC0), Low-Poly | nein |

## Einschätzung

Das meiste bisherige Werk ist unabhängig von der Grafik und bleibt: Grundriss, Gelände, Platzierungsregeln
(Werkplätze, Sperren, freie Wege), Personen-KI und Tagesablauf, Zellen-Streaming, Tests, Messwerkzeug, Rundgang.
Die Grafik hängt an wenigen Stellen und ist austauschbar:

- Ausstattung: jede Art ist eine Nummer; `ausstattung.gd` baut das Mesh in `_mesh(art)`. Ein Scan ersetzt eine Art,
  ohne dass sich Platzierung, Kollision oder Tests ändern.
- Figuren und Tiere: `figur.gd` und `tier.gd` laden Modelle aus `modelle/`; ein anderer Körper braucht ein
  passendes Skelett oder ein Retargeting der Animationen.

Der Austausch wird also nicht teuer – teuer würde es, wenn wir noch viele weitere Dinge prozedural bauen.

## Empfehlung

1. **Ab jetzt neue Dinge gleich realistisch**: zuerst nach einem CC0-Scan suchen (Poly Haven, ambientCG); nur wo es
   keinen gibt (Wagen, Schiffe, Amboss), weiter selbst bauen, dann aber mit Fotoscan-Materialien statt Grundfarben.
2. **Ausstattung austauschen, die Nummern bleiben**: Werkzeug `werkzeuge/modell_laden.py` (laden, vereinfachen, nahe
   und ferne Fassung; erledigt, erste elf Scans in `modelle/ausstattung/QUELLEN.md`). Eine Art kann aus mehreren Scans
   und eigener Geometrie bestehen (Werkbank mit Scan-Hammer und -Säge); Kollision und Platzierung bleiben. Poly Haven hat u. a. Fässer, Kisten, Eimer, Körbe, Äxte,
   Hämmer, Sägen, Leitern, Laternen, Hocker, Tische, Bänke, Truhe, Spinnrad, Schild.
3. **Figuren**: Prototyp in einem eigenen Zweig – realistische CC0-Körper (MakeHuman, Export unter CC0) mit den
   Animationen der Quaternius-Bibliothek (CC0) über Godots Retargeting. Erst wenn das im Spiel überzeugt, umstellen.
4. **Tiere**: realistische CC0-Tiere mit Animationen sind selten; suchen, sonst vorerst behalten.
5. **Leistung**: realistische Modelle kosten mehr Dreiecke; jede Art bekommt eine nahe und eine ferne Fassung
   (wie Bäume und Felsen). Spielraum heute: Episch 57 fps bei 30 fps Ziel.

Grenze: Godot 4.7.2 mit GDScript ohne eigenen Build erreicht einen glaubwürdigen, realistischen Eindruck, aber nicht
den Stand großer Studio-Spiele (Gesichter, Kleidung, Animation aus Motion Capture).

## Stand der Umstellung

| Schritt | Stand |
|---|---|
| Ausstattung: Werkzeug und erste Scans (Fass, Kisten, Korb, Axt, Hammer, Säge, Schild, Laterne, Eimer, Zuber, Hocker) | erledigt (21.11.2026) |
| Ausstattung: weitere Arten (Säcke, Amboss, Wagen, Marktstand, Leiter, Tränke) | offen; für Wagen, Schiffe und Amboss gibt es keinen CC0-Scan, dort selbst bauen mit Fotoscan-Materialien |
| Figuren: Prototyp mit realistischen Körpern | Prototyp steht (Zweig `figuren-prototyp`, siehe unten) |
| Tiere | offen |

## Figuren-Prototyp (21.11.2026)

Werkzeug `werkzeuge/mensch_bauen.py`, Quellen in `modelle/figuren/menschen/QUELLEN.md`.

- **Körper**: MakeHuman-Grundkörper (CC0) mit den Makro-Zielen wie in MakeHuman (Geschlecht, Alter, Muskeln,
  Gewicht, Größe), Hauttexturen nach Alter und Herkunft, Haare, Augen, Brauen und Wimpern aus den Systemassets.
- **Skelett und Animation**: Der Körper wird an das Skelett der Quaternius-Figuren gebunden (gleiche 65 Knochen, gleiche
  Ausrichtung in T-Haltung, Längen vom MakeHuman-Körper; die Bindungsmatrizen beschreiben die A-Haltung). Damit laufen
  alle 43 vorhandenen Animationen ohne Umrechnung; nur ihre Positionsspuren (außer Wurzel und Becken) fallen weg, damit
  die Proportionen bleiben. Hut, Zubehör, Blick und Dinge in der Hand hängen an denselben Knochen wie bisher.
- **Kleidung**: aus der Hilfsgeometrie des Grundkörpers (Strumpfhose, Rock): Kittel mit langen Ärmeln und Rock bis zum
  Knie, oder Kleid bis zum Knöchel; Beinlinge, Gürtel als Ring, Lederschuhe. Stoffe aus Poly-Haven-Scans, grau, die
  Tracht der Figur färbt sie. Haut unter der Kleidung fällt weg (nichts sticht durch).
- **Kosten**: etwa 28 000 Dreiecke je Figur, wie die heutigen (Körper 14 000 und Kleidung 13 000).
- **Schalter**: `figur.gd` baut mit `FIGUREN_REALISTISCH=1` (oder Projekteinstellung `sorrowland/figuren_realistisch`)
  die neuen Körper; Kinder bleiben vorerst Quaternius.

Offen bis zur Umstellung: mehr Körper im Vorrat (Alter, Statur, Hautton, Frisuren), Bärte (MakeHuman hat keine
CC0-Bärte; eigene Karte nötig), Berufskleidung (Schürze, Kettenhemd, Wappenrock, Kutte), eine ferne Fassung mit weniger
Dreiecken (MakeHuman-Proxy `male1591` mit 1600 Ecken), Frauen im Kleid ohne Beinlinge beim Sitzen prüfen.
