# ---------- Burgfeste Drachenstein nach dem Grundriss (docs/bilder/grundriss-drachenstein-3.webp) ----------
# Auf dem Felsgrat hintereinander (plan_drachenstein.py und grundriss3.py haben die Planpunkte):
#   Vorburg mit zwei Rundtürmen im Westen · Mittelburg mit dem gebogenen Südflügel · Oberburg mit dem Winkelbau im
#   Nordwesten · Palas mit Bergfried in einem engen Zwinger. Im Norden sind die Mauern von Vorburg und Mittelburg die
#   Außenmauer; die Ringmauer läuft vom Nordwesten über das Nordtor an die Vorburg und hinter Oberburg und Palas herum
#   bis an das Hafentor (Wassertor) und die Mauer zwischen Stadt und Burgbezirk.
# Der Weg hinauf (blau im Plan): Stadt → Vorburgtor → Hof der Vorburg → Osttor → an der Mauer entlang → Rampe →
# Rampentor (Mittelburg) → gleich rechts das Zwingertor → Zwinger an der Südseite der Oberburg → Südtor der Oberburg
# oder der Durchgang → Tor der Oberburg / Palastor. Höhen: Vorburg -8, Mittelburg +6, Oberburg +14, Palas +16.
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
G3M = PD.G3_MASSSTAB * M          # Meter je Bildpunkt des neuen Plans


def turmmasse(pp, r, ueber):
    """Rundturm am Planpunkt: [x, z, unten, oben] – unten unter dem tiefsten Gelände, oben über dem höchsten."""
    x, z = W(pp)
    werte = [H(x + dx, z + dz) for dx in (-r, 0, r) for dz in (-r, 0, r)]
    return [x, z, min(werte) - 2.5, max(werte) + ueber]


def tor_an(punkte, p, breite, name, boden=None, tuerme=None, regel=None):
    """Tor für mauerring: {Kantenindex: (Anteil, Breite, Name)} an der Kante des Linienzugs, die dem Planpunkt p
    am nächsten liegt (punkte und p im Plan). regel: Torflügel (szenen/welt/fluegel.gd), z. B. "zu:eid_waechter"."""
    bester = None
    for i, (a, b) in enumerate(zip(punkte, punkte[1:])):
        dx, dy = b[0] - a[0], b[1] - a[1]
        t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)))
        d = math.dist(p, (a[0] + dx * t, a[1] + dy * t))
        if bester is None or d < bester[0]:
            bester = (d, i, t)
    # tuerme=False: Tor ohne eigene Tortürme (sonst wie in mauerring: Tortürme, außer bei einem Wassertor mit boden)
    rest = () if boden is None and tuerme is None and regel is None else (boden, boden is None if tuerme is None else tuerme, regel)
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


def g3p(p):
    """Bildpunkt des neuen Plans → Weltpunkt."""
    return W(PD.g3(p))


def richtung_welt(dreh):
    """Richtung (Grad im Plan) → Richtung in der Welt (Plan (dx, dy) ist Welt (dy, -dx))."""
    a = math.radians(dreh)
    return (round(math.sin(a), 4), round(-math.cos(a), 4))


def eckturm(pp, seite, ueber, dach=1, dreh=0.0):
    """Eckiger Turm (Torbau ohne Durchgang) am Planpunkt, Seite in Metern, Zeltdach (dach 1) oder Zinnen (0);
    dreh: Richtung einer Seite im Plan (Grad)."""
    x, z = W(pp)
    werte = [H(x + dx, z + dz) for dx in (-seite / 2, 0, seite / 2) for dz in (-seite / 2, 0, seite / 2)]
    return [x, z, *richtung_welt(dreh), min(werte) - 3, max(werte) + ueber, seite, seite, 1, dach]


MITTE_BURG = W(PD.MITTE_OBERBURG)
# Torflügel (szenen/welt/fluegel.gd): Stadttore und das Vorburgtor stehen tagsüber offen und werden nachts und bei Alarm
# geschlossen; die Tore weiter hinein in die Burg bleiben zu. Leuten der Burg öffnet die Wache immer, dem Spieler erst,
# wenn er den Eid als Wächter geleistet hat.
TAG = "tag:eid_waechter"
ZU = "zu:eid_waechter"
# Fahnen und Banner (szenen/welt/burgbau.gd, "fahnen"): x, y, z, Gier, Breite, Länge, Art (0 Mast, 1 Banner an der Wand)
FAHNEN = []
_HOF_TUERME = []            # Planpunkte aller Türme an den Höfen (für den Felssockel in teil_felsen.py)

# --- Ringmauer ---
# Niedriger als die Burgmauern (wie im Referenzbild), mit halbrunden, innen offenen Schalentürmen; an den Ecken im
# Nordosten und Südosten geschlossene Bastionen mit Zinnen, der Turm hinter der Oberburg mit Kegeldach
RN = PD.RING_NORD
mauerring("RingmauerNord", BG, WL(RN), 6.5, dicke=3.0, mitte=W(PD.MITTE_VORBURG),
         tore=tor_an(RN, PD.TORE["Nordtor"], 5.0, "Nordtor", regel=TAG))
RSO = PD.RING_SUED_OST
mauerring("Ringmauer", BG, WL(RSO), 6.5, dicke=3.0, mitte=MITTE_BURG,
         tore=tor_an(RSO, PD.TORE["Hafentor"], 10.0, "Hafentor", -19.6))
# Mauerwachen auf dem Wehrgang der Ringmauer: auf jedem fünften langen Mauerstück eine Wache, mit Blick nach außen
# (die Personen selbst setzt region_drachenstein.py, wenn es den Knoten "Personen" gibt)
MAUERWACHEN = []
_rs = [m_ for m_ in MAUERSTUECKE if m_[0] in ("Ringmauer", "RingmauerNord") and math.dist(m_[1:3], m_[3:5]) > 10.0]
for k_, (_, ax_, az_, bx_, bz_, oben_, dicke_, aussen_) in enumerate(_rs):
    if k_ % 4 != 2 or len(MAUERWACHEN) >= 8:
        continue
    mx_, mz_ = (ax_ + bx_) / 2 - aussen_[0] * 0.4, (az_ + bz_) / 2 - aussen_[1] * 0.4
    MAUERWACHEN.append((round(mx_, 2), round(oben_ + 0.1, 2), round(mz_, 2), round(math.degrees(math.atan2(aussen_[0], aussen_[1])), 1)))
print("Mauerwachen:", len(MAUERWACHEN))
_tuerme = []
_ring_w = WL(RN) + WL(RSO)
for (gp, gr) in PD.G3.RING_TUERME:
    pp = PD.g3(gp)
    x, z = W(pp)
    r = round(max(3.5, gr * G3M), 1)
    unten = min(H(x + dx, z + dz) for dx in (-r, 0, r) for dz in (-r, 0, r)) - 2.5
    if gr >= 25 or gp in ((1207, 205), (735, 212)):          # Ecktürme geschlossen, sonst klafft die Ecke
        # Bastionen an den Ecken und der Turm hinter der Oberburg: geschlossen und hoch, mit Fahne
        oben = max(H(x + dx, z + dz) for dx in (-r, 0, r) for dz in (-r, 0, r)) + (14 if gr >= 25 else 16)
        _tuerme += [x, z, unten, oben, r, 0 if gr >= 25 else 1, 0 if gr >= 25 else r * 1.8]
        if gr >= 25:
            FAHNEN.extend([x, oben + 0.05, z, 30, 2.4, 3.8, 0])
        continue
    # Schalenturm: offen zur Innenseite der Mauer (Richtung von der nächsten Mauerkante nach innen)
    _best = min([(i_, l_) for l_ in (WL(RN), WL(RSO)) for i_ in range(len(l_) - 1)],
                key=lambda il: abstand_linie([il[1][il[0]], il[1][il[0] + 1]], x, z))
    (ax_, az_), (bx_, bz_) = _best[1][_best[0]], _best[1][_best[0] + 1]
    l_ = math.hypot(bx_ - ax_, bz_ - az_)
    nx_, nz_ = -(bz_ - az_) / l_, (bx_ - ax_) / l_
    if nx_ * (MITTE_BURG[0] - x) + nz_ * (MITTE_BURG[1] - z) < 0:
        nx_, nz_ = -nx_, -nz_
    oben = max(H(x + nx_ * d_, z + nz_ * d_) for d_ in (2.0, 4.0, 6.0)) + 6.5 + 2.5
    _tuerme += [x, z, unten, oben, r, 2, round(math.degrees(math.atan2(nz_, nx_)), 1)]
# Torhäuser im Nordwesten und Südwesten der Stadt: eckige Türme mit Zeltdach über der Mauer
_torhaeuser = []
for (gp, gs) in [PD.G3.TORHAUS_NW, PD.G3.TORHAUS_SW]:
    _torhaeuser += eckturm(PD.g3(gp), round(gs * G3M, 1), 13, 1, 45)
N("RingmauerTuerme", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_tuerme)})
torbauten = PackedFloat32Array({_zahlen(_torhaeuser)})""")

# Die Hofmauern sind nur so hoch, dass die Häuser an ihnen mit Obergeschossen und Dächern darüber hinausragen
# (wie im Referenzbild); höher sind die Türme.
# --- Vorburg: Tor in der Südmauer von der Stadt, Osttor hinab in den Burgbezirk ---
VB = PD.VORBURG + [PD.VORBURG[0]]
mauerring("Vorburg", BG, WL(VB), 6.0, dicke=3.0, mitte=W(PD.MITTE_VORBURG),
         tore=tore_an(VB, (PD.TORE["Vorburgtor"], 4.5, "Vorburgtor", None, False, TAG),
                      (PD.TORE["Osttor der Vorburg"], 4.0, "", None, False, ZU)))
_vt = []
for (gp, gr) in PD.G3.VORBURG_TUERME + [PD.G3.VORBURG_TOR]:
    r = round(gr * G3M, 1)
    pp = PD.g3(gp)
    m = turmmasse(pp, r, 0)
    _vt += m[:3] + [PD.H_VORBURG + 14, r, 1, r * 1.7]
    _HOF_TUERME.append(pp)
N("VorburgTuerme", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_vt)})""")
schild("SchildVorburg", BG, *(lambda p: (p[0], PD.H_VORBURG + 9, p[1]))(W(PD.MITTE_VORBURG)), "Vorburg", 40)


def bruestung(name, linie, hoehen, abstand, ab=None, nicht_bei=()):
    """Niedrige Futtermauern mit Brüstung zu beiden Seiten eines Wegs (Rampe, gemauerter Weg)."""
    pkt, mauern = WL(linie), []
    for i_ in range(len(pkt) - 1):
        (ax_, az_), (bx_, bz_) = pkt[i_], pkt[i_ + 1]
        l_ = math.hypot(bx_ - ax_, bz_ - az_)
        if l_ < 0.5:
            continue
        ux_, uz_ = (bx_ - ax_) / l_, (bz_ - az_) / l_
        n_ = max(1, math.ceil(l_ / 2.5))
        for k_ in range(n_):
            t0_, t1_ = k_ / n_, (k_ + 1) / n_
            h0_ = hoehen[i_] + (hoehen[i_ + 1] - hoehen[i_]) * t0_
            h1_ = hoehen[i_] + (hoehen[i_ + 1] - hoehen[i_]) * t1_
            p0_ = (ax_ + (bx_ - ax_) * t0_, az_ + (bz_ - az_) * t0_)
            p1_ = (ax_ + (bx_ - ax_) * t1_, az_ + (bz_ - az_) * t1_)
            if any(math.dist(p0_, W(q)) < 4.0 or math.dist(p1_, W(q)) < 4.0 for q in nicht_bei):
                continue
            for e_ in (-1, 1):
                nx_, nz_ = -uz_ * e_, ux_ * e_
                unten_ = min(H(p0_[0] + nx_ * (abstand + 2), p0_[1] + nz_ * (abstand + 2)), h0_) - 3.0
                mauern += [p0_[0] + nx_ * abstand - ux_ * 0.3, p0_[1] + nz_ * abstand - uz_ * 0.3,
                           p1_[0] + nx_ * abstand + ux_ * 0.3, p1_[1] + nz_ * abstand + uz_ * 0.3,
                           round(unten_, 2), round(max(h0_, h1_) + 1.0, 2), 1.2, nx_, nz_, 0]
    N(name, "Node3D", BG, f"""script = ExtResource("28_burgbau")
mauern = PackedFloat32Array({_zahlen([round(v_, 3) for v_ in mauern])})""")


