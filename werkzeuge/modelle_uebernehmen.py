"""Übernimmt freie Modelle (CC0) von Quaternius ins Projekt: Menschen, Kleidung, Haare, Animationen und Tiere.

Quellen (alle CC0 1.0, https://quaternius.com):
  - Universal Base Characters [Standard]     https://quaternius.itch.io/universal-base-characters
  - Modular Character Outfits - Fantasy      https://quaternius.itch.io/modular-character-outfits-fantasy
  - Universal Animation Library [Standard]   https://quaternius.itch.io/universal-animation-library
  - Farm Animals, Animal Pack Vol.2          https://opengameart.org (Nutzer Quaternius)

Die Pakete werden von Hand (oder per Skript) heruntergeladen und entpackt; dieses Skript bekommt die Ordner:
    python3 werkzeuge/modelle_uebernehmen.py <entpackte Figurenpakete> <entpackte Tierpakete>
Es kopiert nur, was das Spiel braucht, nach modelle/figuren und modelle/tiere, verkleinert die 4K-Texturen auf
1024 Pixel (Farbe und ORM als JPEG, Normalen als PNG) und schreibt die Verweise in den glTF-Dateien um.
"""
import json, shutil, sys
from pathlib import Path

from PIL import Image

ZIEL = Path(__file__).resolve().parent.parent / "modelle"
GROESSE = 1024


def textur(quelle: Path, ziel_ordner: Path) -> str:
    """Verkleinert eine Textur und gibt den neuen Dateinamen zurück."""
    name = quelle.stem.replace("_png", "")
    normal = "normal" in name.lower()
    neu = name + (".png" if normal else ".jpg")
    ziel = ziel_ordner / neu
    if not quelle.exists():
        # manche glTF verweisen auf "<name>_png.png", im Paket liegt "<name>.png" (oder in einem Nachbarordner)
        kandidaten = [quelle.with_name(name + ".png")] + list(quelle.parent.parent.rglob(name + ".png"))
        quelle = next((k for k in kandidaten if k.exists()), quelle)
    if not ziel.exists():
        bild = Image.open(quelle)
        bild = bild.convert("RGB")
        if max(bild.size) > GROESSE:
            bild = bild.resize((GROESSE, GROESSE), Image.LANCZOS)
        if normal:
            bild.save(ziel, optimize=True)
        else:
            bild.save(ziel, quality=90, optimize=True)
    return neu


def gltf(quelle: Path, ziel_ordner: Path, neuer_name: str | None = None) -> None:
    """Kopiert eine .gltf samt .bin und Texturen, Texturen verkleinert."""
    ziel_ordner.mkdir(parents=True, exist_ok=True)
    g = json.loads(quelle.read_text(encoding="utf-8"))
    for b in g.get("buffers", []):
        uri = b.get("uri")
        if uri and not uri.startswith("data:"):
            shutil.copy(quelle.parent / uri, ziel_ordner / uri)
    for bild in g.get("images", []):
        uri = bild.get("uri")
        if uri and not uri.startswith("data:"):
            neu = textur(quelle.parent / uri, ziel_ordner)
            bild["uri"] = neu
            bild["mimeType"] = "image/png" if neu.endswith(".png") else "image/jpeg"
    (ziel_ordner / (neuer_name or quelle.name)).write_text(json.dumps(g), encoding="utf-8")
    print("  ", (neuer_name or quelle.name))


def main(figuren: Path, tiere: Path) -> None:
    fig = ZIEL / "figuren"
    outfits = next(figuren.rglob("Outfits"))
    for name in ["Male_Peasant", "Female_Peasant", "Male_Ranger", "Female_Ranger"]:
        gltf(outfits / f"{name}.gltf", fig)
    basis = next(p for p in figuren.rglob("Godot - UE") if p.is_dir())
    for name in ["Superhero_Male_FullBody", "Superhero_Female_FullBody"]:
        gltf(basis / f"{name}.gltf", fig)
    haare = next(p for p in figuren.rglob("glTF (Godot -Unreal)") if "Rigged" in str(p))
    for p in sorted(haare.glob("*.gltf")):
        gltf(p, fig / "haare")
    anim = next(figuren.rglob("UAL1_Standard.glb"))
    shutil.copy(anim, fig / "animationen.glb")
    print("   animationen.glb")
    for lizenz in figuren.rglob("License*.txt"):
        shutil.copy(lizenz, fig / ("LIZENZ_" + lizenz.parent.name.split("[")[0].strip().replace(" ", "_") + ".txt"))
    t = ZIEL / "tiere"
    t.mkdir(parents=True, exist_ok=True)
    for name in ["Horse", "Cow", "Sheep", "Pig", "Dog", "Cat", "Wolf", "Llama"]:
        quelle = next(tiere.rglob(f"{name}.fbx"))
        shutil.copy(quelle, t / f"{name}.fbx")
        print("  ", name)
    for lizenz in tiere.rglob("License*.txt"):
        shutil.copy(lizenz, t / "LIZENZ.txt")
    (ZIEL / "QUELLEN.md").write_text(__doc__, encoding="utf-8")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
