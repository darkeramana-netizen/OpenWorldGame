# ---------- Burgfeste Drachenstein nach dem Grundriss (docs/bilder/grundriss-drachenstein-2.webp) ----------
# Auf einem Felsgrat hintereinander (werkzeuge/bau/plan_drachenstein.py hat die Planpunkte):
#   I. Vorburg (12. Jh.) mit zwei Rundtürmen · II. Burghof (14. Jh.) · III. Burghof mit dem Hof aus Akt I ·
#   Kernburg mit Bergfried, Palas, Drachenkapelle, Burgküche und Zeughaus, umgeben von der Zwingermauer.
#   Die Ringmauer umschließt den Grat: Torhaus Nord, Halbturm, Wehrturm, Zwinger, Rondell, Hafentor (Wassertor).
# Der Weg hinauf (blaue Linie im Grundriss): Stadt → Burgstraßentor → am Halbturm vorbei hinauf (dort kommt der Weg
# vom Torhaus Nord dazu) → außen um die ganze Burg → Rampe → Rampentor (II. Burghof) → III. Burghof → Burgtor →
# Zwingerweg um die Kernburg → Kernburgtor. Unten zweigt der Weg zum Südtor der Vorburg ab.
# Die Höfe sind gestaffelt (Schnitt B-B): Vorburg 0, II. Burghof +6, III. Burghof +14, Kernburg +38.
import sys
sys.path.insert(0, str(BAU))
import plan_drachenstein as PD
teil("teil_mauern.py")

W = PD.welt
WL = PD.welt_liste
DS = "Drachenstein"
N(DS, "Node3D", ".")
BG = DS + "/Burgen"
N("Burgen", "Node3D", DS)
M = PD.MASSSTAB


def turmmasse(pp, r, ueber):
    """Rundturm am Planpunkt: [x, z, unten, oben] – unten unter dem tiefsten Gelände, oben über dem höchsten."""
    x, z = W(pp)
    werte = [H(x + dx, z + dz) for dx in (-r, 0, r) for dz in (-r, 0, r)]
    return [x, z, min(werte) - 2.5, max(werte) + ueber]


def tor_an(punkte, p, breite, name, boden=None, tuerme=None):
    """Tor für mauerring: {Kantenindex: (Anteil, Breite, Name)} an der Kante des Linienzugs, die dem Planpunkt p
    am nächsten liegt (punkte und p im Plan)."""
    bester = None
    for i, (a, b) in enumerate(zip(punkte, punkte[1:])):
        dx, dy = b[0] - a[0], b[1] - a[1]
        t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)))
        d = math.dist(p, (a[0] + dx * t, a[1] + dy * t))
        if bester is None or d < bester[0]:
            bester = (d, i, t)
    # tuerme=False: Tor ohne eigene Tortürme (sonst wie in mauerring: Tortürme, außer bei einem Wassertor mit boden)
    rest = () if boden is None and tuerme is None else (boden, boden is None if tuerme is None else tuerme)
    return {bester[1]: (round(bester[2], 3), breite, name) + rest}


def tore_an(punkte, *tore):
    erg = {}
    for p, breite, name, *rest in tore:
        erg.update(tor_an(punkte, p, breite, name, *rest))
    return erg


def gebaeude(name, eltern, bau, hoehe, boden, mat="Material_mauer", dach="Material_dach_schiefer", dachhoehe=None, art=None,
             begehbar=True, zweck=0):
    """Bau aus dem Plan: ((Mitte), Länge entlang Plan-x, Breite, Drehung)."""
    (pp, laenge, breite, dreh) = bau
    x, z = W(pp)
    # Länge entlang Plan-x = Welt -z; steinbau legt die Länge entlang lokal z, Gier 0 → Welt z
    return steinbau(name, eltern, x, z, laenge * M, breite * M, hoehe, gier=-dreh, mat=mat, dach=dach,
                    dachhoehe=dachhoehe, boden=boden, art=art, begehbar=begehbar, zweck=zweck)


