"""Zeichnet die Blätter für den Efeu an den Mauern (szenen/welt/efeu.gd) nach texturen/efeu_blatt.png: ein Atlas mit vier
Blättern (2 × 2), je ein drei- bis fünflappiges Efeublatt (Hedera helix) mit hellen Adern, dunkel glänzendem Grün und
leicht welkem Rand; Alpha außerhalb des Blatts 0. Eigene Arbeit (CC0).

Aufruf aus dem Projektordner: python3 werkzeuge/efeu_textur.py
"""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPO = Path(__file__).resolve().parent.parent
GROESSE = 512
FELD = GROESSE // 2
ZUFALL = np.random.default_rng(1717)


def blattumriss(lappen, breite):
    """Umriss eines Efeublatts (Punkte relativ zur Feldmitte, Spitze oben): lappen Lappen auf einem Halbkreis,
    jeder Lappen eine rundliche Spitze."""
    punkte = []
    teile = 240
    for i in range(teile):
        w = math.pi * 2 * i / teile                 # 0 = oben (Spitze)
        # Grundform: herzförmig, unten eine Einbuchtung am Stiel
        r = 1.0 - 0.18 * math.cos(w) ** 2
        # Lappen: Spitzen bei gleichmäßig verteilten Winkeln über die obere 3/4 des Umfangs
        for k in range(lappen):
            mitte = -math.pi * 0.75 + 1.5 * math.pi * (k + 0.5) / lappen
            d = (w - mitte + math.pi) % (2 * math.pi) - math.pi
            r += 0.42 * math.exp(-(d / 0.26) ** 2)
        # Stielansatz unten einbuchten
        unten = (w % (2 * math.pi)) - math.pi
        r -= 0.35 * math.exp(-(unten / 0.25) ** 2)
        r *= 1.0 + ZUFALL.normal(0, 0.01)
        x = math.sin(w) * r * breite
        y = -math.cos(w) * r
        punkte.append((x, y))
    return punkte


def zeichne_blatt(lappen, breite, ton):
    gr = FELD
    bild = Image.new("RGBA", (gr, gr), (0, 0, 0, 0))
    d = ImageDraw.Draw(bild)
    m = gr / 2
    s = gr * 0.36
    umriss = [(m + x * s, m + y * s + gr * 0.04) for x, y in blattumriss(lappen, breite)]
    d.polygon(umriss, fill=tuple(int(c * 255) for c in ton) + (255,))
    # Farbverlauf: zur Mitte etwas heller, Rand dunkler und stellenweise gelblich-welk
    a = np.asarray(bild).astype(np.float32) / 255.0
    yy, xx = np.mgrid[0:gr, 0:gr]
    r = np.hypot(xx - m, yy - (m + gr * 0.04)) / s
    hell = np.clip(1.15 - 0.35 * r, 0.7, 1.15)
    rausch = np.asarray(Image.fromarray((ZUFALL.random((gr // 8, gr // 8)) * 255).astype(np.uint8)).resize((gr, gr), Image.BICUBIC)) / 255.0
    a[..., :3] *= (hell * (0.88 + 0.24 * rausch))[..., None]
    welk = np.clip((r - 0.75) * 3.0, 0, 1) * (rausch > 0.6)
    a[..., 0] += welk * 0.12
    a[..., 1] += welk * 0.06
    bild = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    # Adern: vom Stielansatz zu den Lappenspitzen, hell
    d = ImageDraw.Draw(bild)
    basis = (m, m + gr * 0.04 + s * 0.55)
    for k in range(lappen):
        mitte = -math.pi * 0.75 + 1.5 * math.pi * (k + 0.5) / lappen
        w = mitte
        ende = (m + math.sin(w) * s * 1.05 * breite, m + gr * 0.04 - math.cos(w) * s * 1.05)
        farbe = tuple(int(min(1.0, c * 1.5 + 0.05) * 255) for c in ton) + (255,)
        d.line([basis, ende], fill=farbe, width=max(2, gr // 110))
    alpha = Image.new("L", (gr, gr), 0)
    ImageDraw.Draw(alpha).polygon(umriss, fill=255)
    bild.putalpha(alpha.filter(ImageFilter.GaussianBlur(0.6)))
    return bild


def main():
    atlas = Image.new("RGBA", (GROESSE, GROESSE), (0, 0, 0, 0))
    formen = [(5, 1.0, (0.2, 0.36, 0.12)), (3, 0.9, (0.24, 0.4, 0.14)), (5, 1.1, (0.17, 0.31, 0.11)), (3, 1.0, (0.27, 0.42, 0.15))]
    for i, (lappen, breite, ton) in enumerate(formen):
        atlas.paste(zeichne_blatt(lappen, breite, ton), ((i % 2) * FELD, (i // 2) * FELD))
    # Farbe unter dem Alpha nach außen fortsetzen (sonst dunkle Säume in den Mipmaps)
    a = np.asarray(atlas).astype(np.float32)
    rgb = Image.fromarray(a[..., :3].astype(np.uint8)).filter(ImageFilter.MaxFilter(9))
    gefuellt = np.where(a[..., 3:4] > 0, a[..., :3], np.asarray(rgb).astype(np.float32))
    aus = np.concatenate([gefuellt, a[..., 3:4]], axis=2).astype(np.uint8)
    ziel = REPO / "texturen" / "efeu_blatt.png"
    Image.fromarray(aus).save(ziel)
    print("geschrieben:", ziel)


if __name__ == "__main__":
    main()