# Gemauerter Weg vom Osttor der Vorburg hinab und die Rampe hinauf zur Mittelburg: Futtermauern mit Brüstung
_vw = PD.WEG_VORBURG[PD.WEG_VORBURG.index(PD.TORE["Osttor der Vorburg"]):]
bruestung("WegVorburgOst", _vw, PD.WEG_VORBURG_HOEHEN[-len(_vw):], 3.6, nicht_bei=[_vw[0], _vw[-1]])
_ri = len(PD.G3.WEG_UNTEN) - 1
bruestung("Rampe", PD.WEG_BURG[_ri:], PD.WEG_BURG_HOEHEN[_ri:], 4.0, nicht_bei=[PD.WEG_BURG[_ri], PD.TORE["Rampentor"]])

# --- Mittelburg: Rampentor an der Südostecke, gleich rechts das Zwingertor ---
MB = PD.MITTELBURG + [PD.MITTELBURG[0]]
mauerring("Mittelburg", BG, WL(MB), 6.5, dicke=3.0, mitte=W(PD.MITTE_MITTELBURG),
         tore=tore_an(MB, (PD.TORE["Rampentor"], 5.0, "Rampentor", None, None, ZU), (PD.TORE["Zwingertor"], 4.5, "", None, False, ZU)))
_mt = []
_g, _r = PD.G3.MITTELBURG_ECKTURM
_mt += turmmasse(PD.g3(_g), round(_r * G3M, 1), 0)[:3] + [PD.H_BURGHOF2 + 13, round(_r * G3M, 1), 1, round(_r * G3M * 1.7, 1)]
_HOF_TUERME.append(PD.g3(_g))
N("MittelburgTuerme", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_mt)})
torbauten = PackedFloat32Array({_zahlen(eckturm(PD.g3(PD.G3.MITTELBURG_NORDTURM), 7.0, 15, 1, 30))})""")
_HOF_TUERME.append(PD.g3(PD.G3.MITTELBURG_NORDTURM))
schild("SchildMittelburg", BG, *(lambda p: (p[0], PD.H_BURGHOF2 + 9, p[1]))(W(PD.MITTE_MITTELBURG)), "Mittelburg", 40)

# --- Zwinger der Oberburg: die Zwingermauer im Süden, niedriger als die Hofmauer ---
mauerring("ZwingermauerSued", BG, WL(PD.ZWINGERMAUER_SUED), 4.5, dicke=2.5, mitte=MITTE_BURG)

# --- Oberburg: Südtor vom Ende des Zwingers, Tor der Oberburg zum Durchgang ---
OB = PD.OBERBURG + [PD.OBERBURG[0]]
mauerring("Oberburg", BG, WL(OB), 7.0, dicke=3.0, mitte=MITTE_BURG,
         tore=tore_an(OB, (PD.TORE["Südtor der Oberburg"], 4.5, "", None, None, ZU),
                      (PD.TORE["Tor der Oberburg"], 5.0, "Tor der Oberburg", None, False, ZU)))   # ohne Tortürme: der Durchgang bleibt frei
# Torhaus über dem Südtor (wie im Plan des Spielers: der Weg führt unter einem Gebäude hindurch in die Oberburg): ein
# Fachwerkhaus auf dem Torbogen zwischen den beiden Tortürmen
_st_ = [t_ for t_ in MAUERSTUECKE if t_[0] == "Oberburg"]
_sx, _sz = W(PD.TORE["Südtor der Oberburg"])
_s_oben = max(o_ for _, ax_, az_, bx_, bz_, o_, *_ in _st_ if min(math.dist((ax_, az_), (_sx, _sz)), math.dist((bx_, bz_), (_sx, _sz))) < 12.0)
_s_kante = min(_st_, key=lambda t_: abstand_linie([t_[1:3], t_[3:5]], _sx, _sz))
_s_u = (_s_kante[3] - _s_kante[1], _s_kante[4] - _s_kante[2])
_s_g = math.degrees(math.atan2(_s_u[0], _s_u[1]))
N("TorhausOberburg", "Node3D", BG, f"""script = ExtResource("28_burgbau")
gebaeude = PackedFloat32Array({_zahlen([round(_sx, 2), round(_sz, 2), round(_s_g, 2), 6.2, 9.0, round(_s_oben + 0.1, 2), round(_s_oben, 2), 4.2, 3.4, 3, 1, 0])})""")
# Der Durchgang zwischen den Toren von Oberburg und Palas: im Norden zu, im Süden die Mauer zum Ende des Zwingers
mauerring("DurchgangNord", BG, WL(PD.DURCHGANG_NORD), 6.0, dicke=2.5, mitte=W(PD.TORE["Tor der Oberburg"]))
mauerring("DurchgangSued", BG, WL(PD.DURCHGANG_SUED), 6.0, dicke=2.5, mitte=W(PD.TORE["Tor der Oberburg"]))
# Vortor: gebogene, niedrige Mauer um den Platz vor dem Südtor, nach Osten offen
mauerring("Vortor", BG, WL(PD.VORTOR), 3.5, dicke=2.5, mitte=W(PD.TORE["Südtor der Oberburg"]))
# Im engen Zwinger des Palas: Mauer zwischen dem Weg vom Zwingertor zum Palastor und dem Weg um den Palas
mauerring("PalaszwingerQuer", BG, WL(PD.PALASZWINGER_QUER), 5.0, dicke=2.5, mitte=W(PD.TORE["Palastor"]))
_ot = []
for (gp, gr) in PD.G3.OBERBURG_TUERME:
    r = round(max(2.5, gr * G3M), 1)
    _ot += turmmasse(PD.g3(gp), r, 0)[:3] + [PD.H_KERNHOF + (12 if gr > 8 else 10), r, 1, round(r * 1.8, 1)]
    _HOF_TUERME.append(PD.g3(gp))
_gp, _gs = PD.G3.OBERBURG_TORTURM
N("OberburgTuerme", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_ot)})
torbauten = PackedFloat32Array({_zahlen(eckturm(PD.g3(_gp), round(_gs * G3M, 1), 14, 0, 30))})""")
_HOF_TUERME.append(PD.g3(_gp))
schild("SchildOberburg", BG, *(lambda p: (p[0], PD.H_KERNHOF + 13, p[1]))(W(PD.MITTE_OBERBURG)), "Oberburg", 40)

# --- Palas: zwei Mauerringe dicht hintereinander (wie im Referenzbild), die Tore gegenüber dem Tor der Oberburg ---
ZW = PD.ZWINGER_KERNBURG + [PD.ZWINGER_KERNBURG[0]]
mauerring("Zwingermauer", BG, WL(ZW), 6.0, dicke=3.0, mitte=W(PD.MITTE_PALAS),
         tore=tore_an(ZW, (PD.TORE["Zwingertor des Palas"], 5.0, "", None, False, ZU), (PD.TORE["Zwingerpforte des Palas"], 3.5, "", None, False, ZU)))
