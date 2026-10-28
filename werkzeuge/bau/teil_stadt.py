# ---------- Die Stadt Drachenstein nach dem Grundriss: Marktviertel, Hafen, Vorburg, Löwenward ----------
# Wird aus teil_drachenstein.py ausgeführt (PD = plan_drachenstein, W = Planpunkt → Welt, Mauer-Bausteine).
#   I   Untere Burg (Marktviertel): langer Marktplatz (8) vom Treppentor hinab zum Hafen, Kirche St. Georg (22),
#       Rathaus (24), Schmiedehaus (27), Badehaus (29), Mühle (30), Bürgerhäuser (25) in Zeilen an den Straßen
#   V   Hafenbezirk (Drachenkai): Hafenbecken (31) mit Kaimauern, Kanal (32), Docklager (33), Schiffstor (34),
#       Zollhaus (35)
#   IV  Vorburg: Gärten (36, 37) zwischen innerer Vorburgmauer und Löwenward
#   V   Löwenward: äußerer Artillerie-Ring mit Rundtürmen und den Toren nach Gravemarch, zum Küstenweg (Westtor)
#       und zur Nordstraße (Südöstliches Tor, 19)
# Die Häuser zeichnet szenen/welt/stadthaeuser.gd; die Hausformen (Breite, Tiefe) stehen dort.
import re

E("Script", "res://szenen/welt/stadthaeuser.gd", "27_stadthaeuser")
HAUSFORMEN = [(float(b), float(t), int(g)) for b, t, g in re.findall(
    r"\[(\d+\.\d+), (\d+\.\d+), (\d), \d, (?:true|false), \d, \d\]",
    (REPO / "szenen" / "welt" / "stadthaeuser.gd").read_text(encoding="utf-8"))]
assert len(HAUSFORMEN) == 24, len(HAUSFORMEN)
VORKRAGUNG = 0.35
KAI_OBEN = PD.H_HAFEN

ST = DS + "/Stadt"
N("Stadt", "Node3D", DS)

# --- Straßen ---
STRASSEN = [WL(s) for s in PD.STRASSEN]
# Landstraßen vor den Toren (für die Tore in der Löwenward)
AUSSENWEGE = [[(-72.6, 181.3), (-120, 215), (-220, 170)], [(474.2, -296.6), (430, -380)], [(502.4, 425.0), (500, 520)]]
STRASSE_HALB = 3.6
MARKT = WL(PD.MARKTPLATZ)
STADT_UMRISS = WL(PD.LOEWENWARD + [(520, 905), (612, 905)] + PD.LOEWENWARD_OST)
ring = STADT_UMRISS

# --- Löwenward: äußerer Ring (V) ---
LW = WL(PD.LOEWENWARD)
LWO = WL(PD.LOEWENWARD_OST)
MITTE_STADT = W((560, 560))
mauerring("Loewenward", ST, LW, 13.0, dicke=4.0, mitte=MITTE_STADT, turm_r=7.0, turm_dach=False,
         strassen=AUSSENWEGE, torbreite=7.0, torname="Tor nach Gravemarch",
         tore={7: (0.1, 7.0, "Westtor (Küstenweg)")})
mauerring("LoewenwardOst", ST, LWO, 13.0, dicke=4.0, mitte=MITTE_STADT, turm_r=7.0, turm_dach=False,
         tore={1: (0.9, 7.0, "Südöstliches Tor (Nordstraße)")})
# Vorburg (IV): innere Mauer zwischen Gärten und Marktviertel, Mauer um den Garten 36 mit dem Vorburgtor (11)
mauerring("VorburgMauer", ST, WL(PD.VORBURG_INNEN), 8.0, dicke=3.0, mitte=MITTE_STADT, turm_r=4.5,
         strassen=STRASSEN, torname="")
mauerring("VorburgGarten", ST, WL(PD.VORBURG_GARTEN), 8.0, dicke=3.0, mitte=W((380, 330)), turm_r=4.5,
         tore={1: (0.15, 6.0, "Vorburgtor")})
