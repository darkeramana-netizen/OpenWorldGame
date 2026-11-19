"""Lädt Fotoscans von Poly Haven (CC0) als glTF mit 2K-Texturen und übernimmt sie nach modelle/felsen/<name>/:
ein vereinfachtes Mesh zum Zeichnen und eine stark vereinfachte Form für die Kollision (werkzeuge/fels_vereinfachen.py).

Aufruf aus dem Projektordner:
    python3 werkzeuge/felsen_laden.py rock_07 rock_09 boulder_01 rock_face_01
Weitere Angaben: --dreiecke 8000 (Mesh), --form 400 (Kollision), --grau 0.15 (Farbtextur entsättigen: so viel Farbe
bleibt; für Scans aus anderen Gegenden, die zum grauen Burgfels passen sollen). Die Quellen trägt man in modelle/felsen/QUELLEN.md ein.
"""
import json, subprocess, sys, tempfile, urllib.request
from pathlib import Path

args = sys.argv[1:]
def angabe(name, vorgabe):
    if name in args:
        i = args.index(name); wert = args[i + 1]; del args[i:i + 2]; return int(wert)
    return vorgabe
DREIECKE = angabe("--dreiecke", 8000)
FORM = angabe("--form", 400)
GRAU = None
if "--grau" in args:
    i = args.index("--grau"); GRAU = float(args[i + 1]); del args[i:i + 2]
HIER = Path(__file__).resolve().parent
ZIEL = HIER.parent / "modelle" / "felsen"


KOPF = {"User-Agent": "sorrowland-werkzeuge/1.0"}   # ohne eigenen Namen lehnt der Server Python ab (403)


def lade(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=KOPF), timeout=120) as r:
        return r.read()


def hole(url, datei):
    datei.parent.mkdir(parents=True, exist_ok=True)
    datei.write_bytes(lade(url))


for name in args:
    info = json.loads(lade(f"https://api.polyhaven.com/files/{name}"))
    g = info["gltf"]["2k"]["gltf"]
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        quelle = tmp / Path(g["url"]).name
        hole(g["url"], quelle)
        for pfad, teil in g["include"].items():
            hole(teil["url"], tmp / pfad)
        ziel = ZIEL / name
        ziel.mkdir(parents=True, exist_ok=True)
        py = sys.executable
        subprocess.run([py, str(HIER / "fels_vereinfachen.py"), str(quelle), str(ziel), str(DREIECKE)], check=True)
        subprocess.run([py, str(HIER / "fels_vereinfachen.py"), str(quelle), str(ziel), str(FORM), "form"], check=True)
        if GRAU is not None:
            from PIL import Image, ImageEnhance
            for bild in ziel.glob("*_diff_*.jpg"):
                ImageEnhance.Color(Image.open(bild).convert("RGB")).enhance(GRAU).save(bild, quality=92)
    print("übernommen:", name)