MITTE_BURG = W(PD.MITTE)
# Fahnen und Banner (szenen/welt/burgbau.gd, "fahnen"): x, y, z, Gier, Breite, Länge, Art (0 Mast, 1 Banner an der Wand)
FAHNEN = []
# --- Ringmauer um den Grat ---
RING = PD.RINGMAUER + [PD.RINGMAUER[0]]
mauerring("Ringmauer", BG, WL(RING), 9.0, dicke=3.0, mitte=MITTE_BURG,
         tore=tore_an(RING, (PD.TORE["Torhaus Nord"], 6.0, "Torhaus Nord"), (PD.TORE["Hafentor"], 10.0, "Hafentor", -19.6),
                      (PD.TORE["Burgstraßentor"], 6.0, "Burgstraßentor"), (PD.TORE["Torhaus West"], 6.0, "Torhaus West")))
# Mauerwachen auf dem Wehrgang der Ringmauer: auf jedem fünften langen Mauerstück eine Wache, mit Blick nach außen
# (die Personen selbst setzt region_drachenstein.py, wenn es den Knoten "Personen" gibt)
MAUERWACHEN = []
_rs = [m_ for m_ in MAUERSTUECKE if m_[0] == "Ringmauer" and math.dist(m_[1:3], m_[3:5]) > 10.0]
for k_, (_, ax_, az_, bx_, bz_, oben_, dicke_, aussen_) in enumerate(_rs):
    if k_ % 5 != 2 or len(MAUERWACHEN) >= 8:
        continue
    mx_, mz_ = (ax_ + bx_) / 2 - aussen_[0] * 0.4, (az_ + bz_) / 2 - aussen_[1] * 0.4
    MAUERWACHEN.append((round(mx_, 2), round(oben_ + 0.1, 2), round(mz_, 2), round(math.degrees(math.atan2(aussen_[0], aussen_[1])), 1)))
print("Mauerwachen:", len(MAUERWACHEN))
# Türme der Ringmauer: Wehrturm, Zwinger, Rondell und weitere Rundtürme; Halbturm eckig
_tuerme = []
for pp, r, dach in [(PD.WEHRTURM, 6.0, 0), ((1190, 55), 6.0, 1), ((1230, 140), 6.5, 1), (PD.RONDELL, 10.0, 0),
                    ((880, 60), 5.0, 1), ((560, 100), 5.0, 1), ((330, 180), 5.0, 1), ((470, 376), 4.5, 0),
                    ((1000, 393), 5.0, 1),
                    # weitere Rundtürme mit Kegeldach wie im Referenzbild
                    ((700, 403), 5.0, 1), ((600, 390), 5.0, 1), ((640, 72), 5.0, 1), ((1100, 30), 5.0, 1),
                    ((1245, 250), 5.5, 1), ((1100, 375), 5.0, 1), ((900, 405), 5.0, 1)]:
    x, z = W(pp)
    unten = min(H(x + dx, z + dz) for dx in (-r, 0, r) for dz in (-r, 0, r)) - 2.5
    oben = max(H(x + dx, z + dz) for dx in (-r, 0, r) for dz in (-r, 0, r)) + 14
    _tuerme += [x, z, unten, oben, r, dach, r * 1.8]
    if dach == 0:
        FAHNEN.extend([x, oben + 0.05, z, 30, 2.4, 3.8, 0])
