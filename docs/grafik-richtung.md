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
| Ausstattung (Fässer, Kisten, Werkbank, Wagen, Schiffe …) | 50 Arten, aus Klötzen und Zylindern im Skript gebaut | nein |
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
2. **Ausstattung austauschen, die Nummern bleiben**: Werkzeug `werkzeuge/modell_laden.py` nach dem Vorbild von
   `baum_laden.py` (laden, vereinfachen, LOD, Kollision). Poly Haven hat u. a. Fässer, Kisten, Eimer, Körbe, Äxte,
   Hämmer, Sägen, Leitern, Laternen, Hocker, Tische, Bänke, Truhe, Spinnrad, Schild.
3. **Figuren**: Prototyp in einem eigenen Zweig – realistische CC0-Körper (MakeHuman, Export unter CC0) mit den
   Animationen der Quaternius-Bibliothek (CC0) über Godots Retargeting. Erst wenn das im Spiel überzeugt, umstellen.
4. **Tiere**: realistische CC0-Tiere mit Animationen sind selten; suchen, sonst vorerst behalten.
5. **Leistung**: realistische Modelle kosten mehr Dreiecke; jede Art bekommt eine nahe und eine ferne Fassung
   (wie Bäume und Felsen). Spielraum heute: Episch 57 fps bei 30 fps Ziel.

Grenze: Godot 4.7.2 mit GDScript ohne eigenen Build erreicht einen glaubwürdigen, realistischen Eindruck, aber nicht
den Stand großer Studio-Spiele (Gesichter, Kleidung, Animation aus Motion Capture).