# Mauer zwischen Burg und Marktviertel
mauerring("StadtmauerNord", ST, WL(PD.STADTMAUER_NORD), 7.0, dicke=3.0, mitte=MITTE_STADT, turm_r=3.5,
         strassen=STRASSEN)
mauerring("StadtmauerNordOst", ST, WL(PD.STADTMAUER_NORD_OST), 7.0, dicke=3.0, mitte=MITTE_STADT, turm_r=3.5,
         strassen=STRASSEN)

# --- V Hafenbezirk ---
HF = DS + "/Drachenkai"
N("Drachenkai", "Node3D", DS)
BECKEN = WL(PD.HAFENBECKEN)
KANAL = WL(PD.KANALBECKEN)
def kaimauer(name, punkte, offen=()):
    for i, (a, b) in enumerate(zip(punkte, punkte[1:] + punkte[:1])):
        if i in offen:
            continue
        mauerring(f"{name}{i}", HF, [a, b], 0.9, dicke=2.0, zinnen=False, mat="Material_kai")
kaimauer("KaiBecken", BECKEN, offen=(1, 3))
kaimauer("KaiKanal", KANAL, offen=(3,))
# Ostkai des Beckens mit der Öffnung zum Kanal
b1a, b1b = BECKEN[1], BECKEN[2]
for k, (t0, t1) in enumerate([(0.0, 0.36), (0.8, 1.0)]):
    a = (b1a[0] + (b1b[0] - b1a[0]) * t0, b1a[1] + (b1b[1] - b1a[1]) * t0)
    b = (b1a[0] + (b1b[0] - b1a[0]) * t1, b1a[1] + (b1b[1] - b1a[1]) * t1)
    mauerring(f"KaiOst{k}", HF, [a, b], 0.9, dicke=2.0, zinnen=False, mat="Material_kai")
# Schiffstor (34) mit zwei Türmen, Zollhaus (35)
for k, pp in enumerate([(536, 912), (594, 912)]):
    x, z = W(pp)
    zyl(f"Schiffstorturm{k}", HF, x, KAI_OBEN + 5, z, 6.0, 30, "Material_mauer", 16)
    turmdach(f"Schiffstorturm{k}Dach", HF, x, KAI_OBEN + 20, z, 6.8, 8)
schild("SchildSchiffstor", HF, *(lambda p: (p[0], KAI_OBEN + 32, p[1]))(W((565, 912))), "Schiffstor", 48)
zx, zz = W(PD.ZOLLHAUS)
zyl("Zollhaus", HF, zx, KAI_OBEN + 6, zz, 7.5, 22, "Material_mauer", 16)
turmdach("ZollhausDach", HF, zx, KAI_OBEN + 17, zz, 8.3, 7)
schild("SchildZoll", HF, zx, KAI_OBEN + 27, zz, "Zollhaus", 44)
# Docklager (33) östlich des Beckens und am Westkai
for k, (pp, laenge, breite, g) in enumerate([((660, 745), 34, 12, 85), ((700, 760), 30, 11, 5), ((470, 790), 30, 12, 0),
                                             ((480, 880), 22, 12, 30)]):
    x, z = W(pp)
    steinbau(f"Docklager{k}", HF, x, z, laenge, breite, 10, gier=g, mat="Material_holz", dach="Material_dach")
schild("SchildDocklager", HF, *(lambda p: (p[0], KAI_OBEN + 16, p[1]))(W((660, 745))), "Docklager", 40)
# Schiffe im Becken
for k, (pp, g) in enumerate([((545, 770), 92), ((585, 820), 85), ((560, 870), 95), ((650, 820), 0)]):
    x, z = W(pp)
    box(f"Schiff{k}", HF, x, -19.6, z, 18, 3.2, 5.5, "Material_holz", gier=g)
    zyl(f"Mast{k}", HF, x, -9, z, 0.3, 18, "Material_holz", 6, False)
    box(f"Rahe{k}", HF, x, -4, z, 0.3, 0.3, 9, "Material_holz", gier=g, kollision=False)
