# ---------- 3D-Felsen an den Klippen von Drachenstein (szenen/welt/felsen.gd) ----------
# Fotoscans von Poly Haven (modelle/felsen/, CC0). Gesucht werden Steilhänge außerhalb der Burgen, der Stadt und des
# Hafens: unter der Ringmauer zum Meer und ins Tal, und die Felsstufen zwischen den Burghöfen. Die Klippenscans liegen
# als Fels-Haut in Reihen entlang der Höhenlinien, überlappend und in die Wand gesetzt (Front hangabwärts); am Fuß
# liegen Geröll und Brocken, auf Absätzen wachsen Farn, Gras und Moos (modelle/pflanzen/).
# Wird aus region_drachenstein.py nach teil_drachenstein.py ausgeführt (H, PD, W, abstand_linie, im_vieleck).

E("Script", "res://szenen/welt/felsen.gd", "30_felsen")
FELSMODELLE = [
    # Pfad, Breite, Höhe (Meter, Front nach +z)
    ("res://modelle/felsen/coastal_cliff_02/coastal_cliff_02.gltf", 40.9, 10.1),
    ("res://modelle/felsen/namaqualand_cliff_02/namaqualand_cliff_02.gltf", 20.2, 7.2),
    ("res://modelle/felsen/coastal_cliff_04/coastal_cliff_04.gltf", 86.8, 11.0),
    ("res://modelle/felsen/rock_face_02/rock_face_02.gltf", 2.7, 2.5),
] + [(f"res://modelle/felsen/rock_moss_set_02/rock_moss_set_02.gltf#{k}", 1.8, 0.9) for k in range(7)]
GROSS, MITTEL, RIESIG, STUECK = 0, 1, 2, 3
BROCKEN = list(range(4, 11))
# Bewuchs auf den Absätzen der Klippen (modelle/pflanzen/): Farn, Grasbüschel, Moospolster
FARN = len(FELSMODELLE)
FELSMODELLE += [(f"res://modelle/pflanzen/fern_02/fern_02.gltf#{k}", 0, 0) for k in range(4)]
GRAS = len(FELSMODELLE)
FELSMODELLE += [(f"res://modelle/pflanzen/grass_medium_01/grass_medium_01.gltf#{k}", 0, 0) for k in range(17)]
MOOS = len(FELSMODELLE)
FELSMODELLE += [(f"res://modelle/pflanzen/moss_01/moss_01.gltf#{k}", 0, 0) for k in range(12)]
# Tönung: Die Scans aus Südafrika (namaqualand) und das Felsstück sind rötlich, sie passen sich dem grauen Fels an
# Alle Scans etwas heller, damit sie zum grauen Fels des Geländes und zum hellen Kalkstein der Mauern passen
FARBEN = {GROSS: "1.3, 1.29, 1.27, 1", RIESIG: "1.3, 1.29, 1.27, 1", MITTEL: "1.07, 1.13, 1.25, 1",
          STUECK: "1.15, 1.19, 1.26, 1", **{b_: "1.25, 1.24, 1.22, 1" for b_ in BROCKEN}}

random.seed(4711)
_frei = [WL(PD.VORBURG), WL(PD.BURGHOF2), WL(PD.BURGHOF3), WL(PD.KERNBURG), WL(PD.STADT), WL(PD.HAFEN_BEZIRK)]
# Äußere Mauern bleiben frei; an den Burgmauern darf der Fels bis an den Mauerfuß reichen (die Burgen stehen auf ihm)
_mauern = [WL(PD.RINGMAUER + PD.RINGMAUER[:1]), WL(PD.STADTMAUER), WL(PD.HAFENMAUER_OST)]
_ring_flaeche = WL(PD.RINGMAUER)
_wege = [WL(w) for w in PD.BURGWEGE] + [WL(PD.KAIWEG)] + [
    # Landstraßen vor den Toren (werkzeuge/gelaende_erzeuger.gd: WEG_GRAVEMARCH, WEG_NORD, WEG_KUESTE)
    [(-27.2, 220.5), (-45, 225), (-120, 215), (-220, 170)],
    [(-45, 225), (-110, 200), (-150, 120), (-160, 0), (-155, -150), (-130, -300), (-60, -380), (40, -410), (150, -430)],
    [(-220, 170), (-300, 80), (-380, -20)],
    [(91, 297), (98, 312), (116, 340), (122, 390), (132, 470), (140, 540), (150, 615), (160, 690)],
    [(150, -430), (230, -500), (150, -560), (110, -610), (85, -660)]]