hx, hz = W(PD.HALBTURM)
_hb = H(hx, hz)
N("RingmauerTuerme", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_tuerme)})
torbauten = PackedFloat32Array({_zahlen([hx, hz, 1, 0, _hb - 6, _hb + 13, 11, 11, 1, 1.0])})""")
schild("SchildHalbturm", BG, hx, _hb + 30, hz, "Halbturm", 40)
schild("SchildWehrturm", BG, *(lambda p: (p[0], H(*p) + 26, p[1]))(W(PD.WEHRTURM)), "Wehrturm", 40)
schild("SchildRondell", BG, *(lambda p: (p[0], H(*p) + 26, p[1]))(W(PD.RONDELL)), "Rondell", 40)

# Die Hofmauern sind nur so hoch, dass die Häuser an ihnen mit Obergeschossen und Dächern darüber hinausragen
# (wie im Referenzbild); höher sind die Ringmauer außen und die Türme.
# --- I. Vorburg (12. Jh.) mit zwei Rundtürmen ---
VB = PD.VORBURG + [PD.VORBURG[0]]
mauerring("Vorburg", BG, WL(VB), 6.0, dicke=3.0, mitte=W(PD.OVAL_VORBURG[0]),
         tore=tore_an(VB, (PD.TORE["Tor zur Vorburg"], 5.0, "Tor zur Vorburg"),
                      (PD.TORE["Tor des II. Burghofs"], 5.0, "")))
_vt = []
for pp, r in [((318, 250), 7.0), ((350, 358), 5.5)]:
    x, z = W(PD.ecke(pp))
    _vt += [x, z, H(x, z) - 8, PD.H_VORBURG + 13, r, 1, r * 1.6]
N("VorburgTuerme", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_vt)})""")
for k, bau in enumerate(PD.VORBURG_BAUTEN):
    gebaeude(f"Vorburgbau{k}", BG, bau, 7, PD.H_VORBURG, dach="Material_dach", zweck=(5, 4)[k])   # Gesindehaus, Stall
schild("SchildVorburg", BG, *(lambda p: (p[0], PD.H_VORBURG + 9, p[1]))(W((390, 300))), "I. Vorburg", 40)

# Sperrmauer im Zwinger westlich der Vorburg: Von Westen kommt man nicht unter die Vorburg, nur vom Rampentor her
mauerring("Sperrmauer", BG, WL(PD.SPERRMAUER), 7.0, dicke=2.5, mitte=W((300, 380)))

# --- II. Burghof (14. Jh.); die Wand zur Vorburg gehört zur Vorburg ---
B2 = PD.BURGHOF2 + [PD.BURGHOF2[0]]          # oval, mit eigenen Toren zur Vorburg und zum III. Burghof
mauerring("BurghofZwei", BG, WL(B2), 6.5, dicke=3.0, mitte=W(PD.OVAL_BURGHOF2[0]),
         tore=tore_an(B2, (PD.TORE["Rampentor"], 5.0, "Rampentor"), (PD.TORE["Tor des III. Burghofs, Westseite"], 6.0, "", None, False),
                      (PD.TORE["Tor des II. Burghofs, Ostseite"], 5.0, "", None, False)))   # die Tortürme stehen an der Nachbarmauer
# Torrampe im II. Burghof: Futtermauern mit Brüstung zu beiden Seiten, vom Fuß bis an das Tor zum III. Burghof
_rp = WL(PD.WEG_BURG[PD.RAMPE_III:])
_rh = PD.WEG_BURG_HOEHEN[PD.RAMPE_III:]
_rm = []
_ende = PD.welt(PD.TORE["Tor des III. Burghofs, Westseite"])
_rampe_zu = WL([PD.WEG_BURG[PD.RAMPE_III - 1], PD.WEG_BURG[PD.RAMPE_III]])


def _abstand_strecke(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / (dx * dx + dz * dz)))
    return math.dist(p, (a[0] + dx * t, a[1] + dz * t))
