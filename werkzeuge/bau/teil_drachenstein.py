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
                MAUERLINIEN.append([(p0_[0] + nx_ * abstand, p0_[1] + nz_ * abstand), (p1_[0] + nx_ * abstand, p1_[1] + nz_ * abstand)])
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
# Begehbar (Art 4 + 10): sein Boden liegt auf der Höhe des Wegs über dem Bogen (wie burgbau._tor: mindestens 1 m über
# dem Scheitel), seine Giebel stecken 0,5 m in den Tortürmen, deren Kammern Türen in die Stube bekommen
_tb_ = min((t_ for t_ in TORBOEGEN_ALLE if t_[0] == "Oberburg"), key=lambda t_: math.dist(t_[1:3], (_sx, _sz)))
_s_weg = max(_tb_[7], _tb_[5] + 3.4 + _tb_[6] / 2 + 1.0)
_s_lang = 2 * ((_tb_[6] / 2 + 2.6) - 2.5 + 0.5)
N("TorhausOberburg", "Node3D", BG, f"""script = ExtResource("28_burgbau")
gebaeude = PackedFloat32Array({_zahlen([round(_tb_[1], 2), round(_tb_[2], 2), round(_s_g, 2), 6.2, round(_s_lang, 2), round(_s_weg + 0.03, 2), round(_s_oben, 2), 4.2, 3.4, 3, 1, 14])})""")
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

# --- Palas, Bergfried, Eckturm und Rundturm hängen zusammen wie im Referenzbild: der Palas reicht hinten bis an den
# Bergfried (seine Hoffassade bleibt, wo sie ist), der eckige Turm steht bündig an seinem Ende, der Rundturm mit
# Kegeldach halb in seiner vorderen Ecke ---
def _rahmen(bau):
    """Planbau → (Mitte, Richtung der Länge, Richtung der Breite zum Hof, halbe Länge, halbe Breite) in der Welt"""
    (pp_, laenge_, breite_, dreh_) = bau
    a_ = math.radians(-dreh_)
    return W(pp_), (math.sin(a_), math.cos(a_)), (math.cos(a_), -math.sin(a_)), laenge_ * M / 2, breite_ * M / 2


def _lokal(punkt, mitte, ul, ub):
    d_ = (punkt[0] - mitte[0], punkt[1] - mitte[1])
    return d_[0] * ul[0] + d_[1] * ul[1], d_[0] * ub[0] + d_[1] * ub[1]


def _welt(mitte, ul, ub, l_, b_):
    return (mitte[0] + ul[0] * l_ + ub[0] * b_, mitte[1] + ul[1] * l_ + ub[1] * b_)