# Tore und Durchgänge, vor denen nichts liegen darf (dazu der Kai am Wassertor und das Felsentor)
_tore = [W(p) for p in PD.TORE.values()] + [W(PD.MOLENPFORTE), W((740, 420))]


def _gefaelle(x, z):
    """Hangabwärts-Richtung und Steilheit."""
    gx = (H(x + 1.5, z) - H(x - 1.5, z)) / 3.0
    gz = (H(x, z + 1.5) - H(x, z - 1.5)) / 3.0
    s = math.hypot(gx, gz)
    return (-gx / s, -gz / s, s) if s > 1e-6 else (0.0, 0.0, 0.0)


def _abstand(p, linien):
    return min(abstand_linie(l, *p) for l in linien)


# Wie weit die Front der Modelle vor ihrem Ursprung liegt (Meter, lokal +z): so tief kommen sie in die Wand
FRONT = {GROSS: 4.1, MITTEL: 2.2, RIESIG: 15.2, STUECK: 0.9}
REIHE = 6.5          # Höhe einer Felsreihe; die Stücke sind höher und überlappen die Reihe darüber
REIHE_KLEIN = 3.5    # an niedrigeren Wänden (unter den Burgen) kleinere Reihen


def _frei_fuer(umriss):
    return all(not any(im_vieleck(q, v) for v in _frei) and _abstand(q, _wege) > 6.5 and _abstand(q, _mauern) > 1.5
               and min(math.dist(q, t) for t in _tore) > 10.0 for q in umriss)


# Fels-Haut: Die Klippenscans liegen in Reihen entlang der Höhenlinien, Reihe über Reihe, nebeneinander überlappend und
# in die Wand gesetzt, so dass die Geländewand dahinter fast ganz verschwindet.
FELSSTUECKE = []
_reihen = {}         # Reihe → [(x, z, halbe Breite)]
kandidaten = []
for x in range(-150, 330, 2):
    for z in range(-330, 330, 2):
        px, pz = x + random.uniform(-0.8, 0.8), z + random.uniform(-0.8, 0.8)
        dx, dz, s = _gefaelle(px, pz)
        h0 = H(px, pz)
        if s < 1.3 or h0 < -24:      # nur echte Steilwände, nicht die Hänge im Zwinger
            continue
        # an allen Steilwänden außerhalb der Höfe: außen an den Klippen und innen unter den Terrassen der Burghöfe
        if any(im_vieleck((px, pz), v) for v in _frei):
            continue
        oben = max(H(px - dx * d, pz - dz * d) for d in (2, 4, 6, 10, 14, 20))
        unten = min(H(px + dx * d, pz + dz * d) for d in (2, 4, 6, 10, 14, 20))
        reihe_m = REIHE if oben - unten >= 14 else REIHE_KLEIN
        r = (h0 + 20.0) / reihe_m
        if abs(r - round(r)) > 0.25:
            continue
        kandidaten.append((oben - unten, (reihe_m, round(r)), px, pz, dx, dz, oben, unten, s))
kandidaten.sort(reverse=True)

