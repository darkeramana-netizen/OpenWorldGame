# Bäume

Fotoscans von [Poly Haven](https://polyhaven.com), Lizenz CC0, mit 1K-Texturen. Die Scans haben 1 bis 8 Millionen
Dreiecke und einzeln modellierte Blätter bzw. Nadelzweige; `werkzeuge/baum_laden.py` macht daraus spieltaugliche Bäume:
Holz mit meshoptimizer vereinfacht (Fotoscan-Texturen bleiben), das Laub als gekreuzte Karten je Blattbüschel mit einem
selbst gerasterten Laub-Atlas (`*_laub_atlas.png`, aus den echten Blättern des Scans). Je Baum zwei Fassungen:
`*_nah.gltf` (3700–5500 Dreiecke) und `*_fern.gltf` (450–1600 Dreiecke, ein einziges Material: das Holz nimmt das
Rindenfeld oben links im Atlas). `baum.json` nennt die Höhe des Modells. Verwendet von `szenen/welt/bewuchs.gd`
(`nadel_modelle`, `laub_modelle`).

| Modell | Art | Autoren | Aufruf |
|---|---|---|---|
| [fir_tree_01](https://polyhaven.com/a/fir_tree_01) | Tanne | Rob Tuytel, Rico Cilliers | `--buesche 420 --karten 3 --gross 170` |
| [fir_sapling_medium](https://polyhaven.com/a/fir_sapling_medium) | junge Tanne | Rob Tuytel, Rico Cilliers | Vorgabe |
| [island_tree_01](https://polyhaven.com/a/island_tree_01) | Laubbaum | Rob Tuytel, Rico Cilliers | Vorgabe |
| [island_tree_02](https://polyhaven.com/a/island_tree_02) | Laubbaum | Rob Tuytel, Rico Cilliers | Vorgabe |
| [tree_small_02](https://polyhaven.com/a/tree_small_02) | Laubbaum | Rico Cilliers | Vorgabe |
