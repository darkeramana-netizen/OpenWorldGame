# Ausstattung

Fotoscans von [Poly Haven](https://polyhaven.com), Lizenz CC0, mit 1K-Texturen. `werkzeuge/modell_laden.py` lädt sie,
stellt sie mittig auf y = 0 (Maßstab und Ausrichtung wie im Scan, Meter) und schreibt zwei Fassungen: `*_nah.gltf`
(mit meshoptimizer auf 2500 Dreiecke je Meter Größe vereinfacht, höchstens 3000 bzw. `--dreiecke`) und `*_fern.gltf`
(etwa ein Sechstel). `modell.json` nennt Ausdehnung, Dreiecke und Quelle. Verwendet von `szenen/welt/ausstattung.gd`
(Tabelle `SCANS`: welche Art aus welchen Scans besteht, mit Ort, Drehung und Maßstab; bis 30 m die nahe Fassung).

| Modell | Verwendung | Autoren | Dreiecke nah / fern | Aufruf |
|---|---|---|---|---|
| [wine_barrel_01](https://polyhaven.com/a/wine_barrel_01) | Fass (Art 0) | James Ray Cock | 884 / 104 | `--dreiecke 1200` |
| [wooden_crate_01](https://polyhaven.com/a/wooden_crate_01) | Kistenstapel (Art 1, dreimal) | James Ray Cock | 1200 / 172 | `--dreiecke 1200` |
| [wicker_basket_02](https://polyhaven.com/a/wicker_basket_02) | Fischkorb (Art 38, mit Fischen) | Kuutti Siitonen | 865 / 108 | Vorgabe |
| [wooden_axe_03](https://polyhaven.com/a/wooden_axe_03) | Axt im Hackklotz (Art 46) | Ulan Cabanilla | 1579 / 262 | Vorgabe |
| [wooden_hammer_01](https://polyhaven.com/a/wooden_hammer_01) | Hammer auf der Werkbank (Art 40) | James Ray Cock | 696 / 173 | Vorgabe |
| [handsaw_wood](https://polyhaven.com/a/handsaw_wood) | Säge auf der Werkbank (Art 40) | Konrad Szałankiewicz | 1582 / 244 | Vorgabe |
| [kite_shield](https://polyhaven.com/a/kite_shield) | Normannenschild am Rüstungsständer (Art 48) | Ulan Cabanilla | 2998 / 574 | Vorgabe |
| [wooden_lantern_01](https://polyhaven.com/a/wooden_lantern_01) | Wandlaterne (Art 20) | James Ray Cock | 1339 / 166 | Vorgabe |
| [wooden_bucket_01](https://polyhaven.com/a/wooden_bucket_01) | Eimer (Art 50) | James Ray Cock | 1373 / 192 | Vorgabe |
| [wooden_bucket_02](https://polyhaven.com/a/wooden_bucket_02) | Waschzuber (Art 51) | James Ray Cock | 1538 / 195 | Vorgabe |
| [wooden_stool_01](https://polyhaven.com/a/wooden_stool_01) | Hocker (Art 52) | Kuutti Siitonen | 1105 / 91 | Vorgabe |