for hoehe, reihe, px, pz, dx, dz, oben, unten, steil in kandidaten:
    if hoehe < (5 if im_vieleck((px, pz), _ring_flaeche) else 8):   # Wände ab 8 m, unter den Terrassen ab 5 m
        continue
    reihe_m = reihe[0]
    reihe_h = -20.0 + reihe[1] * reihe_m
    if reihe_m == REIHE_KLEIN:
        m = random.choice([MITTEL, MITTEL, GROSS])
    elif reihe_h < -10 and hoehe > 20:
        m = random.choice([GROSS, GROSS, RIESIG])
    else:
        m = random.choice([GROSS, GROSS, GROSS, MITTEL, MITTEL])
    _, breite, mh = FELSMODELLE[m]
    groesse = reihe_m * 1.45 / mh * random.uniform(0.9, 1.15)
    nachbarn = _reihen.setdefault(reihe, [])
    if any(math.dist((px, pz), (qx, qz)) < max(hb, breite * groesse * 0.5) * 0.7 for qx, qz, hb in nachbarn):
        continue
    for _ in range(4):
        halb = breite * groesse * 0.45
        umriss = [(px - dz * t * halb, pz + dx * t * halb) for t in (-1.0, -0.5, 0.0, 0.5, 1.0)]
        if all(_gefaelle(qx, qz)[2] > 1.0 for qx, qz in umriss) and _frei_fuer(umriss):
            break
        groesse *= 0.75
    else:
        continue
    # Die Front liegt parallel zum Hang (um die Hangneigung nach hinten gekippt) und steht etwa 1 m davor; der Punkt
    # auf halber Höhe der Front sitzt über der Kandidatenstelle (px, H, pz).
    beta = math.radians(max(0.0, min(35.0, 90.0 - math.degrees(math.atan(steil)))))
    h0 = H(px, pz)
    passt = False
    for _ in range(3):
        a_, f_ = mh * groesse * 0.5, FRONT[m] * groesse
        y_mitte = a_ * math.cos(beta) + f_ * math.sin(beta)       # lokal gekippt, Mitte der Front
        z_mitte = -a_ * math.sin(beta) + f_ * math.cos(beta)
        oy = h0 - y_mitte
        ox, oz = px + dx * (1.0 - z_mitte), pz + dz * (1.0 - z_mitte)
        oben_stueck = oy + mh * groesse * math.cos(beta) + f_ * math.sin(beta)
        if oben_stueck <= oben + 0.5:
            passt = True
            break
        groesse *= 0.75           # oben an der Kante: kleiner, damit nichts über die Mauern ragt
    if not passt:
        continue
    gier = math.degrees(math.atan2(dx, dz)) + random.uniform(-8, 8)
    FELSSTUECKE.append((m, round(ox, 2), round(oy, 2), round(oz, 2), round(gier, 1), round(math.degrees(beta), 1),
                        round(groesse, 2)))
    nachbarn.append((px, pz, breite * groesse * 0.5))

# Geröll und Brocken am Fuß der Klippen an der Wasserlinie
for hoehe, reihe, px, pz, dx, dz, oben, unten, steil in [k for k in kandidaten if k[1][0] == REIHE][::3]:
    for k in range(3):
        qx, qz = px + dx * random.uniform(4, 14) + random.uniform(-3, 3), pz + dz * random.uniform(4, 14) + random.uniform(-3, 3)
        hq = H(qx, qz)
        if not -22 < hq < -16.5 or not _frei_fuer([(qx, qz)]):
            continue
        m = random.choice(BROCKEN + [STUECK, STUECK])
        g = random.uniform(1.4, 3.0) if m == STUECK else random.uniform(1.5, 3.5)
        FELSSTUECKE.append((m, round(qx, 2), round(hq - 0.4 * g, 2), round(qz, 2), round(random.uniform(0, 360), 1),
                            round(random.uniform(0, 20), 1), round(g, 2)))

