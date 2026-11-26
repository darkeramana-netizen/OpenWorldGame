"""Erzeugt die Geräusche des Spiels nach klaenge/ (OGG, mono, 44,1 kHz).

Zwei Quellen, beide frei (CC0):
  - Synthese mit numpy (dieses Skript): Wind (sanft, stark), Feuer, Brandung, Vogelrufe, Amboss, Kirchenglocken, Schritte
    auf Gras und Erde (aus den Schritten von Kenney abgeleitet). Alles, was hier entsteht, ist eigene Arbeit.
  - Aufnahmen aus zwei CC0-Paketen von OpenGameArt.org, unverändert oder leicht bearbeitet (Tonhöhe, Lautstärke):
      * Kenney, „50 RPG sound effects“ (RPGsounds_Kenney.zip): Schritte, Türen, Knarren, Metall, Holz, Leder
      * artisticdude, „RPG Sound Pack“ (rpg_sound_pack.zip): Kettenhemd, Schwert ziehen, Holz, Metall
    Quellen und Lizenz: klaenge/QUELLEN.md.

Aufruf aus dem Projektordner:
    python3 werkzeuge/klaenge_erzeugen.py KENNEY_ORDNER ARTISTICDUDE_ORDNER
(die entpackten Zip-Dateien; ohne Angaben nur die Synthese). Braucht numpy, scipy und ffmpeg.
"""
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy import signal

RATE = 44100
REPO = Path(__file__).resolve().parent.parent
ZIEL = REPO / "klaenge"
ZUFALL = np.random.default_rng(20261126)


# ---------- Grundbausteine ----------

def rauschen(n):
    return ZUFALL.standard_normal(n)


def rosa(n):
    """Rosa Rauschen (1/f) über einen Filter auf weißem Rauschen (Voss-McCartney angenähert)."""
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    return signal.lfilter(b, a, rauschen(n)) * 8.0


def braun(n):
    x = np.cumsum(rauschen(n))
    x = signal.filtfilt(*signal.butter(1, 15 / (RATE / 2), "high"), x)
    return x / (np.abs(x).max() + 1e-9)


def band(x, lo, hi, ordnung=2):
    sos = signal.butter(ordnung, [lo / (RATE / 2), hi / (RATE / 2)], "band", output="sos")
    return signal.sosfilt(sos, x)


def tief(x, f, ordnung=2):
    return signal.sosfilt(signal.butter(ordnung, f / (RATE / 2), "low", output="sos"), x)


def hoch(x, f, ordnung=2):
    return signal.sosfilt(signal.butter(ordnung, f / (RATE / 2), "high", output="sos"), x)


def glatt_zufall(n, schritte, lo=0.0, hi=1.0):
    """Langsam schwankender Verlauf (Werte lo..hi) aus schritte Stützpunkten, kubisch verbunden."""
    stuetz = ZUFALL.uniform(lo, hi, schritte + 3)
    t = np.linspace(0, schritte - 1e-6, n)
    i = np.floor(t).astype(int)
    f = t - i
    p0, p1, p2, p3 = stuetz[i], stuetz[i + 1], stuetz[i + 2], stuetz[i + 3]
    return p1 + 0.5 * f * (p2 - p0 + f * (2 * p0 - 5 * p1 + 4 * p2 - p3 + f * (3 * (p1 - p2) + p3 - p0)))


def schleife(x, ueberblend_s=2.0):
    """Nahtlose Schleife: das Ende wird über ueberblend_s in den Anfang geblendet (gleiche Leistung)."""
    k = int(ueberblend_s * RATE)
    w = np.linspace(0, np.pi / 2, k)
    anfang = x[:k] * np.sin(w) + x[-k:] * np.cos(w)
    return np.concatenate([anfang, x[k:-k]])


def normiere(x, spitze=0.9):
    return x / (np.abs(x).max() + 1e-9) * spitze


def huelle(n, an_s, ab_s):
    """Einschwingen linear, Ausklingen exponentiell."""
    t = np.arange(n) / RATE
    h = np.minimum(t / max(an_s, 1e-4), 1.0) * np.exp(-t / max(ab_s, 1e-4))
    return h


def schreibe(name, x, qualitaet=4):
    """Als OGG (Vorbis) nach klaenge/ schreiben."""
    ZIEL.mkdir(exist_ok=True)
    x = np.clip(x, -1.0, 1.0)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((x * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", str(qualitaet),
                        str(ZIEL / f"{name}.ogg")], check=True)
    Path(tmp.name).unlink()


