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
    teile = ((0.5, 0.9, 1.0), (1.0, 0.8, 0.55), (1.2, 0.7, 0.45), (1.5, 0.35, 0.35), (2.0, 1.0, 0.3),
             (2.5, 0.4, 0.18), (3.0, 0.35, 0.14), (4.0, 0.2, 0.1), (5.33, 0.15, 0.07))
    for verh, staerke, anteil in teile:
        f = grund * verh
        ab = dauer * anteil
        schweb = 1.0 + 0.004 * np.sin(2 * np.pi * ZUFALL.uniform(0.3, 1.2) * t)
        x += staerke * np.sin(2 * np.pi * f * t * schweb + ZUFALL.uniform(0, 6)) * np.exp(-t / ab)
    x += band(rauschen(n), 1500, 9000) * np.exp(-t / 0.008) * 0.6
    return normiere(x, 0.85)


def schuss():
    """Musketenschuss: Knall (sehr kurzer, lauter Rauschstoß), tiefes Wummern der Pulverladung, Nachhall über das Land."""
    n = int(2.6 * RATE)
    t = np.arange(n) / RATE
    knall = rauschen(n) * np.exp(-t / 0.012) * 3.0
    wumm = tief(rauschen(n), 180, 4) * np.exp(-t / 0.18) * 6.0
    hall = band(rauschen(n), 150, 3000) * np.exp(-t / 0.7) * 0.35 * np.clip(t / 0.06, 0, 1)
    return normiere(tief(knall, 9000) + wumm + hall, 0.95)


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
    schreibe("glocke_gross", glocke(196.0, 9.0))     # G3: Glocke von St. Marien
    schreibe("glocke_klein", glocke(392.0, 5.0))     # G4: Kapellenglocke
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