for i_ in range(len(_rp) - 1):
    (ax_, az_), (bx_, bz_) = _rp[i_], _rp[i_ + 1]
    l_ = math.hypot(bx_ - ax_, bz_ - az_)
    if l_ < 0.5:
        continue
    ux_, uz_ = (bx_ - ax_) / l_, (bz_ - az_) / l_
    n_ = max(1, math.ceil(l_ / 2.5))
    for k_ in range(n_):
        t0_, t1_ = k_ / n_, (k_ + 1) / n_
        h0_ = _rh[i_] + (_rh[i_ + 1] - _rh[i_]) * t0_
        h1_ = _rh[i_] + (_rh[i_ + 1] - _rh[i_]) * t1_
        p0_ = (ax_ + (bx_ - ax_) * t0_, az_ + (bz_ - az_) * t0_)
        p1_ = (ax_ + (bx_ - ax_) * t1_, az_ + (bz_ - az_) * t1_)
        if h1_ < PD.H_BURGHOF2 + 0.4 or math.dist(p0_, _ende) < 2.5:
            continue
        for e_ in (-1, 1):
            nx_, nz_ = -uz_ * e_, ux_ * e_
            o_ = 4.2
            # nicht quer über den Weg, der unten am Fuß der Rampe ankommt
            m_ = ((p0_[0] + p1_[0]) / 2 + nx_ * o_, (p0_[1] + p1_[1]) / 2 + nz_ * o_)
            if _abstand_strecke(m_, *_rampe_zu) < 3.0:
                continue
            # die Stücke überlappen leicht, damit an den Knicken keine Fuge bleibt
            _rm += [p0_[0] + nx_ * o_ - ux_ * 0.3, p0_[1] + nz_ * o_ - uz_ * 0.3, p1_[0] + nx_ * o_ + ux_ * 0.3, p1_[1] + nz_ * o_ + uz_ * 0.3,
                    PD.H_BURGHOF2 - 1.5, round(max(h0_, h1_) + 1.0, 2), 1.2, nx_, nz_, 0]
N("TorrampeIII", "Node3D", BG, f"""script = ExtResource("28_burgbau")
mauern = PackedFloat32Array({_zahlen([round(v_, 3) for v_ in _rm])})""")

# Rundtürme mit Kegeldach an den Ecken des II. und III. Burghofs
_bt = []
for pp in [(530, 192), (600, 182), (650, 136), (838, 134), (842, 310), (668, 318)]:
    _bt += turmmasse(PD.ecke(pp), 4.5, 13) + [4.5, 1, 7.5]
N("BurghofTuerme", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_bt)})""")
for k, bau in enumerate(PD.BURGHOF2_BAUTEN):
    gebaeude(f"Burghof2Bau{k}", BG, bau, 8, PD.H_BURGHOF2, zweck=5)
schild("SchildBurghof2", BG, *(lambda p: (p[0], PD.H_BURGHOF2 + 9, p[1]))(W((560, 262))), "II. Burghof", 40)

# --- III. Burghof (oval, der Hof aus Akt I ist ins Ordensvorwerk vor der Stadt gezogen) ---
B3 = PD.BURGHOF3 + [PD.BURGHOF3[0]]          # oval; berührt den II. Burghof am Tor des III. Burghofs
mauerring("BurghofDrei", BG, WL(B3), 7.0, dicke=3.0, mitte=MITTE_BURG,
         tore=tore_an(B3, (PD.TORE["Burgtor"], 6.0, "Burgtor"), (PD.TORE["Tor des III. Burghofs"], 6.0, "")))
for k, bau in enumerate(PD.BURGHOF3_BAUTEN):
    gebaeude(f"Burghof3Bau{k}", BG, bau, 9, PD.H_KERNHOF, zweck=(5, 1)[k])   # Heilstube und Ordenshaus, Küche
schild("SchildBurghof3", BG, 0, PD.H_KERNHOF + 13, -36, "III. Burghof", 40)

# --- Zwinger und Kernburg ---
ZW = PD.ZWINGER_KERNBURG[PD.ZWINGER_BOGEN - 1:] + PD.ZWINGER_KERNBURG[:1]   # bis an den III. Burghof, dessen Ostbogen dazwischen liegt
mauerring("Zwingermauer", BG, WL(ZW), 8.0, dicke=3.0, mitte=W((990, 220)), turm_r=0.0)
# Quermauer im südlichen Zwinger: Dort endet der Zwingerweg oben, westlich davon liegt der Zwinger unten
mauerring("Quermauer", BG, WL([(945, 296), (945, 340)]), 6.0, dicke=2.5, mitte=W((990, 220)))
_zt = []
for pp in [(965, 88), (1152, 130), (1112, 322), (895, 332)]:
    _zt += turmmasse(pp, 4.5, 12) + [4.5, 1, 8]
KB = PD.KERNBURG + [PD.KERNBURG[0]]
mauerring("Kernburg", BG, WL(KB), 8.0, dicke=3.5, mitte=W(PD.OVAL_KERNBURG[0]),
         tore=tor_an(KB, PD.TORE["Kernburgtor"], 5.0, "Kernburgtor"))
for pp in [(912, 138), (1100, 150), (1102, 280), (896, 288)]:
    m = turmmasse(PD.ecke(pp), 4.5, 0)
    _zt += m[:3] + [PD.H_KERNBURG + 17, 4.5, 1, 9]
N("KernburgTuerme", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_zt)})""")

