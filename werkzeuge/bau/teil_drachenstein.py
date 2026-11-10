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
# Fahnen und Banner (szenen/welt/burgbau.gd, "fahnen"): x, y, z, Gier, Breite, Länge, Art (0 Mast, 1 Banner an der Wand)
FAHNEN = []
_HOF_TUERME = []            # Planpunkte aller Türme an den Höfen (für den Felssockel in teil_felsen.py)

# --- Ringmauer ---
# Niedriger als die Burgmauern (wie im Referenzbild), mit halbrunden, innen offenen Schalentürmen; an den Ecken im
# Nordosten und Südosten geschlossene Bastionen mit Zinnen, der Turm hinter der Oberburg mit Kegeldach
RN = PD.RING_NORD
mauerring("RingmauerNord", BG, WL(RN), 6.5, dicke=3.0, mitte=W(PD.MITTE_VORBURG),
         tore=tor_an(RN, PD.TORE["Nordtor"], 5.0, "Nordtor"))
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
         tore=tore_an(VB, (PD.TORE["Vorburgtor"], 4.5, "Vorburgtor", None, False),
                      (PD.TORE["Osttor der Vorburg"], 4.0, "", None, False)))
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
         tore=tore_an(MB, (PD.TORE["Rampentor"], 5.0, "Rampentor"), (PD.TORE["Zwingertor"], 4.5, "", None, False)))
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
         tore=tore_an(OB, (PD.TORE["Südtor der Oberburg"], 4.5, ""),
                      (PD.TORE["Tor der Oberburg"], 5.0, "Tor der Oberburg", None, False)))   # ohne Tortürme: der Durchgang bleibt frei
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
mauerring("Vortor", BG, WL(PD.VORTOR), 3.5, dicke=2.0, mitte=W(PD.TORE["Südtor der Oberburg"]))
# Im engen Zwinger des Palas: Mauer zwischen dem Weg vom Zwingertor zum Palastor und dem Weg um den Palas
mauerring("PalaszwingerQuer", BG, WL(PD.PALASZWINGER_QUER), 5.0, dicke=2.0, mitte=W(PD.TORE["Palastor"]))
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
         tore=tore_an(ZW, (PD.TORE["Zwingertor des Palas"], 5.0, "", None, False), (PD.TORE["Zwingerpforte des Palas"], 3.5, "", None, False)))
KB = PD.PALAS_HOF + [PD.PALAS_HOF[0]]
mauerring("Kernburg", BG, WL(KB), 8.0, dicke=3.5, mitte=W(PD.MITTE_PALAS),
         tore=tor_an(KB, PD.TORE["Palastor"], 5.0, "Palastor"))
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
N("BergfriedKernburg", "Node3D", BG, f"""script = ExtResource("28_burgbau")
torbauten = PackedFloat32Array({_zahlen([bx, bz, *richtung_welt(PD.BERGFRIED_DREH), PD.H_KERNBURG - 3, PD.H_BERGFRIEDFELS + PD.BERGFRIED_HOEHE, PD.BERGFRIED_SEITE, PD.BERGFRIED_SEITE, 1, -1])})""")
_HOF_TUERME.append(PD.BERGFRIED_KERNBURG)
schild("SchildBergfriedKernburg", BG, bx, PD.H_BERGFRIEDFELS + PD.BERGFRIED_HOEHE + 12, bz, "Bergfried", 56)
FAHNEN.extend([bx, PD.H_BERGFRIEDFELS + PD.BERGFRIED_HOEHE + 0.05, bz, 30, 3.6, 6.0, 0])

# Palas: drei Geschosse mit gotischen Doppelfenstern, steiles Schieferdach, an der Nordostmauer
gebaeude("Palas", BG, PD.PALAS, 16, PD.H_KERNBURG, mat="Material_hell", dachhoehe=11, art=3, zweck=3)
gebaeude("Drachenkapelle", BG, PD.DRACHENKAPELLE, 11, PD.H_KERNBURG, mat="Material_hell", art=1, dachhoehe=8)
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
              13: (1.9, 0.7), 14: (0.7, 0.7), 15: (0.8, 0.7), 16: (1.8, 1.4), 17: (4.6, 3.6), 18: (1.9, 1.9), 19: (0.7, 2.6)}
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


