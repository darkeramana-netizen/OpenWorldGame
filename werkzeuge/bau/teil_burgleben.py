# ---------- Leben in der Burgfeste Drachenstein ----------
# Wird aus region_drachenstein.py nach teil_stadtleben.py ausgeführt. Daten aus teil_drachenstein.py: TREPPEN (Treppen
# auf die Wehrgänge), MAUERSTUECKE, HOFHAEUSER, BURG_AUSSTATTUNG und ihre Sperrflächen, BURG_BRUNNEN.
#   - Je Mauertreppe eine Wache: die Treppe hinauf und auf dem Wehrgang auf und ab (Tag und Nacht).
#   - Torwachen an den Toren der Burg und der Stadt.
#   - Gesinde in den Höfen: tagsüber zwischen Brunnen und Häusern unterwegs, abends daheim.
#   - Ein Kaplan vor der Drachenkapelle, der Haushofmeister vor dem Palas, ein Stallknecht an der Tränke.
BL = "Personen/Burgleben"
N("Burgleben", "Node3D", "Personen")
random.seed(1188)
GESINDE_TRACHTEN = ["0.42, 0.34, 0.24, 1", "0.36, 0.3, 0.26, 1", "0.5, 0.44, 0.32, 1", "0.33, 0.36, 0.3, 1"]
WACHE_TRACHT = "0.27, 0.24, 0.2, 1"


def _drin(q, poly):
    x, z = q; innen = False
    for (x1, z1), (x2, z2) in zip(poly, poly[1:] + poly[:1]):
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
            innen = not innen
    return innen


_HINDERNISSE = _haeuser_w + _feste_w + BURG_SPERREN + _treppen_w


def strecke_frei(a, b):
    """Liegt die gerade Strecke von a nach b frei von Häusern, Bauten, Ausstattung und Treppen?"""
    n = max(1, int(math.dist(a, b) / 0.4))
    for i in range(n + 1):
        q = (a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n)
        if any(_drin(q, r_) for r_ in _HINDERNISSE):
            return False
    return True


def p3(punkte, boden=None):
    return [(round(x, 2), round(H(x, z) if boden is None else boden, 2), round(z, 2)) for x, z in punkte]


# --- Wachen auf den Wehrgängen: je Treppe eine ---
WACHEN_NAMEN = ["Mauerwache Gero Lind", "Mauerwache Hella Brück", "Mauerwache Utz Raben", "Mauerwache Swana Teich",
                "Mauerwache Bodo Kiel", "Mauerwache Ragna Holt", "Mauerwache Lutz Ammer", "Mauerwache Femke Dorn",
                "Mauerwache Ansgar Rieth", "Mauerwache Tilda Wehr", "Mauerwache Kuno Sand", "Mauerwache Edda Born"]
_wachen = 0
for k_ in range(0, len(TREPPEN), 7):
    fx_, fz_, fy_, tx_, tz_, ty_, _ = TREPPEN[k_:k_ + 7]
    oben_ = ty_ - 0.62
    stueck_ = min(MAUERSTUECKE, key=lambda m_: abstand_linie([m_[1:3], m_[3:5]], tx_, tz_) + abs(m_[5] - oben_) * 10)
    _, ax_, az_, bx_, bz_, _, dicke_, aussen_ = stueck_
    l_ = math.dist((ax_, az_), (bx_, bz_))
    ux_, uz_ = (bx_ - ax_) / l_, (bz_ - az_) / l_
    px_, pz_ = tx_ + aussen_[0] * dicke_ / 2, tz_ + aussen_[1] * dicke_ / 2        # Mitte des Wehrgangs
    s_ = (px_ - ax_) * ux_ + (pz_ - az_) * uz_
    vor_, zurueck_ = min(8.0, l_ - s_ - 1.5), min(8.0, s_ - 1.5)
    w1_ = (px_ + ux_ * vor_, pz_ + uz_ * vor_)
    w2_ = (px_ - ux_ * zurueck_, pz_ - uz_ * zurueck_)
    y_ = oben_ + 0.06
    punkte_ = [(fx_, fy_, fz_), (tx_, ty_, tz_), (px_, y_, pz_), (w1_[0], y_, w1_[1]), (w2_[0], y_, w2_[1]), (w1_[0], y_, w1_[1])]
    punkte_ = [tuple(round(v_, 2) for v_ in q_) for q_ in punkte_]
    person(f"Wehrgangwache{_wachen}", BL, *punkte_[3], WACHEN_NAMEN[_wachen % len(WACHEN_NAMEN)], "mauerwache", 1, WACHE_TRACHT,
           ablauf={"morgengrauen": (punkte_, ["runde=3"]), "nacht": (punkte_, ["runde=3", "haltung=fackel"])}, tempo=1.1)
    _wachen += 1

