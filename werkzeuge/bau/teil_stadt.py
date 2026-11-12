# ---------- Festungsstadt und Hafendorf Drachenstein nach dem Grundriss ----------
# Wird aus teil_drachenstein.py ausgeführt (PD = plan_drachenstein, W = Planpunkt → Welt, Mauer-Bausteine).
# Die Stadt legt sich im Westen und Süden um die Vorburg: Fachwerkhäuser in Bogenreihen, St. Marien und der Marktplatz,
# die Stadtmauer mit dem Südtor und den Torhäusern im Nordwesten und Südwesten; daneben, offen zur Stadt, der
# Drachenhafen mit Kaimauern, Hafenmauer, Speicher und Koggen. Die Hafeneinfahrt ist offen zum Meer; das Hafentor in der Ringmauer ist ein Wassertor, durch das
# ein Kanal bis an die Mauer führt; hinter dem Fallgitter geht es in den Untergrundhafen. Von der Molenpforte am Speicherkai geht die Mole ab.
# Die Häuser zeichnet szenen/welt/stadthaeuser.gd; die Hausformen (Breite, Tiefe) stehen dort.
import re

E("Script", "res://szenen/welt/stadthaeuser.gd", "27_stadthaeuser")
E("Script", "res://szenen/welt/ausstattung.gd", "29_ausstattung")
HAUSFORMEN = [(float(b), float(t), int(g)) for b, t, g in re.findall(
    r"\[(\d+\.\d+), (\d+\.\d+), (\d), \d, (?:true|false), \d, \d\]",
    (REPO / "szenen" / "welt" / "stadthaeuser.gd").read_text(encoding="utf-8"))]
assert len(HAUSFORMEN) == 32, len(HAUSFORMEN)   # 24 Formen an den Gassen, 8 kleine für die Hinterhöfe
VORKRAGUNG = 0.35
KAI_OBEN = PD.H_HAFEN
KAI_KRONE = KAI_OBEN + 0.04

ST = DS + "/Stadt"
N("Stadt", "Node3D", DS)
HF = DS + "/Drachenhafen"
N("Drachenhafen", "Node3D", DS)

STRASSEN = [WL(s) for s in PD.STRASSEN]
STRASSE_HALB = 2.4      # die Gassen sind eng
MARKT = WL(PD.MARKTPLATZ)
STADT_UMRISS = WL(PD.STADT)
MITTE_STADT = W((400, 540))

