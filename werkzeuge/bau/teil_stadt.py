# ---------- Festungsstadt und Hafendorf Drachenstein nach dem Grundriss ----------
# Wird aus teil_drachenstein.py ausgeführt (PD = plan_drachenstein, W = Planpunkt → Welt, Mauer-Bausteine).
# Unten in der Ebene: die Stadt mit Fachwerkhäusern, St. Marien und dem Marktplatz hinter der Stadtmauer mit dem
# Torhaus West; daneben der Drachenhafen mit Kaimauern, Hafenmauer, Speicher und Koggen. Die Hafenpforte verbindet
# Stadt und Hafen. Die Hafeneinfahrt ist offen zum Meer; das Hafentor in der Ringmauer ist ein Wassertor, durch das
# ein Kanal bis an die Mauer führt; hinter dem Fallgitter geht es in den Untergrundhafen. Von der Molenpforte am Speicherkai geht die Mole ab.
# Die Häuser zeichnet szenen/welt/stadthaeuser.gd; die Hausformen (Breite, Tiefe) stehen dort.
import re

E("Script", "res://szenen/welt/stadthaeuser.gd", "27_stadthaeuser")
E("Script", "res://szenen/welt/ausstattung.gd", "29_ausstattung")
HAUSFORMEN = [(float(b), float(t), int(g)) for b, t, g in re.findall(
    r"\[(\d+\.\d+), (\d+\.\d+), (\d), \d, (?:true|false), \d, \d\]",
    (REPO / "szenen" / "welt" / "stadthaeuser.gd").read_text(encoding="utf-8"))]
assert len(HAUSFORMEN) == 24, len(HAUSFORMEN)
VORKRAGUNG = 0.35
KAI_OBEN = PD.H_HAFEN

ST = DS + "/Stadt"
N("Stadt", "Node3D", DS)
HF = DS + "/Drachenhafen"
N("Drachenhafen", "Node3D", DS)

STRASSEN = [WL(s) for s in PD.STRASSEN]
STRASSE_HALB = 2.4      # die Gassen sind eng
MARKT = WL(PD.MARKTPLATZ)
STADT_UMRISS = WL(PD.STADT)
MITTE_STADT = W((400, 540))

# --- Stadtmauer mit der Hafenpforte (in die Stadt kommt man vom Burgweg durch das Burgstraßentor) ---
SM = PD.STADTMAUER
mauerring("Stadtmauer", ST, WL(SM), 8.0, dicke=3.0, mitte=MITTE_STADT, strassen=STRASSEN, torname="Hafenpforte")
_st = []
for pp in [(240, 600), (330, 665), (420, 674), (600, 664)]:
    x, z = W(pp)
    _st += [x, z, H(x, z) - 4, H(x, z) + 11, 4.5, 0, 0]
N("StadtmauerTuerme", "Node3D", ST, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_st)})""")

# --- Drachenhafen ---
BECKEN = WL(PD.HAFENBECKEN)
def kaimauer(name, punkte, offen=()):
    for i, (a, b) in enumerate(zip(punkte, punkte[1:] + punkte[:1])):
        if i in offen:
            continue
        # 4 m dick: das Gelände fällt an der Kante über ein Rasterfeld (2,5 m) ab, die Mauer deckt den Abhang ganz ab;
        # oben bündig mit dem Kai, so geht man vom Kai auf die Stege
        mauerring(f"{name}{i}", HF, [a, b], 0.0, dicke=4.0, zinnen=False, mat="Material_kai")
# Kaimauern ums Becken; offen bleiben die Hafeneinfahrt und der Kanal zum Wassertor
kaimauer("KaiBecken", BECKEN, offen=(PD.HAFENEINFAHRT, 1))
kaimauer("KaiNord", WL([(700, 444), (744, 447.5)]) + WL([(764, 449.2), (790, 452)]), offen=(1, 3))
for k, (a_, b_) in enumerate([((744, 448), (744, 411)), ((764, 449), (764, 411))]):
    mauerring(f"KaiKanal{k}", HF, WL([a_, b_]), 0.9, dicke=4.0, zinnen=False, mat="Material_kai")
HM = PD.HAFENMAUER_OST
mauerring("Hafenmauer", HF, WL(HM), 8.0, dicke=3.0, mitte=W((720, 520)))
mauerring("Speicherkai", HF, WL([(640, 642), (770, 646), (790, 630)]), 6.0, dicke=3.0, mitte=W((720, 520)),
         tore=tor_an([(640, 642), (770, 646), (790, 630)], PD.MOLENPFORTE, 5.0, "Molenpforte"))
_ht = []
# Zwei Rundtürme an der Hafeneinfahrt: am Ende der Hafenmauer und am Ende des Speicherkais
for pp, r in [((792, 628), 6.0), ((834, 540), 6.0)]:
    x, z = W(pp)
    _ht += [x, z, -28.0, KAI_OBEN + 12, r, 0, 0]
N("HafenTuerme", "Node3D", HF, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_ht)})""")
sx, sz = W(PD.SPEICHER[0])
steinbau("Speicher", HF, sx, sz, PD.SPEICHER[1] * M, PD.SPEICHER[2] * M, 9, gier=0, mat="Material_holz",
         dach="Material_dach", boden=KAI_OBEN, art=2)
