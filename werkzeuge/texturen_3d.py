#!/usr/bin/env python3
"""Stellt die Importeinstellungen aller 3D-Texturen (texturen/, modelle/) auf Godots 3D-Vorgabe: VRAM-komprimiert
und mit Mipmaps (Phase 1, Punkt 2, docs/03-messgrundlage.md).

Warum: Godot erkennt 3D-Texturen sonst erst, wenn der Editor sie in einem 3D-Material sieht ("detect_3d"). Unsere
Materialien entstehen aber meist erst zur Laufzeit im Code, also blieben alle Texturen verlustfrei und ohne Mipmaps:
- beim Laden wird jede Textur auf der CPU entpackt (der größte Teil der Felsen-Bauzeit),
- im Grafikspeicher liegt jede 2k-Textur unkomprimiert (16 MB statt 2,7 bis 5,6 MB mit Mipmaps),
- ohne Mipmaps liest die Grafikkarte auch in der Ferne die volle Auflösung (langsamer und es flimmert).

Normalen- und Höhenkarten bekommen die hohe Qualität (BC7), damit Licht und Parallax keine Blockkanten zeigen;
Farbe, Rauheit und ORM die übliche (BC1/BC3). Daten-Texturen (Höhenkarten und Masken unter daten/, die Karte) und
der Wolkenhimmel bleiben, wie sie sind: Sie werden im Code ausgelesen bzw. vertragen keine Blockkompression.

Aufruf (im Projektordner): python3 werkzeuge/texturen_3d.py
Danach importiert Godot die Texturen neu (Editor öffnen oder: godot --headless --path . --import).
"""
import os
import re
import sys

ORDNER = ["texturen", "modelle"]
AUSGENOMMEN = {"texturen/wolken.png"}
HOHE_QUALITAET = re.compile(r"(normal|nor_gl|hoehe|disp)", re.IGNORECASE)


def stelle_um(pfad: str) -> bool:
    with open(pfad, encoding="utf-8") as f:
        alt = f.read()
    if 'importer="texture"' not in alt:
        return False
    neu = alt
    werte = {
        "compress/mode": "2",
        "mipmaps/generate": "true",
        "compress/high_quality": "true" if HOHE_QUALITAET.search(os.path.basename(pfad)) else "false",
    }
    for schluessel, wert in werte.items():
        neu = re.sub(r"(?m)^%s=.*$" % re.escape(schluessel), "%s=%s" % (schluessel, wert), neu)
    if neu == alt:
        return False
    with open(pfad, "w", encoding="utf-8", newline="\n") as f:
        f.write(neu)
    return True


def main() -> int:
    wurzel = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    geaendert = 0
    for ordner in ORDNER:
        for verz, _, dateien in os.walk(os.path.join(wurzel, ordner)):
            for name in sorted(dateien):
                if not name.endswith(".import"):
                    continue
                pfad = os.path.join(verz, name)
                rel = os.path.relpath(pfad, wurzel).replace(os.sep, "/")[: -len(".import")]
                if rel in AUSGENOMMEN:
                    continue
                if stelle_um(pfad):
                    geaendert += 1
    print("%d Texturen auf VRAM-Kompression mit Mipmaps umgestellt" % geaendert)
    return 0


if __name__ == "__main__":
    sys.exit(main())