_pm, _pl, _pb, _pL, _pB = _rahmen(PD.PALAS)
_bf_l, _bf_b = _lokal(W(PD.BERGFRIED_KERNBURG), _pm, _pl, _pb)
# Rückwand des Palas an den Bergfried: dessen Sockel springt unten 0,7 m vor, er soll in der Rückwand (0,6 m) des
# Palas stecken, nicht in dessen Erdgeschoss (dort steht die Treppe); darüber bleibt eine Fuge von 0,1 m
_hinten = min(-_pB, _bf_b + PD.BERGFRIED_SEITE / 2 + 0.1)
_neu_b = (_pB - _hinten) / 2                      # neue halbe Breite (vorn bleibt bei +_pB)
_neu_mitte = _welt(_pm, _pl, _pb, 0.0, _pB - _neu_b)
PD.PALAS = (PD.plan(_neu_mitte), PD.PALAS[1], _neu_b * 2 / M, PD.PALAS[3])
_pm, _pl, _pb, _pL, _pB = _rahmen(PD.PALAS)
# Eckturm: bündig an das Palasende auf seiner Seite (0,3 m in die Giebelwand)
_eb_l, _eb_b = _lokal(W(PD.PALAS_ECKBAU[0]), _pm, _pl, _pb)
_eb_h = PD.PALAS_ECKBAU[1] * M / 2
_eb_seite = 1.0 if _eb_l > 0 else -1.0
PD.PALAS_ECKBAU = (PD.plan(_welt(_pm, _pl, _pb, _eb_seite * (_pL + _eb_h - 0.3), _eb_b)),) + tuple(PD.PALAS_ECKBAU[1:])
# Rundturm mit Kegeldach an der anderen Ecke vorn, halb im Palas
_rt_welt = _welt(_pm, _pl, _pb, -_eb_seite * (_pL + 1.0), _pB - 1.2)
print("Palas %.1f m tief (bis an den Bergfried), Eckturm und Rundturm an seinen Enden" % (_neu_b * 2))

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
for k_, (gp, gr) in enumerate(PD.G3.PALAS_TUERME):
    r = round(max(3.0, gr * G3M), 1)
    pp_ = PD.plan(_rt_welt) if k_ == 0 else PD.g3(gp)     # der erste steht an der Ecke des Palas
    _zt += turmmasse(pp_, r, 0)[:3] + [PD.H_KERNBURG + 20, r, 1, round(r * 2.0, 1)]   # Kegeldächer am Palas
    _HOF_TUERME.append(pp_)
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
material_rampe = ExtResource("Material_holz")
mit_schildern = false""")
# Einrichtung der Ebenen: in drei Ecken des Raums und an der Rückwand (in der vierten Ecke steht die Wendeltreppe)
BI = BG + "/BergfriedInnen"
def _ecke(k_, r_=7.4):
    if k_ == 1:     # die Ecke der Treppe: statt dessen mitten an der Rückwand
        w_ = math.radians(_tuer_w + 180)
        return (round((_innen - 1.3) * math.cos(w_), 2), round((_innen - 1.3) * math.sin(w_), 2))
    return (round(r_ * math.cos(math.radians(_tuer_w + 45 + 90 * k_)), 2), round(r_ * math.sin(math.radians(_tuer_w + 45 + 90 * k_)), 2))
_drehung = lambda k_: round(-(_tuer_w + 180) - 45, 1) if k_ == 1 else round(-(_tuer_w + 45 + 90 * k_), 1)
# Jedes Geschoss ganz eingerichtet (burgbau.gd, raeume): Hausrat an allen Wänden, Möbelgruppen in der Fläche, in den
# hohen Räumen Hängestangen; frei bleiben die Wendeltreppe in der Ecke, der Weg von ihr zur Mitte, die Mitte, im
# Eingang der Weg von der Tür und in der Glockenstube die Glocke mit ihrem Stuhl.
_r_mitte = math.radians(_tr_ecke + 180)
_tm_w = (bx + _tr_mitte[0], bz + _tr_mitte[1])
_dw = math.radians(_tuer_w)
_frei_bf = [(_tm_w[0], _tm_w[1], _tr_r + 0.5, -1e4),
            (_tm_w[0] + math.cos(_r_mitte) * 3.6, _tm_w[1] + math.sin(_r_mitte) * 3.6, 1.4, -1e4),
            (bx, bz, 1.4, -1e4)] + \
           [(bx + math.cos(_dw) * d_, bz + math.sin(_dw) * d_, 1.4, PD.H_KERNBURG) for d_ in (6.2, 3.6)]
_gl = _ecke(0, 6.0)
_frei_bf.append((bx + _gl[0], bz + _gl[1], 2.6, PD.H_KERNBURG + 6 * _bstufe))
_raeume_bf = []
_bg = math.degrees(math.atan2(-_bu[1], _bu[0]))          # u = _bu
for ebene_, art_ in enumerate([20, 21, 22, 23, 24, 25, 26, 27]):
    _raeume_bf += [bx, bz, round(_bg, 2), 6.75, 6.75, round(PD.H_KERNBURG + ebene_ * _bstufe, 3),
                   round(PD.H_KERNBURG + (ebene_ + 1) * _bstufe - 0.3, 3), art_]
N("BergfriedEinrichtung", "Node3D", BG, f"""script = ExtResource("28_burgbau")
raeume = PackedFloat32Array({_zahlen(_raeume_bf)})
raum_frei = PackedVector4Array({", ".join(f"{a_:.3f}, {b_:.3f}, {c_:.2f}, {d_:.3f}" for a_, b_, c_, d_ in _frei_bf)})""")
# In der Glockenstube hängt die Glocke an ihrem Stuhl über der Mitte des Raums
_y6 = 6 * _bstufe
x_, z_ = _ecke(0)
box("E6Glockenstuhl0", BI, x_, round(_y6 + 0.15, 2), z_, 2.6, 0.3, 0.3, "Material_holz", gier=_drehung(0) + 45)
x_, z_ = _ecke(0, 6.0)
zyl("Glocke", BI, x_, round(_y6 + 4.2, 2), z_, 0.9, 1.4, "Material_metall", 12, kollision=False)
box("E6Seil1", BI, x_, round(_y6 + 2.0, 2), z_, 0.06, 3.0, 0.06, "Material_holz", kollision=False)
BERGFRIED_TUER = (round(bx - _bu[0] * PD.BERGFRIED_SEITE / 2, 2), round(bz - _bu[1] * PD.BERGFRIED_SEITE / 2, 2))
_HOF_TUERME.append(PD.BERGFRIED_KERNBURG)
FAHNEN.extend([bx, PD.H_BERGFRIEDFELS + PD.BERGFRIED_HOEHE + 0.05, bz, 30, 3.6, 6.0, 0])

# Palas: drei Geschosse mit gotischen Doppelfenstern, steiles Schieferdach, an der Nordostmauer
gebaeude("Palas", BG, PD.PALAS, 16, PD.H_KERNBURG, mat="Material_hell", dachhoehe=11, art=3, zweck=3)
gebaeude("Drachenkapelle", BG, PD.DRACHENKAPELLE, 11, PD.H_KERNBURG, mat="Material_hell", art=1, dachhoehe=8, zweck=6)
gebaeude("Burgkueche", BG, PD.BURGKUECHE, 7, PD.H_KERNBURG, dach="Material_dach", zweck=1)
gebaeude("Zeughaus", BG, PD.ZEUGHAUS, 8, PD.H_KERNBURG, zweck=2)

# --- Begehbare Bauten in den übrigen Höfen (wie bisher je Hof zwei) ---
# Der Stall der Vorburg reichte bis in die Ecke, in der der Treppenturm steht (treppenturm in teil_mauern.py,
# Außenradius 5 m): auf der Seite zum Turm gekürzt, die andere Seite bleibt, wo sie war. Pferch, Tränke und
# Einrichtung richten sich nach demselben Planeintrag.
TREPPENTURM_VORBURG = (19.62, 133.1)


def _kuerze_bau(bau, punkt, frei):
    (pp, laenge, breite, dreh) = bau
    a = math.radians(-dreh)
    x, z = W(pp)
    vx, vz = math.sin(a), math.cos(a)          # Richtung der Länge in der Welt
    lz = (punkt[0] - x) * vx + (punkt[1] - z) * vz
    halb = laenge * M / 2
    sg = 1.0 if lz > 0 else -1.0
    rand = lz - sg * frei                      # neue Kante zum Punkt hin
    if (rand - sg * halb) * sg >= 0:
        return bau                             # weit genug weg
    fern = -sg * halb
    mitte = (rand + fern) / 2
    neu_w = (x + vx * mitte, z + vz * mitte)
    # zurück in den Plan (W ist affin)
    e = 1.0
    (x1, z1), (x2, z2) = W((pp[0] + e, pp[1])), W((pp[0], pp[1] + e))
    j = ((x1 - x) / e, (x2 - x) / e, (z1 - z) / e, (z2 - z) / e)
    det = j[0] * j[3] - j[1] * j[2]
    dx, dz = neu_w[0] - x, neu_w[1] - z
    pp_neu = (pp[0] + (j[3] * dx - j[1] * dz) / det, pp[1] + (-j[2] * dx + j[0] * dz) / det)
    return (pp_neu, abs(rand - fern) / M, breite, dreh)


def _kuerze_quer(bau, punkt, frei):
    """Wie _kuerze_bau, aber entlang der Breite (die andere Achse des Baus)."""
    (pp, laenge, breite, dreh) = bau
    (pp2, breite2, laenge2, _) = _kuerze_bau((pp, breite, laenge, dreh - 90.0), punkt, frei)
    return (pp2, laenge, breite2, dreh)


def _kuerze_an_mauern(bau, ringe, abstand=0.15):
    """Kürzt einen Bau an seinen Enden (Länge und Breite), wo der Körper einer Mauer der genannten Ringe (aus
    MAUERSTUECKE) in ihn hineinreicht: das Ende rückt bis abstand vor die Mauer. Gibt den neuen Planeintrag und die
    Kürzungen (Ring, Achse, Kante) zurück."""
    gekuerzt = []
    for achse in ("laenge", "breite"):
        (pp, laenge, breite, dreh) = bau
        a = math.radians(-dreh)
        x, z = W(pp)
        vx, vz = (math.sin(a), math.cos(a)) if achse == "laenge" else (math.cos(a), -math.sin(a))
        halb, halb_q = (laenge * M / 2, breite * M / 2) if achse == "laenge" else (breite * M / 2, laenge * M / 2)
        for (name, ax, az, bx, bz, _oben, dicke, _aussen) in MAUERSTUECKE:
            l_ = math.hypot(bx - ax, bz - az)
            if name not in ringe or l_ < 0.3:
                continue
            ux, uz = (bx - ax) / l_, (bz - az) / l_
            if abs(ux * vx + uz * vz) > 0.7:
                continue                    # läuft längs dieser Achse: kürzt das andere Paar Enden
            werte = []
            for k in range(int(l_ / 0.25) + 1):
                for q in (-dicke / 2, 0.0, dicke / 2):
                    px, pz = ax + ux * k * 0.25 - uz * q, az + uz * k * 0.25 + ux * q
                    if abs((px - x) * vz - (pz - z) * vx) < halb_q + 0.1:
                        werte.append((px - x) * vx + (pz - z) * vz)
            drin = [w_ for w_ in werte if -halb < w_ < halb]
            if not drin:
                continue
            kante = min(w_ for w_ in werte if w_ > 0) if sum(drin) > 0 else max(w_ for w_ in werte if w_ < 0)
            punkt = (x + vx * kante, z + vz * kante)
            bau = _kuerze_bau(bau, punkt, abstand) if achse == "laenge" else _kuerze_quer(bau, punkt, abstand)
            gekuerzt.append((name, achse, round(kante, 2)))
    return bau, gekuerzt


PD.VORBURG_BAUTEN[6] = _kuerze_bau(PD.VORBURG_BAUTEN[6], TREPPENTURM_VORBURG, 5.6)
# Am anderen Ende stieß der Stall in die Mauer der Mittelburg (das Boxenpferd stand dort mit dem Rumpf in der Mauer)
PD.VORBURG_BAUTEN[6], _gek = _kuerze_an_mauern(PD.VORBURG_BAUTEN[6], ("Mittelburg",))
print("Stall der Vorburg an Mauern gekürzt:", _gek)
print("Stall der Vorburg vor dem Treppenturm: %.1f m lang" % (PD.VORBURG_BAUTEN[6][1] * M))
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
          # beim kurzen Platz (9,6 m Pferch) liegt der Koben gleich daneben (bis 9,6 m weiter): er gehört mit zur Fläche
          r_ = _rechteck_ab(x_, z_, _laenge, 6.6, g_) if _laenge > 10 else \
              _rechteck_ab(x_ + ux_ * 2.6, z_ + uz_ * 2.6, 15.4, 6.6, g_)
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
    _ua_ = math.radians(g_)
    _ux_, _uz_ = math.cos(_ua_), -math.sin(_ua_)
    _feste_w.append(_rechteck_ab(x_, z_, laenge_ + 1.0, 7.6, g_) if laenge_ > 10 else
                    _rechteck_ab(x_ + _ux_ * 2.6, z_ + _uz_ * 2.6, 16.4, 7.6, g_))   # für nichts anderes
    HOFHAEUSER = [h_ for i_, h_ in enumerate(HOFHAEUSER) if i_ not in set(weg_)]
    print(f"Wirtschaftshof an der Vorburgmauer: {math.dist((x_, z_), _stall_tuer):.1f} m von der Stalltür, {len(weg_)} Häuser weichen")
N("Mauertreppen", "Node3D", BG, f"""script = ExtResource("28_burgbau")
treppen = PackedFloat32Array({_zahlen(TREPPEN)})""")
# --- Kein Hofhaus steckt in einem Rundturm (mit Anlauf am Fuß) oder in einer Mauer: Punkte auf dem Rand und in der
# Fläche des Hauses (mit Vorkragung) gegen Turmkreise und Mauerstücke
def _haus_stoesst(h_):
    ecken_ = _haus_rechteck(h_, 0.15)
    punkte_ = []
    for i_ in range(4):
        (x1_, z1_), (x2_, z2_) = ecken_[i_], ecken_[(i_ + 1) % 4]
        n_ = max(1, int(math.dist((x1_, z1_), (x2_, z2_)) / 0.5))
        punkte_ += [(x1_ + (x2_ - x1_) * k_ / n_, z1_ + (z2_ - z1_) * k_ / n_) for k_ in range(n_)]
    for fa_ in (0.25, 0.5, 0.75):
        for fb_ in (0.25, 0.5, 0.75):
            punkte_.append((ecken_[0][0] + (ecken_[1][0] - ecken_[0][0]) * fa_ + (ecken_[3][0] - ecken_[0][0]) * fb_,
                            ecken_[0][1] + (ecken_[1][1] - ecken_[0][1]) * fa_ + (ecken_[3][1] - ecken_[0][1]) * fb_))
    for rx_, rz_, rr_ in _runde_w:
        if any(math.dist(q_, (rx_, rz_)) < rr_ + 0.8 for q_ in punkte_):
            return "Turm bei (%.1f, %.1f)" % (rx_, rz_)
    for (nm_, ax_, az_, bx_, bz_, _, dicke_, _) in MAUERSTUECKE:
        if any(abstand_linie([(ax_, az_), (bx_, bz_)], *q_) < dicke_ / 2 + 0.1 for q_ in punkte_):
            return "Mauer %s" % nm_
    return ""


_stossend = []
for i_, h_ in enumerate(HOFHAEUSER):
    grund_ = _haus_stoesst(h_)
    if not grund_:
        continue
    # erst ein kleineres Haus an derselben Stelle (Rücken an derselben Linie), dann seitlich verschoben, zuletzt bis
    # 1,2 m von der Mauer abgerückt
    x_, y_, z_, g_, f_ = h_
    a_ = math.radians(g_)
    ux_, uz_, vx_, vz_ = math.cos(a_), -math.sin(a_), math.sin(a_), math.cos(a_)
    t_alt_ = _FORMEN[f_][1]
    ersatz_ = None
    for schub_, extra_ in [(s_, e_) for e_ in (0.0, 0.4, 0.8, 1.2) for s_ in (0.0, -0.6, 0.6, -1.2, 1.2, -1.8, 1.8, -2.5, 2.5)]:
        for f2_ in sorted(range(len(_FORMEN)), key=lambda k_: -_FORMEN[k_][0] * _FORMEN[k_][1]):
            b2_, t2_ = _FORMEN[f2_]
            if b2_ > _FORMEN[f_][0] + 0.01 or t2_ > t_alt_ + 0.01:
                continue
            vor_ = (t2_ - t_alt_) / 2 + extra_   # Rücken bleibt an seiner Linie (oder rückt ein Stück vor)
            neu_ = (round(x_ + ux_ * schub_ + vx_ * vor_, 2), y_, round(z_ + uz_ * schub_ + vz_ * vor_, 2), g_, f2_)
            if _haus_stoesst(neu_):
                continue
            if any(j_ != i_ and _ueberlappen_plan(_haus_rechteck(neu_, 0.05), _haus_rechteck(o_, 0.05))
                   for j_, o_ in enumerate(HOFHAEUSER)):
                continue
            ersatz_ = neu_
            break
        if ersatz_:
            break
    if ersatz_:
        HOFHAEUSER[i_] = ersatz_
        print(f"Hofhaus bei ({x_}, {z_}) stieß an {grund_}: jetzt Form {ersatz_[4]} bei ({ersatz_[0]}, {ersatz_[2]})")
    else:
        _stossend.append(i_)
        print(f"Hofhaus bei ({x_}, {z_}) stößt an {grund_}: weicht")
HOFHAEUSER = [h_ for i_, h_ in enumerate(HOFHAEUSER) if i_ not in set(_stossend)]
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
              27: (0.6, 1.1), 28: (4.2, 0.6), 29: (1.2, 1.2), 30: (1.6, 1.2), 31: (0.2, 0.3),
              40: (2.0, 0.8), 41: (3.4, 0.9), 42: (1.3, 0.9), 43: (1.5, 3.7), 44: (1.8, 0.4), 45: (2.2, 2.0), 46: (1.4, 1.3),
              47: (2.2, 1.5), 48: (0.9, 0.9), 3: (3.2, 2.2), 49: (2.1, 4.8), 33: (3.2, 0.5)}
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
# Die Blickpunkte des Foto-Rundgangs (werkzeuge/rundgang/drachenstein.json) stehen dort, wo man einen Hof betritt und
# überblickt: 8 × 8 m bleiben frei von größeren Stücken (sonst stünde z. B. ein Fuhrwerk in der Kamera)
import json as _json
for _bp in _json.loads((REPO / "werkzeuge" / "rundgang" / "drachenstein.json").read_text(encoding="utf-8")).get("punkte", []):
    _vorplaetze_w.append(_rechteck_w(_bp["von"][0], _bp["von"][2], 8.0, 8.0, 0.0))


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
BURGBAEUME = []                  # Hoflinden (x, y, z, Größe; negativ: Laubbaum), für bewuchs in region_drachenstein.py
WERKPLAETZE = {}                 # Name → (x, z, entlang, nach innen, Boden): dort steht jemand bei der Arbeit


def werkplatz(name, teile, hof_w, boden, tiefe=1.0, frei_im_hof=False, mitte=False):
    """Sucht an der Hofmauer einen Platz für eine Gruppe von Stücken. teile: (Art, entlang, nach innen, Drehung) im
    Rahmen der Mauer (entlang der Kante, nach innen in den Hof); gestellt wird nur, wenn alle passen.
    frei_im_hof: sonst frei im Hof; mitte: zuerst frei im Hof (dort, wo man den Hof betritt und sieht)."""
    if mitte and _werkplatz_im_hof(name, teile, hof_w, boden):
        return True
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
    if not frei_im_hof:
        return False
    return _werkplatz_im_hof(name, teile, hof_w, boden)


def _werkplatz_im_hof(name, teile, hof_w, boden):
    """Wie werkplatz, aber frei im Hof (Raster 2 m, vier Richtungen, mindestens 8 m von der Mauer)."""
    # An der Mauer ist kein Platz: frei im Hof, auf einem Raster, in vier Richtungen (die Höfe sind in der Mitte weit
    # und leer, Mängelliste M21)
    raster_ = []
    xs_, zs_ = [q[0] for q in hof_w], [q[1] for q in hof_w]
    x_ = min(xs_) + 4.0
    while x_ < max(xs_) - 4.0:
        z_ = min(zs_) + 4.0
        while z_ < max(zs_) - 4.0:
            if _im_poly((x_, z_), hof_w) and _abstand_rand((x_, z_), hof_w) > 8.0:
                raster_.append((x_, z_))
            z_ += 2.0
        x_ += 2.0
    # nahe der Hofmitte zuerst (dort sieht man sie, wenn man den Hof betritt), mit etwas Zufall
    mx_, mz_ = sum(xs_) / len(xs_), sum(zs_) / len(zs_)
    raster_.sort(key=lambda q_: math.dist(q_, (mx_, mz_)) + random.uniform(0.0, 6.0))
    for px_, pz_ in raster_:
        for g0_ in random.sample((0.0, 90.0, 180.0, 270.0), 4):
            a_ = math.radians(g0_)
            nx_, nz_ = math.sin(a_), math.cos(a_)
            ux_, uz_ = nz_, -nx_
            lagen_ = [(art_, px_ + ux_ * e_ + nx_ * i_, pz_ + uz_ * e_ + nz_ * i_, g0_ + d_) for art_, e_, i_, d_ in teile]
            if all(stelle(art_, x_, z_, g_, hof_w, boden, wegabstand=3.0, probe=True) for art_, x_, z_, g_ in lagen_):
                for art_, x_, z_, g_ in lagen_:
                    stelle(art_, x_, z_, g_, hof_w, boden, wegabstand=3.0)
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
    # Hoflinde (Laubbaum) unweit des Brunnens: Stamm abseits der Wege, die Krone (7 m) über keinem Haus und keinem Bau
    if name_ in BURG_BRUNNEN and name_ != "Palas":
        bx_, bz_ = BURG_BRUNNEN[name_]
        for k_ in range(60):
            w_, r_ = k_ * 2.4, 7.0 + 0.15 * k_
            x_, z_ = bx_ + r_ * math.cos(w_), bz_ + r_ * math.sin(w_)
            krone_ = _rechteck_w(x_, z_, 7.0, 7.0, 0.0)
            if any(_ueberlappen_plan(krone_, f_) for f_ in _haeuser_w + _feste_w):
                continue
            if stelle(10, x_, z_, 0.0, hof_w_, boden_, wegabstand=3.0, probe=True):
                BURGBAEUME.append((round(x_, 2), round(boden_, 2), round(z_, 2), -1.25))
                BURG_SPERREN.append(_rechteck_w(x_, z_, 1.6, 1.6, 0.0))
                # Tisch mit Bänken im Schatten der Linde (M21): dort sitzen Leute bei der Rast
                for k2_ in range(24):
                    w2_ = k2_ * 0.9
                    tx_, tz_ = x_ + 3.2 * math.cos(w2_), z_ + 3.2 * math.sin(w2_)
                    g2_ = math.degrees(w2_) + 90.0          # die Bänke liegen tangential zum Stamm
                    if stelle(45, tx_, tz_, g2_, hof_w_, boden_, wegabstand=2.6):
                        WERKPLAETZE[f"Tisch {name_}"] = (tx_, tz_, (math.cos(math.radians(g2_)), -math.sin(math.radians(g2_))),
                                                         (math.sin(math.radians(g2_)), math.cos(math.radians(g2_))), boden_)
                        break
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
        # Heuplatz: zwei Heuhaufen und ein Karren, der gerade abgeladen wird
        werkplatz(f"Heuplatz {name_}", [(18, -1.3, 0.2, 0), (18, 1.2, 0.5, 35), (4, 4.3, 1.5, 80)],
                  hof_w_, boden_, tiefe=1.2)
    # Ladeplatz an der Hofmauer: ein Karren, daneben Fässer, Kisten und Säcke (Vorräte, die gerade ankommen)
    werkplatz(f"Ladeplatz {name_}", [(4, 0.0, 1.6, 15), (0, 3.1, 0.4, 0), (0, 3.9, 0.8, 0), (0, 3.4, 1.6, 0),
                                     (1, -3.1, 0.5, 10), (1, -3.2, 1.5, 40), (2, -2.1, 2.5, 0)], hof_w_, boden_, tiefe=1.0)
    if name_ in ("Mittelburg", "Oberburg"):
        # Tränke für die Reitpferde der Boten, daneben ein Wasserfass
        werkplatz(f"Tränke {name_}", [(12, 0.0, 0.4, 0), (0, 1.9, 0.3, 0)], hof_w_, boden_)
    # Mängelliste M21: Arbeit und Alltag in jedem Hof (die Leute dazu setzt teil_burgleben.py)
    if name_ == "Vorburg":
        # Hackplatz: Brennholz für Küche und Schmiede
        werkplatz("Hackplatz Vorburg", [(46, 0.0, 0.9, 0), (11, -2.4, 0.1, 90), (11, 2.6, 0.1, 90)], hof_w_, boden_,
                  frei_im_hof=True)
    if name_ == "Mittelburg":
        # Zimmerplatz: ein Stamm wird auf dem Sägebock zu Balken gesägt, daneben Werkbank und Hackklotz
        werkplatz("Zimmerplatz Mittelburg", [(41, 0.0, 0.6, 0), (40, -3.4, 0.0, 0), (46, 3.1, 1.3, 0), (11, 0.0, -1.6, 0)],
                  hof_w_, boden_, mitte=True)
    if name_ == "Oberburg":
        # Kräuter- und Gemüsegarten der Burgküche: drei Beete nebeneinander, die Schmalseite an der Mauer
        werkplatz("Garten Oberburg", [(43, -2.0, 1.2, 0), (43, 0.0, 1.2, 0), (43, 2.0, 1.2, 0), (2, 3.6, 0.2, 20)],
                  hof_w_, boden_, tiefe=0.4, frei_im_hof=True)
        # Steinmetz: Quader für die Ausbesserung der Mauern
        werkplatz("Steinmetz Oberburg", [(47, 0.0, 0.7, 0), (40, -3.0, 0.1, 0)], hof_w_, boden_, frei_im_hof=True)
        # Händler aus der Stadt: zwei Stände mit Waren für das Gesinde, dahinter Kisten und Säcke
        werkplatz("Markt Oberburg", [(3, -2.0, 0.0, 0), (3, 2.0, 0.0, 0), (1, -3.2, -1.6, 15), (2, 0.0, -1.7, 0),
                                     (0, 3.3, -1.5, 0)], hof_w_, boden_, mitte=True)
    if name_ == "Palas":
        # Übungsplatz der Knappen: Zielscheiben mit dem Rücken zur Mauer, Waffen- und Rüstungsständer, Bank
        werkplatz("Übungsplatz Palas", [(42, -2.0, 0.2, 0), (42, 0.6, 0.2, 0), (48, 3.0, 0.2, 0), (13, 4.8, 0.3, 0),
                                        (44, -4.6, 0.3, 0)], hof_w_, boden_, mitte=True)
    # Zweite Runde (M21): ein Fuhrwerk mitten im Hof, das gerade be- oder entladen wird: Leiterwagen, davor das Zugpferd,
    # hinter dem Wagen Fässer und Kisten
    if name_ in ("Vorburg", "Mittelburg", "Oberburg"):
        werkplatz(f"Fuhrwerk {name_}", [(49, 0.0, 0.0, 0), (19, 0.0, 4.1, 0), (0, -0.6, -3.3, 0), (0, 0.3, -3.5, 0),
                                        (1, 1.2, -3.1, 25)], hof_w_, boden_, mitte=True)
    if name_ == "Palas":
        # zwei Reitpferde für einen Ausritt der Herrschaft, am Anbindebalken, daneben Heu
        werkplatz("Reitpferde Palas", [(19, -1.1, 0.0, 0), (19, 1.1, 0.2, 0), (33, 0.0, 1.55, 0), (18, 3.4, 0.4, 0)],
                  hof_w_, boden_, mitte=True)
        # Wachtisch: die Wachen der Kernburg würfeln in der Pause, daneben ein Feuerkorb und ein Waffenständer
        werkplatz("Wachtisch Palas", [(45, 0.0, 0.0, 0), (14, 2.0, 0.0, 0), (13, -2.4, 0.2, 90)], hof_w_, boden_, mitte=True)
    # Bank an der Hofmauer (zum Ausruhen)
    werkplatz(f"Bank {name_}", [(44, 0.0, 0.1, 0)], hof_w_, boden_)
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


# Die Pferde in den Boxen des Stalls setzt burgbau.gd selbst (_einrichtung, Zweck 4), passend zu seinen Boxen
print("Ausstattung der Höfe:", len(BURG_AUSSTATTUNG), "Stücke, davon", sum(1 for a_ in BURG_AUSSTATTUNG if a_[0] == 14), "Feuerkörbe;",
      "Brunnen in", sorted(BURG_BRUNNEN), "abgelehnt:", _GRUND)
N("Hofhaeuser", "Node3D", BG, "script = ExtResource(\"27_stadthaeuser\")\nnur_ziegel = true\nnur_fachwerk = true\nbegehbar = true\n"
  + "haeuser = PackedVector4Array(" + ", ".join(f"{x:.5g}, {y:.5g}, {z:.5g}, {g:.4g}" for x, y, z, g, _ in HOFHAEUSER) + ")\n"
  + "formen = PackedInt32Array(" + ", ".join(str(f) for *_, f in HOFHAEUSER) + ")")
print("Fachwerkhäuser in den Höfen:", len(HOFHAEUSER), "(gebaut", _nh, ")")
# Die Fachwerkhäuser sind begehbar (stadthaeuser.gd, begehbar): jedes Geschoss ganz eingerichtet (burgbau.gd, raeume),
# unten die Wohnstube, oben Kammern. Frei bleiben der Weg von der Tür, die Treppen (an wechselnden Seitenwänden, die
# geraden von vorn nach hinten, die ungeraden von hinten nach vorn ansteigend, wie stadthaeuser.treppen), das Loch, aus
# dem man heraufkommt, und der Weg an der Rückwand zum Fuß der nächsten Treppe; die Mitte der Geschosse gehört den Möbeln.
_FORMEN_OG = [int(o_) for o_ in _re.findall(r"\[\d+\.\d+, \d+\.\d+, (\d), \d, (?:true|false), \d, \d\]",
              (REPO / "szenen" / "welt" / "stadthaeuser.gd").read_text(encoding="utf-8"))]
_WAND, _EG, _OG, _VK = 0.3, 3.2, 2.8, 0.35
_raeume_hh, _frei_hh = [], []
for hx_, hy_, hz_, hg_, hf_ in HOFHAEUSER:
    hb_, ht_ = _FORMEN[hf_]
    og_ = _FORMEN_OG[hf_]
    a_ = math.radians(hg_)

    def _w(x_, z_):
        return (hx_ + x_ * math.cos(a_) + z_ * math.sin(a_), hz_ - x_ * math.sin(a_) + z_ * math.cos(a_))
    treppen_ = []                 # (Seite, z oberes Ende, z Fuß)
    for k_ in range(og_):
        lauf_ = (_EG if k_ == 0 else _OG) * 1.5
        if k_ % 2 == 0:
            zh_ = -ht_ / 2 + _WAND + 0.3
            treppen_.append((-1.0, zh_, zh_ + lauf_))
        else:
            zf_ = -ht_ / 2 + _WAND + 1.0
            treppen_.append((1.0, zf_ + lauf_, zf_))
    for g_ in range(og_ + 1):
        boden_ = hy_ + (0.03 if g_ == 0 else _EG + _OG * (g_ - 1))
        decke_ = hy_ + _EG + _OG * g_ - 0.25
        aus_ = _VK * g_
        frei_ = []
        sx_ = lambda s_: s_ * (hb_ / 2 - _WAND - 0.5)
        if g_ == 0:
            frei_ += [_w(0, ht_ / 2 - 0.9), _w(0, ht_ / 2 - 1.9)]
        if g_ < og_:              # die Treppe hinauf und der Platz vor ihrem Fuß
            s_, zo_, zf_ = treppen_[g_]
            d_ = 1.0 if zf_ > zo_ else -1.0          # vom oberen Ende zum Fuß
            z_ = zo_
            while (z_ - (zf_ + d_ * 0.9)) * d_ <= 0.0:
                frei_.append(_w(sx_(s_), z_))
                z_ += 0.7 * d_
            if d_ > 0:
                frei_ += [_w(sx_(s_) * 0.3, zf_ + 0.9), _w(0, zf_ + 0.4)]
            else:                 # Fuß hinten: der Gang an der Rückwand vom Loch herüber
                zr_ = max(-ht_ / 2 - aus_ + _WAND + 0.5, zf_ - 0.6)
                x_ = -sx_(1.0)
                while x_ <= sx_(1.0) + 0.01:
                    frei_.append(_w(x_, zr_))
                    x_ += 0.7
        if g_ > 0:                # das Loch, aus dem man heraufkommt, und der Austritt an seinem oberen Ende
            s_, zo_, zf_ = treppen_[g_ - 1]
            d_ = 1.0 if zf_ > zo_ else -1.0
            z_ = min(zo_, zf_)
            while z_ <= max(zo_, zf_) + 0.2:
                frei_.append(_w(sx_(s_), z_))
                z_ += 0.7
            frei_.append(_w(sx_(s_) * -0.2, zo_ + d_ * 0.4))
            if g_ == og_:         # oberstes Geschoss: vom Austritt ein Stück in den Raum
                frei_.append(_w(0, zo_ + d_ * 1.0))
        _frei_hh += [(x_, z_, 0.6, round(boden_, 3)) for x_, z_ in frei_]
        _raeume_hh += [round(hx_, 3), round(hz_, 3), round(hg_, 2), round(hb_ / 2 - _WAND, 3), round(ht_ / 2 + aus_ - _WAND, 3),
                       round(boden_, 3), round(decke_, 3), 28 if g_ == 0 else 29]
N("HofhausEinrichtung", "Node3D", BG, f"""script = ExtResource("28_burgbau")
zellgroesse = 64.0
zell_laden_ab = 90.0
raeume = PackedFloat32Array({_zahlen(_raeume_hh)})
raum_frei = PackedVector4Array({", ".join(f"{a_:.3f}, {b_:.3f}, {c_:.2f}, {d_:.3f}" for a_, b_, c_, d_ in _frei_hh)})""")
print("Fachwerkhäuser begehbar und eingerichtet: %d Räume" % (len(_raeume_hh) // 8))

# Keine schwebenden Namen über Höfen und Bauten der Burg: beim Betreten zeigt die Oberfläche den Ort an (ort.gd)

# Übungsplatz mit zwei Puppen im Hof des Palas (Stufe 4, Kampf), im Süden des Hofs abseits vom Weg zum Palas
OB_ = DS + "/ObererBurg"
UEB = g3p((1440, 395))
N("ObererBurg", "Node3D", DS, T(round(UEB[0], 2), PD.H_KERNBURG, round(UEB[1], 2)))
for k, x in enumerate([-2.5, 2.5]):
    gegner(f"Uebungspuppe{k + 1}", OB_, x, 0, 0, "Übungspuppe", waffe="puppe", tracht="0.55, 0.45, 0.3, 1")

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
N("BurgAusstattung", "Node3D", BG, "script = ExtResource(\"29_ausstattung\")\nzellgroesse = 64.0\nzell_laden_ab = 240.0\nstuecke = PackedFloat32Array("
  + ", ".join(f"{v:.5g}" for st_ in BURG_AUSSTATTUNG for v in st_) + ")")
E("Script", "res://szenen/figuren/tauben.gd", "42_tauben")
N("Tauben", "Node3D", BG)
for k_, (x_, y_, z_, g_, n_, weite_, sitzend_) in enumerate(TAUBEN_BURG):
    N(f"Schwarm{k_}", "Node3D", BG + "/Tauben", f"""{T(x_, y_, z_, g_)}