schild("SchildSpeicher", HF, sx, KAI_OBEN + 18, sz, "Speicher", 40)

# --- Hinter dem Wassertor: dunkle Tiefe (der Gang zum Untergrundhafen, kommt mit Höhlen im Gelände) ---
S('''[sub_resource type="StandardMaterial3D" id="Material_dunkel"]
albedo_color = Color(0.015, 0.015, 0.02, 1)
roughness = 1.0''')
_wt = W(PD.TORE["Hafentor"])
box("WassertorTiefe", HF, round(_wt[0] - 5.0, 2), -14.5, round(_wt[1], 2), 6.0, 11.0, 11.0, "Material_dunkel")
schild("SchildWassertor", HF, round(_wt[0] + 4, 2), KAI_OBEN + 4, round(_wt[1] + 7, 2), "Zum Untergrundhafen", 40)
_hm = W((720, 520))
schild("SchildHafen", HF, _hm[0], KAI_OBEN + 8, _hm[1], "Drachenhafen", 64)
# Koggen im Becken (szenen/welt/ausstattung.gd, Art 5; die Wasserlinie liegt bei -20)
SCHIFFE = [(5, *(lambda p: (p[0], -20.0, p[1]))(W(pp)), g) for pp, g in
           [((660, 480), 80), ((745, 478), 95), ((700, 560), 85), ((770, 545), 60)]]
# Draußen in der Bucht: Koggen unter vollem Segel (Art 6)
SCHIFFE += [(6, *(lambda p: (p[0], -20.0, p[1]))(W(pp)), g) for pp, g in [((960, 560), 150), ((1080, 640), 200)]]
# Ruderboote an den Stegen (Art 7)
SCHIFFE += [(7, *(lambda p: (p[0], -20.0, p[1]))(W(pp)), g) for pp, g in
            [((692, 468), 2), ((709, 458), -4), ((640, 515), 92), ((645, 532), 86)]]
# Tretradkräne (Art 8): auf dem Ostkai an der Hafenmauer und am Ende des Nordkais, der Ausleger über dem Wasser
SCHIFFE += [(8, *(lambda p: (p[0], KAI_OBEN + 0.2, p[1]))(W(pp)), g) for pp, g in [((820, 482), 180), ((784, 438), -90)]]

# --- Landungsstege aus dem Steg-Fotoscan (modelle/hafen/): je Abschnitt 2,9 m, Deck 2,62 m über dem Ursprung ---
STEG = "res://modelle/hafen/modular_wooden_pier/modular_wooden_pier.gltf"
_steg = []
for start, richtung, abschnitte in [((700, 447), (1, 0), 5), ((628, 525), (0, -1), 4)]:
    sx_, sz_ = W(start)
    dx_, dz_ = richtung                  # Weltrichtung ins Becken
    g_ = math.degrees(math.atan2(dx_, dz_))
    qx_, qz_ = math.cos(math.radians(g_)), -math.sin(math.radians(g_))   # lokal x (quer)
    for k in range(abschnitte):
        ox = sx_ + dx_ * (k * 2.9 + 0.32) - qx_ * 0.98
        oz = sz_ + dz_ * (k * 2.9 + 0.32) - qz_ * 0.98
        for steg_teil in (3, 0):         # Deck und Pfähle
            _steg.append((steg_teil, round(ox, 2), round(KAI_OBEN + 0.2 - 2.62, 2), round(oz, 2), round(g_, 1), 0, 1))
# Hafenkram: Fässer und Kisten (Fotoscans) in Gruppen am Nordkai und am Ostkai
random.seed(77)
for pp in [(645, 419), (675, 419), (705, 420), (728, 421), (815, 515)]:      # an der Mauer, abseits der Laufwege
    gx_, gz_ = W(pp)
    for _ in range(random.randint(3, 6)):
        art_ = random.choice([5, 5, 6, 7, 7])
        px_, pz_ = gx_ + random.uniform(-1.6, 1.6), gz_ + random.uniform(-1.6, 1.6)
        _steg.append((art_, round(px_, 2), round(KAI_OBEN + 0.2, 2), round(pz_, 2), round(random.uniform(0, 360), 1), 0, 1))