def lies(pfad):
    """Beliebige Audiodatei (ogg, wav) als mono float, 44,1 kHz."""
    roh = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(pfad), "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(roh, np.int16).astype(np.float64) / 32768.0


def tonhoehe(x, faktor):
    """Tonhöhe und Länge zusammen ändern (wie schneller/langsamer abspielen)."""
    n = int(len(x) / faktor)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


# ---------- Umgebung ----------

def wind(stark):
    """Wind: rosa Rauschen durch einen wandernden Bandpass, dazu Böen; stark mit Pfeifen (Zinnen, Turmkanten)."""
    n = 24 * RATE
    x = rosa(n)
    boeen = glatt_zufall(n, 14, 0.25, 1.0) ** (1.6 if stark else 1.2)
    # Mitte des Bandes wandert mit den Böen (stärkerer Wind: heller)
    lagen = []
    for lo, hi in ((60, 300), (200, 900), (600, 2200)):
        lagen.append(band(x, lo, hi))
    tiefe, mitte, hell = lagen
    w = tiefe * (0.8 + 0.4 * boeen) + mitte * boeen * (1.2 if stark else 0.7) + hell * boeen ** 2 * (0.5 if stark else 0.18)
    if stark:
        # Pfeifen: schmales Band um einen langsam gleitenden Ton, nur in Böen
        f = 700 + 500 * glatt_zufall(n, 10)
        phase = 2 * np.pi * np.cumsum(f) / RATE
        pfiff = np.sin(phase) * band(rauschen(n), 400, 1600) * 0.6 + np.sin(phase * 1.5) * 0.15
        w += pfiff * np.clip(boeen - 0.55, 0, 1) * 1.2
    w *= 0.4 + 0.6 * boeen
    return normiere(schleife(w, 3.0), 0.7)


def feuer():
    """Feuer: tiefes Grollen (braunes Rauschen), Fauchen, Knistern (kurze Rauschstöße) und einzelne Knalle."""
    n = 14 * RATE
    grollen = tief(braun(n), 220) * (0.7 + 0.3 * glatt_zufall(n, 20))
    fauchen = band(rauschen(n), 500, 2500) * 0.05 * glatt_zufall(n, 30, 0.3, 1.0)
    knistern = np.zeros(n)
    t = 0.0
    while t < 14.0:
        t += ZUFALL.exponential(1 / 9.0)
        i = int(t * RATE)
        if i >= n - 4000:
            break
        lang = int(ZUFALL.uniform(0.002, 0.012) * RATE)
        stoss = rauschen(lang) * np.exp(-np.arange(lang) / (lang / 4))
        lo = ZUFALL.uniform(900, 3000)
        stoss = band(np.concatenate([stoss, np.zeros(200)]), lo, min(lo * 3.5, 15000))
        knistern[i:i + len(stoss)] += stoss * ZUFALL.uniform(0.2, 1.0) ** 2
    for _ in range(6):        # Knalle: Holz platzt
        i = int(ZUFALL.uniform(0.5, 13.0) * RATE)
        lang = int(0.03 * RATE)
        knistern[i:i + lang] += band(rauschen(lang), 300, 4000) * np.exp(-np.arange(lang) / 300) * 2.5
    x = grollen * 0.9 + fauchen + knistern * 0.8
    return normiere(schleife(x, 1.5), 0.75)


def brandung():
    """Brandung: Wellen alle 6 bis 10 s, jede schwillt an, bricht (hell) und läuft zischend aus."""
    n = 32 * RATE
    x = np.zeros(n)
    grund = tief(rosa(n), 500) * 0.25
    t = 0.0
    while t < 30.0:
        lang = int(ZUFALL.uniform(4.5, 7.0) * RATE)
        i = int(t * RATE)
        if i + lang > n:
            break
        tt = np.linspace(0, 1, lang)
        an = np.clip(tt / 0.35, 0, 1) ** 2
        ab = np.exp(-np.clip(tt - 0.35, 0, None) * 5.0)
        h = an * ab
        welle = tief(rosa(lang), 600) * h + band(rauschen(lang), 1500, 7000) * h ** 1.5 * np.clip((tt - 0.3) * 4, 0, 1) * 0.35
        x[i:i + lang] += welle * ZUFALL.uniform(0.6, 1.0)
        t += ZUFALL.uniform(6.0, 10.0)
    return normiere(schleife(x + grund, 3.0), 0.7)