schild("SchildKai", HF, *(lambda p: (p[0], KAI_OBEN + 6, p[1]))(W((565, 760))), "Drachenkai", 64)

# --- Markt (8), Kirche, Rathaus und weitere Bauten des Marktviertels ---
MK = DS + "/Marktplatz"
N("Marktplatz", "Node3D", DS)
MARKT_MITTE = W((550, 597))
mx, mz = MARKT_MITTE
mb = H(mx, mz)
zyl("Brunnen", MK, mx, round(mb + 0.4, 2), mz, 2.8, 1.2, "Material_hell", 14)
zyl("BrunnenWasser", MK, mx, round(mb + 0.95, 2), mz, 2.4, 0.1, "Material_wasser_becken", 14, False)
zyl("BrunnenSaeule", MK, mx, round(mb + 2.2, 2), mz, 0.4, 3.0, "Material_hell", 10)
STAENDE = [W((515, 540)), W((585, 545)), W((515, 640)), W((585, 650)), W((520, 590)), W((580, 600))]
for i, (x, z) in enumerate(STAENDE):
    y = H(x, z)
    box(f"Stand{i+1}", MK, round(x, 2), round(y + 0.5, 2), round(z, 2), 3, 1.0, 2, "Material_holz")
    box(f"StandDach{i+1}", MK, round(x, 2), round(y + 2.4, 2), round(z, 2), 3.4, 0.15, 2.4, "Material_stoff", kollision=False)
schild("SchildMarkt", MK, mx, round(mb + 7, 2), mz, "Marktplatz", 64)

kx, kz = W(PD.KIRCHE[0])
steinbau("KircheStGeorg", ST, kx, kz, 66, 30, 22, gier=90, mat="Material_hell", dachhoehe=16)
tx, tz = W(PD.KIRCHTURM)
tb = H(tx, tz)
box("Kirchturm", ST, tx, round(tb + 20, 2), tz, 10, 44, 10, "Material_hell")
turmdach("KirchturmHelm", ST, tx, tb + 42, tz, 7.5, 22, kanten=8)
schild("SchildKirche", ST, tx, round(tb + 68, 2), tz, "Kirche St. Georg", 56)
for name, (pp, laenge, breite), hoehe in [("Rathaus", PD.RATHAUS, 16), ("Badehaus", PD.BADEHAUS, 9), ("Muehle", PD.MUEHLE, 11),
                                          ("Schmiedehaus", PD.SCHMIEDE, 8)]:
    x, z = W(pp)
    oben = steinbau(name, ST, x, z, laenge * 1.117, breite * 1.117, hoehe, gier=90 if laenge > breite else 0,
                    mat="Material_hell" if name == "Rathaus" else "Material_mauer", dach="Material_dach")
    schild(f"Schild{name}", ST, round(x, 2), round(oben + 9, 2), round(z, 2),
           {"Muehle": "Mühle", "Schmiedehaus": "Schmiedehaus"}.get(name, name), 48)

# --- Bürgerhäuser (25) in Zeilen entlang der Straßen und um den Markt ---
def rechteck(x, z, b, t, gier):
    a = math.radians(gier); c, s = math.cos(a), math.sin(a)
    return [(x + c * px + s * pz, z - s * px + c * pz) for px, pz in [(-b / 2, -t / 2), (b / 2, -t / 2), (b / 2, t / 2), (-b / 2, t / 2)]]

def ueberlappen(r1, r2):
    for poly in (r1, r2):
        for i in range(len(poly)):
            (x1, z1), (x2, z2) = poly[i], poly[(i + 1) % len(poly)]
            nx, nz = z2 - z1, x1 - x2
            p1 = [nx * x + nz * z for x, z in r1]
            p2 = [nx * x + nz * z for x, z in r2]
            if max(p1) <= min(p2) or max(p2) <= min(p1):
                return False
    return True

def im_vieleck(p, poly):
    x, z = p; innen = False
    for (x1, z1), (x2, z2) in zip(poly, poly[1:] + poly[:1]):
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
            innen = not innen
    return innen