# --- Torwachen: zu beiden Seiten der Tore, mit Blick nach außen ---
TOR_WACHEN = [("Vorburgtor", PD.VORBURG, False, 2), ("Rampentor", PD.MITTELBURG, False, 1),
              ("Südtor der Oberburg", PD.OBERBURG, False, 1), ("Palastor", PD.PALAS_HOF, True, 2),
              ("Nordtor", PD.STADT, True, 1), ("Südtor", PD.STADT, True, 1)]
TORWACHEN_NAMEN = ["Torwache Albrecht Koll", "Torwache Mette Haar", "Torwache Sieghard Brunn", "Torwache Imke Faber",
                   "Torwache Detlef Ruhm", "Torwache Gesa Wolter", "Torwache Volkmar Eich", "Torwache Rike Schell"]
_tw = 0
for tor_, hof_, innen_, anzahl_ in TOR_WACHEN:
    tx_, tz_ = W(PD.TORE[tor_])
    hof_w_ = WL(hof_)
    (ux_, uz_), (nx_, nz_) = _naechste_kante_innen((tx_, tz_), hof_w_)
    seite_ = 1 if innen_ else -1
    for s_ in ((-1, 1) if anzahl_ == 2 else (1,)):
        for q_ in (2.2, 2.8, 3.4):
            x_, z_ = tx_ + nx_ * seite_ * q_ + ux_ * s_ * 3.0, tz_ + nz_ * seite_ * q_ + uz_ * s_ * 3.0
            if not any(_drin((x_, z_), r_) for r_ in _HINDERNISSE):
                break
        blick_ = math.degrees(math.atan2(-nx_ * seite_, -nz_ * seite_))      # vom Tor weg nach außen
        person(f"Torwache{_tw}", BL, round(x_, 2), round(H(x_, z_), 2), round(z_, 2), TORWACHEN_NAMEN[_tw % len(TORWACHEN_NAMEN)],
               "torwache_burg", 1, WACHE_TRACHT, gier=round(blick_, 1),
               ablauf={"morgengrauen": (p3([(x_, z_)]), [f"blick={round(blick_, 1)}"]),
                       "nacht": (p3([(x_, z_)]), [f"blick={round(blick_, 1)}", "haltung=fackel"])})
        _tw += 1

# --- Gesinde: tagsüber zwischen Brunnen und Häusern, abends daheim ---
GESINDE_NAMEN = ["Magd Wiebke Rohr", "Knecht Hannes Pfahl", "Magd Trine Lauch", "Knecht Bertram Ast", "Magd Elsbeth Krug",
                 "Knecht Ole Stamm", "Magd Grete Fass", "Knecht Mattis Rain", "Magd Svea Strohm", "Knecht Arne Bühl"]