N("Hafenausstattung", "Node3D", HF, f"""script = ExtResource("30_felsen")
modelle = PackedStringArray("{STEG}#0", "{STEG}#1", "{STEG}#2", "{STEG}#3", "{STEG}#4", "res://modelle/hafen/barrel_03/barrel_03.gltf", "res://modelle/hafen/wooden_crate_01/wooden_crate_01.gltf#1", "res://modelle/hafen/wooden_crate_02/wooden_crate_02.gltf#0")
stuecke = PackedFloat32Array({", ".join(f"{v:.6g}" for st_ in _steg for v in st_)})
sichtweite = 400.0""")

# --- Marktplatz mit Brunnen und Ständen ---
MK = DS + "/Marktplatz"
N("Marktplatz", "Node3D", DS)
MARKT_MITTE = W(PD.MARKT_MITTE)
mx, mz = MARKT_MITTE
mb = H(mx, mz)
zyl("Brunnen", MK, mx, round(mb + 0.4, 2), mz, 2.8, 1.2, "Material_hell", 14)
zyl("BrunnenWasser", MK, mx, round(mb + 0.95, 2), mz, 2.4, 0.1, "Material_wasser_becken", 14, False)
zyl("BrunnenSaeule", MK, mx, round(mb + 2.2, 2), mz, 0.4, 3.0, "Material_hell", 10)
schild("SchildMarkt", MK, mx, round(mb + 7, 2), mz, "Marktplatz", 64)
# Stände in zwei Reihen an den Längsseiten; die ersten sechs haben Händler
_STAND_PLAN = [(472, 489), (536, 489), (472, 547), (536, 547), (494, 489), (514, 547)]
STAENDE = [W(p) for p in _STAND_PLAN]
STAENDE_MEHR = [W((px, py)) for py in (489, 547) for px in range(472, 550, 21)
                if all(math.dist((px, py), q) > 8 for q in _STAND_PLAN)]

# --- St. Marien ---
kx, kz = W(PD.ST_MARIEN[0])
steinbau("StMarien", ST, kx, kz, PD.ST_MARIEN[1] * M, PD.ST_MARIEN[2] * M, 15, gier=0, mat="Material_hell",
         dachhoehe=10, art=1)
tx, tz = W(PD.ST_MARIEN_TURM)
tb = H(tx, tz)
N("StMarienTurm", "Node3D", ST, f"""script = ExtResource("28_burgbau")
torbauten = PackedFloat32Array({_zahlen([tx, tz, 1, 0, tb - 2, tb + 30, 8, 8, 1, 2.4])})
stein = \"hell\"""")
schild("SchildKirche", ST, tx, round(tb + 52, 2), tz, "St. Marien", 56)

# --- Bürgerhäuser in Zeilen entlang der Gassen und um den Markt ---
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

def pr(bau, rand=1.0):
    """Sperrfläche für einen Bau aus dem Plan ((Mitte), Länge entlang Plan-x, Breite, Drehung)."""
    (pp, laenge, breite, dreh) = bau
    x, z = W(pp)
    return rechteck(x, z, breite * M + 2 * rand, laenge * M + 2 * rand, -dreh)

def abstand_vieleck(p, poly):
    return 0.0 if im_vieleck(p, poly) else min(abstand_linie([a, b], *p) for a, b in zip(poly, poly[1:] + poly[:1]))

SPERR = [MARKT, pr(PD.ST_MARIEN, 2.0), pr((PD.ST_MARIEN_TURM, 18, 18, 0))]
MAUERN = [WL(SM), WL(PD.RINGMAUER)]

def bauplatz_frei(ecken4, haeuser_ecken, halb):
    if not all(im_vieleck(p, STADT_UMRISS) for p in ecken4):
        return False
    # auch Punkte entlang der Wände prüfen: sonst könnte eine Gasse mitten durch ein Haus laufen
    rand = [(a[0] + (b[0] - a[0]) * k / 4, a[1] + (b[1] - a[1]) * k / 4)
            for a, b in zip(ecken4, ecken4[1:] + ecken4[:1]) for k in range(1, 4)]
    if any(min(abstand_linie(s, x, z) for s in STRASSEN) < STRASSE_HALB - 0.3 for x, z in rand + ecken4):
        return False
    for x, z in ecken4:
        if min(abstand_linie(m, x, z) for m in MAUERN) < 3.5:
            return False
    if any(ueberlappen(ecken4, r) for r in SPERR):
        return False
    return not any(ueberlappen(ecken4, r) for r in haeuser_ecken)