def _abstand_rand(q, poly):
    return min(abstand_linie([a_, b_], *q) for a_, b_ in zip(poly, poly[1:] + poly[:1]))


def stelle(art, x, z, gier, hof_w, boden, wegabstand=3.2, licht=False, probe=False):
    """Stellt ein Stück auf, wenn der Platz frei ist; gibt zurück, ob es geklappt hat."""
    b_, t_ = _A_GROESSE[art]
    r_ = _rechteck_w(x, z, b_ + 0.3, t_ + 0.3, gier)
    if not all(_im_poly(q_, hof_w) for q_ in r_) or min(_abstand_rand(q_, hof_w) for q_ in r_) < 2.2:
        _GRUND["rand"] = _GRUND.get("rand", 0) + 1
        return False
    for n_, l_ in (("haus", _haeuser_w), ("bau", _feste_w), ("treppe", _treppen_w), ("tuer", _tueren_w), ("stueck", BURG_SPERREN)):
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
            break
    # Werkplätze: Schmiede, Holzplatz und ein Unterstand für Karren in der Vorburg, Holzplatz und Unterstand in der
    # Mittelburg (die Stücke stehen mit dem Rücken zur Hofmauer)
    if name_ in ("Vorburg", "Mittelburg"):
        if name_ == "Vorburg":
            werkplatz("Schmiede", [(16, 0.0, 0.0, 0), (15, 0.0, 2.6, 90), (1, -2.0, 0.0, 15), (0, 2.1, -0.1, 0), (13, 3.6, 0.0, 0)], hof_w_, boden_)
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
        if stelle(art_, x_, z_, -dr_ + 180 + random.uniform(-15, 15), WL(PD.VORBURG), PD.H_VORBURG, wegabstand=2.6):
            _pferde += 1
            break
_tueren_w.extend(_tue)
if "Unterstand Mittelburg" in WERKPLAETZE:
    px_, pz_, (ux_, uz_), (nx_, nz_), boden_ = WERKPLAETZE["Unterstand Mittelburg"]
    for e_ in (-4.0, -5.5):
        stelle(19, px_ + ux_ * e_ + nx_ * 1.2, pz_ + uz_ * e_ + nz_ * 1.2, math.degrees(math.atan2(-nx_, -nz_)), WL(PD.MITTELBURG), boden_, wegabstand=2.6)
# Laternen neben den Türen: an jedem Haus und jedem begehbaren Bau eine, an jeder zweiten brennt nachts ein Licht
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
        q_ = (pp_[0] - math.sin(a_) * (br_ / 2 + 0.25) + math.cos(a_) * s_ * 4.0, pp_[1] + math.cos(a_) * (br_ / 2 + 0.25) + math.sin(a_) * s_ * 4.0)
        lx_, lz_ = W(q_)
        g_ = math.degrees(math.atan2(*(lambda d_: (d_[0], d_[1]))((W((q_[0] - math.sin(a_), q_[1] + math.cos(a_)))[0] - lx_,
                                                              W((q_[0] - math.sin(a_), q_[1] + math.cos(a_)))[1] - lz_))))
        BURG_AUSSTATTUNG.append((20, round(lx_, 2), round(boden_, 2), round(lz_, 2), round(g_, 1)))
        if s_ > 0:
            BURG_LICHTER.append((round(lx_, 2), round(boden_ + 2.3, 2), round(lz_, 2)))
        _laternen += 1
print("Werkplätze:", sorted(WERKPLAETZE), "Pferde und Heu am Stall:", _pferde, "Laternen:", _laternen, "Lichter:", len(BURG_LICHTER))
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
for k_, (x_, y_, z_) in enumerate(BURG_LICHTER):
    licht(f"BurgFeuer{k_}", BG, x_, y_, z_, 11.0)
zinnen_schreiben(DS)
