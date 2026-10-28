"""Erzeugt kachelbare Texturen (Farbe, Normalen, Rauheit) nach texturen/.
Alles wird aus Rauschen und einfachen Formen berechnet, es gibt also keine fremden Lizenzen.
Aufruf: python3 werkzeuge/texturen_erzeugen.py [name ...]   (ohne Namen: alle)
Danach in Godot einmal importieren (Editor öffnen oder godot --headless --import)."""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

ZIEL = Path(__file__).resolve().parent.parent / "texturen"
N = 1024
rng = np.random.default_rng(1750)


# ---------- Bausteine ----------

def rauschen(n=N, staerke=2.0, grob=4, saat=None, streckung=1.0):
    """Kachelbares fraktales Rauschen in [0, 1]: weißes Rauschen, im Frequenzraum mit 1/f^staerke gefiltert.
    grob: unterhalb dieser Frequenz wird nichts mehr verstärkt (sonst nur ein großer Fleck).
    streckung > 1 zieht das Rauschen in x in die Länge (Holzmaserung)."""
    r = np.random.default_rng(saat) if saat is not None else rng
    f = np.fft.fftfreq(n) * n
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt((fx * streckung) ** 2 + fy ** 2)
    k[0, 0] = 1
    spektrum = np.fft.fft2(r.standard_normal((n, n))) / np.maximum(k, grob) ** staerke
    bild = np.real(np.fft.ifft2(spektrum))
    return (bild - bild.min()) / (bild.max() - bild.min())


