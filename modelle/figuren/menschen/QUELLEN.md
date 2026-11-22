# Realistische Menschen (Prototyp)

Gebaut mit `werkzeuge/mensch_bauen.py` aus:

- **MakeHuman 1.x** (https://github.com/makehumancommunity/makehuman, Ordner `makehuman/data`): Grundkörper
  `3dobjs/base.obj`, Makro-Ziele `targets/macrodetails` (Geschlecht, Alter, Muskeln, Gewicht, Größe, Herkunft),
  Skelett `rigs/default.mhskel` mit Gewichten `rigs/default_weights.mhw`. Lizenz CC0.
- **MakeHuman-Systemassets** (`makehuman_system_assets_cc0.zip`, https://files.makehumancommunity.org/asset_packs/
  makehuman_system_assets/): Haut, Haare, Augen, Augenbrauen, Wimpern. Lizenz CC0.
- **Stoffe** von [Poly Haven](https://polyhaven.com), CC0, 1K, in `stoffe/` (Farbe entsättigt, die Figur färbt):
  [cotton_jersey](https://polyhaven.com/a/cotton_jersey) (Kittel, Kleid),
  [poly_wool_herringbone](https://polyhaven.com/a/poly_wool_herringbone) (Beinlinge),
  [brown_leather](https://polyhaven.com/a/brown_leather) (Gürtel, Schuhe).

Kleidung: aus der Hilfsgeometrie des Grundkörpers geschnitten (`helper-tights`: Kittel mit Ärmeln, Beinlinge, Gürtel
als Ring; `helper-skirt`: Rock bis zum Knie bzw. Kleid bis zum Knöchel; Schuhe aus der Fußhaut). Haut unter der
Kleidung entfällt.

Skelett: das der Quaternius-Figuren (65 Knochen, `../Superhero_Male_FullBody.gltf`), damit die Animationen
(`../animationen.glb`) laufen. Die Animationen werden ohne Positionsspuren (außer Wurzel und Becken) abgespielt, damit
die Proportionen des MakeHuman-Körpers bleiben.

Der Vorrat wird mit `werkzeuge/menschen_vorrat.py` gebaut (alle Angaben je Name dort): mann_1 bis mann_6, frau_1
bis frau_5, schmied, koch, magd, wache_1, wache_2, moench. Selbst gezeichnet (CC0, dieses Projekt): `stoffe/barthaar.png`
(Barthaar), `stoffe/kette_farbe.png` und `kette_normal.png` (Kettengeflecht).

Jede Figur enthält eine ferne Fassung jedes größeren Teils (`<Teil>_fern`, etwa ein Fünftel der Dreiecke), die
`figur.gd` ab 20 m zeigt.