def vogel(art):
    """Vogelrufe aus frequenzmodulierten Tönen: Amsel (flötend, abfallend), Spatz (Tschilpen), Meise (zwei Töne),
    Fink (Triller mit Schlag), Schwalbe (Zwitschern), Krähe (rau)."""
    stuecke = []
    def ton(dauer, f0, f1, harmonisch=0.15, vibrato=0.0, rau=0.0):
        m = int(dauer * RATE)
        t = np.arange(m) / RATE
        f = np.linspace(f0, f1, m) * (1 + vibrato * np.sin(2 * np.pi * 28 * t))
        ph = 2 * np.pi * np.cumsum(f) / RATE
        s = np.sin(ph) + harmonisch * np.sin(2 * ph) + harmonisch * 0.4 * np.sin(3 * ph)
        if rau:
            s = s * (1 - rau) + rau * band(rauschen(m), 400, 3000) * 3 * np.sin(ph * 0.5)
        h = np.sin(np.pi * np.clip(t / dauer, 0, 1)) ** 0.6
        return s * h
    def pause(d):
        return np.zeros(int(d * RATE))
    if art == "amsel":
        for _ in range(ZUFALL.integers(3, 6)):
            f = ZUFALL.uniform(1600, 2600)
            stuecke += [ton(ZUFALL.uniform(0.12, 0.3), f, f * ZUFALL.uniform(0.7, 1.2), 0.2, 0.01), pause(ZUFALL.uniform(0.03, 0.12))]
    elif art == "spatz":
        for _ in range(ZUFALL.integers(4, 8)):
            stuecke += [ton(0.07, 4200, 3100, 0.35), pause(ZUFALL.uniform(0.12, 0.3))]
    elif art == "meise":
        for _ in range(ZUFALL.integers(3, 5)):
            stuecke += [ton(0.11, 5200, 5000, 0.1), pause(0.04), ton(0.13, 3600, 3500, 0.1), pause(0.08)]
    elif art == "fink":
        for k in range(10):
            f = 4800 - k * 180
            stuecke += [ton(0.05, f, f - 600, 0.2), pause(0.025)]
        stuecke += [ton(0.25, 3000, 4600, 0.2, 0.02)]
    elif art == "schwalbe":
        for _ in range(14):
            f = ZUFALL.uniform(3500, 6500)
            stuecke += [ton(ZUFALL.uniform(0.03, 0.08), f, f * ZUFALL.uniform(0.8, 1.3), 0.3), pause(ZUFALL.uniform(0.01, 0.05))]
    elif art == "kraehe":
        for _ in range(ZUFALL.integers(2, 4)):
            stuecke += [ton(0.32, 650, 520, 0.8, 0.0, rau=0.6), pause(0.25)]
    x = np.concatenate(stuecke + [pause(0.2)])
    # etwas Raum: kurzer, leiser Nachhall
    hall = signal.fftconvolve(x, np.exp(-np.arange(int(0.25 * RATE)) / (0.06 * RATE)) * rauschen(int(0.25 * RATE)) * 0.02)[:len(x)]
    return normiere(x + hall, 0.8)


def amboss(nr):
    """Hammer auf Amboss: harter Anschlag, unharmonische Teiltöne (wie ein Stahlblock), dumpfer Schlag darunter."""
    n = int(1.6 * RATE)
    t = np.arange(n) / RATE
    grund = [1150.0, 1320.0, 980.0][nr]
    x = np.zeros(n)
    for verh, staerke, abkling in ((1.0, 1.0, 0.55), (2.71, 0.6, 0.35), (4.13, 0.45, 0.22), (5.62, 0.3, 0.15),
                                   (7.9, 0.18, 0.09), (1.51, 0.25, 0.4)):
        f = grund * verh * ZUFALL.uniform(0.99, 1.01)
        x += staerke * np.sin(2 * np.pi * f * t + ZUFALL.uniform(0, 6)) * np.exp(-t / abkling)
    anschlag = band(rauschen(n), 2000, 12000) * np.exp(-t / 0.004) * 1.5
    dumpf = tief(rauschen(n), 300) * np.exp(-t / 0.03) * 3.0
    return normiere(x + anschlag + dumpf, 0.85)