def normalen(hoehe, staerke=4.0):
    """Normalenkarte (OpenGL, Y nach oben) aus einer kachelbaren Höhenkarte."""
    dx = (np.roll(hoehe, -1, 1) - np.roll(hoehe, 1, 1)) * staerke
    dy = (np.roll(hoehe, -1, 0) - np.roll(hoehe, 1, 0)) * staerke
    n = np.stack([-dx, dy, np.ones_like(hoehe)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def farbe_aus(wert, farben):
    """Färbt Werte in [0, 1] entlang einer Farbskala [(stelle, (r, g, b)), ...]."""
    stellen = np.array([s for s, _ in farben])
    kanaele = [np.interp(wert, stellen, [c[i] for _, c in farben]) for i in range(3)]
    return np.stack(kanaele, -1)


def mischen(a, b, t):
    return a * (1 - t[..., None]) + b * t[..., None]


def speichere(name, farbe, hoehe, rau, normal_staerke=4.0):
    ZIEL.mkdir(exist_ok=True)
    farbe = np.clip(farbe, 0, 1)
    Image.fromarray((farbe * 255).astype(np.uint8)).save(ZIEL / f"{name}_farbe.jpg", quality=90)
    Image.fromarray((normalen(hoehe, normal_staerke) * 255).astype(np.uint8)).save(ZIEL / f"{name}_normal.jpg", quality=92)
    rau_bild = Image.fromarray((np.clip(rau, 0, 1) * 255).astype(np.uint8)).resize((N // 2, N // 2))
    rau_bild.save(ZIEL / f"{name}_rau.jpg", quality=88)
    print("geschrieben:", name)


def mauerwerk(reihen, laenge_min, laenge_max, fuge, versatz_zufall=True, saat=0):
    """Quadermauerwerk, kachelbar: je Reihe Steine zufälliger Länge, die über den Rand umlaufen.
    Gibt (Stein-Id je Pixel, Abstand zur Fuge in Pixeln) zurück."""
    r = np.random.default_rng(saat)
    hoehe_reihe = N // reihen
    ids = np.zeros((N, N), int)
    abstand = np.zeros((N, N))
    y = np.arange(N)
    naechste_id = 1
    for reihe in range(reihen):
        y0, y1 = reihe * hoehe_reihe, (reihe + 1) * hoehe_reihe
        # Fugen in x: Steinlängen bis N füllen, Rest auf den letzten Stein verteilen
        kanten = [int(r.integers(0, N))]
        while True:
            l = int(r.integers(laenge_min, laenge_max))
            if kanten[-1] + l >= kanten[0] + N - laenge_min:
                break
            kanten.append(kanten[-1] + l)
        kanten.append(kanten[0] + N)
        x = np.arange(N)
        for a, b in zip(kanten, kanten[1:]):
            spalten = (x - a) % N < (b - a)
            ids[y0:y1, spalten] = naechste_id
            xs = (x - a) % N
            dx = np.minimum(xs, (b - a) - xs)
            dy = np.minimum(y[y0:y1] - y0, y1 - 1 - y[y0:y1])
            abstand[y0:y1][:, spalten] = np.minimum(dx[None, spalten], dy[:, None])
            naechste_id += 1
    return ids, abstand


def je_stein(ids, werte):
    """Ordnet jedem Stein einen Zufallswert aus werte zu."""
    return werte[ids % len(werte)]


def zellen(anzahl, saat=0):
    """Kachelbare Voronoi-Zellen: (Zellen-Id, Abstand zur Kante in Pixeln)."""
    r = np.random.default_rng(saat)
    punkte = r.uniform(0, N, (anzahl, 2))
    y, x = np.mgrid[0:N, 0:N].astype(np.float32)
    d1 = np.full((N, N), 1e9, np.float32)
    d2 = np.full((N, N), 1e9, np.float32)
    ids = np.zeros((N, N), int)
    for i, (px, py) in enumerate(punkte):
        dx = np.abs(x - px); dx = np.minimum(dx, N - dx)
        dy = np.abs(y - py); dy = np.minimum(dy, N - dy)
        d = np.sqrt(dx * dx + dy * dy)
        neu = d < d1
        d2 = np.where(neu, d1, np.minimum(d2, d))
        ids = np.where(neu, i, ids)
        d1 = np.where(neu, d, d1)
    return ids, (d2 - d1) / 2


# ---------- Texturen ----------

def quader(name="quader", grund=(0.47, 0.44, 0.39), streuung=0.09, reihen=8, saat=1):
    """Gesägte Quader aus hellem Sandstein/Granit, schmale Mörtelfugen (Burgmauern)."""
    ids, abst = mauerwerk(reihen, N // 6, N // 3, 6, saat=saat)
    r = np.random.default_rng(saat)
    hell = je_stein(ids, r.uniform(1 - streuung, 1 + streuung, 4000))
    ton = je_stein(ids, r.uniform(-0.012, 0.018, 4000))
    korn = rauschen(staerke=1.2, grob=40, saat=saat)
    flecken = rauschen(staerke=2.2, grob=3, saat=saat + 1)
    kante = np.clip(abst / 7.0, 0, 1)
    rund = np.sqrt(np.clip(abst / 14.0, 0, 1))
    farbe = np.array(grund)[None, None] * (hell * (0.85 + 0.25 * korn) * (0.9 + 0.18 * flecken))[..., None]
    farbe[..., 0] += ton; farbe[..., 2] -= ton
    moertel = np.array([0.55, 0.53, 0.49]) * (0.8 + 0.3 * korn[..., None])
    farbe = mischen(moertel, farbe, kante)
    hoehe = rund * 0.8 + korn * 0.15 + flecken * 0.1
    rau = 0.8 + 0.15 * korn - 0.1 * (1 - kante)
    speichere(name, farbe, hoehe, rau, 3.0)


def bruchstein(name="bruchstein", grund=(0.36, 0.34, 0.31), saat=2):
    """Unregelmäßiges Bruchsteinmauerwerk (Ringmauern, Kais, Dörfer)."""
    ids, abst = zellen(140, saat)
    r = np.random.default_rng(saat)
    hell = je_stein(ids, r.uniform(0.75, 1.2, 200))
    korn = rauschen(staerke=1.3, grob=40, saat=saat)
    flecken = rauschen(staerke=2.0, grob=4, saat=saat + 1)
    kante = np.clip((abst - 3) / 6.0, 0, 1)
    farbe = np.array(grund)[None, None] * (hell * (0.8 + 0.3 * korn) * (0.85 + 0.3 * flecken))[..., None]
    moertel = np.array([0.46, 0.44, 0.4]) * (0.8 + 0.3 * korn[..., None])
    farbe = mischen(moertel, farbe, kante)
    hoehe = np.sqrt(np.clip(abst / 25.0, 0, 1)) * 0.9 + korn * 0.2
    speichere(name, farbe, hoehe, 0.85 + 0.1 * korn, 3.5)


def basalt(name="basalt", saat=3):
    """Dunkler Basalt in hohen, glatten Blöcken (Schwarzer Bergfried)."""
    ids, abst = mauerwerk(6, N // 5, N // 2, 4, saat=saat)
    r = np.random.default_rng(saat)
    hell = je_stein(ids, r.uniform(0.85, 1.15, 4000))
    korn = rauschen(staerke=1.0, grob=60, saat=saat)
    adern = 1 - np.abs(rauschen(staerke=1.8, grob=6, saat=saat + 1) - 0.5) * 2
    farbe = np.array([0.12, 0.12, 0.135])[None, None] * (hell * (0.8 + 0.4 * korn) + 0.25 * adern ** 8)[..., None]
    kante = np.clip(abst / 5.0, 0, 1)
    farbe = mischen(np.array([0.08, 0.08, 0.09]), farbe, kante)
    hoehe = np.sqrt(np.clip(abst / 10, 0, 1)) * 0.7 + korn * 0.08
    speichere(name, farbe, hoehe, 0.55 + 0.3 * korn, 3.0)


def putz(name="putz", grund=(0.78, 0.73, 0.64), saat=4):
    """Kalkputz mit Flecken und Wasserspuren (Hauswände, helle Bauten)."""
    korn = rauschen(staerke=1.0, grob=80, saat=saat)
    flecken = rauschen(staerke=2.3, grob=3, saat=saat + 1)
    spuren = rauschen(staerke=2.0, grob=3, saat=saat + 2)
    # senkrechte Wasserspuren: Rauschen in y stark gestreckt
    spuren = np.repeat(spuren[::8], 8, axis=0)[:N]
    farbe = np.array(grund)[None, None] * (0.9 + 0.1 * korn + 0.06 * (flecken - 0.5))[..., None]
    farbe *= (1 - 0.1 * np.clip(spuren - 0.6, 0, 1) * 2.5)[..., None]
    hoehe = korn * 0.3 + flecken * 0.2
    speichere(name, farbe, hoehe, 0.9 + 0.08 * korn, 1.5)


def holz(name="holz", grund=(0.42, 0.29, 0.18), bretter=8, saat=5):
    """Waagrechte Bretter mit Maserung und Fugen."""
    y = np.arange(N)
    breite = N // bretter
    r = np.random.default_rng(saat)
    brett = y // breite
    hell = r.uniform(0.8, 1.15, bretter)[brett]
    maserung = rauschen(staerke=1.6, grob=6, saat=saat, streckung=12.0)
    linien = 0.5 + 0.5 * np.sin(maserung * 40)
    korn = rauschen(staerke=1.0, grob=60, saat=saat + 1, streckung=6.0)
    fuge = np.minimum(y % breite, breite - 1 - y % breite)
    kante = np.clip(fuge / 3.0, 0, 1)[:, None] * np.ones((1, N))
    farbe = np.array(grund)[None, None] * ((hell[:, None] * (0.8 + 0.2 * linien + 0.1 * korn)))[..., None]
    farbe = mischen(np.array([0.12, 0.08, 0.05]), farbe, kante)
    hoehe = kante * 0.6 + linien * 0.15
    speichere(name, farbe, hoehe, 0.75 + 0.15 * korn, 3.0)


def dach(name="dach", grund=(0.55, 0.26, 0.18), reihen=16, saat=6):
    """Biberschwanzziegel, versetzt, jede Reihe überlappt die nächste."""
    r = np.random.default_rng(saat)
    hoehe_reihe = N // reihen
    pro_reihe = 16
    breite = N // pro_reihe
    y, x = np.mgrid[0:N, 0:N]
    reihe = y // hoehe_reihe
    xv = (x + (reihe % 2) * breite // 2) % N
    ziegel = reihe * pro_reihe + xv // breite
    v = (y % hoehe_reihe) / hoehe_reihe                  # 0 oben, 1 unten in der Reihe
    u = (xv % breite) / breite - 0.5
    # runder unterer Rand: unten in der Mitte länger
    rand = 1 - np.clip((v - (1 - 0.25 * np.sqrt(np.clip(0.25 - u * u, 0, 1)) * 2)) * 8, 0, 1)
    hell = r.uniform(0.75, 1.2, reihen * pro_reihe + pro_reihe)[ziegel]
    korn = rauschen(staerke=1.0, grob=60, saat=saat)
    moos = np.clip(rauschen(staerke=2.2, grob=3, saat=saat + 1) - 0.6, 0, 1) * 2
    spalt = np.clip(np.minimum(np.abs(u) * -1 + 0.5, 1) * breite / 2.5, 0, 1)
    farbe = np.array(grund)[None, None] * (hell * (0.85 + 0.2 * korn))[..., None] * (0.55 + 0.45 * v)[..., None]
    farbe = mischen(farbe, np.array([0.25, 0.3, 0.15]), moos * 0.6)
    farbe = farbe * (0.25 + 0.75 * spalt * rand)[..., None]
    hoehe = v * 0.8 * rand + korn * 0.1
    speichere(name, farbe, hoehe, 0.8 + 0.15 * korn, 4.0)


def platten(name="platten", grund=(0.45, 0.43, 0.4), saat=7):
    """Große Steinplatten (Höfe, Böden in Burgen)."""
    ids, abst = mauerwerk(5, N // 6, N // 3, 4, saat=saat)
    r = np.random.default_rng(saat)
    hell = je_stein(ids, r.uniform(0.8, 1.15, 4000))
    korn = rauschen(staerke=1.2, grob=40, saat=saat)
    flecken = rauschen(staerke=2.2, grob=3, saat=saat + 1)
    kante = np.clip(abst / 4.0, 0, 1)
    farbe = np.array(grund)[None, None] * (hell * (0.85 + 0.2 * korn) * (0.8 + 0.3 * flecken))[..., None]
    farbe = mischen(np.array([0.2, 0.19, 0.17]), farbe, kante)
    hoehe = np.sqrt(np.clip(abst / 8, 0, 1)) * 0.5 + korn * 0.1
    speichere(name, farbe, hoehe, 0.85 + 0.1 * korn, 2.5)


def pflaster(name="pflaster", saat=8):
    """Kopfsteinpflaster aus runden Steinen (Straßen, Markt)."""
    ids, abst = zellen(170, saat)
    r = np.random.default_rng(saat)
    hell = je_stein(ids, r.uniform(0.75, 1.15, 500))
    ton = je_stein(ids, r.uniform(-0.015, 0.02, 500))
    korn = rauschen(staerke=1.2, grob=50, saat=saat)
    kuppe = np.sqrt(np.clip(abst / 26.0, 0, 1))
    farbe = np.array([0.42, 0.4, 0.37])[None, None] * (hell * (0.8 + 0.25 * korn))[..., None] * (0.7 + 0.3 * kuppe)[..., None]
    farbe[..., 0] += ton
    erde = np.array([0.25, 0.21, 0.16])
    farbe = mischen(erde, farbe, np.clip((abst - 3) / 4, 0, 1))
    speichere(name, farbe, kuppe + korn * 0.1, 0.8 + 0.15 * (1 - kuppe), 4.0)


def stoff(name="stoff", grund=(0.55, 0.15, 0.12), saat=9):
    y, x = np.mgrid[0:N, 0:N]
    gewebe = 0.5 + 0.25 * np.sin(x * np.pi / 3) + 0.25 * np.sin(y * np.pi / 3)
    korn = rauschen(staerke=1.5, grob=8, saat=saat)
    farbe = np.array(grund)[None, None] * (0.75 + 0.2 * gewebe + 0.15 * korn)[..., None]
    speichere(name, farbe, gewebe * 0.3, 0.95 + 0 * korn, 2.0)


def metall(name="metall", saat=10):
    korn = rauschen(staerke=1.2, grob=40, saat=saat)
    rost = np.clip(rauschen(staerke=2.2, grob=3, saat=saat + 1) - 0.55, 0, 1) * 2.5
    farbe = mischen(np.array([0.26, 0.26, 0.28]) * (0.85 + 0.2 * korn[..., None]), np.array([0.35, 0.2, 0.1]), rost)
    speichere(name, farbe, korn * 0.2 + rost * 0.3, 0.4 + 0.4 * rost + 0.1 * korn, 2.0)


# Gelände (im Geländeshader nach Hang und Höhe gemischt)
def gras(name="gras", saat=11):
    grob = rauschen(staerke=2.2, grob=3, saat=saat)
    fein = rauschen(staerke=0.8, grob=200, saat=saat + 1)
    halme = rauschen(staerke=0.6, grob=300, saat=saat + 2)
    halme = np.repeat(halme[::3], 3, axis=0)[:N]
    t = np.clip(grob * 0.6 + fein * 0.4, 0, 1)
    farbe = farbe_aus(t, [(0, (0.17, 0.24, 0.09)), (0.5, (0.27, 0.34, 0.14)), (0.8, (0.38, 0.4, 0.2)), (1, (0.45, 0.42, 0.26))])
    farbe *= (0.7 + 0.55 * halme)[..., None] * (0.9 + 0.2 * fein)[..., None]
    speichere(name, farbe, halme * 0.5 + fein * 0.3, 0.95 + 0 * fein, 2.0)


def erde(name="erde", saat=12):
    grob = rauschen(staerke=2.2, grob=3, saat=saat)
    fein = rauschen(staerke=1.0, grob=120, saat=saat + 1)
    steinchen = np.clip(rauschen(staerke=0.5, grob=300, saat=saat + 2) - 0.72, 0, 1) * 4
    farbe = farbe_aus(grob * 0.5 + fein * 0.5, [(0, (0.24, 0.19, 0.13)), (0.6, (0.38, 0.31, 0.22)), (1, (0.5, 0.43, 0.32))])
    farbe = mischen(farbe, np.array([0.5, 0.48, 0.44]), steinchen)
    speichere(name, farbe, fein * 0.4 + steinchen * 0.6, 0.95 + 0 * fein, 3.0)


def fels(name="fels", saat=13):
    grob = rauschen(staerke=2.0, grob=4, saat=saat)
    rippen = 1 - np.abs(rauschen(staerke=1.7, grob=8, saat=saat + 1) - 0.5) * 2
    fein = rauschen(staerke=1.0, grob=100, saat=saat + 2)
    schichten = 0.5 + 0.5 * np.sin((np.arange(N)[:, None] / N * 24 + grob * 6) * np.pi)
    t = grob * 0.4 + rippen * 0.3 + fein * 0.2 + schichten * 0.1
    farbe = farbe_aus(t, [(0, (0.18, 0.17, 0.16)), (0.45, (0.33, 0.32, 0.3)), (0.75, (0.45, 0.43, 0.4)), (1, (0.55, 0.53, 0.5))])
    speichere(name, farbe, rippen * 0.6 + fein * 0.3 + schichten * 0.1, 0.85 + 0.1 * fein, 5.0)


def sand(name="sand", saat=14):
    fein = rauschen(staerke=0.8, grob=200, saat=saat)
    wellen = 0.5 + 0.5 * np.sin((np.arange(N)[None, :] / N * 40 + rauschen(staerke=2.2, grob=3, saat=saat + 1) * 8) * np.pi)
    grob = rauschen(staerke=2.2, grob=3, saat=saat + 2)
    farbe = farbe_aus(fein * 0.5 + grob * 0.4 + wellen * 0.1, [(0, (0.5, 0.45, 0.35)), (1, (0.66, 0.6, 0.47))])
    speichere(name, farbe, wellen * 0.15 + fein * 0.3, 0.95 + 0 * fein, 2.0)


def schnee(name="schnee", saat=15):
    grob = rauschen(staerke=2.2, grob=3, saat=saat)
    fein = rauschen(staerke=0.8, grob=200, saat=saat + 1)
    farbe = farbe_aus(grob * 0.6 + fein * 0.4, [(0, (0.78, 0.82, 0.88)), (1, (0.95, 0.96, 0.98))])
    speichere(name, farbe, grob * 0.5 + fein * 0.2, 0.6 + 0.2 * fein, 1.5)


def sumpf(name="sumpf", saat=16):
    grob = rauschen(staerke=2.2, grob=3, saat=saat)
    fein = rauschen(staerke=0.9, grob=150, saat=saat + 1)
    nass = np.clip(grob - 0.55, 0, 1) * 3
    farbe = farbe_aus(fein, [(0, (0.12, 0.14, 0.08)), (1, (0.25, 0.27, 0.15))])
    farbe = mischen(farbe, np.array([0.08, 0.09, 0.07]), np.clip(nass, 0, 1))
    speichere(name, farbe, fein * 0.4 - nass * 0.3, 0.9 - 0.6 * np.clip(nass, 0, 1), 2.0)


def wolken(name="wolken", saat=17):
    """Wolkendecke als Panorama (2:1) für den Himmel: oben Haufenwolken, zum Horizont dünner und flacher."""
    breite, hoehe = 2048, 1024
    r = np.random.default_rng(saat)
    # kachelbar in x: zwei quadratische Rauschfelder nebeneinander aus einem breiten Spektrum
    f = np.fft.fftfreq(breite) * breite
    g = np.fft.fftfreq(hoehe) * hoehe
    fx, fy = np.meshgrid(f, g)
    k = np.sqrt(fx ** 2 + (fy * 2) ** 2)
    k[0, 0] = 1
    feld = np.real(np.fft.ifft2(np.fft.fft2(r.standard_normal((hoehe, breite))) / np.maximum(k, 6) ** 1.9))
    feld = (feld - feld.min()) / (feld.max() - feld.min())
    v = np.linspace(0, 1, hoehe)[:, None]          # 0 Zenit, 0.5 Horizont, 1 Nadir
    dichte = np.clip((feld - 0.5) * 3.2, 0, 1)
    dichte *= np.clip((0.5 - v) * 8, 0, 1)          # nur über dem Horizont
    dichte *= 0.6 + 0.4 * np.clip(1 - v * 2, 0, 1)  # zum Horizont etwas dünner
    hell = 0.75 + 0.25 * np.clip(feld - 0.4, 0, 1) / 0.6
    bild = np.stack([hell * dichte] * 3 + [dichte], -1)
    ZIEL.mkdir(exist_ok=True)
    Image.fromarray((np.clip(bild, 0, 1) * 255).astype(np.uint8), "RGBA").save(ZIEL / f"{name}.png")
    print("geschrieben:", name)


ALLE = {
    "quader": quader, "bruchstein": bruchstein, "basalt": basalt, "putz": putz, "holz": holz, "dach": dach,
    "platten": platten, "pflaster": pflaster, "stoff": stoff, "metall": metall,
    "wolken": wolken,
    "gras": gras, "erde": erde, "fels": fels, "sand": sand, "schnee": schnee, "sumpf": sumpf,
}



# ---------- Materialien (material/*.tres) ----------
# Name → (Textur, Meter je Kachel, Farbton, Metall, Rauheit-Faktor). Triplanar in Weltkoordinaten: Jede Fläche
# bekommt Steine in echter Größe, egal wie groß der Klotz ist.
MATERIALIEN = {
    "mauer": ("quader", 4.0, (1, 1, 1), 0.0, 1.0),
    "hell": ("putz", 3.0, (1, 1, 1), 0.0, 1.0),
    "basalt": ("basalt", 6.0, (1, 1, 1), 0.0, 1.0),
    "holz": ("holz", 2.0, (1, 1, 1), 0.0, 1.0),
    "eis": ("fels", 8.0, (1.35, 1.45, 1.6), 0.0, 0.8),
    "kai": ("bruchstein", 5.0, (1, 1, 1), 0.0, 1.0),
    "boden": ("platten", 6.0, (1, 1, 1), 0.0, 1.0),
    "pflaster": ("pflaster", 3.0, (1, 1, 1), 0.0, 1.0),
    "bruchstein": ("bruchstein", 5.0, (1, 1, 1), 0.0, 1.0),
    "dach": ("dach", 3.0, (1, 1, 1), 0.0, 1.0),
    "dach_schiefer": ("dach", 3.0, (0.42, 0.5, 0.62), 0.0, 1.0),
    "stoff": ("stoff", 1.0, (1, 1, 1), 0.0, 1.0),
    "metall": ("metall", 2.0, (1, 1, 1), 0.6, 1.0),
    "fels": ("fels", 8.0, (1, 1, 1), 0.0, 1.0),
    "erde": ("erde", 4.0, (1, 1, 1), 0.0, 1.0),
    "sand": ("sand", 4.0, (1, 1, 1), 0.0, 1.0),
}
MATERIAL_ORDNER = ZIEL.parent / "material"


def schreibe_materialien():
    MATERIAL_ORDNER.mkdir(exist_ok=True)
    for name, (tex, meter, ton, metall, rau) in MATERIALIEN.items():
        s = 1.0 / meter
        (MATERIAL_ORDNER / f"{name}.tres").write_text(f'''[gd_resource type="StandardMaterial3D" load_steps=4 format=3]

[ext_resource type="Texture2D" path="res://texturen/{tex}_farbe.jpg" id="1_farbe"]
[ext_resource type="Texture2D" path="res://texturen/{tex}_normal.jpg" id="2_normal"]
[ext_resource type="Texture2D" path="res://texturen/{tex}_rau.jpg" id="3_rau"]

[resource]
albedo_color = Color({ton[0]}, {ton[1]}, {ton[2]}, 1)
albedo_texture = ExtResource("1_farbe")
metallic = {metall}
roughness = {rau}
roughness_texture = ExtResource("3_rau")
roughness_texture_channel = 0
normal_enabled = true
normal_texture = ExtResource("2_normal")
uv1_scale = Vector3({s:.4g}, {s:.4g}, {s:.4g})
uv1_triplanar = true
uv1_triplanar_sharpness = 4.0
uv1_world_triplanar = true
texture_filter = 5
''', encoding="utf-8")
    print("Materialien:", len(MATERIALIEN))


if __name__ == "__main__":
    # "material" schreibt nur die .tres-Dateien neu, ohne die Texturen zu berechnen
    namen = sys.argv[1:] or list(ALLE)
    for name in namen:
        if name in ALLE:
            ALLE[name]()
    schreibe_materialien()