# Bergfried der Kernburg (wie im Referenzbild): sehr hoher, schlichter Vierkantturm mit Zinnenkrone, mittig hinter dem Palas
bx, bz = W(PD.BERGFRIED_KERNBURG)
N("BergfriedKernburg", "Node3D", BG, f"""script = ExtResource("28_burgbau")
torbauten = PackedFloat32Array({_zahlen([bx, bz, 1, 0, PD.H_KERNBURG - 3, PD.H_BERGFRIEDFELS + PD.BERGFRIED_HOEHE, PD.BERGFRIED_SEITE, PD.BERGFRIED_SEITE, 1, -1])})""")
schild("SchildBergfriedKernburg", BG, bx, PD.H_BERGFRIEDFELS + PD.BERGFRIED_HOEHE + 12, bz, "Bergfried", 56)
# Fahne auf dem Bergfried (der Turm selbst bleibt schlicht wie im Referenzbild)
FAHNEN.extend([bx, PD.H_BERGFRIEDFELS + PD.BERGFRIED_HOEHE + 0.05, bz, 30, 3.6, 6.0, 0])

# Palas: drei Geschosse mit gotischen Doppelfenstern, steiles Schieferdach; am Westende ein schlanker Rundturm
gebaeude("Palas", BG, PD.PALAS, 16, PD.H_KERNBURG, mat="Material_hell", dachhoehe=11, art=3, zweck=3)
# Links vorn am Palas ein runder Eckturm mit Kegeldach, rechts ein eckiger Turmbau mit Zinnen und einem Ecktürmchen
_pt = turmmasse((951, 192), 4.2, 0)
_pk = turmmasse((1044, 186), 2.2, 0)
N("PalasTurm", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_pt[:3] + [PD.H_KERNBURG + 25, 4.2, 1, 9] + _pk[:3] + [PD.H_KERNBURG + 27, 2.2, 1, 5])})
torbauten = PackedFloat32Array({_zahlen([*W((1035, 175)), 1, 0, PD.H_KERNBURG - 3, PD.H_KERNBURG + 23, 9, 9, 1, 0])})""")
gebaeude("Drachenkapelle", BG, PD.DRACHENKAPELLE, 11, PD.H_KERNBURG, mat="Material_hell", art=1, dachhoehe=8)
gebaeude("Burgkueche", BG, PD.BURGKUECHE, 7, PD.H_KERNBURG, dach="Material_dach", zweck=1)
gebaeude("Zeughaus", BG, PD.ZEUGHAUS, 8, PD.H_KERNBURG, zweck=2)
# --- Weitere Bauten an den Hofmauern (wie im Referenzbild): Reihen von Wirtschafts- und Wohnbauten innen an den Mauern
# der Vorburg, des II. Burghofs und der Kernburg. Frei bleiben Tore, Wege, Türme, die vorhandenen Bauten und die Plätze
# vor ihren Türen, der Übungsplatz und der Felssockel des Bergfrieds. Massiv (nicht begehbar), Tür zum Hof.
def _rechteck_plan(mx, my, laenge, tiefe, ux, uy):
    nx_, ny_ = -uy, ux
    return [(mx + ux * a_ * laenge / 2 + nx_ * b_ * tiefe / 2, my + uy * a_ * laenge / 2 + ny_ * b_ * tiefe / 2)
            for a_, b_ in ((-1, -1), (1, -1), (1, 1), (-1, 1))]

def _ueberlappt(r1, r2):
    for poly in (r1, r2):
        for i in range(len(poly)):
            (x1, z1), (x2, z2) = poly[i], poly[(i + 1) % len(poly)]
            nx_, nz_ = z2 - z1, x1 - x2
            p1 = [nx_ * x + nz_ * z for x, z in r1]
            p2 = [nx_ * x + nz_ * z for x, z in r2]
            if max(p1) <= min(p2) or max(p2) <= min(p1):
                return False
    return True

def _im(p, poly):
    x, z = p; innen = False
    for (x1, z1), (x2, z2) in zip(poly, poly[1:] + poly[:1]):
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
            innen = not innen
    return innen

def _abst_linie(p, a, b):
    ax, ay = a; bx_, by_ = b
    dx, dy = bx_ - ax, by_ - ay
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / max(dx * dx + dy * dy, 1e-9)))
    return math.hypot(p[0] - ax - t * dx, p[1] - ay - t * dy)

def _bau_plan(bau, rand=0.0):
    (pp, laenge, breite, dreh) = bau
    a_ = math.radians(dreh)
    return _rechteck_plan(pp[0], pp[1], laenge + 2 * rand, breite + 2 * rand, math.cos(a_), math.sin(a_))

_HOF_SPERREN = [_bau_plan(b_, 4) for b_ in PD.VORBURG_BAUTEN + PD.BURGHOF2_BAUTEN + PD.BURGHOF3_BAUTEN + [PD.PALAS, PD.DRACHENKAPELLE, PD.BURGKUECHE, PD.ZEUGHAUS]]
# Plätze vor den Türen der begehbaren Bauten (Tür mitten auf der Längsseite +x lokal, bei der Kapelle am Giebel)
for b_ in PD.VORBURG_BAUTEN + PD.BURGHOF2_BAUTEN + PD.BURGHOF3_BAUTEN + [PD.PALAS, PD.BURGKUECHE, PD.ZEUGHAUS]:
    (pp_, l_, br_, dr_) = b_
    d_ = (-math.sin(math.radians(dr_)), math.cos(math.radians(dr_)))
    _HOF_SPERREN.append(_rechteck_plan(pp_[0] + d_[0] * (br_ / 2 + 9), pp_[1] + d_[1] * (br_ / 2 + 9), 18, 18, 1, 0))
_kp, _kl, _kb, _kd = PD.DRACHENKAPELLE
_HOF_SPERREN.append(_rechteck_plan(_kp[0] - (_kl / 2 + 9) * math.cos(math.radians(_kd)), _kp[1] - (_kl / 2 + 9) * math.sin(math.radians(_kd)), 18, 18, 1, 0))
_HOF_SPERREN += [_rechteck_plan(951, 192, 22, 22, 1, 0), _rechteck_plan(1037, 178, 26, 26, 1, 0)]   # Palastürme
_HOF_SPERREN += [_rechteck_plan(PD.BERGFRIED_KERNBURG[0], PD.BERGFRIED_KERNBURG[1], PD.BERGFRIED_SEITE * 2 + 6, PD.BERGFRIED_SEITE * 2 + 6, 1, 0),
                 _rechteck_plan(960, 225, 36, 36, 1, 0)]                       # Bergfriedfels, Übungsplatz
_HOF_TUERME = [PD.plan((_tuerme[i], _tuerme[i + 1])) for i in range(0, len(_tuerme), 7)] + \
              [PD.plan((_vt[i], _vt[i + 1])) for i in range(0, len(_vt), 7)] + \
              [PD.plan((_bt[i], _bt[i + 1])) for i in range(0, len(_bt), 7)] + \
              [PD.plan((_zt[i], _zt[i + 1])) for i in range(0, len(_zt), 7)]
_HOF_WEGE = [w_ for w_ in PD.BURGWEGE]
# III. Burghof: frei in der Mitte, quer hindurch vom Tor des III. Burghofs zum Burgtor
_HOF_WEGE.append([PD.TORE["Tor des III. Burghofs"], PD.TORE["Burgtor"]])   # quer über den III. Burghof
# Kernburg: vom Kernburgtor über den Hof zum Übungsplatz und vor die Kapelle
_HOF_WEGE.append([PD.TORE["Kernburgtor"], (1040, 240), (990, 225), (940, 225)])
_HOF_WEGE.append([(1040, 240), (1060, 200)])
random.seed(4711)
_hofbauten = []

# Hofgebäude wie im Referenzbild: geschlossene Reihen von Fachwerkhäusern (unten Stein, oben Fachwerk) eng an den
# Mauern, Rücken zur Mauer, Tür zum Hof; in der Mitte bleibt der Hof frei. Gebaut von szenen/welt/stadthaeuser.gd.
import re as _re
_FORMEN = [(float(b_), float(t_)) for b_, t_ in _re.findall(r"\[(\d+\.\d+), (\d+\.\d+), \d, \d, (?:true|false), \d, \d\]",
           (REPO / "szenen" / "welt" / "stadthaeuser.gd").read_text(encoding="utf-8"))]
_STEIN_FORMEN = [k_ for k_ in range(len(_FORMEN)) if _FORMEN[k_][1] <= 10.0]    # nicht zu tief für die Höfe
HOFHAEUSER = []          # (x, y, z, Gier, Form)

def _punkt_auf(pk, laengen, s_):
    """Punkt auf dem geschlossenen Linienzug pk bei Bogenlänge s_."""
    gesamt = laengen[-1]
    s_ %= gesamt
    for k_ in range(len(pk) - 1):
        if s_ <= laengen[k_ + 1]:
            t_ = (s_ - laengen[k_]) / max(laengen[k_ + 1] - laengen[k_], 1e-9)
            return (pk[k_][0] + (pk[k_ + 1][0] - pk[k_][0]) * t_, pk[k_][1] + (pk[k_ + 1][1] - pk[k_][1]) * t_)
    return pk[-1]


def hofbauten(name, poly, boden, rand_mauer=0.6):
    """Ein geschlossener Ring von Häusern entlang der ganzen Hofmauer (auch um die Rundungen), Lücken nur an Toren,
    Türmen, Wegen und vor den Türen der großen Bauten."""
    n_ = 0
    pk = poly + [poly[0]]
    flaeche = sum(a_[0] * b_[1] - b_[0] * a_[1] for a_, b_ in zip(pk, pk[1:]))
    laengen = [0.0]
    for a_, b_ in zip(pk, pk[1:]):
        laengen.append(laengen[-1] + math.dist(a_, b_))
    s_ = 0.0
    while s_ < laengen[-1] - 6.0:
        form = random.choice(_STEIN_FORMEN)
        b, t = _FORMEN[form]
        laenge, tiefe = b / M, (t + 0.7) / M
        pa, pb = _punkt_auf(pk, laengen, s_), _punkt_auf(pk, laengen, s_ + laenge)
        sehne = math.dist(pa, pb)
        if sehne < laenge * 0.7:
            s_ += 2.0
            continue
        ux, uy = (pb[0] - pa[0]) / sehne, (pb[1] - pa[1]) / sehne
        nx_, ny_ = (-uy, ux) if flaeche > 0 else (uy, -ux)              # nach innen
        # auf Rundungen etwas weiter hinein, damit die Hausecken nicht in der Mauer stecken
        pm = _punkt_auf(pk, laengen, s_ + laenge / 2)
        bogen = max(0.0, (pm[0] - (pa[0] + pb[0]) / 2) * nx_ + (pm[1] - (pa[1] + pb[1]) / 2) * ny_)
        d_ = 3.0 / M * 0.5 + rand_mauer / M + tiefe / 2 + bogen
        mx, my = (pa[0] + pb[0]) / 2 + nx_ * d_, (pa[1] + pb[1]) / 2 + ny_ * d_
        r_ = _rechteck_plan(mx, my, laenge, tiefe, ux, uy)
        hof = _rechteck_plan(mx + nx_ * (tiefe / 2 + 4), my + ny_ * (tiefe / 2 + 4), laenge * 0.5, 7, ux, uy)
        punkte_ = r_ + [((r_[k_][0] + r_[(k_ + 1) % 4][0]) / 2, (r_[k_][1] + r_[(k_ + 1) % 4][1]) / 2) for k_ in range(4)] + [(mx, my)]
        ok = all(_im(e_, poly) for e_ in r_)
        ok = ok and all(math.dist(e_, t_) > 10.5 for t_ in _HOF_TUERME for e_ in punkte_)
        ok = ok and all(math.dist(e_, t_) > 12.0 for t_ in PD.TORE.values() for e_ in punkte_)
        ok = ok and not any(_ueberlappt(r_, sp) or _ueberlappt(hof, sp) for sp in _HOF_SPERREN + _hofbauten)
        ok = ok and all(_abst_linie(e_, w_[i], w_[i + 1]) > 7 for w_ in _HOF_WEGE for i in range(len(w_) - 1) for e_ in punkte_)
        if ok:
            wx, wz = W((mx, my))
            if max(abs(H(*W(e_)) - boden) for e_ in r_) < 1.5:
                wn = (W((mx + nx_, my + ny_))[0] - wx, W((mx + nx_, my + ny_))[1] - wz)
                gier = math.degrees(math.atan2(wn[0], wn[1]))             # Vorderseite (lokal +z) zum Hof
                HOFHAEUSER.append((round(wx, 2), round(boden, 2), round(wz, 2), round(gier, 1), form))
                _hofbauten.append(_rechteck_plan(mx, my, laenge - 0.4, tiefe - 0.4, ux, uy))   # Nachbarn dürfen anstoßen
                n_ += 1
                s_ += laenge + 0.2
                continue
        s_ += 1.0
    return n_


_nh = [hofbauten("Vorburg", PD.VORBURG, PD.H_VORBURG), hofbauten("II", PD.BURGHOF2, PD.H_BURGHOF2),
       hofbauten("III", PD.BURGHOF3, PD.H_KERNHOF), hofbauten("Kernburg", PD.KERNBURG, PD.H_KERNBURG)]
N("Hofhaeuser", "Node3D", BG, "script = ExtResource(\"27_stadthaeuser\")\nnur_ziegel = true\n"
  + "haeuser = PackedVector4Array(" + ", ".join(f"{x:.5g}, {y:.5g}, {z:.5g}, {g:.4g}" for x, y, z, g, _ in HOFHAEUSER) + ")\n"
  + "formen = PackedInt32Array(" + ", ".join(str(f) for *_, f in HOFHAEUSER) + ")")
print("Hofhäuser an den Mauern (Vorburg, II., III., Kernburg):", _nh)
if os.environ.get("HOF_JSON"): import json as _j; open(os.environ["HOF_JSON"], "w").write(_j.dumps({"neu": _hofbauten, "sperren": _HOF_SPERREN, "tuerme": _HOF_TUERME}))

for name, pp, text in [("SchildPalas", (995, 155), "Palas"), ("SchildKapelle", (1075, 215), "Drachenkapelle"),
                       ("SchildKueche", (905, 252), "Burgküche"), ("SchildZeughaus", (1030, 260), "Zeughaus")]:
    x, z = W(pp)
    schild(name, BG, x, PD.H_KERNBURG + 22, z, text, 40)
schild("SchildKernburg", BG, *(lambda p: (p[0], PD.H_KERNBURG + 10, p[1]))(W((975, 225))), "Kernburg", 44)

# Übungsplatz mit zwei Puppen im Hof der Kernburg (Stufe 4, Kampf)
OB = DS + "/ObererBurg"
UEB = W((960, 225))
N("ObererBurg", "Node3D", DS, T(round(UEB[0], 2), PD.H_KERNBURG, round(UEB[1], 2)))
for k, x in enumerate([-2.5, 2.5]):
    gegner(f"Uebungspuppe{k + 1}", OB, x, 0, 0, "Übungspuppe", waffe="puppe", tracht="0.55, 0.45, 0.3, 1")
schild("SchildUebungsplatz", OB, 0, 3.5, 4, "Übungsplatz", 40)

N("Fahnen", "Node3D", BG, f"""script = ExtResource("28_burgbau")
fahnen = PackedFloat32Array({_zahlen(FAHNEN)})
kollision = false""")

# --- Stadt und Hafen ---
teil("teil_stadt.py")
zinnen_schreiben(DS)