# Felssockel unter den Hofmauern (wie im Referenzbild): eine geschlossene, zerklüftete Felswand, gebaut von
# szenen/welt/felssockel.gd aus Säulen am Hofrand (alle 1,6 m). Sie reicht vom Mauerfuß bis unter das Gelände. An Toren,
# Wegen und Nachbarhöfen beginnt ein neuer Abschnitt; dort bleibt sie offen.
E("Script", "res://szenen/welt/felssockel.gd", "31_felssockel")
E("Material", "res://material/felssockel.tres", "32_felssockel_mat")
_SOCKEL = []
_abschnitt = 0
_hang = 0
_hang_orte = []
_alle_hoefe = [WL(PD.VORBURG), WL(PD.BURGHOF2), WL(PD.BURGHOF3), WL(PD.KERNBURG)]
# Türme an den Hofmauern (aus teil_drachenstein.py): vor ihnen kein Sockel, sie stehen selbst auf dem Fels
_sockel_tuerme = [W(q) for q in _HOF_TUERME] if "_HOF_TUERME" in globals() else []
for umriss_, hof_h in [(WL(PD.VORBURG), PD.H_VORBURG), (WL(PD.BURGHOF2), PD.H_BURGHOF2), (WL(PD.BURGHOF3), PD.H_KERNHOF),
                       (WL(PD.KERNBURG), PD.H_KERNBURG)]:
    mx_ = sum(q[0] for q in umriss_) / len(umriss_)
    mz_ = sum(q[1] for q in umriss_) / len(umriss_)
    ring_ = umriss_ + umriss_[:1]
    _abschnitt += 1
    offen_ = True
    for a_, b_ in zip(ring_, ring_[1:]):
        l_ = math.dist(a_, b_)
        if l_ < 0.3:
            continue
        ux, uz = (b_[0] - a_[0]) / l_, (b_[1] - a_[1]) / l_
        nx, nz = -uz, ux
        if nx * ((a_[0] + b_[0]) / 2 - mx_) + nz * ((a_[1] + b_[1]) / 2 - mz_) < 0:
            nx, nz = -nx, -nz                         # nach außen
        n_ = max(1, int(l_ / 1.6))
        for k_ in range(n_):
            t_ = k_ / n_
            px, pz = a_[0] + (b_[0] - a_[0]) * t_, a_[1] + (b_[1] - a_[1]) * t_
            vx, vz = px + nx * 3.5, pz + nz * 3.5     # vor der Wand
            oben_ = hof_h - 0.15
            unten_ = min(H(px + nx * d_, pz + nz * d_) for d_ in (2.0, 4.0, 6.0, 9.0)) - 2.5
            frei_ = (oben_ - unten_ > 3.0 and _abstand((vx, vz), _wege) > 4.0
                     and min(math.dist((vx, vz), t) for t in _tore) > 9.0
                     and not any(im_vieleck((vx, vz), v) for v in _alle_hoefe)
                     and all(math.dist((px, pz), t) > 9.0 for t in _sockel_tuerme))
            if not frei_:
                if not offen_:
                    _abschnitt += 1
                    offen_ = True
                continue
            offen_ = False
            _SOCKEL += [round(px, 2), round(pz, 2), round(nx, 4), round(nz, 4), round(oben_, 2), round(unten_, 2), _abschnitt]