def pr(pp, laenge, breite, g=0):
    x, z = W(pp)
    return rechteck(x, z, breite * 1.117, laenge * 1.117, g)

def konvexe_teile(poly):
    """Ein Vieleck als Fächer aus Dreiecken (für die Überlappungsprüfung, die nur konvexe Formen kann)."""
    return [[poly[0], poly[i], poly[i + 1]] for i in range(1, len(poly) - 1)]

SPERR = [MARKT] + [t for z in (PD.AEUSSERER_ZWINGER, PD.OSTTERRASSE, PD.HAFENBECKEN, PD.KANALBECKEN, PD.DOCK_OST, PD.KAI_WEST)
                   for t in konvexe_teile(WL(z))] + [
    pr(PD.KIRCHE[0], 70, 36, 90), pr(PD.KIRCHTURM, 12, 12), pr(PD.RATHAUS[0], 40, 28, 90), pr(PD.BADEHAUS[0], 30, 24, 90),
    pr(PD.MUEHLE[0], 24, 24), pr(PD.SCHMIEDE[0], 22, 20, 90), pr((565, 912), 90, 30), pr((470, 790), 30, 26),
    pr((480, 880), 26, 26), pr(PD.ZOLLHAUS, 20, 20)]
# Gärten der Vorburg (zwischen innerer Vorburgmauer und Löwenward) und Garten 36 bleiben frei
VORBURG_GAERTEN = WL([(398, 385), (300, 510), (220, 690), (362, 833), (165, 765), (100, 632), (210, 437), (325, 300)])
GARTEN36 = WL([(325, 300), (400, 268), (418, 195), (358, 190), (320, 255)])
FREI_FLAECHEN = [VORBURG_GAERTEN, GARTEN36]
MAUERN = [LW, LWO, WL(PD.VORBURG_INNEN), WL(PD.STADTMAUER_NORD), WL(PD.STADTMAUER_NORD_OST),
          WL(PD.AEUSSERER_ZWINGER), WL(PD.OSTTERRASSE)]

def abstand_vieleck(p, poly):
    return 0.0 if im_vieleck(p, poly) else min(abstand_linie([a, b], *p) for a, b in zip(poly, poly[1:] + poly[:1]))

def bauplatz_frei(ecken4, haeuser_ecken, halb):
    if not all(im_vieleck(p, STADT_UMRISS) for p in ecken4):
        return False
    if any(im_vieleck(p, f) for f in FREI_FLAECHEN for p in ecken4):
        return False
    # auch Punkte entlang der Wände prüfen: sonst könnte eine Straße mitten durch ein Haus laufen
    rand = [(a[0] + (b[0] - a[0]) * k / 4, a[1] + (b[1] - a[1]) * k / 4)
            for a, b in zip(ecken4, ecken4[1:] + ecken4[:1]) for k in range(1, 4)]
    if any(min(abstand_linie(s, x, z) for s in STRASSEN) < STRASSE_HALB - 0.3 for x, z in rand):
        return False
    for x, z in ecken4:
        if min(abstand_linie(m, x, z) for m in MAUERN) < 3.5:
            return False
        if min(abstand_linie(s, x, z) for s in STRASSEN) < STRASSE_HALB - 0.3:
            return False
        if min(abstand_vieleck((x, z), b) for b in (BECKEN, KANAL)) < 12:
            return False
    if any(ueberlappen(ecken4, r) for r in SPERR):
        return False
    return not any(ueberlappen(ecken4, r) for r in haeuser_ecken)