KB = PD.PALAS_HOF + [PD.PALAS_HOF[0]]
# Im Bergfried steht keine Hofmauer: er hat eigene, hohle Mauern (begehbar)
_bfa = math.radians(PD.BERGFRIED_DREH)
_bfh = PD.BERGFRIED_SEITE / M / 2 - 1.2
_bf_ecken = [W((PD.BERGFRIED_KERNBURG[0] + (math.cos(_bfa) * sx - math.sin(_bfa) * sy) * _bfh,
                PD.BERGFRIED_KERNBURG[1] + (math.sin(_bfa) * sx + math.cos(_bfa) * sy) * _bfh)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
mauerring("Kernburg", BG, WL(KB), 8.0, dicke=3.5, mitte=W(PD.MITTE_PALAS), aussparen=[_bf_ecken],
         tore=tor_an(KB, PD.TORE["Palastor"], 5.0, "Palastor", regel=ZU))
_zt = []
for (gp, gr) in PD.G3.PALAS_ZWINGER_TUERME:
    r = round(max(3.5, gr * G3M), 1)
    _zt += turmmasse(PD.g3(gp), r, 9) + [r, 0, 0]          # Zwingertürme mit Zinnen
    _HOF_TUERME.append(PD.g3(gp))
for (gp, gr) in PD.G3.PALAS_TUERME:
    r = round(max(3.0, gr * G3M), 1)
    _zt += turmmasse(PD.g3(gp), r, 0)[:3] + [PD.H_KERNBURG + 20, r, 1, round(r * 2.0, 1)]   # Kegeldächer am Palas
    _HOF_TUERME.append(PD.g3(gp))
_eb = PD.PALAS_ECKBAU
N("KernburgTuerme", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_zt)})
torbauten = PackedFloat32Array({_zahlen(eckturm(_eb[0], round(_eb[1] * M, 1), 23, 0, _eb[3]))})""")
_HOF_TUERME.append(_eb[0])

# Bergfried (wie im Referenzbild): sehr hoher, schlichter Vierkantturm mit Zinnenkrone, an der Nordmauer hinter dem Palas
bx, bz = W(PD.BERGFRIED_KERNBURG)
# Begehbar (Dach -2): hohle Mauern, die Tür auf der Seite zum Hof neben dem Palas (Welt -u); innen baut turm.gd
# Böden, Treppenhaus und eine Wendelrampe bis auf die Plattform unter der Krone.
_bu = richtung_welt(PD.BERGFRIED_DREH)                  # Welt u (entlang der Nordostmauer)
_bn = (-_bu[1], _bu[0])                                  # Welt n
N("BergfriedKernburg", "Node3D", BG, f"""script = ExtResource("28_burgbau")
hohl_boden = {PD.H_KERNBURG}
torbauten = PackedFloat32Array({_zahlen([bx, bz, round(_bn[0], 4), round(_bn[1], 4), PD.H_KERNBURG - 3, PD.H_BERGFRIEDFELS + PD.BERGFRIED_HOEHE, PD.BERGFRIED_SEITE, PD.BERGFRIED_SEITE, -1, -2])})""")
_bh = PD.H_BERGFRIEDFELS + PD.BERGFRIED_HOEHE - PD.H_KERNBURG
_bstufe = _bh / 8
_tuer_w = round(math.degrees(math.atan2(-_bu[1], -_bu[0])), 2)
_innen = PD.BERGFRIED_SEITE / 2 - 2.5 + 0.3
# Wendeltreppe in der hinteren linken Ecke (vom Eingang gesehen), eng und mit zwei Windungen je Geschoss: der Raum
# bleibt frei. Das Treppenhaus ragt 0,4 m in die Mauern, seine Tür zeigt zur Mitte des Raums.
_tr_r = 2.5
_tr_ecke = _tuer_w + 135
_tr_ab = (_innen - _tr_r + 0.4) * math.sqrt(2)
_tr_mitte = (round(_tr_ab * math.cos(math.radians(_tr_ecke)), 3), round(_tr_ab * math.sin(math.radians(_tr_ecke)), 3))
N("BergfriedInnen", "Node3D", BG, f"""transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {bx}, {PD.H_KERNBURG}, {bz})
script = ExtResource("14_turm")
ebenen_nummern = PackedInt32Array(0, 1, 2, 3, 4, 5, 6, 7)
ebenen_namen = PackedStringArray("Eingang", "Wachstube", "Vorratskammer", "Waffenkammer", "Kammer des Komturs", "Archiv", "Glockenstube", "Türmerstube")
boden_hoehen = PackedFloat32Array({", ".join(f"{k * _bstufe:.3f}" for k in range(9))})
aussen_radien = PackedFloat32Array({", ".join([f"{_innen / math.cos(math.pi / 4):.3f}"] * 8)})
wandstaerken = PackedFloat32Array({", ".join(["0.5"] * 8)})
ecken = 4
ohne_mauer = true
achteck_winkel = {_tuer_w}
treppen_winkel = {round(_tr_ecke + 180, 2)}
treppen_mitte = Vector2({_tr_mitte[0]}, {_tr_mitte[1]})
windungen = 2
treppenhaus_radius = {_tr_r}
saeulen_radius = 0.35
material_wand = ExtResource("Material_mauer")
material_boden = ExtResource("Material_boden")
material_rampe = ExtResource("Material_holz")""")
# Einrichtung der Ebenen: in drei Ecken des Raums und an der Rückwand (in der vierten Ecke steht die Wendeltreppe)
BI = BG + "/BergfriedInnen"
def _ecke(k_, r_=7.4):
    if k_ == 1:     # die Ecke der Treppe: statt dessen mitten an der Rückwand
        w_ = math.radians(_tuer_w + 180)
        return (round((_innen - 1.3) * math.cos(w_), 2), round((_innen - 1.3) * math.sin(w_), 2))
    return (round(r_ * math.cos(math.radians(_tuer_w + 45 + 90 * k_)), 2), round(r_ * math.sin(math.radians(_tuer_w + 45 + 90 * k_)), 2))
_drehung = lambda k_: round(-(_tuer_w + 180) - 45, 1) if k_ == 1 else round(-(_tuer_w + 45 + 90 * k_), 1)
for ebene_, teile_ in enumerate([
        [("Bank", 2.6, 0.45, 0.5, "Material_holz"), ("Bank", 2.6, 0.45, 0.5, "Material_holz"), ("Waffen", 1.6, 2.2, 0.4, "Material_metall"), ("Truhe", 1.2, 0.7, 0.8, "Material_holz")],
        [("Tisch", 2.2, 0.8, 1.1, "Material_holz"), ("Bank", 2.2, 0.45, 0.45, "Material_holz"), ("Fass", 0.8, 1.0, 0.8, "Material_holz"), ("Pritsche", 2.0, 0.5, 0.9, "Material_stoff")],
        [("Kisten", 1.6, 1.6, 1.6, "Material_holz"), ("Kisten", 1.6, 1.2, 1.6, "Material_holz"), ("Saecke", 1.4, 0.8, 1.2, "Material_stoff"), ("Faesser", 1.6, 1.0, 1.6, "Material_holz")],
        [("Spiesse", 2.0, 2.6, 0.4, "Material_metall"), ("Ruestung", 0.6, 1.9, 0.6, "Material_metall"), ("Spiesse", 2.0, 2.6, 0.4, "Material_metall"), ("Schilde", 1.6, 1.4, 0.3, "Material_holz")],
        [("Bett", 2.2, 0.6, 1.5, "Material_stoff"), ("Tisch", 1.8, 0.8, 1.0, "Material_holz"), ("Truhe", 1.4, 0.8, 0.8, "Material_holz"), ("Teppich", 2.6, 0.03, 1.8, "Material_stoff")],
        [("Regal", 2.4, 2.6, 0.5, "Material_holz"), ("Pult", 1.4, 1.1, 0.9, "Material_papier"), ("Regal", 2.4, 2.6, 0.5, "Material_holz"), ("Truhe", 1.2, 0.7, 0.8, "Material_holz")],
        [("Glockenstuhl", 2.6, 0.3, 0.3, "Material_holz"), ("Seil", 0.1, 3.0, 0.1, "Material_holz"), ("Kisten", 1.2, 1.0, 1.2, "Material_holz"), ("Bank", 2.0, 0.45, 0.5, "Material_holz")],
        [("Tisch", 1.8, 0.8, 1.0, "Material_holz"), ("Feuerbecken", 1.0, 0.9, 1.0, "Material_metall"), ("Pritsche", 2.0, 0.5, 0.9, "Material_stoff"), ("Fass", 0.8, 1.0, 0.8, "Material_holz")]]):
    y0_ = ebene_ * _bstufe
    for k_, (n_, sx_, sy_, sz_, mat_) in enumerate(teile_):
        x_, z_ = _ecke(k_)
        box(f"E{ebene_}{n_}{k_}", BI, x_, round(y0_ + sy_ / 2, 2), z_, sx_, sy_, sz_, mat_, gier=_drehung(k_) + 45)
    if ebene_ == 6:      # die Glocke hängt über der Mitte des Raums an einem Balken
        x_, z_ = _ecke(0, 6.0)
        zyl("Glocke", BI, x_, round(y0_ + 4.2, 2), z_, 0.9, 1.4, "Material_metall", 12, kollision=False)
BERGFRIED_TUER = (round(bx - _bu[0] * PD.BERGFRIED_SEITE / 2, 2), round(bz - _bu[1] * PD.BERGFRIED_SEITE / 2, 2))
_HOF_TUERME.append(PD.BERGFRIED_KERNBURG)
schild("SchildBergfriedKernburg", BG, bx, PD.H_BERGFRIEDFELS + PD.BERGFRIED_HOEHE + 12, bz, "Bergfried", 56)
FAHNEN.extend([bx, PD.H_BERGFRIEDFELS + PD.BERGFRIED_HOEHE + 0.05, bz, 30, 3.6, 6.0, 0])

# Palas: drei Geschosse mit gotischen Doppelfenstern, steiles Schieferdach, an der Nordostmauer
gebaeude("Palas", BG, PD.PALAS, 16, PD.H_KERNBURG, mat="Material_hell", dachhoehe=11, art=3, zweck=3)
gebaeude("Drachenkapelle", BG, PD.DRACHENKAPELLE, 11, PD.H_KERNBURG, mat="Material_hell", art=1, dachhoehe=8, zweck=6)
gebaeude("Burgkueche", BG, PD.BURGKUECHE, 7, PD.H_KERNBURG, dach="Material_dach", zweck=1)
gebaeude("Zeughaus", BG, PD.ZEUGHAUS, 8, PD.H_KERNBURG, zweck=2)

# --- Begehbare Bauten in den übrigen Höfen (wie bisher je Hof zwei) ---
gebaeude("Vorburgbau0", BG, PD.VORBURG_BAUTEN[0], 7, PD.H_VORBURG, dach="Material_dach", zweck=5)   # Gesindehaus
gebaeude("Vorburgbau1", BG, PD.VORBURG_BAUTEN[6], 7, PD.H_VORBURG, dach="Material_dach", zweck=4)   # Stall
gebaeude("Burghof2Bau0", BG, PD.BURGHOF2_BAUTEN[2], 8, PD.H_BURGHOF2, zweck=5)
gebaeude("Burghof2Bau1", BG, PD.BURGHOF2_BAUTEN[6], 8, PD.H_BURGHOF2, zweck=5)
gebaeude("Burghof3Bau0", BG, PD.BURGHOF3_BAUTEN[0], 9, PD.H_KERNHOF, zweck=5)    # Heilstube und Ordenshaus
gebaeude("Burghof3Bau1", BG, PD.BURGHOF3_BAUTEN[2], 8, PD.H_KERNHOF, zweck=5)    # Gesindehaus (kurz: 4 m je Geschoss; der Rauchfang einer Küche stünde oben an der Treppe)
_BEGEHBAR = [PD.VORBURG_BAUTEN[0], PD.VORBURG_BAUTEN[6], PD.BURGHOF2_BAUTEN[2], PD.BURGHOF2_BAUTEN[6],
             PD.BURGHOF3_BAUTEN[0], PD.BURGHOF3_BAUTEN[2], PD.BURGKUECHE, PD.DRACHENKAPELLE, PD.ZEUGHAUS]

# --- Die übrigen Bauten des Plans als Reihen von Fachwerkhäusern (unten Stein, oben Fachwerk, wie im Referenzbild):
# Jeder Bau des Plans wird der Länge nach mit Häusern aus szenen/welt/stadthaeuser.gd gefüllt, Rücken zur Mauer,
# Vorderseite zum Hof.
import re as _re
_FORMEN = [(float(b_), float(t_)) for b_, t_ in _re.findall(r"\[(\d+\.\d+), (\d+\.\d+), \d, \d, (?:true|false), \d, \d\]",
           (REPO / "szenen" / "welt" / "stadthaeuser.gd").read_text(encoding="utf-8"))]
HOFHAEUSER = []          # (x, y, z, Gier, Form)
random.seed(4711)


def _ecken_plan(bau, rand=0.0):
    """Ecken eines Baus aus dem Plan (Mitte, Länge, Breite, Drehung) im Plan."""
    (pp, laenge, breite, dreh) = bau
    a_ = math.radians(dreh)
    ux, uy, vx, vy = math.cos(a_), math.sin(a_), -math.sin(a_), math.cos(a_)
    return [(pp[0] + ux * sx * (laenge / 2 + rand) + vx * sy * (breite / 2 + rand),
             pp[1] + uy * sx * (laenge / 2 + rand) + vy * sy * (breite / 2 + rand)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def _ueberlappen_plan(r1, r2):
    for poly in (r1, r2):
        for i in range(len(poly)):
            (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % len(poly)]
            nx_, ny_ = y2 - y1, x1 - x2
            p1 = [nx_ * x + ny_ * y for x, y in r1]
            p2 = [nx_ * x + ny_ * y for x, y in r2]
            if max(p1) <= min(p2) or max(p2) <= min(p1):
                return False
    return True


# In die begehbaren Bauten (und die Türme an ihnen) ragt kein Fachwerkhaus hinein
_FREI_HALTEN = [_ecken_plan(b_, 4.0) for b_ in _BEGEHBAR + [PD.PALAS]]   # 2 m Abstand (Vorkragung und Dachüberstand)


def hausreihe(bau, boden):
    """Füllt den Bau (Plan: Mitte, Länge, Breite, Drehung) mit Fachwerkhäusern; die Vorderseite zeigt wie die Tür
    des Baus (Plan (-sin dreh, cos dreh))."""
    (pp, laenge, breite, dreh) = bau
    lm, bm = laenge * M, breite * M
    a = math.radians(dreh)
    ux, uy = math.cos(a), math.sin(a)                  # Längsachse im Plan
    vx, vy = -math.sin(a), math.cos(a)                 # Vorderseite im Plan
    passend = [k_ for k_ in range(len(_FORMEN)) if _FORMEN[k_][1] + 0.7 <= bm + 0.5]
    if not passend:
        passend = [min(range(len(_FORMEN)), key=lambda k_: _FORMEN[k_][1])]
    s_ = -lm / 2
    n_ = 0
    while s_ < lm / 2 - 3.0:
        rest = lm / 2 - s_
        moeglich = [k_ for k_ in passend if _FORMEN[k_][0] <= rest + 0.3] or [min(passend, key=lambda k_: _FORMEN[k_][0])]
        form = random.choice(moeglich)
        b, t = _FORMEN[form]
        mitte = s_ + b / 2
        # Rücken an die hintere Kante des Baus (zur Mauer)
        tiefe_vor = -bm / 2 + (t + 0.7) / 2
        px = pp[0] + (ux * mitte + vx * tiefe_vor) / M
        py = pp[1] + (uy * mitte + vy * tiefe_vor) / M
        haus_ = _ecken_plan(((px, py), b / M, (t + 0.7) / M, dreh))
        if any(_ueberlappen_plan(haus_, f_) for f_ in _FREI_HALTEN):
            s_ += b + 0.1
            continue
        wx, wz = W((px, py))
        wn = (W((px + vx, py + vy))[0] - wx, W((px + vx, py + vy))[1] - wz)
        gier = math.degrees(math.atan2(wn[0], wn[1]))            # Vorderseite (lokal +z) zum Hof
        HOFHAEUSER.append((round(wx, 2), round(boden, 2), round(wz, 2), round(gier, 1), form))
        s_ += b + 0.1
        n_ += 1
    return n_


_nh = 0
for liste, boden in [(PD.VORBURG_BAUTEN, PD.H_VORBURG), (PD.BURGHOF2_BAUTEN, PD.H_BURGHOF2),
                     (PD.BURGHOF3_BAUTEN, PD.H_KERNHOF), (PD.PALAS_BAUTEN, PD.H_KERNBURG)]:
    for bau in liste:
        if bau not in _BEGEHBAR:
            _nh += hausreihe(bau, boden)
# --- Treppen auf die Wehrgänge: senkrecht zur Mauer, innen im Hof, an freien Stellen zwischen den Hausreihen (oder dort,
# wo am wenigsten Häuser weichen müssen), nicht an Toren, Türmen, Wegen und begehbaren Bauten. Oben endet die Treppe auf
# der Höhe der niedrigen Mauer an der Hofseite des Wehrgangs; von dort tritt man hinab auf den Wehrgang.
def _haus_rechteck(h_, rand=0.6):
    x_, _, z_, g_, f_ = h_
    b_, t_ = _FORMEN[f_][0] / 2 + rand, (_FORMEN[f_][1] + 0.7) / 2 + rand
    a_ = math.radians(g_)
    ux_, uz_ = math.cos(a_), -math.sin(a_)          # lokal x
    vx_, vz_ = math.sin(a_), math.cos(a_)           # lokal z
    return [(x_ + ux_ * sx * b_ + vx_ * sz * t_, z_ + uz_ * sx * b_ + vz_ * sz * t_) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def _im_poly(q, poly):
    x, z = q; innen = False
    for (x1, z1), (x2, z2) in zip(poly, poly[1:] + poly[:1]):
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
            innen = not innen
    return innen


_feste_w = [[W(q) for q in _ecken_plan(b_, 3.0)] for b_ in _BEGEHBAR + [PD.PALAS, PD.PALAS_ECKBAU,
            (PD.BERGFRIED_KERNBURG, PD.BERGFRIED_SEITE / M, PD.BERGFRIED_SEITE / M, PD.BERGFRIED_DREH)]]
_tuerme_w = [W(q) for q in _HOF_TUERME]
# Rundtürme mit ihrem Radius (die Bastionen der Ringmauer sind bis 10 m dick)
_runde_w = [(l_[i_], l_[i_ + 1], l_[i_ + 4]) for l_ in (_tuerme, _vt, _mt, _ot, _zt) for i_ in range(0, len(l_), 7)]
_tore_w = [W(q) for q in PD.TORE.values()]
_wege_w = [WL(w_) for w_ in PD.BURGWEGE]
TREPPEN = []
_weg_haeuser = set()
for name_, hof_, anzahl_ in [("Vorburg", PD.VORBURG, 2), ("Mittelburg", PD.MITTELBURG, 2), ("Oberburg", PD.OBERBURG, 2),
                             ("Kernburg", PD.PALAS_HOF, 2), ("Ringmauer", None, 3), ("RingmauerNord", None, 1)]:
    hof_w_ = WL(hof_) if hof_ else WL(PD.BURGBEZIRK if name_ == "Ringmauer" else PD.STADT)
    kandidaten_ = []
    for (_, ax_, az_, bx_, bz_, oben_, dicke_, aussen_) in [m_ for m_ in MAUERSTUECKE if m_[0] == name_]:
        l_ = math.dist((ax_, az_), (bx_, bz_))
        if l_ < 8.0:
            continue
        ux_, uz_ = (bx_ - ax_) / l_, (bz_ - az_) / l_
        ix_, iz_ = -aussen_[0], -aussen_[1]          # nach innen
        for k_ in range(int((l_ - 7.0) / 2.0) + 1):
            s_ = 3.5 + k_ * 2.0
            px_, pz_ = ax_ + ux_ * s_, az_ + uz_ * s_
            top_ = (px_ + ix_ * dicke_ / 2, pz_ + iz_ * dicke_ / 2)
            fuss_y_ = H(top_[0] + ix_ * 3, top_[1] + iz_ * 3)
            steig_ = oben_ + 0.62 - fuss_y_
            if steig_ < 2.0 or steig_ > 12.0:
                continue
            lauf_ = steig_ * 1.6          # gut 32°
            fuss_ = (top_[0] + ix_ * lauf_, top_[1] + iz_ * lauf_)
            # Grundfläche mit Wangen und einem Platz vor dem Fuß
            ecken_ = [(top_[0] + ux_ * sx * 2.4 + ix_ * t_, top_[1] + uz_ * sx * 2.4 + iz_ * t_) for sx in (-1, 1) for t_ in (0.3, lauf_ + 2.5)]
            punkte_ = ecken_ + [((ecken_[0][0] + ecken_[3][0]) / 2, (ecken_[0][1] + ecken_[3][1]) / 2), fuss_]
            if not all(_im_poly(q_, hof_w_) for q_ in punkte_):
                continue
            if any(abs(H(*q_) - fuss_y_) > 1.2 for q_ in [fuss_, ecken_[1], ecken_[3]]):
                continue
            if any(math.dist(q_, (rx_, rz_)) < rr_ + 4.0 for q_ in punkte_ for rx_, rz_, rr_ in _runde_w):
                continue
            if any(math.dist(q_, t_) < 7.0 for q_ in punkte_ for t_ in _tuerme_w) or any(math.dist(q_, t_) < 10.0 for q_ in punkte_ for t_ in _tore_w):
                continue
            if any(abstand_linie(w_, *q_) < 5.0 for w_ in _wege_w for q_ in punkte_):
                continue
            rechteck_ = [ecken_[0], ecken_[1], ecken_[3], ecken_[2]]
            if any(_ueberlappen_plan(rechteck_, f_) for f_ in _feste_w):
                continue
            stoert_ = [i_ for i_, h_ in enumerate(HOFHAEUSER) if _ueberlappen_plan(rechteck_, _haus_rechteck(h_))]
            kandidaten_.append((len(stoert_), (px_, pz_), [round(fuss_[0], 2), round(fuss_[1], 2), round(fuss_y_, 2),
                                                          round(top_[0], 2), round(top_[1], 2), round(oben_ + 0.62, 2), 2.4], stoert_))
    kandidaten_.sort(key=lambda k_: k_[0])
    gewaehlt_ = []
    for anz_, p_, t_, stoert_ in kandidaten_:
        if len(gewaehlt_) >= anzahl_ or anz_ > 3:
            break
        if all(math.dist(p_, g_[1]) > 35.0 for g_ in gewaehlt_):
            gewaehlt_.append((anz_, p_, t_, stoert_))
    for _, _, t_, stoert_ in gewaehlt_:
        TREPPEN.extend(t_)
        _weg_haeuser.update(stoert_)
    print(f"Mauertreppen {name_}: {len(gewaehlt_)} (Kandidaten {len(kandidaten_)}, weichende Häuser {sum(g_[0] for g_ in gewaehlt_)})")
HOFHAEUSER = [h_ for i_, h_ in enumerate(HOFHAEUSER) if i_ not in _weg_haeuser]
# --- Wirtschaftshof der Vorburg: Pferch und Schweinekoben (zusammen 15 × 6,6 m) an der Hofmauer nahe der Stalltür. Wie
# bei den Mauertreppen weichen dort Häuser der Reihe; gewählt wird die Stelle, an der am wenigsten Häuser weichen und
# die der Stalltür am nächsten ist.
def _rechteck_ab(x, z, b, t, gier):
    a_ = math.radians(gier)
    ux_, uz_, vx_, vz_ = math.cos(a_), -math.sin(a_), math.sin(a_), math.cos(a_)
    return [(x + ux_ * sx * b / 2 + vx_ * sz * t / 2, z + uz_ * sx * b / 2 + vz_ * sz * t / 2) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


(_spp, _sl, _sbr, _sdr) = PD.VORBURG_BAUTEN[6]
_sa = math.radians(-_sdr)
_stall_tuer = (W(_spp)[0] + math.cos(_sa) * (_sbr * M / 2 + 2.0), W(_spp)[1] - math.sin(_sa) * (_sbr * M / 2 + 2.0))
_hof_vb_ = WL(PD.VORBURG)
_treppen_tmp = []
for k_ in range(0, len(TREPPEN), 7):
    fx_, fz_, _, tx_, tz_, _, _ = TREPPEN[k_:k_ + 7]
    _treppen_tmp.append(_rechteck_ab((fx_ + tx_) / 2, (fz_ + tz_) / 2, 6.0, math.dist((fx_, fz_), (tx_, tz_)) + 4.0,
                                     math.degrees(math.atan2(-(tz_ - fz_), tx_ - fx_)) + 90))
_hofstellen = []
for _laenge in (15.0, 9.6):
  for a_, b_ in zip(_hof_vb_, _hof_vb_[1:] + _hof_vb_[:1]):
      l_ = math.dist(a_, b_)
      if l_ < _laenge + 1.0:
          continue
      ux_, uz_ = (b_[0] - a_[0]) / l_, (b_[1] - a_[1]) / l_
      nx_, nz_ = -uz_, ux_
      mx_, mz_ = sum(q[0] for q in _hof_vb_) / len(_hof_vb_), sum(q[1] for q in _hof_vb_) / len(_hof_vb_)
      if nx_ * (mx_ - a_[0]) + nz_ * (mz_ - a_[1]) < 0:
          nx_, nz_ = -nx_, -nz_
      g_ = math.degrees(math.atan2(-uz_, ux_))           # lokal x entlang der Mauer
      t_ = _laenge / 2 + 1.0
      while t_ < l_ - _laenge / 2 - 1.0:
          x_, z_ = a_[0] + ux_ * t_ + nx_ * 5.3, a_[1] + uz_ * t_ + nz_ * 5.3
          r_ = _rechteck_ab(x_, z_, _laenge, 6.6, g_)
          t_ += 1.0
          if not all(_im_poly(q_, _hof_vb_) for q_ in r_):
              continue
          if any(_ueberlappen_plan(r_, f_) for f_ in _feste_w + _treppen_tmp):
              continue
          if any(math.dist(q_, t2_) < 9.0 for q_ in r_ for t2_ in _tore_w):
              continue
          if any(math.dist((x_, z_), (rx_, rz_)) < rr_ + 8.0 for rx_, rz_, rr_ in _runde_w):
              continue
          rand_ = [(r_[i_][0] + (r_[(i_ + 1) % 4][0] - r_[i_][0]) * f_ / 5, r_[i_][1] + (r_[(i_ + 1) % 4][1] - r_[i_][1]) * f_ / 5)
                   for i_ in range(4) for f_ in range(5)]
          if any(abstand_linie(w_, *q_) < 1.6 for w_ in _wege_w for q_ in rand_):
              continue
          weg_ = [i_ for i_, h_ in enumerate(HOFHAEUSER) if _ueberlappen_plan(r_, _haus_rechteck(h_, 0.4))]
          _hofstellen.append((len(weg_) * 8.0 + math.dist((x_, z_), _stall_tuer) + (0.0 if _laenge > 10 else 6.0), x_, z_, g_, weg_, _laenge))
PFERCH_RESERVE = None
if _hofstellen:
    _hofstellen.sort(key=lambda h_: h_[0])
    _, x_, z_, g_, weg_, laenge_ = _hofstellen[0]
    PFERCH_RESERVE = (x_, z_, g_, laenge_)
    _feste_w.append(_rechteck_ab(x_, z_, laenge_ + (0.0 if laenge_ > 10 else 6.0) + 1.0, 7.6, g_))   # für nichts anderes
    HOFHAEUSER = [h_ for i_, h_ in enumerate(HOFHAEUSER) if i_ not in set(weg_)]
    print(f"Wirtschaftshof an der Vorburgmauer: {math.dist((x_, z_), _stall_tuer):.1f} m von der Stalltür, {len(weg_)} Häuser weichen")
N("Mauertreppen", "Node3D", BG, f"""script = ExtResource("28_burgbau")
treppen = PackedFloat32Array({_zahlen(TREPPEN)})""")
# --- Ausstattung der Höfe (szenen/welt/ausstattung.gd): Ziehbrunnen in der Mitte, Fässer, Kisten und Säcke vor den
# Häusern (neben den Türen), Holzstapel, Karren, Pferdetränke am Stall, Waffenständer am Zeughaus und in der Oberburg,
# Feuerkörbe mit Licht an den Toren. Nichts steht auf Wegen, vor Türen begehbarer Bauten, an Treppen oder Toren.
random.seed(1609)
BURG_AUSSTATTUNG = []            # (Art, x, y, z, Gier)
BURG_SPERREN = []                # Rechtecke (Welt) der Ausstattung, für die Wege der Burgleute
BURG_LICHTER = []                # (x, y, z)
LAGERPLAETZE = []                # (x, z, nach innen x, z, Boden, Hof): dort arbeitet jemand
_GRUND = {}
_A_GROESSE = {0: (0.8, 0.8), 1: (0.8, 0.8), 2: (1.3, 1.0), 4: (1.7, 3.2), 10: (2.6, 2.6), 11: (2.3, 1.5), 12: (2.5, 1.0),
              13: (1.9, 0.7), 14: (0.7, 0.7), 15: (0.8, 0.7), 16: (1.8, 1.4), 17: (4.6, 3.6), 18: (1.9, 1.9), 19: (0.7, 2.6),
              21: (7.6, 5.4), 22: (0.4, 1.0), 23: (0.3, 0.6), 24: (0.7, 1.4), 25: (0.7, 1.3), 26: (0.9, 2.2),
              27: (0.6, 1.1), 28: (4.2, 0.6), 29: (1.2, 1.2), 30: (1.6, 1.2), 31: (0.2, 0.3)}
_treppen_w = []
for k_ in range(0, len(TREPPEN), 7):
    fx_, fz_, _, tx_, tz_, _, br_ = TREPPEN[k_:k_ + 7]
    ux_, uz_ = (tx_ - fx_), (tz_ - fz_)
    l_ = math.hypot(ux_, uz_); ux_, uz_ = ux_ / l_, uz_ / l_
    _treppen_w.append([(fx_ + ux_ * t_ - uz_ * q_, fz_ + uz_ * t_ + ux_ * q_) for t_, q_ in ((-3.0, -2.6), (l_, -2.6), (l_, 2.6), (-3.0, 2.6))])
_tueren_w = []
for b_ in _BEGEHBAR + [PD.PALAS]:
    (pp_, l_, br_, dr_) = b_
    a_ = math.radians(dr_)
    vx_, vy_ = -math.sin(a_), math.cos(a_)
    _tueren_w.append([W(q) for q in _ecken_plan(((pp_[0] + vx_ * (br_ / 2 + 7), pp_[1] + vy_ * (br_ / 2 + 7)), 16, 14, dr_))])
_haeuser_w = [_haus_rechteck(h_, 0.3) for h_ in HOFHAEUSER]
_alle_wege_w = [WL(w_) for w_ in PD.BURGWEGE] + [WL(w_) for w_ in _HOF_WEGE] if "_HOF_WEGE" in globals() else [WL(w_) for w_ in PD.BURGWEGE]


def _rechteck_w(x, z, b, t, gier):
    a_ = math.radians(gier)
    ux_, uz_, vx_, vz_ = math.cos(a_), -math.sin(a_), math.sin(a_), math.cos(a_)
    return [(x + ux_ * sx * b / 2 + vx_ * sz * t / 2, z + uz_ * sx * b / 2 + vz_ * sz * t / 2) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


# Vorplätze: vor jeder Haustür der Hofhäuser bleibt eine Fläche frei (später kommen die offene Front der Schmiede und
# der Platz um jeden Brunnen dazu). Nur Fässer, Kisten, Säcke, Feuerkörbe und Laternen dürfen neben der Tür stehen.
_vorplaetze_w = []
for x_, y_, z_, g_, f_ in HOFHAEUSER:
    b_, t_ = _FORMEN[f_]
    a_ = math.radians(g_)
    vor_ = (t_ + 0.7) / 2 + 1.4
    _vorplaetze_w.append(_rechteck_w(x_ + math.sin(a_) * vor_, z_ + math.cos(a_) * vor_, 2.4, 2.8, g_))
VORPLATZ_ERLAUBT = {0, 1, 2, 14, 20}


def _abstand_rand(q, poly):
    return min(abstand_linie([a_, b_], *q) for a_, b_ in zip(poly, poly[1:] + poly[:1]))


def stelle(art, x, z, gier, hof_w, boden, wegabstand=3.2, licht=False, probe=False):
    """Stellt ein Stück auf, wenn der Platz frei ist; gibt zurück, ob es geklappt hat."""
    b_, t_ = _A_GROESSE[art]
    r_ = _rechteck_w(x, z, b_ + 0.3, t_ + 0.3, gier)
    if not all(_im_poly(q_, hof_w) for q_ in r_) or min(_abstand_rand(q_, hof_w) for q_ in r_) < 2.2:
        _GRUND["rand"] = _GRUND.get("rand", 0) + 1
        return False
    pruefen_ = [("haus", _haeuser_w), ("bau", _feste_w), ("treppe", _treppen_w), ("tuer", _tueren_w), ("stueck", BURG_SPERREN)]
    if art not in VORPLATZ_ERLAUBT:
        pruefen_.append(("vorplatz", _vorplaetze_w))
    for n_, l_ in pruefen_:
        if any(_ueberlappen_plan(r_, f_) for f_ in l_):
            _GRUND[n_] = _GRUND.get(n_, 0) + 1
            return False
    if any(abstand_linie(w_, *q_) < wegabstand for w_ in _alle_wege_w for q_ in r_ + [(x, z)]):
        _GRUND["weg"] = _GRUND.get("weg", 0) + 1
        return False
    if any(math.dist((x, z), t_) < 7.0 for t_ in _tore_w) or any(math.dist((x, z), (rx_, rz_)) < rr_ + 1.5 for rx_, rz_, rr_ in _runde_w):
        _GRUND["turm"] = _GRUND.get("turm", 0) + 1
        return False
    if probe:
        return True
    BURG_AUSSTATTUNG.append((art, round(x, 2), round(boden, 2), round(z, 2), round(gier, 1)))
    BURG_SPERREN.append(r_)
    if licht:
        BURG_LICHTER.append((round(x, 2), round(boden + 2.6, 2), round(z, 2)))
    return True


def _naechste_kante_innen(p, poly):
    """Richtung entlang und nach innen an der Kante des Vielecks, die p am nächsten liegt."""
    kanten_ = [i_ for i_ in range(len(poly)) if math.dist(poly[i_], poly[(i_ + 1) % len(poly)]) > 0.01]
    bester = min(kanten_, key=lambda i_: abstand_linie([poly[i_], poly[(i_ + 1) % len(poly)]], *p))
    (ax_, az_), (bx_, bz_) = poly[bester], poly[(bester + 1) % len(poly)]
    l_ = math.hypot(bx_ - ax_, bz_ - az_)
    ux_, uz_ = (bx_ - ax_) / l_, (bz_ - az_) / l_
    mx_, mz_ = sum(q[0] for q in poly) / len(poly), sum(q[1] for q in poly) / len(poly)
    nx_, nz_ = -uz_, ux_
    if nx_ * (mx_ - p[0]) + nz_ * (mz_ - p[1]) < 0:
        nx_, nz_ = -nx_, -nz_
    return (ux_, uz_), (nx_, nz_)


BURG_BRUNNEN = {}
WERKPLAETZE = {}                 # Name → (x, z, entlang, nach innen, Boden): dort steht jemand bei der Arbeit


def werkplatz(name, teile, hof_w, boden, tiefe=1.0):
    """Sucht an der Hofmauer einen Platz für eine Gruppe von Stücken. teile: (Art, entlang, nach innen, Drehung) im
    Rahmen der Mauer (entlang der Kante, nach innen in den Hof); gestellt wird nur, wenn alle passen."""
    kante_ = hof_w + hof_w[:1]
    mx_, mz_ = sum(q[0] for q in hof_w) / len(hof_w), sum(q[1] for q in hof_w) / len(hof_w)
    versuche_ = []
    for a_, b_ in zip(kante_, kante_[1:]):
        l_ = math.dist(a_, b_)
        if l_ < 9.0:
            continue
        ux_, uz_ = (b_[0] - a_[0]) / l_, (b_[1] - a_[1]) / l_
        nx_, nz_ = -uz_, ux_
        if nx_ * (mx_ - a_[0]) + nz_ * (mz_ - a_[1]) < 0:
            nx_, nz_ = -nx_, -nz_
        t_ = 4.5
        while t_ < l_ - 4.5:
            versuche_.append((a_[0] + ux_ * t_ + nx_ * (3.2 + tiefe), a_[1] + uz_ * t_ + nz_ * (3.2 + tiefe), ux_, uz_, nx_, nz_))
            t_ += 1.5
    random.shuffle(versuche_)
    for px_, pz_, ux_, uz_, nx_, nz_ in versuche_:
        g0_ = math.degrees(math.atan2(nx_, nz_))            # lokal +z zeigt in den Hof
        lagen_ = [(art_, px_ + ux_ * e_ + nx_ * i_, pz_ + uz_ * e_ + nz_ * i_, g0_ + d_) for art_, e_, i_, d_ in teile]
        if all(stelle(art_, x_, z_, g_, hof_w, boden, wegabstand=2.6, probe=True) for art_, x_, z_, g_ in lagen_):
            # einzeln setzen (die Stücke einer Gruppe dürfen sich nicht gegenseitig sperren)
            for art_, x_, z_, g_ in lagen_:
                stelle(art_, x_, z_, g_, hof_w, boden, wegabstand=2.6)
            WERKPLAETZE[name] = (px_, pz_, (ux_, uz_), (nx_, nz_), boden)
            return True
    return False


_hoefe = [("Vorburg", PD.VORBURG, PD.H_VORBURG), ("Mittelburg", PD.MITTELBURG, PD.H_BURGHOF2),
          ("Oberburg", PD.OBERBURG, PD.H_KERNHOF), ("Palas", PD.PALAS_HOF, PD.H_KERNBURG)]
for name_, hof_, boden_ in _hoefe:
    hof_w_ = WL(hof_)
    mx_, mz_ = sum(q[0] for q in hof_w_) / len(hof_w_), sum(q[1] for q in hof_w_) / len(hof_w_)
    # Ziehbrunnen: möglichst nahe der Mitte
    for k_ in range(400):
        w_, r_ = k_ * 2.4, 0.6 * math.sqrt(k_)
        x_, z_ = mx_ + r_ * math.cos(w_), mz_ + r_ * math.sin(w_)
        if stelle(10, x_, z_, random.uniform(0, 90), hof_w_, boden_, wegabstand=4.0):
            BURG_BRUNNEN[name_] = (x_, z_)
            _vorplaetze_w.append(_rechteck_w(x_, z_, 5.4, 5.4, 0.0))   # rund um den Brunnen bleibt Platz zum Wasserholen
            break
    # Werkplätze: Schmiede, Holzplatz und ein Unterstand für Karren in der Vorburg, Holzplatz und Unterstand in der
    # Mittelburg (die Stücke stehen mit dem Rücken zur Hofmauer)
    if name_ in ("Vorburg", "Mittelburg"):
        if "Schmiede" not in WERKPLAETZE:
            # Schmiede als gemauerte Werkstatt mit dem Rücken zur Hofmauer, davor Fässer, Kisten und Holz
            if werkplatz("Schmiede", [(21, 0.0, 0.0, 0), (0, -3.0, 3.7, 0), (0, -2.2, 3.8, 0), (1, 3.0, 3.7, 20),
                                      (11, 6.2, 0.8, 90)], hof_w_, boden_, tiefe=2.0):
                px_, pz_, (ux_, uz_), (nx_, nz_), _ = WERKPLAETZE["Schmiede"]
                lx_, lz_ = nz_, -nx_                     # lokal x der Schmiede
                _vorplaetze_w.append(_rechteck_w(px_ + nx_ * 4.6, pz_ + nz_ * 4.6, 6.8, 3.8, math.degrees(math.atan2(nx_, nz_))))
                BURG_LICHTER.append((round(px_ + lx_ * -2.2 + nx_ * -1.6, 2), round(boden_ + 1.6, 2),
                                     round(pz_ + lz_ * -2.2 + nz_ * -1.6, 2)))
                print("Schmiede:", round(px_, 1), round(boden_, 1), round(pz_, 1), "nach innen", round(nx_, 2), round(nz_, 2))
        werkplatz(f"Holzplatz {name_}", [(11, -1.4, 0.0, 90), (11, 1.4, 0.2, 90), (1, 0.0, 2.6, 30)], hof_w_, boden_)
        werkplatz(f"Unterstand {name_}", [(17, 0.0, 0.6, 0), (4, 3.6, 1.6, 10)], hof_w_, boden_, tiefe=1.6)
    # Feuerkörbe zu beiden Seiten jedes Tors, innen im Hof
    for tor_ in PD.TORE.values():
        tw_ = W(tor_)
        if not _im_poly(tw_, hof_w_) and _abstand_rand(tw_, hof_w_) > 3.0:
            continue
        (ux_, uz_), (nx_, nz_) = _naechste_kante_innen(tw_, hof_w_)
        for s_ in (-1, 1):
            for q_ in (4.5, 5.5, 6.5):
                x_, z_ = tw_[0] + nx_ * q_ + ux_ * s_ * 4.2, tw_[1] + nz_ * q_ + uz_ * s_ * 4.2
                _alt = list(_tore_w)
                _tore_w.clear()                          # Feuerkörbe gehören ans Tor
                ok_ = stelle(14, x_, z_, 0, hof_w_, boden_, wegabstand=1.6, licht=True)
                _tore_w.extend(_alt)
                if ok_:
                    break
    # Gruppen von Fässern, Kisten und Säcken neben den Türen der Häuser, dazu Holzstapel und Karren
    haeuser_ = [h_ for h_ in HOFHAEUSER if _im_poly((h_[0], h_[2]), hof_w_)]
    random.shuffle(haeuser_)
    stapel_, karren_ = 0, 0
    for x_, _, z_, g_, f_ in haeuser_:
        b_, t_ = _FORMEN[f_]
        a_ = math.radians(g_)
        vx_, vz_ = math.sin(a_), math.cos(a_)            # Vorderseite (lokal +z)
        ux_, uz_ = math.cos(a_), -math.sin(a_)
        vor_ = (t_ + 0.7) / 2
        zufall_ = random.random()
        if zufall_ < 0.12 and stapel_ < 2:
            if stelle(11, x_ + vx_ * (vor_ + 1.7), z_ + vz_ * (vor_ + 1.7), g_, hof_w_, boden_):
                stapel_ += 1
            continue
        if zufall_ < 0.2 and karren_ < 1:
            if stelle(4, x_ + vx_ * (vor_ + 2.2) + ux_ * b_ * 0.3, z_ + vz_ * (vor_ + 2.2) + uz_ * b_ * 0.3, g_ + 90 + random.uniform(-20, 20), hof_w_, boden_):
                karren_ += 1
            continue
        for seite_ in ((-1, 1) if random.random() < 0.6 else (random.choice((-1, 1)),)):
            for k_ in range(random.randint(2, 4)):
                art_ = random.choice((0, 0, 1, 1, 2))
                q_ = b_ / 2 - 0.6 - k_ * 0.85
                if q_ < 1.0:
                    break
                stelle(art_, x_ + vx_ * (vor_ + 1.1) + ux_ * seite_ * q_, z_ + vz_ * (vor_ + 1.1) + uz_ * seite_ * q_,
                       random.uniform(0, 360), hof_w_, boden_, wegabstand=2.4)
    # Lagerplätze an der Hofmauer, wo kein Haus steht: Fässer, Kisten, Säcke in Gruppen, dazu Holzstapel
    kante_ = hof_w_ + hof_w_[:1]
    for a_, b_ in zip(kante_, kante_[1:]):
        l_ = math.dist(a_, b_)
        if l_ < 4.0:
            continue
        ux_, uz_ = (b_[0] - a_[0]) / l_, (b_[1] - a_[1]) / l_
        nx_, nz_ = -uz_, ux_
        if nx_ * (mx_ - a_[0]) + nz_ * (mz_ - a_[1]) < 0:
            nx_, nz_ = -nx_, -nz_
        gier_ = math.degrees(math.atan2(ux_, uz_)) + 90
        t_ = 3.0
        while t_ < l_ - 3.0:
            px_, pz_ = a_[0] + ux_ * t_ + nx_ * 3.6, a_[1] + uz_ * t_ + nz_ * 3.6
            wahl_ = random.random()
            if wahl_ < 0.25:
                if stelle(11, px_, pz_, gier_, hof_w_, boden_, wegabstand=2.4):
                    LAGERPLAETZE.append((px_, pz_, nx_, nz_, boden_, name_))
            elif wahl_ < 0.7:
                gesetzt_ = 0
                for k_ in range(random.randint(3, 5)):
                    q_ = (k_ - 2) * 0.9
                    gesetzt_ += stelle(random.choice((0, 0, 1, 1, 2)), px_ + ux_ * q_ + nx_ * random.uniform(-0.3, 0.6),
                                       pz_ + uz_ * q_ + nz_ * random.uniform(-0.3, 0.6), random.uniform(0, 360), hof_w_, boden_, wegabstand=2.4)
                if gesetzt_ >= 2:
                    LAGERPLAETZE.append((px_, pz_, nx_, nz_, boden_, name_))
            t_ += random.uniform(5.0, 9.0)
# Pferdetränke und Karren vor dem Stall der Vorburg, Waffenständer vor dem Zeughaus und in der Oberburg
for bau_, art_, boden_, hof_ in [(PD.VORBURG_BAUTEN[6], 12, PD.H_VORBURG, PD.VORBURG), (PD.ZEUGHAUS, 13, PD.H_KERNBURG, PD.PALAS_HOF),
                                 (PD.BURGHOF3_BAUTEN[0], 13, PD.H_KERNHOF, PD.OBERBURG)]:
    (pp_, l_, br_, dr_) = bau_
    a_ = math.radians(dr_)
    vx_, vy_ = -math.sin(a_), math.cos(a_)
    ux_, uy_ = math.cos(a_), math.sin(a_)
    for q_ in (0.3, -0.3, 0.42, -0.42):
        x_, z_ = W((pp_[0] + vx_ * (br_ / 2 + 5) + ux_ * l_ * q_, pp_[1] + vy_ * (br_ / 2 + 5) + uy_ * l_ * q_))
        _tue = list(_tueren_w)
        _tueren_w.clear()
        ok_ = stelle(art_, x_, z_, -dr_ + 90, WL(hof_), boden_, wegabstand=2.6)
        _tueren_w.extend(_tue)
        if ok_:
            break
# Pferde und Heuhaufen vor dem Stall der Vorburg (beiderseits der Tür, Kopf zur Wand) und am Unterstand der Mittelburg
(pp_, l_, br_, dr_) = PD.VORBURG_BAUTEN[6]
a_ = math.radians(dr_)
vx_, vy_ = -math.sin(a_), math.cos(a_)
ux_, uy_ = math.cos(a_), math.sin(a_)
_pferde = 0
_tue = list(_tueren_w)
_tueren_w.clear()
for q_ in (-0.42, -0.3, 0.3, 0.42, -0.18, 0.18):
    for vor_ in (8.0, 11.0, 14.0):   # Planpunkte (0,5 m)
        x_, z_ = W((pp_[0] + vx_ * (br_ / 2 + vor_) + ux_ * l_ * q_, pp_[1] + vy_ * (br_ / 2 + vor_) + uy_ * l_ * q_))
        if abs(q_) < 0.25 and vor_ < 12:
            continue                                     # vor der Tür frei lassen
        art_ = 19 if _pferde < 3 else 18
        g_ = -dr_ + 180 + random.uniform(-8, 8)
        if stelle(art_, x_, z_, g_, WL(PD.VORBURG), PD.H_VORBURG, wegabstand=2.6):
            if art_ == 19:
                # Anbindebalken vor dem Kopf des Pferdes
                w_ = math.radians(g_)
                BURG_AUSSTATTUNG.append((33, round(x_ + math.sin(w_) * 1.55, 2), PD.H_VORBURG, round(z_ + math.cos(w_) * 1.55, 2), round(g_, 1)))
            _pferde += 1
            break
_tueren_w.extend(_tue)
if "Unterstand Mittelburg" in WERKPLAETZE:
    px_, pz_, (ux_, uz_), (nx_, nz_), boden_ = WERKPLAETZE["Unterstand Mittelburg"]
    for e_ in (-4.0, -5.5):
        stelle(19, px_ + ux_ * e_ + nx_ * 1.2, pz_ + uz_ * e_ + nz_ * 1.2, math.degrees(math.atan2(-nx_, -nz_)), WL(PD.MITTELBURG), boden_, wegabstand=2.6)
# ---------- Hofleben mit Sinn: Vieh im Pferch, Wäsche am Hofrand, Stroh am Stall, Pfützen am Brunnen ----------
# Tiere werden eigene Knoten (szenen/figuren/tier.gd) mit einem Revier, in dem sie umherziehen.
TIERE_BURG = []        # (Tierart, x, y, z, Gier, Revier [(x, z), ...] oder [])
TIERART = {"pferd": 0, "kuh": 1, "schaf": 2, "schwein": 3, "hund": 4, "katze": 5}


def _flaeche_frei(r_, hof_w, rand=1.6, wegabstand=1.8):
    """Ist das Rechteck (Welt) im Hof frei von Häusern, Bauten, Treppen, Türen, Vorplätzen, Stücken und Wegen?"""
    if not all(_im_poly(q_, hof_w) for q_ in r_) or min(_abstand_rand(q_, hof_w) for q_ in r_) < rand:
        return False
    for l_ in (_haeuser_w, _feste_w, _treppen_w, _tueren_w, _vorplaetze_w, BURG_SPERREN):
        if any(_ueberlappen_plan(r_, f_) for f_ in l_):
            return False
    kante_ = []
    for a_, b_ in zip(r_, r_[1:] + r_[:1]):
        kante_ += [(a_[0] + (b_[0] - a_[0]) * t_ / 6, a_[1] + (b_[1] - a_[1]) * t_ / 6) for t_ in range(6)]
    if any(abstand_linie(w_, *q_) < wegabstand for w_ in _alle_wege_w for q_ in kante_):
        return False
    mx_, mz_ = sum(q[0] for q in r_) / 4, sum(q[1] for q in r_) / 4
    if any(math.dist((mx_, mz_), t_) < 9.0 for t_ in _tore_w):
        return False
    return True


def _rahmen(x, z, gier):
    """Achsen eines um gier gedrehten Rahmens: lokal x und lokal z (Welt)."""
    a_ = math.radians(gier)
    return (math.cos(a_), -math.sin(a_)), (math.sin(a_), math.cos(a_))


def _umzaeunen(x, z, breite, tiefe, gier, boden, art_zaun, feld, tor_seite):
    """Zaun um ein Rechteck aus Feldern der Länge feld (Breite und Tiefe sind Vielfache davon, sonst klaffen Lücken); in
    der Mitte der Seite tor_seite (0 vorn +z, 1 hinten, 2 links, 3 rechts, -1 keins) steht statt eines Feldes ein
    geschlossenes Doppelgatter: zwei Flügel, je an einem Pfosten angeschlagen, die sich in der Mitte treffen."""
    (lx_, lz_), (vx_, vz_) = _rahmen(x, z, gier)
    seiten_ = [((0, tiefe / 2), breite, 0.0), ((0, -tiefe / 2), breite, 0.0), ((-breite / 2, 0), tiefe, 90.0), ((breite / 2, 0), tiefe, 90.0)]
    for i_, ((ox_, oz_), lang_, dreh_) in enumerate(seiten_):
        n_ = max(1, round(lang_ / feld))
        for k_ in range(n_):
            t_ = -lang_ / 2 + (k_ + 0.5) * lang_ / n_
            ex_, ez_ = (t_, 0) if dreh_ == 0 else (0, t_)
            px_, pz_ = ox_ + ex_, oz_ + ez_
            wx_, wz_ = x + lx_ * px_ + vx_ * pz_, z + lz_ * px_ + vz_ * pz_
            if i_ == tor_seite and k_ == n_ // 2:
                # Ein Flügel reicht vom Angelpfosten 1,45 m in lokal +x; bei Gier+90 zeigt lokal +x nach -z des Rahmens
                for s_ in (-1, 1):
                    hx_, hz_ = (px_ + s_ * lang_ / n_ / 2, pz_) if dreh_ == 0 else (px_, pz_ + s_ * lang_ / n_ / 2)
                    BURG_AUSSTATTUNG.append((35, round(x + lx_ * hx_ + vx_ * hz_, 2), round(boden, 2), round(z + lz_ * hx_ + vz_ * hz_, 2),
                                             round(gier + dreh_ + (0 if (s_ < 0) == (dreh_ == 0) else 180), 1)))
                continue
            BURG_AUSSTATTUNG.append((art_zaun, round(wx_, 2), round(boden, 2), round(wz_, 2), round(gier + dreh_, 1)))
    BURG_SPERREN.append(_rechteck_w(x, z, breite + 0.3, tiefe + 0.3, gier))


def _revier(x, z, breite, tiefe, gier, rand=0.7):
    (lx_, lz_), (vx_, vz_) = _rahmen(x, z, gier)
    b_, t_ = breite / 2 - rand, tiefe / 2 - rand
    return [(round(x + lx_ * sx * b_ + vx_ * sz * t_, 2), round(z + lz_ * sx * b_ + vz_ * sz * t_, 2))
            for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def _hof_revier(hof_w, einzug=3.5):
    """Hof-Vieleck, zum Schwerpunkt hin eingezogen: dort streifen Hunde und Katzen umher."""
    mx_, mz_ = sum(q[0] for q in hof_w) / len(hof_w), sum(q[1] for q in hof_w) / len(hof_w)
    aus_ = []
    for x_, z_ in hof_w:
        d_ = math.dist((x_, z_), (mx_, mz_))
        f_ = max(0.0, (d_ - einzug) / max(d_, 0.01))
        aus_.append((round(mx_ + (x_ - mx_) * f_, 2), round(mz_ + (z_ - mz_) * f_, 2)))
    return aus_


# Pferch (Kuh, Schafe) und Schweinekoben neben dem Stall der Vorburg, nicht vor seiner Tür
(pp_, l_, br_, dr_) = PD.VORBURG_BAUTEN[6]
_stall_x, _stall_z = W(pp_)
_gier_stall = -dr_
(_su_x, _su_z), (_sv_x, _sv_z) = _rahmen(_stall_x, _stall_z, _gier_stall)   # lokal x quer (Tür bei +x), lokal z entlang
_stall_L, _stall_B = l_ * M / 2, br_ * M / 2
_hof_vb = WL(PD.VORBURG)
_pferch = None
_tuer_stall = _stall_tuer
if PFERCH_RESERVE:
    rx_, rz_, rg_, rl_ = PFERCH_RESERVE
    (lx_, lz_), _ = _rahmen(rx_, rz_, rg_)
    # Pferch im einen Teil (9 m), der Koben im anderen (5 m) oder gleich daneben
    _vers = 3.0 if rl_ > 10 else 0.0
    _pferch = (rx_ - lx_ * _vers, rz_ - lz_ * _vers, rg_, 9.0, 6.0)   # drei mal zwei Zaunfelder zu 3 m
    _koben_ort = (rx_ + lx_ * 5.0, rz_ + lz_ * 5.0) if rl_ > 10 else (rx_ + lx_ * 7.6, rz_ + lz_ * 7.6)
if _pferch:
    px_, pz_, g_, pb_, pt_ = _pferch
    _umzaeunen(px_, pz_, pb_, pt_, g_, PD.H_VORBURG, 32, 3.0, 0)
    (lx_, lz_), (vx_, vz_) = _rahmen(px_, pz_, g_)
    rev_ = _revier(px_, pz_, pb_, pt_, g_)
    for art_, ox_, oz_, dg_ in [(12, -2.6, -2.4, 0), (18, 3.2, -2.0, 0), (29, 2.0, 1.4, 30), (29, -1.0, 0.8, 80), (30, 0.6, -0.4, 0)]:
        BURG_AUSSTATTUNG.append((art_, round(px_ + lx_ * ox_ + vx_ * oz_, 2), PD.H_VORBURG, round(pz_ + lz_ * ox_ + vz_ * oz_, 2), round(g_ + dg_, 1)))
    for k_, (art_, ox_, oz_) in enumerate([("kuh", -1.5, 0.6), ("schaf", 1.6, 1.2), ("schaf", 2.6, -0.2), ("schaf", 0.6, 1.8)]):
        TIERE_BURG.append((TIERART[art_], round(px_ + lx_ * ox_ + vx_ * oz_, 2), PD.H_VORBURG, round(pz_ + lz_ * ox_ + vz_ * oz_, 2),
                           round(random.uniform(0, 360), 1), rev_))
    # Schweinekoben gleich daneben, aus Brettern, mit Schlamm
    _orte_koben = [_koben_ort] if PFERCH_RESERVE else []
    for seite_ in (1, -1):
        for weiter_ in (3.0, 3.6, 4.4):
            _orte_koben.append((px_ + lx_ * seite_ * (pb_ / 2 + weiter_), pz_ + lz_ * seite_ * (pb_ / 2 + weiter_)))
            _orte_koben.append((px_ + vx_ * seite_ * (pt_ / 2 + weiter_ - 0.5), pz_ + vz_ * seite_ * (pt_ / 2 + weiter_ - 0.5)))
    for kx_, kz_ in _orte_koben:
        r_ = _rechteck_w(kx_, kz_, 4.0, 4.0, g_)
        if (PFERCH_RESERVE and (kx_, kz_) == _koben_ort) or _flaeche_frei(r_, _hof_vb, rand=1.7, wegabstand=1.4):
            _umzaeunen(kx_, kz_, 4.0, 4.0, g_, PD.H_VORBURG, 34, 2.0, -1)   # Bretterwand ringsum, man steigt hinüber
            BURG_AUSSTATTUNG.append((36, round(kx_, 2), PD.H_VORBURG, round(kz_, 2), round(g_, 1)))
            BURG_AUSSTATTUNG.append((12, round(kx_ - vx_ * 1.4, 2), PD.H_VORBURG, round(kz_ - vz_ * 1.4, 2), round(g_, 1)))
            rk_ = _revier(kx_, kz_, 4.0, 4.0, g_, 0.6)
            for k_ in range(2):
                TIERE_BURG.append((TIERART["schwein"], round(kx_ + lx_ * (k_ - 0.5) * 1.6, 2), PD.H_VORBURG,
                                   round(kz_ + lz_ * (k_ - 0.5) * 1.6, 2), round(random.uniform(0, 360), 1), rk_))
            break
print("Pferch beim Stall:", f"{math.dist(_pferch[:2], _tuer_stall):.1f} m von der Stalltür, {_abstand_rand(_pferch[:2], _hof_vb):.1f} m von der Hofmauer, bei {_pferch[0]:.1f}, {_pferch[1]:.1f}" if _pferch else "kein Platz",
      "Schweine:", sum(1 for t_ in TIERE_BURG if t_[0] == 3))

# Hunde und Katzen streifen durch die Höfe: der Hund liegt gern beim Stall oder Tor, Katzen bei Küche und Lager
for name_, hof_, boden_ in _hoefe:
    hof_w_ = WL(hof_)
    rev_ = _hof_revier(hof_w_)
    for art_, anzahl_ in (("hund", 1), ("katze", 2)):
        for _ in range(anzahl_):
            for versuch_ in range(80):
                x_ = random.uniform(min(q[0] for q in rev_), max(q[0] for q in rev_))
                z_ = random.uniform(min(q[1] for q in rev_), max(q[1] for q in rev_))
                if _im_poly((x_, z_), rev_) and not any(_im_poly((x_, z_), f_) for f_ in _haeuser_w + _feste_w + BURG_SPERREN):
                    TIERE_BURG.append((TIERART[art_], round(x_, 2), boden_, round(z_, 2), round(random.uniform(0, 360), 1), rev_))
                    break

_klein = {}
for name_, hof_, boden_ in _hoefe:
    hof_w_ = WL(hof_)
    mx_, mz_ = sum(q[0] for q in hof_w_) / len(hof_w_), sum(q[1] for q in hof_w_) / len(hof_w_)
    # Wäscheleinen parallel zur Hofmauer, nahe den Wohnhäusern, nie vor Türen oder auf Wegen
    wohnen_ = [(h_[0], h_[2]) for h_ in HOFHAEUSER if _im_poly((h_[0], h_[2]), hof_w_)]
    for b_ in _BEGEHBAR:
        bx_, bz_ = W(b_[0])
        if _im_poly((bx_, bz_), hof_w_):
            wohnen_.append((bx_, bz_))
    kanten_ = []
    for a_, b_ in zip(hof_w_, hof_w_[1:] + hof_w_[:1]):
        l_ = math.dist(a_, b_)
        if l_ < 7.0:
            continue
        ux_, uz_ = (b_[0] - a_[0]) / l_, (b_[1] - a_[1]) / l_
        nx_, nz_ = -uz_, ux_
        if nx_ * (mx_ - a_[0]) + nz_ * (mz_ - a_[1]) < 0:
            nx_, nz_ = -nx_, -nz_
        kanten_.append((a_, l_, ux_, uz_, nx_, nz_))
    wunsch_ = {"Vorburg": 2, "Mittelburg": 2, "Oberburg": 1}.get(name_, 0)
    gesetzt_ = 0
    for _ in range(400):
        if gesetzt_ >= wunsch_ or not kanten_ or not wohnen_:
            break
        a_, l_, ux_, uz_, nx_, nz_ = random.choice(kanten_)
        t_ = random.uniform(3.0, l_ - 3.0)
        x_, z_ = a_[0] + ux_ * t_ + nx_ * 3.3, a_[1] + uz_ * t_ + nz_ * 3.3
        if min(math.dist((x_, z_), w_) for w_ in wohnen_) > 16.0:
            continue
        if stelle(28, x_, z_, math.degrees(math.atan2(nx_, nz_)), hof_w_, boden_, wegabstand=2.0):
            gesetzt_ += 1
    _klein[28] = _klein.get(28, 0) + gesetzt_
    # Pfützen: verschüttetes Wasser am Brunnen und an der Tränke
    if name_ in BURG_BRUNNEN:
        bx_, bz_ = BURG_BRUNNEN[name_]
        for _ in range(30):
            w_ = random.uniform(0, math.tau)
            x_, z_ = bx_ + math.cos(w_) * 2.9, bz_ + math.sin(w_) * 2.9
            _alt_vp = list(_vorplaetze_w)
            _vorplaetze_w.clear()
            ok_ = stelle(30, x_, z_, random.uniform(0, 360), hof_w_, boden_, wegabstand=0.0)
            _vorplaetze_w.extend(_alt_vp)
            if ok_:
                _klein[30] = _klein.get(30, 0) + 1
                break
for art_, x_, y_, z_, g_ in [a_ for a_ in BURG_AUSSTATTUNG if a_[0] == 12]:
    w_ = math.radians(g_)
    for d_ in (2.0, -2.0):
        if stelle(30, x_ + math.sin(w_) * d_, z_ + math.cos(w_) * d_, random.uniform(0, 360), WL(PD.VORBURG) if y_ == PD.H_VORBURG else
                  WL(PD.PALAS_HOF), y_, wegabstand=0.0):
            _klein[30] = _klein.get(30, 0) + 1
            break
# Stroh neben der Stalltür (nicht davor) und am Unterstand
for seite_ in (1, -1):
    for q_ in (4.8, 5.6, 6.4, 7.2):
        x_ = _stall_x + _su_x * (_stall_B + 2.6) + _sv_x * seite_ * q_
        z_ = _stall_z + _su_z * (_stall_B + 2.6) + _sv_z * seite_ * q_
        if stelle(29, x_, z_, random.uniform(0, 360), _hof_vb, PD.H_VORBURG, wegabstand=0.6):
            _klein[29] = _klein.get(29, 0) + 1
            break
# Leitern dort, wo gearbeitet wird: neben Holzplatz und Unterstand an der Hofmauer
for wp_, (px_, pz_, (ux_, uz_), (nx_, nz_), boden_) in WERKPLAETZE.items():
    if not (wp_.startswith("Holzplatz") or wp_.startswith("Unterstand")):
        continue
    hof_ = PD.VORBURG if wp_.endswith("Vorburg") else PD.MITTELBURG
    tiefe_ = 1.6 if wp_.startswith("Unterstand") else 1.0
    for e_ in (4.0, -4.0, 5.5, -5.5):
        x_, z_ = px_ + ux_ * e_ + nx_ * (3.05 - 3.2 - tiefe_), pz_ + uz_ * e_ + nz_ * (3.05 - 3.2 - tiefe_)
        if stelle(27, x_, z_, math.degrees(math.atan2(nx_, nz_)), WL(hof_), boden_, wegabstand=1.4):
            _klein[27] = _klein.get(27, 0) + 1
            break
print("Hofleben: Tiere", len(TIERE_BURG), "Kleinteile (Art: Anzahl):", _klein)
# Taubenschwärme (szenen/figuren/tauben.gd): in Reihen auf der niedrigen Mauer zur Hofseite, am Boden nahe den Brunnen
TAUBEN_BURG = []        # (x, y, z, Gier, Anzahl, Weite, sitzend)
for m_ in random.sample(MAUERSTUECKE, min(22, len(MAUERSTUECKE))):
    _, ax_, az_, bx_, bz_, oben_, dicke_, aussen_ = m_
    l_ = math.dist((ax_, az_), (bx_, bz_))
    if l_ < 4.0:
        continue
    t_ = random.uniform(0.2, 0.8)
    ux_, uz_ = (bx_ - ax_) / l_, (bz_ - az_) / l_
    x_ = ax_ + (bx_ - ax_) * t_ - aussen_[0] * (dicke_ / 2 - 0.17)
    z_ = az_ + (bz_ - az_) * t_ - aussen_[1] * (dicke_ / 2 - 0.17)
    n_ = random.randint(2, 4)
    TAUBEN_BURG.append((round(x_, 2), round(oben_ + 0.62, 2), round(z_, 2), round(math.degrees(math.atan2(-uz_, ux_)), 1), n_, n_ * 0.32, True))
for name_, (bx_, bz_) in BURG_BRUNNEN.items():
    boden_ = {n_: b_ for n_, _, b_ in _hoefe}[name_]
    w_ = random.uniform(0, math.tau)
    TAUBEN_BURG.append((round(bx_ + math.cos(w_) * 4.5, 2), boden_, round(bz_ + math.sin(w_) * 4.5, 2), 0.0, random.randint(5, 8), 1.8, False))
print("Kleinteile in den Höfen (Art: Anzahl):", _klein, "Taubenschwärme:", len(TAUBEN_BURG))
# Laternen neben den Türen: an jedem Haus und jedem begehbaren Bau eine, an jeder zweiten brennt nachts ein Licht.
# Bei den begehbaren Bauten hängen sie auf dem Mauerpfeiler zwischen Tür (1,6 m breit) und erstem Fenster (ab 1,3 m
# von der Mitte), also 1 m neben der Türmitte und nie vor einer Scheibe.
_laternen = 0
for k_, (x_, y_, z_, g_, f_) in enumerate(HOFHAEUSER):
    b_, t_ = _FORMEN[f_]
    a_ = math.radians(g_)
    vx_, vz_ = math.sin(a_), math.cos(a_)
    ux_, uz_ = math.cos(a_), -math.sin(a_)
    s_ = 1.3 if k_ % 2 else -1.3
    lx_, lz_ = x_ + vx_ * (t_ / 2 + 0.36) + ux_ * s_, z_ + vz_ * (t_ / 2 + 0.36) + uz_ * s_
    BURG_AUSSTATTUNG.append((20, round(lx_, 2), round(y_, 2), round(lz_, 2), round(g_, 1)))
    if k_ % 2 == 0:
        BURG_LICHTER.append((round(lx_ + vx_ * 0.5, 2), round(y_ + 2.3, 2), round(lz_ + vz_ * 0.5, 2)))
    _laternen += 1
for bau_, boden_ in [(b_, PD.H_VORBURG) for b_ in (PD.VORBURG_BAUTEN[0], PD.VORBURG_BAUTEN[6])] + \
                    [(b_, PD.H_BURGHOF2) for b_ in (PD.BURGHOF2_BAUTEN[2], PD.BURGHOF2_BAUTEN[6])] + \
                    [(b_, PD.H_KERNHOF) for b_ in (PD.BURGHOF3_BAUTEN[0], PD.BURGHOF3_BAUTEN[2])] + \
                    [(b_, PD.H_KERNBURG) for b_ in (PD.BURGKUECHE, PD.ZEUGHAUS, PD.PALAS)]:
    (pp_, l_, br_, dr_) = bau_
    a_ = math.radians(dr_)
    for s_ in (-1, 1):
        # Türmitte vor der Front, dann 1,0 m (Welt) entlang der Front
        q_ = (pp_[0] - math.sin(a_) * (br_ / 2 + 0.25), pp_[1] + math.cos(a_) * (br_ / 2 + 0.25))
        t0_, t1_ = W(q_), W((q_[0] + math.cos(a_), q_[1] + math.sin(a_)))
        e_ = math.dist(t0_, t1_)
        lx_, lz_ = t0_[0] + (t1_[0] - t0_[0]) / e_ * s_ * 1.0, t0_[1] + (t1_[1] - t0_[1]) / e_ * s_ * 1.0
        aus_ = W((q_[0] - math.sin(a_), q_[1] + math.cos(a_)))          # ein Schritt nach außen: Blickrichtung
        g_ = math.degrees(math.atan2(aus_[0] - t0_[0], aus_[1] - t0_[1]))
        BURG_AUSSTATTUNG.append((20, round(lx_, 2), round(boden_, 2), round(lz_, 2), round(g_, 1)))
        if s_ > 0:
            BURG_LICHTER.append((round(lx_, 2), round(boden_ + 2.3, 2), round(lz_, 2)))
        _laternen += 1
print("Werkplätze:", sorted(WERKPLAETZE), "Pferde und Heu am Stall:", _pferde, "Laternen:", _laternen, "Lichter:", len(BURG_LICHTER))
# --- Lage eines Punktes in einem begehbaren Bau. Lage im Rahmen des Baus wie in szenen/welt/burgbau.gd (_innenraum): uz entlang des
# Firsts, nx quer zur Tür (+B), Treppen am Giebel -L.
def _innen(bau, hoehe, boden, art=0):
    (pp_, laenge_, breite_, dreh_) = bau
    x_, z_ = W(pp_)
    g_ = math.radians(-dreh_)
    nx_ = (math.cos(g_), -math.sin(g_))
    uz_ = (math.sin(g_), math.cos(g_))
    B_, L_ = breite_ * M / 2, laenge_ * M / 2
    geschosse_ = 1 if art == 1 else max(1, int(hoehe / (4.6 if art == 3 else 3.6)))
    gh_ = hoehe / geschosse_

    def punkt(s, q, k=0):
        return (round(x_ + uz_[0] * s + nx_[0] * q, 2), round(boden + 0.03 + k * gh_, 2), round(z_ + uz_[1] * s + nx_[1] * q, 2))

    def blick(s0, q0, s1, q1):
        a_, b_ = punkt(s0, q0), punkt(s1, q1)
        return round(math.degrees(math.atan2(b_[0] - a_[0], b_[2] - a_[2])), 1)
    return punkt, blick, L_ - 0.6, B_ - 0.6, geschosse_


# Pferde in den Boxen des Stalls (Kopf zur Krippe an der Wand -B)
pk_, bl_, iL_, iB_, _ = _innen(PD.VORBURG_BAUTEN[6], 7, PD.H_VORBURG)
s_, _boxen = -iL_ + 0.6, 0
while s_ < iL_ - 2.0:
    if _boxen % 2 == 0:
        x_, y_, z_ = pk_(s_ + 1.4, -(iB_ - 1.5))
        BURG_AUSSTATTUNG.append((19, x_, round(y_ - 0.03, 2), z_, bl_(0, 0, 0, -1)))
    s_ += 2.8
    _boxen += 1
print("Pferde in den Boxen des Stalls:", (_boxen + 1) // 2)
print("Ausstattung der Höfe:", len(BURG_AUSSTATTUNG), "Stücke, davon", sum(1 for a_ in BURG_AUSSTATTUNG if a_[0] == 14), "Feuerkörbe;",
      "Brunnen in", sorted(BURG_BRUNNEN), "abgelehnt:", _GRUND)
N("Hofhaeuser", "Node3D", BG, "script = ExtResource(\"27_stadthaeuser\")\nnur_ziegel = true\nnur_fachwerk = true\n"
  + "haeuser = PackedVector4Array(" + ", ".join(f"{x:.5g}, {y:.5g}, {z:.5g}, {g:.4g}" for x, y, z, g, _ in HOFHAEUSER) + ")\n"
  + "formen = PackedInt32Array(" + ", ".join(str(f) for *_, f in HOFHAEUSER) + ")")
print("Fachwerkhäuser in den Höfen:", _nh)

for name, pp, text, y_ in [("SchildPalas", PD.PALAS[0], "Palas", 22), ("SchildKapelle", PD.DRACHENKAPELLE[0], "Drachenkapelle", 18),
                           ("SchildKueche", PD.BURGKUECHE[0], "Burgküche", 14), ("SchildZeughaus", PD.ZEUGHAUS[0], "Zeughaus", 15)]:
    x, z = W(pp)
    schild(name, BG, x, PD.H_KERNBURG + y_, z, text, 40)

# Übungsplatz mit zwei Puppen im Hof des Palas (Stufe 4, Kampf), im Süden des Hofs abseits vom Weg zum Palas
OB_ = DS + "/ObererBurg"
UEB = g3p((1440, 395))
N("ObererBurg", "Node3D", DS, T(round(UEB[0], 2), PD.H_KERNBURG, round(UEB[1], 2)))
for k, x in enumerate([-2.5, 2.5]):
    gegner(f"Uebungspuppe{k + 1}", OB_, x, 0, 0, "Übungspuppe", waffe="puppe", tracht="0.55, 0.45, 0.3, 1")
schild("SchildUebungsplatz", OB_, 0, 3.5, 4, "Übungsplatz", 40)
schild("SchildKernburg", BG, *(lambda p: (p[0], PD.H_KERNBURG + 10, p[1]))(W(PD.MITTE_PALAS)), "Palas", 44)

# Banner an den Wänden (Art 1): an der Hofseite des Palas, am Bergfried unter der Krone und an den Tortürmen der
# Haupttore; Gier so, dass das Tuch vor der Wand zum Hof hängt
def _banner_plan(pp, richtung_plan, y, breite=1.6, laenge=4.5):
    """Banner an der Wand im Planpunkt pp; richtung_plan zeigt aus der Wand heraus (Plan)."""
    x_, z_ = W(pp)
    nx_, nz_ = richtung_plan[1], -richtung_plan[0]          # Plan (dx, dy) → Welt (dy, -dx)
    l_ = math.hypot(nx_, nz_)
    FAHNEN.extend([round(x_, 2), round(y, 2), round(z_, 2), round(math.degrees(math.atan2(nx_ / l_, nz_ / l_)), 1), breite, laenge, 1])


(pp_, l_, br_, dr_) = PD.PALAS
_a = math.radians(dr_)
_vor = (-math.sin(_a), math.cos(_a))
for q_ in (-0.32, 0.0, 0.32):
    _banner_plan((pp_[0] + _vor[0] * (br_ / 2 + 0.8) + math.cos(_a) * l_ * q_, pp_[1] + _vor[1] * (br_ / 2 + 0.8) + math.sin(_a) * l_ * q_),
                 _vor, PD.H_KERNBURG + 14.5, 1.8, 6.0)
_bm = PD.BERGFRIED_KERNBURG
_zum_hof = (PD.MITTE_PALAS[0] - _bm[0], PD.MITTE_PALAS[1] - _bm[1])
_zl = math.hypot(*_zum_hof)
_zum_hof = (_zum_hof[0] / _zl, _zum_hof[1] / _zl)
_banner_plan((_bm[0] + _zum_hof[0] * (PD.BERGFRIED_SEITE / M / 2 + 0.8), _bm[1] + _zum_hof[1] * (PD.BERGFRIED_SEITE / M / 2 + 0.8)),
             _zum_hof, PD.H_BERGFRIEDFELS + PD.BERGFRIED_HOEHE - 5.0, 3.0, 10.0)
for tor_, hof_, boden_ in [("Rampentor", PD.MITTELBURG, PD.H_BURGHOF2), ("Palastor", PD.PALAS_HOF, PD.H_KERNBURG),
                           ("Vorburgtor", PD.VORBURG, PD.H_VORBURG)]:
    tw_ = W(PD.TORE[tor_])
    (ux_, uz_), (nx_, nz_) = _naechste_kante_innen(tw_, WL(hof_))
    # über dem Torbogen auf der Hofseite (Welt → Plan: Richtung (nx, nz) ist Plan (-nz, nx))
    _banner_plan(PD.plan((tw_[0] + nx_ * 2.3, tw_[1] + nz_ * 2.3)), (-nz_, nx_), boden_ + 9.5, 1.6, 3.8)
N("Fahnen", "Node3D", BG, f"""script = ExtResource("28_burgbau")
fahnen = PackedFloat32Array({_zahlen(FAHNEN)})
kollision = false""")

# --- Stadt und Hafen ---
teil("teil_stadt.py")
N("BurgAusstattung", "Node3D", BG, "script = ExtResource(\"29_ausstattung\")\nstuecke = PackedFloat32Array("
  + ", ".join(f"{v:.5g}" for st_ in BURG_AUSSTATTUNG for v in st_) + ")")
E("Script", "res://szenen/figuren/tauben.gd", "42_tauben")
N("Tauben", "Node3D", BG)
for k_, (x_, y_, z_, g_, n_, weite_, sitzend_) in enumerate(TAUBEN_BURG):
    N(f"Schwarm{k_}", "Node3D", BG + "/Tauben", f"""{T(x_, y_, z_, g_)}
script = ExtResource("42_tauben")
anzahl = {n_}
weite = {weite_:.3g}
sitzend = {"true" if sitzend_ else "false"}""")
# Tiere als eigene Knoten mit Revier (szenen/figuren/tier.gd)
E("Script", "res://szenen/figuren/tier.gd", "41_tier")
N("Tiere", "Node3D", BG)
for k_, (art_, x_, y_, z_, g_, rev_) in enumerate(TIERE_BURG):
    rev_txt_ = ", ".join(f"{a:.5g}, {b:.5g}" for a, b in rev_)
    N(f"Tier{k_}", "Node3D", BG + "/Tiere", f"""{T(x_, y_, z_, g_)}
script = ExtResource("41_tier")
art = {art_}
revier = PackedVector2Array({rev_txt_})""")
for k_, (x_, y_, z_) in enumerate(BURG_LICHTER):
    licht(f"BurgFeuer{k_}", BG, x_, y_, z_, 11.0)
zinnen_schreiben(DS)