_gs = 0
for name_, hof_, boden_ in _hoefe:
    hof_w_ = WL(hof_)
    if name_ not in BURG_BRUNNEN:
        continue
    bx_, bz_ = BURG_BRUNNEN[name_]
    # Plätze vor den Türen der Häuser dieses Hofs, von denen der Weg zum Brunnen frei ist
    tueren_ = []
    for x_, _, z_, g_, f_ in HOFHAEUSER:
        if not _drin((x_, z_), hof_w_):
            continue
        a_ = math.radians(g_)
        vor_ = (_FORMEN[f_][1] + 0.7) / 2 + 1.6
        t_ = (x_ + math.sin(a_) * vor_, z_ + math.cos(a_) * vor_)
        um_brunnen_ = (bx_ + (t_[0] - bx_) / math.dist(t_, (bx_, bz_)) * 2.4, bz_ + (t_[1] - bz_) / math.dist(t_, (bx_, bz_)) * 2.4)
        if not any(_drin(t_, r_) for r_ in _HINDERNISSE) and strecke_frei(t_, um_brunnen_):
            tueren_.append((t_, um_brunnen_))
    random.shuffle(tueren_)
    for i_ in range(min(4, len(tueren_) // 2)):
        (heim_, b1_), (arbeit_, b2_) = tueren_[2 * i_], tueren_[2 * i_ + 1]
        if not strecke_frei(b1_, b2_):
            continue
        runde_ = [heim_, b1_, b2_, arbeit_, b2_, b1_, heim_]
        person(f"Gesinde{_gs}", BL, round(heim_[0], 2), boden_, round(heim_[1], 2), GESINDE_NAMEN[_gs % len(GESINDE_NAMEN)],
               "burggesinde", 0, GESINDE_TRACHTEN[_gs % 4], sichtbar_wenn="alarm<3",
               ablauf={"morgengrauen": (p3(runde_, boden_), ["runde"]),
                       "stille_stunde": (p3([heim_], boden_), ["weg"])})
        _gs += 1

# --- An den Lagerplätzen arbeitet jemand: zählt Fässer, stapelt Holz (steht davor, Blick zur Mauer) ---
ARBEIT_NAMEN = ["Knecht Edgar Strunk", "Magd Liesel Garbe", "Knecht Thies Moor", "Magd Hanna Seil", "Knecht Fiete Rumpf",
                "Magd Kaja Spindel", "Knecht Wido Last", "Magd Berit Kamm"]
_ar = 0
for hofname_ in ("Vorburg", "Mittelburg", "Oberburg", "Palas"):
    plaetze_ = [l_ for l_ in LAGERPLAETZE if l_[5] == hofname_]
    random.shuffle(plaetze_)
    for px_, pz_, nx_, nz_, boden_, _ in plaetze_[:2]:
        for q_ in (2.0, 2.5, 3.0, 3.5):
            x_, z_ = px_ + nx_ * q_, pz_ + nz_ * q_
            if not any(_drin((x_, z_), r_) for r_ in _HINDERNISSE):
                break
        else:
            continue
        person(f"Arbeit{_ar}", BL, round(x_, 2), boden_, round(z_, 2), ARBEIT_NAMEN[_ar % len(ARBEIT_NAMEN)], "burggesinde", 0,
               GESINDE_TRACHTEN[(_ar + 2) % 4], gier=round(math.degrees(math.atan2(-nx_, -nz_)), 1), sichtbar_wenn="alarm<3",
               haltung="knien" if _ar % 2 == 0 else "arbeiten")
        _ar += 1
print("Burgleben: an den Lagerplätzen", _ar)

# --- Der Schmied am Amboss ---
if "Schmiede" in WERKPLAETZE:
    px_, pz_, (ux_, uz_), (nx_, nz_), boden_ = WERKPLAETZE["Schmiede"]
    lx_, lz_ = nz_, -nx_                                         # lokal x der Schmiede (Rücken zur Mauer, offen nach n)
    ax_, az_ = px_ + lx_ * -1.4, pz_ + lz_ * -1.4                # Amboss in der Werkstatt
    sx_, sz_ = ax_ + lx_ * 0.85 + nx_ * 0.45, az_ + lz_ * 0.85 + nz_ * 0.45
    person("Burgschmied", BL, round(sx_, 2), boden_, round(sz_, 2), "Burgschmied Wendel Hart", "schmied_burg", 0, "0.3, 0.22, 0.16, 1",
           gier=round(math.degrees(math.atan2(ax_ - sx_, az_ - sz_)), 1), sichtbar_wenn="alarm<3", haltung="arbeiten")

# --- Kaplan vor der Drachenkapelle, Haushofmeister vor dem Palas, Stallknecht an der Tränke ---
for bau_, name_, anzeige_, dialog_, tracht_, boden_ in [
        (PD.PALAS, "Haushofmeister", "Haushofmeister Reinold Esch", "haushofmeister", "0.35, 0.18, 0.15, 1", PD.H_KERNBURG)]:
    (pp_, l_, br_, dr_) = bau_
    a_ = math.radians(dr_)
    for q_ in (4.0, 5.0, 6.0, 7.5):
        x_, z_ = W((pp_[0] - math.sin(a_) * (br_ / 2 + q_), pp_[1] + math.cos(a_) * (br_ / 2 + q_)))
        if not any(_drin((x_, z_), r_) for r_ in _HINDERNISSE):
            break
    vx_, vz_ = W((pp_[0], pp_[1]))
    person(name_, BL, round(x_, 2), boden_, round(z_, 2), anzeige_, dialog_, 2 if name_ == "Haushofmeister" else 0, tracht_,
           gier=round(math.degrees(math.atan2(x_ - vx_, z_ - vz_)), 1), haltung="reden")
_traenke = [a_ for a_ in BURG_AUSSTATTUNG if a_[0] == 12]
if _traenke:
    _, x_, y_, z_, g_ = _traenke[0]
    a_ = math.radians(g_)
    sx_, sz_ = x_ + math.sin(a_) * 1.6, z_ + math.cos(a_) * 1.6
    person("Stallknecht", BL, round(sx_, 2), y_, round(sz_, 2), "Stallknecht Jorin Mähne", "burggesinde", 0, GESINDE_TRACHTEN[1],
           gier=round(g_ + 180, 1), sichtbar_wenn="alarm<3", haltung="arbeiten")

# --- Leute in den Gebäuden: Koch und Magd in der Küche, Zeugwart, Ritter im Rittersaal, Mägde in den Gesindehäusern
# (Lage im Bau über _innen aus teil_drachenstein.py)
_drinnen = 0
pk_, bl_, iL_, iB_, _ = _innen(PD.BURGKUECHE, 7, PD.H_KERNBURG)
person("Burgkoch", BL, *pk_(iL_ - 2.3, 0.4), "Burgkoch Hamm Seidel", "koch_burg", 0, "0.62, 0.58, 0.5, 1",
       gier=bl_(iL_ - 2.3, 0.4, iL_, 0.4), sichtbar_wenn="alarm<3", haltung="arbeiten")
person("Kuechenmagd", BL, *pk_(iL_ * 0.35, -(iB_ - 1.35)), "Küchenmagd Grete Lauch", "magd_burg", 0, GESINDE_TRACHTEN[2],
       gier=bl_(0, 0, 0, -1), sichtbar_wenn="alarm<3", haltung="arbeiten")
pk_, bl_, iL_, iB_, _ = _innen(PD.ZEUGHAUS, 8, PD.H_KERNBURG)
person("Zeugwart", BL, *pk_(iL_ * 0.3, 0.6), "Zeugwart Bertram Esch", "zeugwart", 1, WACHE_TRACHT,
       gier=bl_(0, 0, 0, -1), sichtbar_wenn="alarm<3", haltung="arbeiten")
_drinnen += 3
pk_, bl_, iL_, iB_, gs_ = _innen(PD.PALAS, 16, PD.H_KERNBURG, art=3)
lauf_ = (16 / gs_) * 1.75
t0_, t1_ = -iL_ + 0.9 + lauf_ + 2.8 + 0.8, iL_ - 3.2
for i_, (anz_, s_, e_) in enumerate([("Ritter Gunther von Asch", 0.3, 1), ("Ritterin Adela Brand", 0.6, -1),
                                       ("Ritter Wolfram Steg", 0.75, 1)]):
    s_ = t0_ + (t1_ - t0_) * s_
    q_ = e_ * (iB_ - 1.9 - 0.95)          # auf der inneren Bank, das Gesicht zur Tafel
    person(f"Ritter{i_}", BL, *pk_(s_, q_, gs_ - 1), anz_, "ritter_burg", 2, "0.38, 0.1, 0.08, 1",
           gier=bl_(s_, q_, s_, e_ * iB_), sichtbar_wenn="alarm<3", haltung="sitzend_reden" if i_ == 1 else "sitzen")
    _drinnen += 1
# Schreiber im Erdgeschoss des Palas, an einem Pult
pk_, bl_, iL_, iB_, gs_ = _innen(PD.PALAS, 16, PD.H_KERNBURG, art=3)
for nr_, (bau_, hoehe_, boden_, name_) in enumerate([(PD.VORBURG_BAUTEN[0], 7, PD.H_VORBURG, "Magd Liese Korb"),
                                                     (PD.BURGHOF2_BAUTEN[2], 8, PD.H_BURGHOF2, "Magd Tilde Hanf"),
                                                     (PD.BURGHOF2_BAUTEN[6], 8, PD.H_BURGHOF2, "Knecht Arno Wiese"),
                                                     (PD.BURGHOF3_BAUTEN[2], 8, PD.H_KERNHOF, "Magd Berta Schaub")]):
    pk_, bl_, iL_, iB_, _ = _innen(bau_, hoehe_, boden_)
    sitzt_ = nr_ % 2 == 0
    q_ = -0.95 if sitzt_ else -min(iB_ - 0.9, 1.7)     # auf der Bank am Tisch oder an der Wand bei der Arbeit
    person(f"Hausgesinde{nr_}", BL, *pk_(iL_ * 0.15, q_), name_, "magd_burg", 0, GESINDE_TRACHTEN[nr_ % 4],
           gier=bl_(0, 0, 0, 1) if sitzt_ else bl_(0, 0, 0, -1), sichtbar_wenn="alarm<3",
           haltung="sitzen" if sitzt_ else "arbeiten")
    _drinnen += 1
# Kaplan am Altar der Kapelle (Altar am Giebel -L)
pk_, bl_, iL_, iB_, _ = _innen(PD.DRACHENKAPELLE, 11, PD.H_KERNBURG, art=1)
person("Kaplan", BL, *pk_(-iL_ + 2.6, 0.0), "Kaplan Benedikt Saar", "kaplan", 0, "0.15, 0.13, 0.14, 1",
       gier=bl_(0, 0, -1, 0), haltung="knien")
print("Burgleben: in den Gebäuden", _drinnen, "Personen, Kaplan am Altar")
print("Burgleben:", _wachen, "Wehrgangwachen,", _tw, "Torwachen,", _gs, "Gesinde, Kaplan, Haushofmeister" + (", Stallknecht" if _traenke else ""))