N("Felssockel", "Node3D", DS, f"""script = ExtResource("31_felssockel")
saeulen = PackedFloat32Array({", ".join(f"{v:.6g}" for v in _SOCKEL)})
material = ExtResource("32_felssockel_mat")""")
print("Felssockel unter den Hofmauern:", len(_SOCKEL) // 7, "Säulen in", _abschnitt, "Abschnitten")


# Bewuchs: auf Absätzen und Kanten bei den Felsen (nicht zu steil), Farn und Gras in Gruppen, dazu Moos und Brocken
_felsen = [(x, z) for m, x, y, z, *_ in FELSSTUECKE if m in (GROSS, MITTEL, RIESIG)] + _hang_orte[::4]
_bewuchs = 0
for x in range(-150, 330, 2):
    for z in range(-330, 330, 2):
        px, pz = x + random.uniform(-0.9, 0.9), z + random.uniform(-0.9, 0.9)
        dx, dz, s = _gefaelle(px, pz)
        h0 = H(px, pz)
        if not 0.2 < s < 0.85 or h0 < -18.5 or random.random() > 0.45:
            continue
        if not any(abs(px - fx) < 22 and abs(pz - fz) < 22 for fx, fz in _felsen):
            continue
        if any(im_vieleck((px, pz), v) for v in _frei) or _abstand((px, pz), _mauern) < 3.0 or _abstand((px, pz), _wege) < 4.5 \
                or min(math.dist((px, pz), t) for t in _tore) < 8.0:
            continue
        wurf = random.random()
        if wurf < 0.35:
            m, g = FARN + random.randrange(4), random.uniform(0.9, 1.5)
        elif wurf < 0.8:
            m, g = GRAS + random.randrange(17), random.uniform(0.8, 1.3)
        elif wurf < 0.95:
            m, g = MOOS + random.randrange(12), random.uniform(18, 30)   # das Moosmodell ist nur 2 cm groß
        else:
            m, g = random.choice(BROCKEN), random.uniform(0.8, 1.8)
        FELSSTUECKE.append((m, round(px, 2), round(h0 - 0.08, 2), round(pz, 2), round(random.uniform(0, 360), 1), 0.0, round(g, 2)))
        _bewuchs += 1

# Grün an den steilen Wänden (wie im Referenzbild): Moospolster, Gras und Farn in Nischen der Felswand, an die
# Neigung des Felsens angelegt; dichter, wo Wasser herabläuft (Rauschen), nicht unter der Hochwasserlinie
_wand = 0
for x in range(-150, 330, 2):
    for z in range(-330, 330, 2):
        px, pz = x + random.uniform(-0.9, 0.9), z + random.uniform(-0.9, 0.9)
        dx, dz, s = _gefaelle(px, pz)
        h0 = H(px, pz)
        if not 0.85 <= s < 3.0 or h0 < -17.5:
            continue
        feucht = 0.5 + 0.5 * math.sin(px * 0.11 + math.cos(pz * 0.07) * 3.0) * math.cos(pz * 0.09)
        if random.random() > 0.05 + 0.25 * feucht:
            continue
        if any(im_vieleck((px, pz), v) for v in _frei) or _abstand((px, pz), _mauern) < 2.0 or _abstand((px, pz), _wege) < 4.5 \
                or min(math.dist((px, pz), t) for t in _tore) < 8.0:
            continue
        neigung = -math.degrees(math.atan(s))            # Pflanze steht senkrecht auf der Wand
        gier = math.degrees(math.atan2(dx, dz))
        wurf = random.random()
        if wurf < 0.55:
            m, g = MOOS + random.randrange(12), random.uniform(22, 36)
        elif wurf < 0.85:
            m, g = GRAS + random.randrange(17), random.uniform(0.7, 1.1)
        else:
            m, g = FARN + random.randrange(4), random.uniform(0.7, 1.1)
        FELSSTUECKE.append((m, round(px + dx * 0.15, 2), round(h0 - 0.12, 2), round(pz + dz * 0.15, 2), round(gier, 1), round(neigung, 1), round(g, 2)))
        _wand += 1
print("Grün an den Felswänden:", _wand)

# Vor den Meereshöhlen (teil_stadt.py) bleibt der Fels frei, sonst verdecken Brocken die Öffnungen
_hoehlen_orte = [(_hl[k], _hl[k + 1]) for k in range(0, len(_hl), 7)] if "_hl" in globals() else []
FELSSTUECKE = [f_ for f_ in FELSSTUECKE if all(math.dist((f_[1], f_[3]), h_) > (11.0 + 3.0 * f_[6] if f_[0] < 4 else 11.0) for h_ in _hoehlen_orte)]   # große Klippenmodelle reichen weit über ihren Ursprung
# Felsmassiv im Burgbezirk (szenen/welt/felsmassiv.gd): Der Grund zwischen den Höfen ist nackter, gestufter Fels.
# Darum liegen dort keine einzelnen Brocken, Platten und Pflanzen mehr; die Klippen außen vor der Ringmauer bleiben.
E("Script", "res://szenen/welt/felsmassiv.gd", "33_felsmassiv")
E("Material", "res://material/felsmassiv.tres", "34_felsmassiv_mat")
_rx = [q[0] for q in _ring_flaeche]
_rz = [q[1] for q in _ring_flaeche]
N("Felsmassiv", "Node3D", DS, f"""script = ExtResource("33_felsmassiv")
gelaende = NodePath("../../Gelaende")
bereich = Rect2({min(_rx) - 2:.1f}, {min(_rz) - 2:.1f}, {max(_rx) - min(_rx) + 4:.1f}, {max(_rz) - min(_rz) + 4:.1f})
material = ExtResource("34_felsmassiv_mat")""")   # gelaende ist ein NodePath (kein Node-Export)
_vorher = len(FELSSTUECKE)
FELSSTUECKE = [f_ for f_ in FELSSTUECKE if not im_vieleck((f_[1], f_[3]), _ring_flaeche)]
print("Felsmassiv im Burgbezirk; dort entfernt:", _vorher - len(FELSSTUECKE), "Brocken, Platten und Pflanzen")
N("Felsen", "Node3D", DS, f"""script = ExtResource("30_felsen")
modelle = PackedStringArray({", ".join(f'"{p}"' for p, _, _ in FELSMODELLE)})
farben = PackedColorArray({", ".join(FARBEN.get(m, "1, 1, 1, 1") for m in range(len(FELSMODELLE)))})
stuecke = PackedFloat32Array({", ".join(f"{v:.6g}" for st in FELSSTUECKE for v in st)})""")
print("Felsen:", len(FELSSTUECKE) - _bewuchs, "aus", len(kandidaten), "Stellen in Reihen, Bewuchs:", _bewuchs,
      {FELSMODELLE[m][0].split("/")[-1]: sum(1 for s in FELSSTUECKE if s[0] == m) for m in range(4)})
