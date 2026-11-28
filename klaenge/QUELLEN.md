# Geräusche: Quellen und Lizenzen

Alle Dateien hier erzeugt `werkzeuge/klaenge_erzeugen.py`. Alles ist frei verwendbar (CC0).

## Eigene Synthese (CC0, in diesem Projekt erzeugt)

`wind_sanft`, `wind_stark`, `feuer`, `brandung`, `markt`, `brunnen` (Schleifen), `vogel_*` (Amsel, Spatz, Meise, Fink,
Schwalbe, Krähe), Tiere (`pferd_*`, `huf_*`, `schwein_*`, `kuh_*`, `schaf_*`, `katze_*`), `ausruf_*`,
`amboss_*`, `glocke_gross`, `glocke_klein`, `schuss`; unter Tage `tropfen_*`, `hoehle` (Schleife) und
`stein_schleifen` (Geheimtür), erzeugt mit `python3 werkzeuge/klaenge_erzeugen.py --untergrund`. Die Schritte stammen aus Aufnahmen (siehe Fantozzi unten).

## Kenney, „50 RPG sound effects“ (CC0)

- https://opengameart.org/content/50-rpg-sound-effects (Datei `RPGsounds_Kenney.zip`), www.kenney.nl
- Lizenz: CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/)
- Verwendet: `tuer_auf_*`, `tuer_zu_*`, `knarren_*`, `riegel`, `hacken`, `leder`,
  `stoff_*`, `muenzen`, `messer_ziehen`, `buch_auf`, `buch_zu`, `topf`; `tor_auf_*` und `tor_zu` sind daraus tiefer und
  dumpfer gemacht.

## artisticdude, „RPG Sound Pack“ (CC0)

- https://opengameart.org/content/rpg-sound-pack (Datei `rpg_sound_pack.zip`)
- Lizenz: CC0 (laut OpenGameArt)
- Verwendet: `kettenhemd_*`, `schwert_ziehen_*`, `schwung_*`, `holz_klein`, `metall_klingt`, `metall_*`, `ruestung`,
  `stoff_schwer`.

## Hunde: „Dog sounds“ (CC0)

- https://opengameart.org/content/dog-sounds (Datei `dog.7z`)
- Lizenz: CC0
- Verwendet: `hund_*` (die vier „Dog Bark“-Aufnahmen), über 3,5 kHz gedämpft.

## Hühner: IMadeIt, „Chicken Sound Effect“ (CC-BY 3.0)

- https://opengameart.org/content/chicken-sound-effect (Datei `chicken_sound_effect.zip`)
- Lizenz: Creative Commons Namensnennung 3.0 (https://creativecommons.org/licenses/by/3.0/). Urheber: IMadeIt.
- Geändert: in einzelne Laute zerlegt (`huhn_*`), Tiefen unter 120 Hz entfernt, Pegel angeglichen.
- Die einzige Datei hier, die nicht CC0 ist: Im Spiel muss der Urheber genannt werden (Abspann).

## Fantozzi, „Fantozzi's Footsteps (Grass/Sand & Stone)“ (CC0)

- https://opengameart.org/content/fantozzis-footsteps-grasssand-stone (Datei `Fantozzi-footsteps.7z`)
- Lizenz: CC0
- Verwendet: alle Schritte. `schritt_stein_*` aus Stone (4 davon etwas tiefer), `schritt_gras_*` aus Sand (gefiltert),
  `schritt_erde_*` aus Sand (tiefer und dumpfer), `schritt_holz_*` aus Stone (tiefer, dumpf, mit kurzem Nachhall der
  Dielen). Bearbeitet mit ffmpeg (Filter, Tonhöhe, Lautheit -18 LUFS).