random.seed(1754)
HAEUSER = []          # (x, y, z, gier, Abstand zur Straße, Form) – für teil_stadtleben.py
_haus_ecken = []
# Zeilen: (Linienzug, halbe Breite bis zur Hauswand, Seiten)
ZEILEN = [(s, STRASSE_HALB, (-1, 1)) for s in STRASSEN]
# Häuser rund um den Markt, die Front zum Platz
markt_ring = MARKT + [MARKT[0]]
ZEILEN += [([a, b], 0.6, (1, -1)) for a, b in zip(markt_ring, markt_ring[1:])]
for linie, halb, seiten in ZEILEN:
    for (x1, z1), (x2, z2) in zip(linie, linie[1:]):
        dx, dz = x2 - x1, z2 - z1
        laenge = math.hypot(dx, dz)
        if laenge < 4:
            continue
        ux, uz = dx / laenge, dz / laenge
        for seite in seiten:
            nx, nz = -uz * seite, ux * seite        # von der Straße weg
            s = 2.0
            while s < laenge - 2.0:
                form = random.randrange(24)
                b, t, _ = HAUSFORMEN[form]
                if s + b / 2 > laenge - 1.0:
                    break
                d = halb + t / 2 + VORKRAGUNG * 2
                hx, hz = x1 + ux * (s + b / 2) + nx * d, z1 + uz * (s + b / 2) + nz * d
                gier = math.degrees(math.atan2(-nx, -nz))   # Vorderseite (+z lokal) zur Straße
                ecken4 = rechteck(hx, hz, b + 0.1, t + 2 * VORKRAGUNG, gier)
                if bauplatz_frei(ecken4, _haus_ecken, halb):
                    tx, tz = hx - nx * (t / 2), hz - nz * (t / 2)
                    hoehen = [H(x, z) for x, z in ecken4]
                    y = H(tx, tz)
                    if max(hoehen) - y < 3.5:
                        HAEUSER.append((round(hx, 2), round(y, 2), round(hz, 2), round(gier, 1), halb, form))
                        _haus_ecken.append(ecken4)
                        s += b + random.choice([0.0, 0.0, 0.0, 0.4, 1.5])
                        continue
                s += 1.5

N("Stadthaeuser", "Node3D", DS, "script = ExtResource(\"27_stadthaeuser\")\n"
  + "haeuser = PackedVector4Array(" + ", ".join(f"{x:.5g}, {y:.5g}, {z:.5g}, {g:.4g}" for x, y, z, g, _, _ in HAEUSER) + ")\n"
  + "formen = PackedInt32Array(" + ", ".join(str(f) for *_, f in HAEUSER) + ")")
print("Stadthäuser:", len(HAEUSER))

if os.environ.get("BAU_KARTE"):
    # Lageplan zum Prüfen: BAU_NUR_PRUEFEN=1 BAU_KARTE=datei.png python3 werkzeuge/bau/region_drachenstein.py
    from PIL import Image, ImageDraw
    x0, z0, m = -340, -420, 1.0
    bild = Image.new("RGB", (int(1060 * m), int(980 * m)), (70, 90, 60))
    zeichnung = ImageDraw.Draw(bild)
    P = lambda p: ((p[0] - x0) * m, (p[1] - z0) * m)
    for j in range(0, bild.height, 3):
        for i in range(0, bild.width, 3):
            h = H(x0 + i / m, z0 + j / m)
            if h < -19.5:
                farbe = (40, 70, 120)
            else:
                t = max(0, min(1, (h + 20) / 55)); farbe = (int(70 + 120 * t), int(90 + 100 * t), int(60 + 100 * t))
            zeichnung.rectangle([i, j, i + 2, j + 2], fill=farbe)
    for r in SPERR + FREI_FLAECHEN:
        zeichnung.polygon([P(p) for p in r], outline=(200, 200, 0))
    for s in STRASSEN:
        zeichnung.line([P(p) for p in s], fill=(150, 130, 100), width=int(STRASSE_HALB * 2 * m))
    for e in _haus_ecken:
        zeichnung.polygon([P(p) for p in e], fill=(190, 90, 70), outline=(60, 30, 20))
    for linie in MAUERN + [WL(PD.URKERN), WL(PD.OBERE_BURG), WL(PD.MITTLERE_BURG), WL(PD.KERNHOF)]:
        zeichnung.line([P(p) for p in linie], fill=(230, 230, 230), width=3)
    bild.save(os.environ["BAU_KARTE"])