def glocke(grund, dauer):
    """Kirchenglocke nach der Teiltonreihe gegossener Glocken (Unterton, Prime, kleine Terz, Quinte, Nominal, ...),
    jeder Teilton mit eigener Abklingzeit und leichter Schwebung; dazu der Anschlag des Klöppels."""
    n = int(dauer * RATE)
    t = np.arange(n) / RATE
    x = np.zeros(n)
    # Der Unterton (0,5) bleibt leise, die Nominale (2,0) und die oberen Teiltöne tragen den Klang (vorher zu
    # basslastig, Rückmeldung 26.11.2026)
    teile = ((0.5, 0.3, 1.0), (1.0, 0.55, 0.6), (1.2, 0.6, 0.45), (1.5, 0.3, 0.35), (2.0, 1.0, 0.32),
             (2.5, 0.55, 0.2), (3.0, 0.45, 0.15), (4.0, 0.35, 0.11), (5.33, 0.25, 0.08), (6.66, 0.15, 0.06))
    for verh, staerke, anteil in teile:
        f = grund * verh
        ab = dauer * anteil
        schweb = 1.0 + 0.004 * np.sin(2 * np.pi * ZUFALL.uniform(0.3, 1.2) * t)
        x += staerke * np.sin(2 * np.pi * f * t * schweb + ZUFALL.uniform(0, 6)) * np.exp(-t / ab)
    x += band(rauschen(n), 1500, 9000) * np.exp(-t / 0.008) * 0.6
    return normiere(hoch(x, 180.0), 0.85)


def schuss():
    """Musketenschuss: Knall (sehr kurzer, lauter Rauschstoß), tiefes Wummern der Pulverladung, Nachhall über das Land."""
    n = int(2.6 * RATE)
    t = np.arange(n) / RATE
    knall = rauschen(n) * np.exp(-t / 0.012) * 3.0
    wumm = tief(rauschen(n), 180, 4) * np.exp(-t / 0.18) * 6.0
    hall = band(rauschen(n), 150, 3000) * np.exp(-t / 0.7) * 0.35 * np.clip(t / 0.06, 0, 1)
    return normiere(tief(knall, 9000) + wumm + hall, 0.95)


# ---------- Stimmen (Tiere, Markt): Stimmton durch Formanten ----------

def stimmton(f0, rau=0.0, offen=0.6):
    """Stimmton mit Tonhöhenverlauf f0 (Hz je Abtastwert): Pulsfolge wie bei Stimmlippen (Sägezahn mit weichem
    Abfall), dazu rau (0..1) Rauschen für Hauch und Heiserkeit."""
    ph = np.cumsum(f0) / RATE
    saw = 2.0 * (ph - np.floor(ph)) - 1.0
    puls = np.where(saw > (1 - 2 * offen), saw, -1.0) - np.mean(saw)
    x = puls * (1 - rau) + rauschen(len(f0)) * rau * 0.8
    return x