script = ExtResource("42_tauben")
anzahl = {n_}
weite = {weite_:.3g}
sitzend = {"true" if sitzend_ else "false"}""")
# Möwen (szenen/figuren/moewen.gd): kreisend über dem Hafenbecken, über der Bucht und an der Klippe unter der
# Kernburg; sitzend in Reihen auf der Kaikante (sie setzen sich selbst auf die Oberfläche)
E("Script", "res://szenen/figuren/moewen.gd", "43_moewen")
N("Moewen", "Node3D", DS)
for k_, (x_, y_, z_, g_, n_, weite_, hoehe_, sitzend_) in enumerate([
        (150, -20, 10, 0, 6, 30, 16, False), (245, -20, 30, 0, 5, 45, 22, False), (105, -20, -125, 0, 4, 35, 30, False),
        (60, -20, 90, 0, 3, 25, 26, False),
        (107.9, -17.8, 8, 90, 4, 5, 0, True), (187.0, -17.8, 22, 90, 3, 4, 0, True)]):   # auf der Kaikante
    N(f"Moewen{k_}", "Node3D", DS + "/Moewen", f"""{T(x_, y_, z_, g_)}
script = ExtResource("43_moewen")
anzahl = {n_}
weite = {weite_}
hoehe = {hoehe_}
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
