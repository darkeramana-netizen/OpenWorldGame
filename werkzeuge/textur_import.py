"""Importeinstellungen für Texturen von 3D-Modellen: VRAM-komprimiert mit Mipmaps, Normalmaps als Normalmap.

Godot importiert Bilder neben einem glTF zuerst verlustfrei ohne Mipmaps und stellt erst im geöffneten Editor auf
komprimiert um (detect_3d). Ohne Editor bleiben sie unkomprimiert: Messung 24.11.2026 – die 17 Menschenmodelle
belegten so 415 statt 126 MB Grafikspeicher. Dieses Werkzeug schreibt die Einstellungen gleich richtig.

python3 werkzeuge/textur_import.py <ordner> [...]   (rekursiv alle .png/.jpg)
"""
import sys
from pathlib import Path

GRUND = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://{pfad}"

[params]

compress/mode=2
compress/normal_map={normal}
mipmaps/generate=true
detect_3d/compress_to=0
"""


def ist_normal(p: Path) -> bool:
    n = p.name.lower()
    return "normal" in n or "_nor_" in n or n.endswith("_nor.png") or n.endswith("_nor.jpg")


def richte(datei: Path, wurzel: Path) -> bool:
    imp = datei.with_name(datei.name + ".import")
    normal = "1" if ist_normal(datei) else "0"
    if not imp.exists():
        imp.write_text(GRUND.format(pfad=datei.resolve().relative_to(wurzel).as_posix(), normal=normal))
        return True
    s = imp.read_text()
    neu = s.replace("compress/mode=0", "compress/mode=2").replace("mipmaps/generate=false", "mipmaps/generate=true")
    if normal == "1":
        neu = neu.replace("compress/normal_map=0", "compress/normal_map=1")
    neu = neu.replace('"vram_texture": false', '"vram_texture": true')
    if neu != s:
        imp.write_text(neu)
        return True
    return False


if __name__ == "__main__":
    wurzel = Path(__file__).resolve().parent.parent
    n = 0
    for ordner in sys.argv[1:]:
        for d in sorted(Path(ordner).rglob("*")):
            if d.suffix.lower() in (".png", ".jpg", ".jpeg"):
                n += richte(d, wurzel)
    print("Texturimporte gesetzt:", n)