random.seed(1754)
HAEUSER = []          # (x, y, z, gier, Abstand zur Straße, Form) – für teil_stadtleben.py
_haus_ecken = []
ZEILEN = [(s, STRASSE_HALB, (-1, 1)) for s in STRASSEN]
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
                    tx_, tz_ = hx - nx * (t / 2), hz - nz * (t / 2)
                    hoehen = [H(x, z) for x, z in ecken4]
                    y = H(tx_, tz_)
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

# --- Ausstattung: Stände, Kram, Koggen ---
AUSSTATTUNG = [(3, x, H(x, z), z, 0) for x, z in STAENDE + STAENDE_MEHR] + SCHIFFE
random.seed(912)
# Nordkai zwischen Ringmauer und Becken: Fässer, Kisten, Säcke in Gruppen, dazu Karren
for px in range(630, 720, 15):
    gx, gz = W((px, random.uniform(414, 418)))
    for k in range(random.randint(2, 4)):
        art = random.choice((0, 0, 1, 1, 2))
        AUSSTATTUNG.append((art, gx + random.uniform(-1.2, 1.2), KAI_OBEN, gz + random.uniform(-1.6, 1.6), random.uniform(0, 360)))
for pp in [(652, 417), (700, 417)]:
    x, z = W(pp)
    AUSSTATTUNG.append((4, x - 2.5, KAI_OBEN, z, random.uniform(-15, 15)))
for x, z in STAENDE_MEHR:
    # neben dem Stand in der Reihe, nicht auf den Wegen davor und dahinter
    for seite in (-1, 1):
        px_, pz_ = x + random.uniform(-0.6, 0.6), z + seite * random.uniform(2.4, 2.8)
        AUSSTATTUNG.append((random.choice((0, 1, 2)), px_, H(px_, pz_), pz_, random.uniform(0, 360)))
N("Ausstattung", "Node3D", ST, "script = ExtResource(\"29_ausstattung\")\nstuecke = PackedFloat32Array("
  + ", ".join(f"{v:.5g}" for st_ in AUSSTATTUNG for v in st_) + ")")

if os.environ.get("BAU_KARTE"):
    # Lageplan zum Prüfen: BAU_NUR_PRUEFEN=1 BAU_KARTE=datei.png python3 werkzeuge/bau/region_drachenstein.py
    from PIL import Image, ImageDraw
    x0, z0, m = -160, -300, 1.6
    bild = Image.new("RGB", (int(420 * m), int(640 * m)), (70, 90, 60))
    zeichnung = ImageDraw.Draw(bild)
    P = lambda p: ((p[0] - x0) * m, (p[1] - z0) * m)
    for j in range(0, bild.height, 3):
        for i in range(0, bild.width, 3):
            h = H(x0 + i / m, z0 + j / m)
            if h < -19.5:
                farbe = (40, 70, 120)
            else:
                t = max(0, min(1, (h + 20) / 30)); farbe = (int(60 + 150 * t), int(80 + 130 * t), int(50 + 130 * t))
            zeichnung.rectangle([i, j, i + 2, j + 2], fill=farbe)
    for r in SPERR:
        zeichnung.polygon([P(p) for p in r], outline=(200, 200, 0))
    for s in STRASSEN + [WL(w) for w in PD.BURGWEGE] + [WL(PD.KAIWEG)]:
        zeichnung.line([P(p) for p in s], fill=(150, 130, 100), width=int(STRASSE_HALB * 2 * m))
    for e in _haus_ecken:
        zeichnung.polygon([P(p) for p in e], fill=(190, 90, 70), outline=(60, 30, 20))
    for linie in [WL(SM), WL(PD.RINGMAUER + PD.RINGMAUER[:1]), WL(PD.VORBURG + PD.VORBURG[:1]), WL(PD.BURGHOF2 + PD.BURGHOF2[:1]),
                  WL(PD.BURGHOF3), WL(PD.ZWINGER_KERNBURG), WL(PD.KERNBURG + PD.KERNBURG[:1]), BECKEN + BECKEN[:1], WL(HM)]:
        zeichnung.line([P(p) for p in linie], fill=(230, 230, 230), width=3)
    zeichnung.rectangle([P((-31, -31)), P((31, 31))], outline=(255, 0, 0), width=2)
    bild.save(os.environ["BAU_KARTE"])
