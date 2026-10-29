"""Lädt fotogescannte Texturen von Poly Haven (polyhaven.com, alle CC0) nach texturen/.

Jede Textur wird unter unserem Namen abgelegt (<name>_farbe.jpg, <name>_normal.jpg, <name>_rau.jpg), so dass
Materialien, Geländeshader und Häuser sie ohne Änderung nutzen. Die echte Größe einer Kachel (Meter) schreibt
das Skript nach texturen/groessen.json; texturen_erzeugen.py liest sie für die Materialien.

Aufruf:  python3 werkzeuge/texturen_laden.py            # alle
         python3 werkzeuge/texturen_laden.py quader dach  # nur diese
Danach:  python3 werkzeuge/texturen_erzeugen.py material  # Materialien mit den echten Kachelgrößen
"""
import io, json, sys, urllib.request
from pathlib import Path

from PIL import Image, ImageOps

ZIEL = Path(__file__).resolve().parent.parent / "texturen"

# unser Name → (Poly-Haven-Name, Auflösung, Graustufen für Einfärben)
QUELLEN = {
    "quader": ("castle_wall_slates", "2k", False),       # Mauern der Burgen
    "bruchstein": ("old_stone_wall", "2k", False),        # Kaimauern, Sockel, Häuser
    "basalt": ("rock_wall_08", "2k", False),              # Urkern, Bergfried
    "hellstein": ("medieval_blocks_05", "2k", False),     # Kirche, Palas, Rathaus
    "putz": ("white_plaster_02", "2k", False),            # Fachwerkfelder (stadthaeuser.gd färbt ein)
    "holz": ("weathered_planks", "2k", False),
    "dach": ("roof_tiles", "2k", False),                  # Ziegel
    "schiefer": ("roof_slates_03", "2k", False),          # Schieferdächer der Burgen
    "platten": ("monastery_stone_floor", "2k", False),    # Höfe und Böden
    "pflaster": ("cobblestone_floor_01", "2k", False),
    "stoff": ("rough_linen", "1k", True),
    "metall": ("rusty_metal_02", "1k", False),
    "fels": ("aerial_rocks_02", "2k", False),             # Gelände: Steilhänge, Burgberg
    "gras": ("leafy_grass", "2k", False),
    "erde": ("forest_ground_04", "2k", False),
    "sand": ("coast_sand_01", "1k", False),
    "schnee": ("snow_02", "1k", False),
    "sumpf": ("mud_forest", "1k", False),
}
API = "https://api.polyhaven.com"


def hole(url):
    anfrage = urllib.request.Request(url, headers={"User-Agent": "sorrowland-texturen"})
    with urllib.request.urlopen(anfrage, timeout=120) as antwort:
        return antwort.read()


def lade(name):
    ph, aufl, grau = QUELLEN[name]
    dateien = json.loads(hole(f"{API}/files/{ph}"))
    info = json.loads(hole(f"{API}/info/{ph}"))
    for schluessel, endung, modus in [("Diffuse", "farbe", "RGB"), ("nor_gl", "normal", "RGB"), ("Rough", "rau", "L")]:
        url = dateien[schluessel][aufl]["jpg"]["url"]
        bild = Image.open(io.BytesIO(hole(url))).convert(modus)
        if grau and endung == "farbe":
            bild = ImageOps.autocontrast(bild.convert("L"), cutoff=1).convert("RGB")
        if endung == "rau" and bild.width > 1024:
            bild = bild.resize((1024, 1024), Image.LANCZOS)
        bild.save(ZIEL / f"{name}_{endung}.jpg", quality=88, optimize=True)
    meter = round(max(info.get("dimensions") or [2000]) / 1000.0, 2)
    print(f"{name:10s} ← {ph} ({aufl}, {meter} m)")
    return ph, meter, info.get("authors", {})


if __name__ == "__main__":
    namen = sys.argv[1:] or list(QUELLEN)
    groessen_datei = ZIEL / "groessen.json"
    groessen = json.loads(groessen_datei.read_text()) if groessen_datei.exists() else {}
    for name in namen:
        ph, meter, autoren = lade(name)
        groessen[name] = {"meter": meter, "quelle": f"https://polyhaven.com/a/{ph}", "lizenz": "CC0",
                          "autoren": ", ".join(autoren)}
    groessen_datei.write_text(json.dumps(groessen, ensure_ascii=False, indent=1), encoding="utf-8")
