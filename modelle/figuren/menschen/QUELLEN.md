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

| Ordner | Aufruf (nach `MH_DATA SYSTEM_ASSETS name`) |
|---|---|
| probe_mann | Vorgabe (Mann, 25 Jahre, Kittel) |
| probe_frau | `geschlecht=0 alter=28 kleidung=kleid haare=braid01 kittelfarbe=0.35,0.16,0.12` |
| probe_alter | `geschlecht=1 alter=62 gewicht=0.7 muskeln=0.6 haut=old_caucasian_male haare=short04 kittelfarbe=0.25,0.28,0.2 beinfarbe=0.3,0.24,0.16` |
| probe_schmied | `ueber=lederschuerze kittelfarbe=0.3,0.3,0.32 haare=short01` |
| probe_magd | `geschlecht=0 alter=34 kleidung=kleid ueber=schuerze haare=ponytail01 kittelfarbe=0.22,0.28,0.38` |
| probe_wache | `ueber=wappenrock alter=30 muskeln=0.75 haare=short03 kittelfarbe=0.3,0.28,0.25` |
| probe_moench | `alter=48 kleidung=kleid haare=short04 kittelfarbe=0.3,0.22,0.14 gewicht=0.6` (Kutte) |

Überkleidung (`ueber=`): Schürze (Leinen, ab dem Gürtel), Lederschürze (Schmied, ab der Brust), Wappenrock (vorn und
hinten von den Schultern bis zum Knie). Jede Bahn liegt oberhalb des Gürtels am Körper an, hängt darunter lotrecht
mit Falten und schwingt an vier Knochenketten; 80 % folgen dem Rock darunter, der Rock hinter der Bahn entfällt.
Gebrauchsspuren als Eckfarben (Schmutz am Saum und an den Knien, Flecken, ausgeblichene Schultern, Scheuerstellen
am Leder); Röcke mit Falten in der Form.