def formanten(x, forms, breite=(80, 110, 160, 220)):
    """Formanten (Resonanzen des Rachen- und Mundraums), je Abschnitt eine Folge [(f1, f2, f3), ...] gleich lang
    verteilt; zwischen den Abschnitten weich überblendet."""
    n = len(x)
    if isinstance(forms[0], (int, float)):
        forms = [forms]
    teile = len(forms)
    aus = np.zeros(n)
    gewicht = np.zeros(n)
    lang = n // teile
    for k, ff in enumerate(forms):
        a0 = max(0, k * lang - lang // 3)
        a1 = min(n, (k + 1) * lang + lang // 3)
        seg = x[a0:a1]
        y = np.zeros(len(seg))
        for j, f in enumerate(ff):
            b = breite[min(j, len(breite) - 1)]
            y += band(seg, max(f - b, 40), min(f + b, RATE / 2 - 100)) * (1.0 / (1 + j * 0.6))
        w = np.hanning(len(seg) + 2)[1:-1]
        aus[a0:a1] += y * w
        gewicht[a0:a1] += w
    return aus / np.maximum(gewicht, 1e-3)


def verlauf(n, punkte):
    """Linearer Verlauf über n Abtastwerte durch die Stützpunkte [(Anteil 0..1, Wert), ...]."""
    t = np.linspace(0, 1, n)
    xs, ys = zip(*punkte)
    return np.interp(t, xs, ys)


def ruf(dauer, f0_punkte, forms, rau=0.0, vibrato=(0.0, 0.0), an=0.02, ab=0.08, offen=0.6):
    n = int(dauer * RATE)
    f0 = verlauf(n, f0_punkte)
    if vibrato[0] > 0:
        t = np.arange(n) / RATE
        f0 = f0 * (1 + vibrato[1] * np.sin(2 * np.pi * vibrato[0] * t))
    x = formanten(stimmton(f0, rau, offen), forms)
    t = np.arange(n) / RATE
    h = np.minimum(t / an, 1.0) * np.minimum((dauer - t) / ab, 1.0)
    return x * np.clip(h, 0, 1)


def stille(d):
    return np.zeros(int(d * RATE))


def huhn():
    """Gackern: kurze „Bock“-Laute mit fallender Tonhöhe, dann ein längeres, ansteigendes „Bagaak“."""
    teile = []
    for _ in range(ZUFALL.integers(3, 7)):
        f = ZUFALL.uniform(350, 480)
        teile += [ruf(ZUFALL.uniform(0.06, 0.1), [(0, f * 1.15), (1, f * 0.85)], [(900, 1900, 3100)], 0.25, an=0.005, ab=0.03),
                  stille(ZUFALL.uniform(0.08, 0.25))]
    if ZUFALL.random() < 0.6:
        f = ZUFALL.uniform(420, 520)
        teile += [ruf(0.07, [(0, f), (1, f * 0.9)], [(800, 1700, 3000)], 0.3, an=0.005, ab=0.02), stille(0.04),
                  ruf(0.32, [(0, f), (0.6, f * 1.55), (1, f * 1.3)], [(700, 1600, 2900), (1000, 2100, 3300)], 0.3, (9, 0.02))]
    return normiere(np.concatenate(teile + [stille(0.15)]), 0.8)


def hahn():
    """Kikeriki: drei kurze, ansteigende Silben, dann eine lange, fallende mit Zittern."""
    f = ZUFALL.uniform(560, 660)
    teile = [ruf(0.13, [(0, f * 0.9), (1, f * 1.1)], [(1100, 2200, 3300)], 0.15), stille(0.03),
             ruf(0.12, [(0, f * 1.1), (1, f * 1.25)], [(1300, 2500, 3500)], 0.15), stille(0.03),
             ruf(0.16, [(0, f * 1.25), (1, f * 1.35)], [(1200, 2300, 3400)], 0.15), stille(0.04),
             ruf(0.95, [(0, f * 1.4), (0.3, f * 1.45), (1, f * 0.95)], [(1200, 2300, 3400), (900, 1900, 3000)], 0.2, (11, 0.025), ab=0.25)]
    return normiere(np.concatenate(teile + [stille(0.2)]), 0.85)


def pferd_wiehern():
    """Wiehern: hoch ansetzend, mit starkem, schnellem Zittern absteigend, am Ende ein tiefes Brummen."""
    f = ZUFALL.uniform(780, 950)
    hoch_ = ruf(1.3, [(0, f), (0.15, f * 1.1), (0.7, f * 0.62), (1, f * 0.45)], [(900, 1700, 2600), (700, 1300, 2400)], 0.35, (24, 0.08), ab=0.3)
    tief_ = ruf(0.45, [(0, 160), (1, 120)], [(400, 900, 2200)], 0.55, (18, 0.05), an=0.05, ab=0.2)
    return normiere(np.concatenate([hoch_, tief_ * 0.6, stille(0.2)]), 0.85)


def pferd_schnauben():
    n = int(0.55 * RATE)
    t = np.arange(n) / RATE
    x = band(rauschen(n), 180, 1400) * (np.exp(-t / 0.12) + 0.4 * np.exp(-((t - 0.25) / 0.06) ** 2))
    flattern = 1 + 0.6 * np.sin(2 * np.pi * 32 * t)       # Lippenflattern
    return normiere(x * flattern, 0.8)


def huf():
    """Hufschlag auf Stein: zwei kurze, harte Anschläge (vorn, hinten)."""
    teile = []
    for k in range(2):
        n = int(0.09 * RATE)
        t = np.arange(n) / RATE
        f = ZUFALL.uniform(700, 1100)
        x = (band(rauschen(n), 500, 4000) * np.exp(-t / 0.008) * 1.2 + np.sin(2 * np.pi * f * t) * np.exp(-t / 0.02) * 0.5
             + tief(rauschen(n), 250) * np.exp(-t / 0.015) * 1.5)
        teile += [x, stille(ZUFALL.uniform(0.05, 0.09))]
    return normiere(np.concatenate(teile), 0.8)


def hund():
    """Bellen: ein bis drei kurze, kräftige Laute mit Hauch."""
    teile = []
    f = ZUFALL.uniform(380, 520)
    for _ in range(ZUFALL.integers(1, 4)):
        teile += [ruf(ZUFALL.uniform(0.12, 0.18), [(0, f * 0.8), (0.25, f * 1.15), (1, f * 0.7)],
                      [(650, 1400, 2700), (500, 1100, 2500)], 0.35, an=0.006, ab=0.05, offen=0.7), stille(ZUFALL.uniform(0.12, 0.3))]
    return normiere(np.concatenate(teile), 0.85)


def schwein():
    """Grunzen: tiefe, rau gepulste Laute durch die Nase."""
    teile = []
    for _ in range(ZUFALL.integers(2, 5)):
        f = ZUFALL.uniform(85, 130)
        teile += [ruf(ZUFALL.uniform(0.15, 0.3), [(0, f), (1, f * 0.85)], [(350, 900, 2300)], 0.5, (14, 0.15), an=0.03, ab=0.06, offen=0.4),
                  stille(ZUFALL.uniform(0.1, 0.35))]
    return normiere(np.concatenate(teile), 0.8)


def kuh():
    """Muhen: „Mmmuuuh“, erst geschlossen (nasal), dann offen, Tonhöhe hebt sich und fällt."""
    f = ZUFALL.uniform(130, 165)
    x = ruf(ZUFALL.uniform(1.4, 1.9), [(0, f * 0.9), (0.3, f * 1.15), (0.8, f), (1, f * 0.8)],
            [(250, 1000, 2400), (450, 900, 2300), (600, 1000, 2400)], 0.2, (4, 0.01), an=0.15, ab=0.4)
    return normiere(np.concatenate([x, stille(0.2)]), 0.85)


def schaf():
    """Blöken: „Mäh“ mit dem typischen Zittern der Stimme."""
    f = ZUFALL.uniform(260, 340)
    x = ruf(ZUFALL.uniform(0.7, 1.0), [(0, f * 0.95), (0.3, f * 1.05), (1, f * 0.9)], [(400, 1700, 2600), (650, 1800, 2700)],
            0.3, (7, 0.08), an=0.05, ab=0.2)
    zittern = 1 + 0.35 * np.sin(2 * np.pi * 7 * np.arange(len(x)) / RATE)
    return normiere(np.concatenate([x * zittern, stille(0.2)]), 0.8)


def katze():
    """Miauen: Vokal von i über a nach u, Tonhöhe steigt und fällt."""
    f = ZUFALL.uniform(520, 700)
    x = ruf(ZUFALL.uniform(0.55, 0.8), [(0, f * 0.9), (0.35, f * 1.25), (1, f * 0.85)],
            [(400, 2300, 3100), (850, 1500, 2800), (500, 900, 2600)], 0.12, (6, 0.01), an=0.04, ab=0.15)
    return normiere(np.concatenate([x, stille(0.15)]), 0.8)


VOKALE = [(730, 1090, 2440), (530, 1840, 2480), (270, 2290, 3010), (570, 840, 2410), (300, 870, 2240), (660, 1720, 2410)]


def stimme(dauer, f0_mitte, laut=False):
    """Eine Kunststimme, die redet: Silben (4 bis 6 je Sekunde) mit wechselnden Vokalen, Tonhöhe wie im Satz,
    kurze Pausen; nichts davon sind echte Wörter."""
    teile = []
    t = 0.0
    while t < dauer:
        silben = ZUFALL.integers(3, 9)
        f0 = f0_mitte * ZUFALL.uniform(0.9, 1.15)
        for k in range(silben):
            d = ZUFALL.uniform(0.12, 0.24)
            ff = VOKALE[ZUFALL.integers(len(VOKALE))]
            sinken = 1.0 - 0.15 * k / max(silben - 1, 1)          # der Satz fällt zum Ende
            teile.append(ruf(d, [(0, f0 * sinken * ZUFALL.uniform(0.95, 1.08)), (1, f0 * sinken * ZUFALL.uniform(0.9, 1.0))],
                             [ff], 0.12 if not laut else 0.08, an=0.015, ab=0.04, offen=0.55))
            t += d
        p = ZUFALL.uniform(0.15, 0.8)
        teile.append(stille(p))
        t += p
    x = np.concatenate(teile)
    return x[:int(dauer * RATE)]


def markt():
    """Stimmengewirr auf dem Markt: 22 Kunststimmen in verschiedener Entfernung (leiser und dumpfer), Männer und
    Frauen, dazu leises Klappern; als nahtlose Schleife."""
    n = 26 * RATE
    x = np.zeros(n)
    for k in range(22):
        frau = ZUFALL.random() < 0.45
        s = stimme(26.0, ZUFALL.uniform(190, 250) if frau else ZUFALL.uniform(100, 150))
        s = np.concatenate([s, np.zeros(max(0, n - len(s)))])[:n]
        ferne = ZUFALL.uniform(0.0, 1.0)
        s = tief(s, 4500 - 3000 * ferne) * (1.0 - 0.75 * ferne)
        x += np.roll(s, ZUFALL.integers(0, n))
    klappern = np.zeros(n)
    for _ in range(40):
        i = ZUFALL.integers(0, n - 3000)
        m = 2000
        klappern[i:i + m] += band(rauschen(m), 1500, 6000) * np.exp(-np.arange(m) / 250) * ZUFALL.uniform(0.1, 0.4)
    return normiere(schleife(x + klappern, 2.0), 0.7)


def ausruf():
    """Ein Marktschreier: eine laute Stimme, langgezogen am Ende (wie „Frische Fische!“, ohne echte Wörter)."""
    f0 = ZUFALL.uniform(120, 170) if ZUFALL.random() < 0.6 else ZUFALL.uniform(210, 270)
    s = stimme(ZUFALL.uniform(0.9, 1.4), f0 * 1.15, laut=True)
    lang = ruf(0.6, [(0, f0 * 1.3), (1, f0 * 1.05)], [VOKALE[0]], 0.08, ab=0.25)
    return normiere(np.concatenate([s, lang, stille(0.2)]), 0.85)


def brunnen():
    """Plätschern eines Brunnens: vier Strahlen fallen ins Becken (rauschendes Prasseln) und viele kleine Tropfen und
    Blasen (kurze Töne, die schnell ansteigen), als nahtlose Schleife."""
    n = 12 * RATE
    t_ = np.arange(n) / RATE
    prasseln = band(rauschen(n), 900, 7000) * (0.55 + 0.25 * glatt_zufall(n, 40, 0.0, 1.0)) * 0.35
    tropfen = np.zeros(n)
    t = 0.0
    while t < 11.8:
        t += ZUFALL.exponential(1 / 28.0)
        i = int(t * RATE)
        m = int(ZUFALL.uniform(0.015, 0.05) * RATE)
        if i + m >= n:
            break
        tt = np.arange(m) / RATE
        f0 = ZUFALL.uniform(700, 2200)
        ph = 2 * np.pi * np.cumsum(f0 * (1 + 3.0 * tt / tt[-1])) / RATE
        tropfen[i:i + m] += np.sin(ph) * np.exp(-tt / (m / RATE / 3)) * ZUFALL.uniform(0.05, 0.4)
    gluckern = tief(rauschen(n), 400) * 0.3 * (0.6 + 0.4 * glatt_zufall(n, 60))
    return normiere(schleife(prasseln + tropfen + gluckern, 1.0), 0.7)


def weiche_schritte(quellen, art):
    """Schritte auf Gras oder Erde aus den Kenney-Schritten: tiefer, dumpfer, dazu Rascheln (Gras) bzw. Knirschen."""
    aus = []
    for i, q in enumerate(quellen):
        x = lies(q)
        x = tief(x, 1800 if art == "gras" else 2600) * 0.8
        x = tonhoehe(x, 0.86 if art == "gras" else 0.92)
        m = len(x)
        tt = np.arange(m) / RATE
        if art == "gras":
            x += band(rauschen(m), 2500, 9000) * np.exp(-tt / 0.09) * 0.12
        else:
            x += band(rauschen(m), 1200, 5000) * np.exp(-tt / 0.05) * 0.08
        aus.append(normiere(x, 0.7))
    return aus


# ---------- Hauptteil ----------

def main():
    kenney = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    artistic = Path(sys.argv[2]) if len(sys.argv) > 2 else None
    schreibe("wind_sanft", wind(False))
    schreibe("wind_stark", wind(True))
    schreibe("feuer", feuer())
    schreibe("brandung", brandung())
    for art in ("amsel", "spatz", "meise", "fink", "schwalbe", "kraehe"):
        for k in range(2):
            schreibe(f"vogel_{art}_{k + 1}", vogel(art))
    for k in range(3):
        schreibe(f"amboss_{k + 1}", amboss(k))
    schreibe("schuss", schuss())
    for k in range(4):
        schreibe(f"huhn_{k + 1}", huhn())
    schreibe("hahn_1", hahn())
    for k in range(3):
        schreibe(f"pferd_wiehern_{k + 1}", pferd_wiehern())
        schreibe(f"pferd_schnauben_{k + 1}", pferd_schnauben())
        schreibe(f"hund_{k + 1}", hund())
        schreibe(f"schwein_{k + 1}", schwein())
        schreibe(f"kuh_{k + 1}", kuh())
        schreibe(f"schaf_{k + 1}", schaf())
        schreibe(f"katze_{k + 1}", katze())
    for k in range(4):
        schreibe(f"huf_{k + 1}", huf())
    schreibe("markt", markt())
    schreibe("brunnen", brunnen())
    for k in range(5):
        schreibe(f"ausruf_{k + 1}", ausruf())
    schreibe("glocke_gross", glocke(294.0, 8.0))     # D4: Glocke von St. Marien
    schreibe("glocke_klein", glocke(587.0, 4.5))     # D5: Kapellenglocke
    if kenney is not None:
        k = next(kenney.rglob("footstep00.ogg")).parent
        schritte = sorted(k.glob("footstep0*.ogg"))
        for i, q in enumerate(schritte):
            schreibe(f"schritt_stein_{i + 1}", normiere(lies(q), 0.75))
        for art in ("gras", "erde"):
            for i, x in enumerate(weiche_schritte(schritte, art)):
                schreibe(f"schritt_{art}_{i + 1}", x)
        for i, q in enumerate(schritte[:6]):    # Holz: heller, hohler
            x = lies(q)
            x = hoch(x, 150) + signal.fftconvolve(x, np.exp(-np.arange(900) / 180.0) * np.sin(np.arange(900) * 2 * np.pi * 240 / RATE))[:len(x)] * 0.02
            schreibe(f"schritt_holz_{i + 1}", normiere(x, 0.7))
        einzeln = {"tuer_auf_1": "doorOpen_1", "tuer_auf_2": "doorOpen_2", "tuer_zu_1": "doorClose_1",
                   "tuer_zu_2": "doorClose_2", "tuer_zu_3": "doorClose_3", "knarren_1": "creak1", "knarren_2": "creak2",
                   "knarren_3": "creak3", "riegel": "metalLatch", "hacken": "chop", "leder": "dropLeather",
                   "stoff_1": "cloth1", "stoff_2": "cloth2", "muenzen": "handleCoins", "messer_ziehen": "drawKnife1",
                   "buch_auf": "bookOpen", "buch_zu": "bookClose", "topf": "metalPot1"}
        for neu, alt in einzeln.items():
            schreibe(neu, normiere(lies(next(kenney.rglob(f"{alt}.ogg"))), 0.8))
        # Burgtor: die Knarr-Geräusche tiefer und länger (schwere Flügel), das Zuschlagen dumpf
        for i, alt in enumerate(("creak1", "creak3")):
            schreibe(f"tor_auf_{i + 1}", normiere(tief(tonhoehe(lies(next(kenney.rglob(f"{alt}.ogg"))), 0.55), 3000), 0.8))
        schreibe("tor_zu", normiere(tief(tonhoehe(lies(next(kenney.rglob("doorClose_4.ogg"))), 0.6), 1500), 0.9))
    if artistic is not None:
        einzeln = {"kettenhemd_1": "chainmail1", "kettenhemd_2": "chainmail2", "schwert_ziehen_1": "sword-unsheathe",
                   "schwert_ziehen_2": "sword-unsheathe2", "schwung_1": "swing", "schwung_2": "swing2", "holz_klein": "wood-small",
                   "metall_klingt": "metal-ringing", "metall_1": "metal-small1", "metall_2": "metal-small2",
                   "ruestung": "armor-light", "stoff_schwer": "cloth-heavy"}
        for neu, alt in einzeln.items():
            q = [p for p in artistic.rglob(f"{alt}.wav") if not p.name.startswith("._")]
            if q:
                schreibe(neu, normiere(lies(q[0]), 0.8))
    print("Geräusche in", ZIEL, ":", len(list(ZIEL.glob("*.ogg"))))


if __name__ == "__main__":
    main()