# --- Stadtmauer mit dem Südtor (zum Küstenweg); im Nordwesten und Südwesten Torhäuser als Türme über der Mauer ---
SM = PD.STADTMAUER
mauerring("Stadtmauer", ST, WL(SM), 8.0, dicke=3.0, mitte=MITTE_STADT, tore=tor_an(SM, PD.TORE["Südtor"], 5.0, "Südtor"))
# Türme der Stadtmauer: an den Ecken und auf langen Strecken Rundtürme mit Kegeldach, an der Süd- und der Hafenecke
# zwei breite Bastionen mit Zinnen (wie im Referenzbild). Am Südtor und an den Torhäusern bleibt die Mauer frei.
_st = []
_turmorte = []
for i_, (a_, b_) in enumerate(zip(SM, SM[1:])):
    if i_ > 0:
        _turmorte.append(a_)
    laenge_ = math.dist(a_, b_)
    for k_ in range(1, int(laenge_ // 70) + 1):
        t_ = k_ / (int(laenge_ // 70) + 1)
        _turmorte.append((a_[0] + (b_[0] - a_[0]) * t_, a_[1] + (b_[1] - a_[1]) * t_))
for pp in _turmorte:
    if math.dist(pp, PD.TORE["Südtor"]) < 18 or any(math.dist(pp, PD.g3(q[0])) < 25 for q in (PD.G3.TORHAUS_NW, PD.G3.TORHAUS_SW)):
        continue
    x, z = W(pp)
    werte_ = [H(x + dx, z + dz) for dx in (-5, 0, 5) for dz in (-5, 0, 5)]
    if pp in [PD.g3((190, 505)), (600, 664)]:
        _st += [x, z, min(werte_) - 4, max(werte_) + 10, 7.0, 0, 0]
    else:
        _st += [x, z, min(werte_) - 4, max(werte_) + 12, 4.5, 1, 7.5]
N("StadtmauerTuerme", "Node3D", ST, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_st)})""")

# --- Drachenhafen ---
BECKEN = WL(PD.HAFENBECKEN)
def kaimauer(name, punkte, offen=()):
    for i, (a, b) in enumerate(zip(punkte, punkte[1:] + punkte[:1])):
        if i in offen:
            continue
        # 4 m dick: das Gelände fällt an der Kante über ein Rasterfeld (2,5 m) ab, die Mauer deckt den Abhang ganz ab;
        # oben 4 cm über dem Kai (das Gelände dort liegt genau auf Kaihöhe): kein Flimmern, und man geht ohne Kante auf die Stege
        mauerring(f"{name}{i}", HF, [a, b], 0.0, dicke=4.0, zinnen=False, mat="Material_kai", oben_fest=KAI_KRONE)
# Kaimauern ums Becken; offen bleiben die Hafeneinfahrt und der Kanal zum Wassertor
kaimauer("KaiBecken", BECKEN, offen=(PD.HAFENEINFAHRT, 1))
kaimauer("KaiNord", WL([(700, 444), (744, 447.5)]) + WL([(764, 449.2), (790, 452)]), offen=(1, 3))
# Kanalmauern bis in das Wassertor: Ihre Kronen sind die Laufstege durch das Tor in den Untergrundhafen
for k, (a_, b_) in enumerate([((744, 448), (744, 409)), ((764, 449), (764, 409))]):
    mauerring(f"KaiKanal{k}", HF, WL([a_, b_]), 0.0, dicke=4.0, zinnen=False, mat="Material_kai", oben_fest=KAI_KRONE)
HM = PD.HAFENMAUER_OST
mauerring("Hafenmauer", HF, WL(HM), 8.0, dicke=3.0, mitte=W((720, 520)))
mauerring("Speicherkai", HF, WL([(640, 642), (770, 646), (790, 630)]), 6.0, dicke=3.0, mitte=W((720, 520)),
         tore=tor_an([(640, 642), (770, 646), (790, 630)], PD.MOLENPFORTE, 5.0, "Molenpforte"))
_ht = []
# Zwei Rundtürme an der Hafeneinfahrt: am Ende der Hafenmauer und am Ende des Speicherkais
for pp, r in [((792, 628), 6.0), ((834, 540), 6.0)]:
    x, z = W(pp)
    # Schalentürme wie im Referenzbild: halbrund, zum Hafenbecken hin offen
    mx_, mz_ = W((720, 530))
    _ht += [x, z, -28.0, KAI_OBEN + 10, r, 2, round(math.degrees(math.atan2(mz_ - z, mx_ - x)), 1)]
N("HafenTuerme", "Node3D", HF, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_ht)})""")
sx, sz = W(PD.SPEICHER[0])
steinbau("Speicher", HF, sx, sz, PD.SPEICHER[1] * M, PD.SPEICHER[2] * M, 9, gier=0, mat="Material_holz",
         dach="Material_dach", boden=KAI_OBEN, art=2, begehbar=True, tuer_hinten=True)   # Tür zum Becken, nicht zur Speicherkaimauer
schild("SchildSpeicher", HF, sx, KAI_OBEN + 18, sz, "Speicher", 40)

# --- Untergrundhafen: Hinter dem Wassertor führt der Kanal durch einen Gang unter dem Zwinger in eine gewölbte Halle
# im Fels (burgbau.gd, hallen). Die Kronen der Kanalmauern sind die Laufstege durch das Tor; in der Halle gehen Kais
# um das Becken herum, so kommt man vom Nordkai auf den Ostkai mit den Kränen. Im Gelände ist am Fuß des Steilhangs
# ein Loch (region_drachenstein.py), sonst läge der Hang quer im Gang.
_wt = W(PD.TORE["Hafentor"])
UH_MUND = (87.6, -9.5)          # Mitte der Mündung an der Innenseite der Ringmauer, die Halle reicht nach -x
UH_LAENGE, UH_BREITE, UH_BECKEN, UH_KANAL = 60.0, 36.0, 12.0, 6.0
UH_JOCH = 6.0
N("Untergrundhafen", "Node3D", HF, f"""script = ExtResource("28_burgbau")
hallen = PackedFloat32Array({_zahlen([*UH_MUND, -1, 0, UH_LAENGE, UH_BREITE, UH_BECKEN, UH_KANAL, KAI_KRONE, 5.0, 6.0, 10.0, -19.6])})""")
uh = lambda s_, q_: (round(UH_MUND[0] - s_, 2), round(UH_MUND[1] - q_, 2))   # lokal (in den Berg, quer) → Welt
# Licht an jeder Laterne (Wandpfeiler alle 6 m) und über dem Becken
for k_, s_ in enumerate(range(6, int(UH_LAENGE), 6)):
    for seite_ in (-1, 1):
        lx_, lz_ = uh(s_, seite_ * (UH_BREITE / 2 - 1.4))
        licht(f"UHLicht{k_}{'ab'[seite_ > 0]}", HF, lx_, KAI_OBEN + 3.2, lz_, 15.0)
for k_, s_ in enumerate(range(3, int(UH_LAENGE), 12)):
    lx_, lz_ = uh(s_, 0)
    licht(f"UHLichtBecken{k_}", HF, lx_, KAI_OBEN + 7.0, lz_, 18.0)
licht("UHLichtTuer", HF, *(lambda p: (p[0], KAI_OBEN + 3.2, p[1]))(uh(UH_LAENGE - 2.0, 0)), 9.0)
schild("SchildUntergrundhafen", HF, *(lambda p: (p[0], KAI_OBEN + 4.2, p[1]))(uh(4, -7.5)), "Untergrundhafen", 40)
schild("SchildUHTuer", HF, *(lambda p: (p[0], KAI_OBEN + 4.2, p[1]))(uh(UH_LAENGE - 0.6, 0)), "Zur Burg (verschlossen)", 32)
# Torhaus über dem Wassertor (wie im Referenzbild): zwei eckige Türme mit Zeltdach zu beiden Seiten des Bogens, darüber
# ein Fachwerkhaus auf der Mauerkrone, das über die Mauer vorkragt
_wa, _wb = W(PD._MAUER_HAFEN[1]), W(PD._MAUER_HAFEN[0])
_wl = math.dist(_wa, _wb)
_wu = ((_wb[0] - _wa[0]) / _wl, (_wb[1] - _wa[1]) / _wl)          # entlang der Ringmauer
_wn = (-_wu[1], _wu[0])
_ringe = [H(_wt[0] + _wu[0] * s_ + _wn[0] * q_, _wt[1] + _wu[1] * s_ + _wn[1] * q_) for s_ in (-10, 0, 10) for q_ in (-4, 0, 4)]
_wt_oben = max(-19.6 + 9.0, max(_ringe) + 9.0)                     # wie mauerring: Krone des Torbaus
_tt = []
for s_ in (-1, 1):
    _tx, _tz = _wt[0] + _wu[0] * s_ * 7.8, _wt[1] + _wu[1] * s_ * 7.8
    _tt += [round(_tx, 2), round(_tz, 2), round(_wu[0], 4), round(_wu[1], 4), -21.0, round(_wt_oben + 7.0, 2), 5.0, 5.4, -1, 1.3]
_tg = math.degrees(math.atan2(_wu[0], _wu[1]))
N("HafenTorhaus", "Node3D", HF, f"""script = ExtResource("28_burgbau")
torbauten = PackedFloat32Array({_zahlen(_tt)})
gebaeude = PackedFloat32Array({_zahlen([round(_wt[0], 2), round(_wt[1], 2), round(_tg, 2), 6.2, 10.4, round(_wt_oben + 0.1, 2), round(_wt_oben, 2), 4.6, 3.6, 3, 1, 0])})""")
schild("SchildWassertor", HF, round(_wt[0] + 4, 2), KAI_OBEN + 4, round(_wt[1] + 7, 2), "Zum Untergrundhafen", 40)
# --- Meereshöhlen in der Klippe unter der Kernburg (wie im Referenzbild), mit Podest und Stufen ---
_hl = []
for px_ in (990, 1090):
    py_ = 395.0
    while H(*W((px_, py_))) > -19.2 and py_ < 470:
        py_ += 0.5
    hx_, hz_ = W((px_, py_))
    steig_ = (H(hx_ - 4, hz_) - H(hx_, hz_)) / 4.0
    _hl += [round(hx_, 2), round(hz_, 2), 1, 0, round(max(steig_, 0.8), 2), random.choice((4.5, 5.5)), random.choice((4.0, 5.0))]
N("Meereshoehlen", "Node3D", HF, f"""script = ExtResource("28_burgbau")
hoehlen = PackedFloat32Array({_zahlen(_hl)})""")
# --- Kaihäuser am Ostkai: eine Zeile schmaler Speicher- und Wohnhäuser unten auf dem Kai, mit dem Rücken an der
# Hafenmauer und der Tür zum Becken (wie im Referenzbild); davor bleibt die Gasse zum Kran frei ---
_hmitte = W((720, 520))
pa_, pb_ = W(HM[1]), W(HM[2])
l_ = math.dist(pa_, pb_)
ux_, uz_ = (pb_[0] - pa_[0]) / l_, (pb_[1] - pa_[1]) / l_
nx_, nz_ = -uz_, ux_
if (_hmitte[0] - pa_[0]) * nx_ + (_hmitte[1] - pa_[1]) * nz_ < 0:
    nx_, nz_ = -nx_, -nz_                       # zum Becken hin
s_ = l_ * 0.3
k_ = 0
while s_ < l_ * 0.93:
    laenge_ = random.choice((7.5, 8.5, 9.5))
    if s_ + laenge_ > l_ * 0.95:
        break
    tiefe_ = 5.0
    mx_ = pa_[0] + ux_ * (s_ + laenge_ / 2) + nx_ * (1.5 + 0.3 + tiefe_ / 2)
    mz_ = pa_[1] + uz_ * (s_ + laenge_ / 2) + nz_ * (1.5 + 0.3 + tiefe_ / 2)
    g_ = math.degrees(math.atan2(ux_, uz_))
    if math.cos(math.radians(g_)) * nx_ - math.sin(math.radians(g_)) * nz_ < 0:
        g_ += 180.0                             # Tür (lokal +x) zum Becken
    steinbau(f"Kaihaus{k_}", HF, round(mx_, 2), round(mz_, 2), laenge_, tiefe_, random.choice((6.0, 6.8, 7.4)), gier=round(g_, 1),
             mat=random.choice(("Material_holz", "Material_hell", "Material_mauer")), dach=random.choice(("Material_dach", "Material_dach_schiefer")),
             boden=KAI_OBEN, art=0)
    k_ += 1
    s_ += laenge_ + 0.4
_hm = W((720, 520))
schild("SchildHafen", HF, _hm[0], KAI_OBEN + 8, _hm[1], "Drachenhafen", 64)
# Koggen im Becken (szenen/welt/ausstattung.gd, Art 5; die Wasserlinie liegt bei -20)
SCHIFFE = [(5, *(lambda p: (p[0], -20.0, p[1]))(W(pp)), g) for pp, g in
           [((660, 480), 80), ((745, 478), 95), ((700, 560), 85), ((760, 548), 60)]]
# Draußen in der Bucht: Koggen unter vollem Segel (Art 6)
SCHIFFE += [(6, *(lambda p: (p[0], -20.0, p[1]))(W(pp)), g) for pp, g in [((960, 560), 150), ((1080, 640), 200)]]
# Ruderboote an den Stegen (Art 7)
SCHIFFE += [(7, *(lambda p: (p[0], -20.0, p[1]))(W(pp)), g) for pp, g in
            [((692, 468), 2), ((709, 458), -4), ((640, 515), 92), ((645, 532), 86), ((642, 490), 88), ((646, 505), 94),
             ((648, 545), 90), ((650, 560), 86)]]
# Im Untergrundhafen: Ruderboote an den Kais, zwei beladene Prahme (Art 9), ein Tretradkran auf dem Querkai
SCHIFFE += [(7, *uh(s_, q_)[:1], -20.0, uh(s_, q_)[1], g_) for s_, q_, g_ in [(10.0, 4.6, 92), (16.5, -4.5, 88), (47.5, 4.4, 91)]]
SCHIFFE += [(9, *uh(s_, q_)[:1], -20.0, uh(s_, q_)[1], g_) for s_, q_, g_ in [(26.0, -3.2, 90), (36.0, 3.2, 270)]]
SCHIFFE += [(8, *uh(56.0, 10.0)[:1], KAI_KRONE, uh(56.0, 10.0)[1], -90)]   # neben der Tür, der Ausleger über dem Becken
# Tretradkräne (Art 8): auf dem Ostkai an der Hafenmauer und am Ende des Nordkais, der Ausleger über dem Wasser
SCHIFFE += [(8, *(lambda p: (p[0], KAI_OBEN + 0.2, p[1]))(W(pp)), g) for pp, g in [((809.5, 500), 180), ((784, 438), -90)]]

# --- Landungsstege aus dem Steg-Fotoscan (modelle/hafen/): je Abschnitt 2,9 m, Deck 2,62 m über dem Ursprung ---
STEG = "res://modelle/hafen/modular_wooden_pier/modular_wooden_pier.gltf"
_steg = []
for start, richtung, abschnitte in [((700, 447), (1, 0), 5), ((628, 525), (0, -1), 4), ((625, 497), (0, -1), 4), ((632, 552), (0, -1), 4)]:
    sx_, sz_ = W(start)
    dx_, dz_ = richtung                  # Weltrichtung ins Becken
    g_ = math.degrees(math.atan2(dx_, dz_))
    qx_, qz_ = math.cos(math.radians(g_)), -math.sin(math.radians(g_))   # lokal x (quer)
    # glatte, unsichtbare Lauffläche als Kollision (die Scanform des Decks ist zu uneben zum Gehen)
    laenge_ = abschnitte * 2.9 + 0.6
    mx_, mz_ = sx_ + dx_ * laenge_ / 2.0, sz_ + dz_ * laenge_ / 2.0
    _nr = start[0]
    S(f'''[sub_resource type="BoxShape3D" id="Form_steg{_nr}"]
size = Vector3(2.5, 0.4, {laenge_:.2f})''')
    N(f"StegBoden{_nr}", "StaticBody3D", HF, T(round(mx_, 2), round(KAI_OBEN - 0.2, 2), round(mz_, 2), round(g_, 1)))
    N("Form", "CollisionShape3D", f"{HF}/StegBoden{_nr}", f'shape = SubResource("Form_steg{_nr}")')
    for k in range(abschnitte):
        ox = sx_ + dx_ * (k * 2.9 + 0.32) - qx_ * 0.98
        oz = sz_ + dz_ * (k * 2.9 + 0.32) - qz_ * 0.98
        for steg_teil in (3, 0):         # Deck und Pfähle
            _steg.append((steg_teil, round(ox, 2), round(KAI_OBEN - 2.62, 2), round(oz, 2), round(g_, 1), 0, 1))   # Deck auf Kaihöhe
# Hafenkram: Fässer und Kisten (Fotoscans) in Gruppen am Nordkai und am Ostkai
random.seed(77)
_kram = [W(pp) for pp in [(645, 419), (675, 419), (705, 420), (728, 421), (812, 528)]]    # an der Mauer, abseits der Laufwege
_kram += [uh(s_ + 3.0, q_ * (UH_BREITE / 2 + 1.6)) for s_ in range(6, 54, 12) for q_ in (-1, 1)]   # in den Lagernischen
for gx_, gz_ in _kram:
    for _ in range(random.randint(3, 6)):
        art_ = random.choice([5, 5, 6, 7, 7])
        px_, pz_ = gx_ + random.uniform(-1.6, 1.6), gz_ + random.uniform(-1.6, 1.6)
        _steg.append((art_, round(px_, 2), round(KAI_OBEN + 0.2, 2), round(pz_, 2), round(random.uniform(0, 360), 1), 0, 1))
N("Hafenausstattung", "Node3D", HF, f"""script = ExtResource("30_felsen")
modelle = PackedStringArray("{STEG}#0", "{STEG}#1", "{STEG}#2", "{STEG}#3", "{STEG}#4", "res://modelle/hafen/barrel_03/barrel_03.gltf", "res://modelle/hafen/wooden_crate_01/wooden_crate_01.gltf#1", "res://modelle/hafen/wooden_crate_02/wooden_crate_02.gltf#0")
stuecke = PackedFloat32Array({", ".join(f"{v:.6g}" for st_ in _steg for v in st_)})
sichtweite = 400.0
ohne_kollision = PackedInt32Array(0, 3)""")

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
steinbau("StMarien", ST, kx, kz, PD.ST_MARIEN[1] * M, PD.ST_MARIEN[2] * M, 15, gier=-PD.ST_MARIEN[3], mat="Material_hell",
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

SPERR = [MARKT, pr(PD.ST_MARIEN, 2.0), pr((PD.ST_MARIEN_TURM, 18, 18, 0)), WL(PD.VORBURG)]   # in der Vorburg keine Bürgerhäuser
# Die Treppen auf die Wehrgänge (teil_drachenstein.py) bleiben frei
for k_ in range(0, len(TREPPEN) if "TREPPEN" in globals() else 0, 7):
    fx_, fz_, _, tx_, tz_, _, br_ = TREPPEN[k_:k_ + 7]
    l_ = math.dist((fx_, fz_), (tx_, tz_))
    SPERR.append(rechteck((fx_ + tx_) / 2, (fz_ + tz_) / 2, br_ + 4.0, l_ + 5.0, math.degrees(math.atan2(tx_ - fx_, tz_ - fz_))))
MAUERN = [WL(SM), WL(PD.RING_NORD), WL(PD.RING_SUED_OST), WL(PD.VORBURG + PD.VORBURG[:1])]

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
                form = random.randrange(32)
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

# Hinterhäuser: Die Blöcke zwischen den Gassen werden dicht bebaut wie in einer alten Hafenstadt. Jedes Haus richtet
# sich nach der nächsten Gasse aus; bewohnt sind nur die Häuser an den Gassen (HAEUSER), die Hinterhäuser stehen
# den Stadtleuten nur im Weg (RECHTECKE in teil_stadtleben.py).
HINTERHAEUSER = []
_xs = [p_[0] for p_ in STADT_UMRISS]; _zs = [p_[1] for p_ in STADT_UMRISS]
_kandidaten = [(x_ + random.uniform(-1.2, 1.2), z_ + random.uniform(-1.2, 1.2))
               for x_ in range(int(min(_xs)), int(max(_xs)), 3) for z_ in range(int(min(_zs)), int(max(_zs)), 3)]
random.shuffle(_kandidaten)
def _naechste_gasse(x, z):
    beste = None
    for s_ in STRASSEN:
        for a_, b_ in zip(s_, s_[1:]):
            d_ = abstand_linie([a_, b_], x, z)
            if beste is None or d_ < beste[0]:
                beste = (d_, a_, b_)
    return beste
for hx, hz in _kandidaten:
    if not im_vieleck((hx, hz), STADT_UMRISS):
        continue
    _, a_, b_ = _naechste_gasse(hx, hz)
    ux, uz = b_[0] - a_[0], b_[1] - a_[1]
    l_ = math.hypot(ux, uz); ux, uz = ux / l_, uz / l_
    # Vorderseite zur Gasse: Normale zur Gasse auf der Seite des Hauses
    nx, nz = -uz, ux
    if (hx - a_[0]) * nx + (hz - a_[1]) * nz < 0:
        nx, nz = -nx, -nz
    gier = math.degrees(math.atan2(-nx, -nz)) + random.choice((0, 0, 0, 180))
    form = random.randrange(24, 32) if random.random() < 0.8 else random.randrange(24)
    b, t, _ = HAUSFORMEN[form]
    ecken4 = rechteck(hx, hz, b + 0.1, t + 2 * VORKRAGUNG, gier)
    if not bauplatz_frei(ecken4, _haus_ecken, STRASSE_HALB):
        continue
    hoehen = [H(x, z) for x, z in ecken4]
    y = min(hoehen)
    if max(hoehen) - y < 3.0:
        HINTERHAEUSER.append((round(hx, 2), round(y, 2), round(hz, 2), round(gier, 1), 0, form))
        _haus_ecken.append(ecken4)

# Hausbäume in den Höfen zwischen den Häusern: wo kein Haus mehr Platz fand, abseits der Gassen und Mauern
STADTBAEUME = []
_hof_kandidaten = [(x_ + random.uniform(-1, 1), z_ + random.uniform(-1, 1))
                   for x_ in range(int(min(_xs)), int(max(_xs)), 3) for z_ in range(int(min(_zs)), int(max(_zs)), 3)]
random.shuffle(_hof_kandidaten)
for hx, hz in _hof_kandidaten:
    if len(STADTBAEUME) >= 16 or not im_vieleck((hx, hz), STADT_UMRISS):
        continue
    if min(abstand_linie(s_, hx, hz) for s_ in STRASSEN) < STRASSE_HALB + 3.0 or min(abstand_linie(m_, hx, hz) for m_ in MAUERN) < 5.0:
        continue
    kreis = rechteck(hx, hz, 6.0, 6.0, 0)
    if any(ueberlappen(kreis, r_) for r_ in _haus_ecken + SPERR):
        continue
    if any(math.dist((hx, hz), (b_[0], b_[2])) < 14.0 for b_ in STADTBAEUME):
        continue
    STADTBAEUME.append((round(hx, 2), round(H(hx, hz), 2), round(hz, 2), round(random.uniform(0.8, 1.15), 2)))
print("Hausbäume in der Stadt:", len(STADTBAEUME))

_alle_haeuser = HAEUSER + HINTERHAEUSER
# Wie im Referenzbild: dicht an dicht Fachwerkhäuser mit warmen, braunroten Ziegeldächern
N("Stadthaeuser", "Node3D", DS, "script = ExtResource(\"27_stadthaeuser\")\nnur_ziegel = true\nnur_fachwerk = true\n"
  + "haeuser = PackedVector4Array(" + ", ".join(f"{x:.5g}, {y:.5g}, {z:.5g}, {g:.4g}" for x, y, z, g, _, _ in _alle_haeuser) + ")\n"
  + "formen = PackedInt32Array(" + ", ".join(str(f) for *_, f in _alle_haeuser) + ")")
print("Stadthäuser:", len(HAEUSER), "an den Gassen,", len(HINTERHAEUSER), "Hinterhäuser")

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
# Speicherkai: Fässer, Kisten und Säcke an der Wand des Speichers (die Tür in der Mitte und der Weg zur Molenpforte
# bleiben frei), dazu ein Karren
for px_ in (652, 662, 672, 708, 718, 728):
    gx, gz = W((px_, random.uniform(615.5, 616.5)))
    for k in range(random.randint(2, 4)):
        art = random.choice((0, 0, 1, 1, 2))
        AUSSTATTUNG.append((art, gx + random.uniform(-0.6, 0.6), KAI_OBEN, gz + random.uniform(-1.3, 1.3), random.uniform(0, 360)))
_kx, _kz = W((740, 616))
AUSSTATTUNG.append((4, _kx, KAI_OBEN, _kz, random.uniform(-8, 8)))   # längs an der Wand
for x, z in STAENDE_MEHR:
    # neben dem Stand in der Reihe, nicht auf den Wegen davor und dahinter
    for seite in (-1, 1):
        px_, pz_ = x + random.uniform(-0.6, 0.6), z + seite * random.uniform(2.4, 2.8)
        AUSSTATTUNG.append((random.choice((0, 1, 2)), px_, H(px_, pz_), pz_, random.uniform(0, 360)))
# Leben zwischen den Ständen (ohne Kollision): Tauben picken auf dem Pflaster, Pfützen, Katzen und Hunde
_stadt_klein = {}
for x, z in STAENDE + STAENDE_MEHR:
    w_ = random.uniform(0, math.tau)
    if random.random() < 0.45:
        for k in range(random.randint(2, 5)):
            px_, pz_ = x + math.cos(w_) * 3.5 + random.uniform(-0.8, 0.8), z + math.sin(w_) * 3.5 + random.uniform(-0.8, 0.8)
            AUSSTATTUNG.append((31, px_, H(px_, pz_), pz_, random.uniform(0, 360)))
            _stadt_klein[31] = _stadt_klein.get(31, 0) + 1
    if random.random() < 0.3:
        px_, pz_ = x + math.cos(w_ + 2.0) * 4.0, z + math.sin(w_ + 2.0) * 4.0
        AUSSTATTUNG.append((30, px_, H(px_, pz_), pz_, random.uniform(0, 360)))
        _stadt_klein[30] = _stadt_klein.get(30, 0) + 1
    if random.random() < 0.25:
        art_ = 23 if random.random() < 0.6 else 22
        px_, pz_ = x + math.cos(w_ - 2.0) * 2.8, z + math.sin(w_ - 2.0) * 2.8
        AUSSTATTUNG.append((art_, px_, H(px_, pz_), pz_, random.uniform(0, 360)))
        _stadt_klein[art_] = _stadt_klein.get(art_, 0) + 1
print("Stadt: Tauben, Pfützen, Katzen, Hunde:", _stadt_klein)
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
    for linie in [WL(SM), WL(PD.RING_NORD), WL(PD.RING_SUED_OST), WL(PD.VORBURG + PD.VORBURG[:1]), WL(PD.BURGHOF2 + PD.BURGHOF2[:1]),
                  WL(PD.BURGHOF3 + PD.BURGHOF3[:1]), WL(PD.ZWINGERMAUER_SUED), WL(PD.ZWINGER_KERNBURG + PD.ZWINGER_KERNBURG[:1]), WL(PD.KERNBURG + PD.KERNBURG[:1]), BECKEN + BECKEN[:1], WL(HM)]:
        zeichnung.line([P(p) for p in linie], fill=(230, 230, 230), width=3)
    zeichnung.rectangle([P((-31, -31)), P((31, 31))], outline=(255, 0, 0), width=2)
    bild.save(os.environ["BAU_KARTE"])
