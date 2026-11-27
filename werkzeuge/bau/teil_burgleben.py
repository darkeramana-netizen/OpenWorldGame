# ---------- Leben in der Burgfeste Drachenstein ----------
# Wird aus region_drachenstein.py nach teil_stadtleben.py ausgeführt. Daten aus teil_drachenstein.py: TREPPEN (Treppen
# auf die Wehrgänge), MAUERSTUECKE, HOFHAEUSER, BURG_AUSSTATTUNG und ihre Sperrflächen, BURG_BRUNNEN.
#   - Je Mauertreppe eine Wache: die Treppe hinauf und die durchgehenden Wehrgänge entlang auf Streife (wehrgang_wachen,
#     erst nach mauern_verbinden aufgerufen).
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


# --- Wachen auf den Wehrgängen: je Treppe eine; ihre Streife läuft die durchgehenden Wehrgänge entlang ---
WACHEN_NAMEN = ["Mauerwache Gero Lind", "Mauerwache Hella Brück", "Mauerwache Utz Raben", "Mauerwache Swana Teich",
                "Mauerwache Bodo Kiel", "Mauerwache Ragna Holt", "Mauerwache Lutz Ammer", "Mauerwache Femke Dorn",
                "Mauerwache Ansgar Rieth", "Mauerwache Tilda Wehr", "Mauerwache Kuno Sand", "Mauerwache Edda Born"]


def wehrgang_wachen(weit=60.0):
    """Erst nach mauern_verbinden aufrufen (die Streifen folgen den endgültigen Mauerstücken). Jede Wache steigt
    ihre Treppe hinauf und geht dann auf dem Wehrgang bis zu weit Meter in die eine Richtung, zurück, ebenso weit in
    die andere und zurück, immer wieder; nachts mit Fackel."""
    stuecke_, tuerme_ = wehrgang_netz()
    zahl_ = 0
    laengen_ = []
    for k_ in range(0, len(TREPPEN), 7):
        fx_, fz_, fy_, tx_, tz_, ty_, _ = TREPPEN[k_:k_ + 7]
        p0_, vor_, rueck_ = wehrgang_runde(stuecke_, tuerme_, (tx_, tz_), ty_ - 0.62, weit)
        runde_ = [p0_] + vor_ + vor_[-2::-1] + [p0_] + rueck_ + rueck_[-2::-1]
        punkte_ = [(round(fx_, 2), round(fy_, 2), round(fz_, 2)), (round(tx_, 2), round(ty_, 2), round(tz_, 2))] + runde_
        laengen_.append(round(sum(math.dist(a_[::2], b_[::2]) for a_, b_ in zip([p0_] + vor_, vor_))
                              + sum(math.dist(a_[::2], b_[::2]) for a_, b_ in zip([p0_] + rueck_, rueck_))))
        person(f"Wehrgangwache{zahl_}", BL, *p0_, WACHEN_NAMEN[zahl_ % len(WACHEN_NAMEN)], "mauerwache", 1, WACHE_TRACHT,
               ablauf={"morgengrauen": (punkte_, ["runde=2"]), "nacht": (punkte_, ["runde=2", "haltung=fackel"])}, tempo=1.1)
        zahl_ += 1
    print("Wehrgangwachen:", zahl_, "Streifen (m je Richtung zusammen):", laengen_)
    return zahl_


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
    for i_ in range(min(6, len(tueren_) // 2)):
        (heim_, b1_), (arbeit_, b2_) = tueren_[2 * i_], tueren_[2 * i_ + 1]
        if not strecke_frei(b1_, b2_):
            continue
        runde_ = [heim_, b1_, b2_, arbeit_, b2_, b1_, heim_]
        # Arbeitsgang: am Brunnen Wasser schöpfen, an der anderen Tür abliefern, daheim kurz zu tun
        punkte_ = p3(runde_, boden_)
        punkte_[1] = punkte_[1] + ("arbeiten", 7, "eimer")     # am Brunnen schöpfen, dann den Eimer tragen
        punkte_[3] = punkte_[3] + ("arbeiten", 4, "-")         # an der Tür abliefern
        punkte_[0] = punkte_[0] + ("arbeiten", 5)
        person(f"Gesinde{_gs}", BL, round(heim_[0], 2), boden_, round(heim_[1], 2), GESINDE_NAMEN[_gs % len(GESINDE_NAMEN)],
               "burggesinde", 0, GESINDE_TRACHTEN[_gs % 4], sichtbar_wenn="alarm<3",
               ablauf={"morgengrauen": (punkte_, ["runde"]),
                       "stille_stunde": (p3([heim_], boden_), ["weg"])})
        _gs += 1

# --- Hofwachen: je Hof eine, die eine Runde um den Brunnen geht (Wegpunkte frei von Häusern, Ausstattung und Treppen,
# jede Strecke dazwischen frei), nachts mit Fackel ---
HOFWACHEN_NAMEN = ["Hofwache Brun Eggert", "Hofwache Lene Stauf", "Hofwache Ortwin Hag", "Hofwache Margit Frey"]
_hw = 0
for name_, hof_, boden_ in _hoefe:
    if name_ not in BURG_BRUNNEN:
        continue
    hof_w_ = WL(hof_)
    bx_, bz_ = BURG_BRUNNEN[name_]
    runde_ = None
    for r_ in (12.0, 10.0, 14.0, 8.0, 16.0, 6.5):
        for dreh_ in range(0, 60, 15):
            kreis_ = [(bx_ + math.cos(math.radians(w_ + dreh_)) * r_, bz_ + math.sin(math.radians(w_ + dreh_)) * r_)
                      for w_ in range(0, 360, 60)]
            if all(_drin(q_, hof_w_) and not any(_drin(q_, h_) for h_ in _HINDERNISSE) for q_ in kreis_) and \
                    all(strecke_frei(a_, b_) for a_, b_ in zip(kreis_, kreis_[1:] + kreis_[:1])):
                runde_ = kreis_ + kreis_[:1]
                break
        if runde_:
            break
    if not runde_:
        continue
    punkte_ = p3(runde_, boden_)
    person(f"Hofwache{_hw}", BL, *punkte_[0], HOFWACHEN_NAMEN[_hw % len(HOFWACHEN_NAMEN)], "hofwache_burg", 1, WACHE_TRACHT,
           ablauf={"morgengrauen": (punkte_, ["runde"]), "nacht": (punkte_, ["runde", "haltung=fackel"])}, tempo=1.0)
    _hw += 1
print("Burgleben: Hofwachen", _hw)

# --- Zwei Knappen üben am Übungsplatz miteinander, abseits der Puppen (lokal x = ±2,5 vor dem Knoten ObererBurg; an
# ihnen übt der Spieler, test_stufe4): sie stehen sich mit dem Schwert gegenüber ---
for i_, (name_, anzeige_) in enumerate([("KnappeBurg0", "Knappe Rupert Harz"), ("KnappeBurg1", "Knappe Ida Wendt")]):
    person(name_, BL, round(UEB[0] + 6.5, 2), PD.H_KERNBURG, round(UEB[1] + (2.6 if i_ == 0 else 4.2), 2), anzeige_,
           "knappe_burg", 0, "0.38, 0.1, 0.08, 1", gier=180.0 if i_ == 0 else 0.0, sichtbar_wenn="alarm<2", haltung="schwert")

# --- Hühner (szenen/figuren/huehner.gd): je Hof ein paar Scharen vor den Haustüren, das Revier ganz im Hof, frei von
# Häusern, Ausstattung und Treppen, nicht am Brunnen und nicht vor der Tür selbst ---
E("Script", "res://szenen/figuren/huehner.gd", "44_huehner")
N("Huehner", "Node3D", BG)
HUEHNER_BURG = []          # (x, y, z, Anzahl, Weite)
for name_, hof_, boden_ in _hoefe:
    hof_w_ = WL(hof_)
    wunsch_ = {"Vorburg": 3, "Mittelburg": 2, "Oberburg": 2, "Palas": 1}.get(name_, 0)
    orte_ = []
    for x_, _, z_, g_, f_ in HOFHAEUSER:
        if not _drin((x_, z_), hof_w_):
            continue
        a_ = math.radians(g_)
        for seit_ in (-1.0, 1.0):
            vor_ = (_FORMEN[f_][1] + 0.7) / 2 + 4.0
            orte_.append((x_ + math.sin(a_) * vor_ + math.cos(a_) * seit_ * 3.5, z_ + math.cos(a_) * vor_ - math.sin(a_) * seit_ * 3.5))
    random.shuffle(orte_)
    gesetzt_ = 0
    for c_ in orte_:
        if gesetzt_ >= wunsch_:
            break
        weite_ = 3.0
        rand_ = [(c_[0] + math.cos(w_) * weite_ * r_, c_[1] + math.sin(w_) * weite_ * r_) for w_ in [k_ * math.tau / 12 for k_ in range(12)]
                 for r_ in (0.5, 1.0)] + [c_]
        if not all(_drin(q_, hof_w_) for q_ in rand_) or any(_drin(q_, r_) for q_ in rand_ for r_ in _HINDERNISSE):
            continue
        if name_ in BURG_BRUNNEN and math.dist(c_, BURG_BRUNNEN[name_]) < weite_ + 3.0:
            continue
        if any(math.dist(c_, (h_[0], h_[2])) < 12.0 for h_ in HUEHNER_BURG):
            continue
        HUEHNER_BURG.append((round(c_[0], 2), boden_, round(c_[1], 2), random.randint(4, 7), weite_))
        gesetzt_ += 1
# Zweite Runde (M21): eine Schar picht neben jedem Fuhrwerk verstreutes Korn auf (mitten im Hof)
for wn_ in sorted(w_ for w_ in WERKPLAETZE if w_.startswith("Fuhrwerk ")):
    px_, pz_, (ux_, uz_), (nx_, nz_), boden_ = WERKPLAETZE[wn_]
    for seite_ in (-1.0, 1.0):
        c_ = (px_ + ux_ * seite_ * 4.4, pz_ + uz_ * seite_ * 4.4)
        rand_ = [(c_[0] + math.cos(w_) * 2.5 * r_, c_[1] + math.sin(w_) * 2.5 * r_) for w_ in [k_ * math.tau / 12 for k_ in range(12)]
                 for r_ in (0.5, 1.0)] + [c_]
        if any(_drin(q_, r_) for q_ in rand_ for r_ in _HINDERNISSE):
            continue
        HUEHNER_BURG.append((round(c_[0], 2), boden_, round(c_[1], 2), random.randint(3, 5), 2.5))
        break
for k_, (x_, y_, z_, n_, weite_) in enumerate(HUEHNER_BURG):
    N(f"Schar{k_}", "Node3D", BG + "/Huehner", f"""{T(x_, y_, z_)}
script = ExtResource("44_huehner")
anzahl = {n_}
weite = {weite_:.3g}""")
print("Hühner: %d Scharen, %d Tiere" % (len(HUEHNER_BURG), sum(h_[3] for h_ in HUEHNER_BURG)))

# --- Kinder spielen Fangen um die Hoflinde (BURGBAEUME aus teil_drachenstein.py), mittags und abends daheim ---
KINDER_BURG = [("Ludo", "Ludo, ein Knechtsjunge"), ("Wenke", "Wenke, eine Magdtochter"), ("Finn", "Finn, ein Stallbursche"),
               ("Mira", "Mira, die Tochter der Wäscherin")]
_kd = 0
for bx_, by_, bz_, _ in BURGBAEUME:
    hof_ = next(((n_, WL(h_)) for n_, h_, _ in _hoefe if _drin((bx_, bz_), WL(h_))), None)
    if hof_ is None:
        continue
    kreis_ = [(bx_ + math.cos(math.radians(w_)) * 3.4, bz_ + math.sin(math.radians(w_)) * 3.4) for w_ in range(0, 360, 40)]
    if any(_drin(q_, r_) for q_ in kreis_ for r_ in _HINDERNISSE if math.dist(q_, (bx_, bz_)) > 0) or \
            not all(_drin(q_, hof_[1]) for q_ in kreis_):
        continue
    tueren_ = []
    for x_, _, z_, g_, f_ in HOFHAEUSER:
        if not _drin((x_, z_), hof_[1]):
            continue
        a_ = math.radians(g_)
        vor_ = (_FORMEN[f_][1] + 0.7) / 2 + 1.6
        t_ = (x_ + math.sin(a_) * vor_, z_ + math.cos(a_) * vor_)
        if not any(_drin(t_, r_) for r_ in _HINDERNISSE):
            tueren_.append(t_)
    tueren_.sort(key=lambda t_: math.dist(t_, (bx_, bz_)))
    heim_ = next((t_ for t_ in tueren_ if strecke_frei(t_, min(kreis_, key=lambda q_: math.dist(q_, t_)))), None)
    if heim_ is None:
        continue
    for i_ in range(2 if hof_[0] == "Vorburg" else 1):
        name_, anzeige_ = KINDER_BURG[_kd % len(KINDER_BURG)]
        k_ = kreis_[i_ * 4:] + kreis_[:i_ * 4]
        k_ = k_ + [k_[0]]
        if i_ == 1:
            k_ = k_[::-1]                       # das zweite Kind läuft andersherum: sie begegnen sich
        punkte_ = p3(k_, by_)
        person(f"BurgKind{name_}", BL, round(heim_[0], 2), by_, round(heim_[1], 2), anzeige_, "kind_burg", 0,
               GESINDE_TRACHTEN[(_kd + 1) % 4], sichtbar_wenn="alarm<2", tempo=2.2, groesse=0.68,
               ablauf={"vormittag": (punkte_, ["runde"]), "mittag": (p3([heim_], by_), ["weg"]),
                       "nachmittag": (punkte_[::-1], ["runde"]), "stille_stunde": (p3([heim_], by_), ["weg"])})
        _kd += 1
print("Burgleben: Kinder an den Hoflinden", _kd)

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
# An Heu- und Ladeplätzen lädt jemand ab (steht vor dem Karren, Blick zur Mauer)
for wn_, (px_, pz_, (ux_, uz_), (nx_, nz_), boden_) in sorted(WERKPLAETZE.items()):
    if not (wn_.startswith("Heuplatz") or wn_.startswith("Ladeplatz")):
        continue
    for q_ in (3.4, 4.0, 4.6):
        x_, z_ = px_ + nx_ * q_, pz_ + nz_ * q_
        if not any(_drin((x_, z_), r_) for r_ in _HINDERNISSE):
            break
    else:
        continue
    person(f"Arbeit{_ar}", BL, round(x_, 2), boden_, round(z_, 2), ARBEIT_NAMEN[_ar % len(ARBEIT_NAMEN)], "burggesinde", 0,
           GESINDE_TRACHTEN[(_ar + 1) % 4], gier=round(math.degrees(math.atan2(-nx_, -nz_)), 1), sichtbar_wenn="alarm<3",
           haltung="arbeiten" if _ar % 2 == 0 else "knien")
    _ar += 1
print("Burgleben: mit den Heu- und Ladeplätzen", _ar)

# --- Der Schmied am Amboss ---
if "Schmiede" in WERKPLAETZE:
    px_, pz_, (ux_, uz_), (nx_, nz_), boden_ = WERKPLAETZE["Schmiede"]
    lx_, lz_ = nz_, -nx_                                         # lokal x der Schmiede (Rücken zur Mauer, offen nach n)
    ax_, az_ = px_ + lx_ * -1.4, pz_ + lz_ * -1.4                # Amboss in der Werkstatt
    sx_, sz_ = ax_ + lx_ * 0.85 + nx_ * 0.45, az_ + lz_ * 0.85 + nz_ * 0.45
    person("Burgschmied", BL, round(sx_, 2), boden_, round(sz_, 2), "Burgschmied Wendel Hart", "schmied_burg", 0, "0.3, 0.22, 0.16, 1",
           gier=round(math.degrees(math.atan2(ax_ - sx_, az_ - sz_)), 1), sichtbar_wenn="alarm<3", haltung="arbeiten")

# --- Mängelliste M21: Leute an den neuen Werkplätzen und an den Tischen unter den Hoflinden. Lage im Rahmen des
# Platzes: e entlang, i nach innen (wie in werkplatz), Blick zur Mauer (-n) oder auf einen Punkt.
_hofarbeit = 0
HOFARBEIT = [  # Platz, e, i, Blick (None: zur Mauer, sonst e, i des Ziels), Haltung, Name, Dialog, Tracht
    ("Hackplatz Vorburg", 0.0, 2.0, None, "arbeiten", "Knecht Hinnerk Scheit", "burggesinde", GESINDE_TRACHTEN[0]),
    ("Zimmerplatz Mittelburg", 0.3, 1.75, None, "arbeiten", "Zimmermann Gero Lot", "burggesinde", "0.45, 0.36, 0.25, 1"),
    ("Zimmerplatz Mittelburg", -3.4, 0.95, None, "arbeiten", "Lehrling Matz Span", "burggesinde", GESINDE_TRACHTEN[3]),
    ("Garten Oberburg", -0.9, 3.6, None, "knien", "Gärtnerin Wiebke Kraut", "magd_burg", GESINDE_TRACHTEN[2]),
    ("Steinmetz Oberburg", 0.2, 1.85, None, "arbeiten", "Steinmetz Ulf Quader", "burggesinde", "0.5, 0.48, 0.42, 1"),
    ("Markt Oberburg", -2.0, -0.9, (-2.0, 3.0), "reden", "Händlerin Grete Wolle", "magd_burg", "0.55, 0.25, 0.18, 1"),
    ("Markt Oberburg", -1.6, 1.4, (-2.0, 0.0), "", "Magd Lene Pfund", "magd_burg", GESINDE_TRACHTEN[1]),
    ("Übungsplatz Palas", -2.0, 9.0, (-2.0, 0.2), "schwert", "Knappe Arnulf Grau", "knappe_burg", WACHE_TRACHT),
    ("Übungsplatz Palas", 0.6, 9.5, (0.6, 0.2), "schwert", "Knappin Ida Falk", "knappe_burg", WACHE_TRACHT),
    ("Reitpferde Palas", -2.3, -0.6, (-1.1, 0.0), "", "Pferdeknecht Veit Hafer", "burggesinde", GESINDE_TRACHTEN[0]),
]
for wn_, e_, i_, ziel_, haltung_, anzeige_, dialog_, tracht_ in HOFARBEIT:
    if wn_ not in WERKPLAETZE:
        continue
    px_, pz_, (ux_, uz_), (nx_, nz_), boden_ = WERKPLAETZE[wn_]
    x_, z_ = px_ + ux_ * e_ + nx_ * i_, pz_ + uz_ * e_ + nz_ * i_
    if ziel_ is None:
        blick_ = math.degrees(math.atan2(-nx_, -nz_))
    else:
        zx_, zz_ = px_ + ux_ * ziel_[0] + nx_ * ziel_[1], pz_ + uz_ * ziel_[0] + nz_ * ziel_[1]
        blick_ = math.degrees(math.atan2(zx_ - x_, zz_ - z_))
    person(f"Hofarbeit{_hofarbeit}", BL, round(x_, 2), boden_, round(z_, 2), anzeige_, dialog_, 0, tracht_,
           gier=round(blick_, 1), sichtbar_wenn="alarm<3", haltung=haltung_)
    _hofarbeit += 1
# An den Tischen unter den Linden sitzen sich zwei gegenüber (einer erzählt)
RAST_NAMEN = ["Magd Frieda Lein", "Knecht Ole Brack", "Wächter Konrad Tann", "Magd Sanne Rieth", "Knecht Bodo Furch",
              "Magd Ute Kessel"]
_rast = 0
for wn_ in sorted(w_ for w_ in WERKPLAETZE if w_.startswith("Tisch ") or w_ == "Wachtisch Palas"):
    px_, pz_, (ux_, uz_), (nx_, nz_), boden_ = WERKPLAETZE[wn_]
    for seite_ in (-1, 1):
        x_, z_ = px_ + nx_ * seite_ * 0.95, pz_ + nz_ * seite_ * 0.95
        wache_ = wn_ == "Wachtisch Palas"
        person(f"Rast{_rast}", BL, round(x_, 2), boden_, round(z_, 2),
               ("Wache Gerold Kies" if seite_ < 0 else "Wache Rike Brand") if wache_ else RAST_NAMEN[_rast % len(RAST_NAMEN)],
               "hofwache_burg" if wache_ else ("burggesinde" if _rast % 3 else "magd_burg"), 1 if wache_ else 0,
               WACHE_TRACHT if wache_ else GESINDE_TRACHTEN[_rast % 4],
               gier=round(math.degrees(math.atan2(px_ - x_, pz_ - z_)), 1), sichtbar_wenn="alarm<3",
               haltung="sitzend_reden" if seite_ > 0 else "sitzen")
        _rast += 1
print("Burgleben: an den Werkplätzen", _hofarbeit, "und an den Tischen", _rast)

# --- Zweite Runde (M21): am Fuhrwerk steht der Fuhrmann beim Pferd; ein Knecht trägt die Ladung vom Wagen zur nächsten
# Haustür und kommt zurück (Weg frei von Häusern und Ausstattung) ---
FUHR_NAMEN = ["Fuhrmann Jost Riemen", "Fuhrfrau Alke Wagner", "Fuhrmann Benno Achs"]
TRAEGER_NAMEN = ["Knecht Lambert Kiep", "Magd Gisla Trage", "Knecht Henner Last"]
_fuhr, _traeger = 0, 0
for wn_ in sorted(w_ for w_ in WERKPLAETZE if w_.startswith("Fuhrwerk ")):
    px_, pz_, (ux_, uz_), (nx_, nz_), boden_ = WERKPLAETZE[wn_]
    hofname_ = wn_.split(" ", 1)[1]
    hof_w_ = next(WL(h_) for n_, h_, _ in _hoefe if n_ == hofname_)
    # Fuhrmann neben dem Kopf des Pferdes, Blick zum Pferd
    fx_, fz_ = px_ + ux_ * 1.25 + nx_ * 4.6, pz_ + uz_ * 1.25 + nz_ * 4.6
    kx_, kz_ = px_ + nx_ * 4.8, pz_ + nz_ * 4.8
    person(f"Fuhrmann{_fuhr}", BL, round(fx_, 2), boden_, round(fz_, 2), FUHR_NAMEN[_fuhr % 3], "burggesinde", 0,
           "0.4, 0.33, 0.22, 1", gier=round(math.degrees(math.atan2(kx_ - fx_, kz_ - fz_)), 1), sichtbar_wenn="alarm<3",
           haltung="reden")
    _fuhr += 1
    # Träger: hinter dem Wagen (neben den Fässern) aufladen, zur nächsten erreichbaren Haustür, dort abladen
    hinten_ = (px_ + ux_ * -1.6 + nx_ * -3.0, pz_ + uz_ * -1.6 + nz_ * -3.0)
    if any(_drin(hinten_, r_) for r_ in _HINDERNISSE):
        hinten_ = (px_ + ux_ * 1.6 + nx_ * -4.2, pz_ + uz_ * 1.6 + nz_ * -4.2)
    tueren_ = []
    for x_, _, z_, g_, f_ in HOFHAEUSER:
        if not _drin((x_, z_), hof_w_):
            continue
        a_ = math.radians(g_)
        vor_ = (_FORMEN[f_][1] + 0.7) / 2 + 1.6
        t_ = (x_ + math.sin(a_) * vor_, z_ + math.cos(a_) * vor_)
        if not any(_drin(t_, r_) for r_ in _HINDERNISSE) and strecke_frei(hinten_, t_):
            tueren_.append(t_)
    if any(_drin(hinten_, r_) for r_ in _HINDERNISSE) or not tueren_:
        continue
    tuer_ = min(tueren_, key=lambda t_: math.dist(t_, hinten_))
    punkte_ = p3([hinten_, tuer_, hinten_], boden_)
    # am Wagen eine Kiste oder einen Sack nehmen, an der Tür abladen
    punkte_[0] = punkte_[0] + ("arbeiten", 5, "kiste" if _traeger % 2 == 0 else "sack")
    punkte_[1] = punkte_[1] + ("arbeiten", 3, "-")
    person(f"Traeger{_traeger}", BL, round(hinten_[0], 2), boden_, round(hinten_[1], 2), TRAEGER_NAMEN[_traeger % 3],
           "burggesinde", 0, GESINDE_TRACHTEN[(_traeger + 1) % 4], sichtbar_wenn="alarm<3",
           ablauf={"vormittag": (punkte_, ["runde"]), "nachmittag": (punkte_, ["runde"]),
                   "stille_stunde": (p3([tuer_], boden_), ["weg"])})
    _traeger += 1
print("Burgleben: Fuhrleute", _fuhr, "Träger", _traeger)

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
print("Burgleben:", _tw, "Torwachen,", _gs, "Gesinde, Kaplan, Haushofmeister" + (", Stallknecht" if _traenke else ""))

# ---------- Mehr Leben in den Höfen (27.11.2026) ----------
# Eine Festung mit 7000 Leuten (docs/01-lore-bibel.md) ist voll: In jedem Hof stehen Leute zusammen und reden, am Brunnen
# wird gewaschen, Mägde kehren, Boten laufen eilig von Tür zu Tür, Ordensritter gehen zu zweit ihre Runde, Kinder spielen,
# Hunde und Katzen streunen. Mittags knien Ordensleute zur Andacht vor der Drachenkapelle. Abends (Stille-Stunde) gehen
# alle heim. Alle Plätze frei von Häusern, Bauten, Ausstattung und Treppen, jede Strecke dazwischen frei.
random.seed(2711)
HL_BESETZT = []
# Die Torbereiche bleiben frei: an den Toren öffnet die Wache sonst jedem, der vorbeigeht
HL_SPERREN = _HINDERNISSE + _tueren_w


def hl_strecke_frei(a, b):
    n = max(1, int(math.dist(a, b) / 0.4))
    for i in range(n + 1):
        q = (a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n)
        if any(_drin(q, r_) for r_ in HL_SPERREN):
            return False
    return True


def hof_tueren(hof_w):
    """Plätze vor den Haustüren eines Hofs (frei), 3 m vor der Tür: außerhalb ihrer Reichweite (fluegel.gd, 2,2 m), sonst
    stünden die Türen ständig offen"""
    aus_ = []
    for x_, _, z_, g_, f_ in HOFHAEUSER:
        if not _drin((x_, z_), hof_w):
            continue
        a_ = math.radians(g_)
        vor_ = (_FORMEN[f_][1] + 0.7) / 2 + 3.0
        t_ = (x_ + math.sin(a_) * vor_, z_ + math.cos(a_) * vor_)
        if not any(_drin(t_, r_) for r_ in HL_SPERREN):
            aus_.append(t_)
    return aus_


def freie_stelle(hof_w, rand=3.0, abstand=1.3, nahe=None, weite=None, versuche=400):
    xs_ = [q[0] for q in hof_w]
    zs_ = [q[1] for q in hof_w]
    for _ in range(versuche):
        if nahe is not None:
            w_ = random.uniform(0, math.tau)
            r_ = random.uniform(weite[0], weite[1])
            q = (nahe[0] + math.cos(w_) * r_, nahe[1] + math.sin(w_) * r_)
        else:
            q = (random.uniform(min(xs_), max(xs_)), random.uniform(min(zs_), max(zs_)))
        if not _drin(q, hof_w) or _abstand_rand(q, hof_w) < rand:
            continue
        if any(_drin((q[0] + dx_, q[1] + dz_), r_) for r_ in HL_SPERREN
               for dx_, dz_ in ((0, 0), (abstand, 0), (-abstand, 0), (0, abstand), (0, -abstand))):
            continue
        if any(math.dist(q, m_) < 2.4 for m_ in HL_BESETZT):
            continue
        if any(math.dist(q, b_) < 2.6 for b_ in BURG_BRUNNEN.values()):
            continue
        return q
    return None


def naechste_tuer(q, tueren):
    frei_ = [t_ for t_ in tueren if hl_strecke_frei(q, t_)]
    return min(frei_, key=lambda t_: math.dist(q, t_)) if frei_ else None


def blick_zu(a, b):
    return round(math.degrees(math.atan2(b[0] - a[0], b[1] - a[1])), 1)


VORNAMEN_F = ["Anna", "Mechthild", "Gesa", "Hille", "Ilse", "Jutta", "Kunigunde", "Liesel", "Marthe", "Nele", "Odile", "Rike",
              "Sanne", "Tilda", "Ute", "Wanda"]
VORNAMEN_M = ["Arnold", "Bernd", "Claus", "Dietmar", "Eckart", "Folker", "Gerd", "Heino", "Ingo", "Jost", "Kuno", "Lutz",
              "Merten", "Nolte", "Otto", "Rainer"]
NACHNAMEN = ["Asch", "Bader", "Dorn", "Eich", "Falk", "Grund", "Hagen", "Kalk", "Linde", "Moor", "Reif", "Sand", "Torf", "Wall"]
_hl_nr = [0]


def hl_name(rolle, weiblich):
    i_ = _hl_nr[0]
    _hl_nr[0] += 1
    vn_ = (VORNAMEN_F if weiblich else VORNAMEN_M)[(i_ * 7) % 16]
    return f"{rolle} {vn_} {NACHNAMEN[(i_ * 5) % len(NACHNAMEN)]}"


_hl = 0
HOF_TIERE = []
for name_, hof_, boden_ in _hoefe:
    hof_w_ = WL(hof_)
    tueren_ = hof_tueren(hof_w_)
    if not tueren_:
        continue
    gross_ = name_ == "Palas"
    # Plaudergruppen: zwei bis drei Leute stehen beisammen und reden
    for g_ in range(3 if gross_ else 2):
        m_ = freie_stelle(hof_w_, rand=4.0, abstand=2.2)
        if m_ is None:
            continue
        HL_BESETZT.append(m_)
        anzahl_ = 3 if g_ % 2 == 0 else 2
        for k_ in range(anzahl_):
            w_ = math.tau * k_ / anzahl_ + g_
            q_ = (m_[0] + math.cos(w_) * 0.85, m_[1] + math.sin(w_) * 0.85)
            heim_ = naechste_tuer(q_, tueren_)
            if heim_ is None or not hl_strecke_frei(q_, m_):
                continue
            weiblich_ = (k_ + g_) % 2 == 0
            ablauf_ = {"morgengrauen": (p3([heim_], boden_), ["weg"]),
                       "vormittag": (p3([q_], boden_), [f"blick={blick_zu(q_, m_)}", "haltung=reden"]),
                       "stille_stunde": (p3([heim_], boden_), ["weg"])}
            person(f"Hofleben{_hl}", BL, round(q_[0], 2), boden_, round(q_[1], 2),
                   hl_name("Magd" if weiblich_ else "Knecht", weiblich_), "magd_burg" if weiblich_ else "burggesinde", 0,
                   GESINDE_TRACHTEN[(k_ + g_) % 4], gier=blick_zu(q_, m_), sichtbar_wenn="alarm<3", ablauf=ablauf_)
            _hl += 1
    # Wäscherinnen am Brunnen: knien am Zuber, mittags hängen sie die Wäsche auf (an der Tür), abends daheim
    if name_ in BURG_BRUNNEN:
        bw_ = BURG_BRUNNEN[name_]
        for k_ in range(2):
            q_ = freie_stelle(hof_w_, rand=2.5, abstand=0.9, nahe=bw_, weite=(2.7, 3.6))
            if q_ is None:
                continue
            HL_BESETZT.append(q_)
            heim_ = naechste_tuer(q_, tueren_)
            if heim_ is None:
                continue
            person(f"Hofleben{_hl}", BL, round(q_[0], 2), boden_, round(q_[1], 2), hl_name("Wäscherin", True), "magd_burg", 0,
                   GESINDE_TRACHTEN[(k_ + 2) % 4], gier=blick_zu(q_, bw_), sichtbar_wenn="alarm<3",
                   ablauf={"morgengrauen": (p3([q_], boden_), [f"blick={blick_zu(q_, bw_)}", "haltung=knien"]),
                           "mittag": (p3([heim_, q_], boden_), ["runde"]),
                           "nachmittag": (p3([q_], boden_), [f"blick={blick_zu(q_, bw_)}", "haltung=knien"]),
                           "stille_stunde": (p3([heim_], boden_), ["weg"])})
            _hl += 1
    # Mägde kehren: eine Runde über vier Plätze, an jedem eine Weile mit dem Besen
    for k_ in range(2 if gross_ else 1):
        a_ = freie_stelle(hof_w_)
        if a_ is None:
            continue
        runde_ = [a_]
        for _ in range(12):
            if len(runde_) >= 4:
                break
            b_ = freie_stelle(hof_w_, nahe=runde_[-1], weite=(4.0, 9.0))
            if b_ is not None and hl_strecke_frei(runde_[-1], b_):
                runde_.append(b_)
        if len(runde_) < 3 or not hl_strecke_frei(runde_[-1], runde_[0]):
            continue
        heim_ = naechste_tuer(a_, tueren_)
        if heim_ is None:
            continue
        punkte_ = [p_ + ("arbeiten", 8) for p_ in p3(runde_, boden_)]
        person(f"Hofleben{_hl}", BL, round(a_[0], 2), boden_, round(a_[1], 2), hl_name("Magd", True), "magd_burg", 0,
               GESINDE_TRACHTEN[k_ % 4], sichtbar_wenn="alarm<3",
               ablauf={"morgengrauen": (punkte_ + [punkte_[0]], ["runde"]), "stille_stunde": (p3([heim_], boden_), ["weg"])})
        _hl += 1
    # Boten: eilig von Tür zu Tür (weit auseinander), dazwischen kurz an der Tür
    for k_ in range(2 if gross_ else 1):
        paare_ = [(a_, b_) for a_ in tueren_ for b_ in tueren_ if math.dist(a_, b_) > 18.0 and hl_strecke_frei(a_, b_)]
        if not paare_:
            continue
        a_, b_ = random.choice(paare_)
        punkte_ = p3([a_, b_], boden_)
        punkte_ = [punkte_[0] + ("reden", 4), punkte_[1] + ("reden", 4)]
        person(f"Hofleben{_hl}", BL, round(a_[0], 2), boden_, round(a_[1], 2), hl_name("Bote", k_ % 2 == 1), "burggesinde", 0,
               "0.45, 0.2, 0.16, 1", sichtbar_wenn="alarm<3", tempo=2.3,
               ablauf={"morgengrauen": (punkte_ + [punkte_[0]], ["runde"]), "stille_stunde": (p3([a_], boden_), ["weg"])})
        _hl += 1
    # Zwei Ordensritter gehen gemeinsam eine Runde (langsam; im Vorbeigehen reden sie)
    runde_ = []
    a_ = freie_stelle(hof_w_, rand=4.0, abstand=1.8)
    if a_ is not None:
        runde_ = [a_]
        for _ in range(16):
            if len(runde_) >= 4:
                break
            b_ = freie_stelle(hof_w_, rand=4.0, abstand=1.8, nahe=runde_[-1], weite=(7.0, 14.0))
            if b_ is not None and hl_strecke_frei(runde_[-1], b_):
                runde_.append(b_)
    if len(runde_) >= 3 and hl_strecke_frei(runde_[-1], runde_[0]):
        for k_ in range(2):
            versatz_ = runde_[k_:] + runde_[:k_]
            heim_ = naechste_tuer(versatz_[0], tueren_) or versatz_[0]
            person(f"Hofleben{_hl}", BL, round(versatz_[0][0], 2), boden_, round(versatz_[0][1], 2),
                   hl_name("Ordensritter" if k_ == 0 else "Ordensritterin", k_ == 1), "ritter_burg", 2, "0.38, 0.1, 0.08, 1",
                   sichtbar_wenn="alarm<3", tempo=0.9,
                   ablauf={"vormittag": (p3(versatz_ + [versatz_[0]], boden_), ["runde"]),
                           "stille_stunde": (p3([heim_], boden_), ["weg"])})
            _hl += 1
    # Kinder spielen Fangen (schnell, eine kleine Runde), mittags und abends daheim
    if name_ in ("Vorburg", "Mittelburg", "Palas"):
        m_ = freie_stelle(hof_w_, rand=4.0, abstand=2.5)
        if m_ is not None:
            runde_ = [(m_[0] + math.cos(w_) * 2.6, m_[1] + math.sin(w_) * 2.6) for w_ in (0.0, 1.6, 3.2, 4.7)]
            if all(hl_strecke_frei(a_, b_) for a_, b_ in zip(runde_, runde_[1:] + runde_[:1])):
                heim_ = naechste_tuer(m_, tueren_)
                HL_BESETZT.append(m_)
                for k_ in range(2):
                    versatz_ = runde_[k_ * 2:] + runde_[:k_ * 2]
                    if heim_ is None:
                        break
                    person(f"Hofleben{_hl}", BL, round(versatz_[0][0], 2), boden_, round(versatz_[0][1], 2),
                           hl_name("Kind", k_ == 0).replace("Kind ", "") , "kind_burg", 0, GESINDE_TRACHTEN[k_ + 1],
                           sichtbar_wenn="alarm<2", tempo=2.6, groesse=0.72,
                           ablauf={"morgengrauen": (p3([heim_], boden_), ["weg"]),
                                   "vormittag": (p3(versatz_ + [versatz_[0]], boden_), ["runde"]),
                                   "mittag": (p3([heim_], boden_), ["weg"]),
                                   "nachmittag": (p3(versatz_ + [versatz_[0]], boden_), ["runde"]),
                                   "stille_stunde": (p3([heim_], boden_), ["weg"])})
                    _hl += 1
    # Hund und Katze streunen im Hof
    for art_ in (22, 23):
        q_ = freie_stelle(hof_w_, rand=3.0, abstand=1.2)
        if q_ is not None:
            HOF_TIERE.extend([art_, round(q_[0], 2), boden_, round(q_[1], 2), random.uniform(0, 360)])

# Mittagsandacht: Ordensleute knien vor dem Portal der Drachenkapelle, sonst gehen sie im Palashof ihre Wege
_kap_c = W(PD.DRACHENKAPELLE[0])
_kap_g = math.radians(-PD.DRACHENKAPELLE[3])
_kap_u = (math.sin(_kap_g), math.cos(_kap_g))
_kap_n = (math.cos(_kap_g), -math.sin(_kap_g))
_portal = (_kap_c[0] + _kap_u[0] * (PD.DRACHENKAPELLE[1] * M / 2 + 3.5), _kap_c[1] + _kap_u[1] * (PD.DRACHENKAPELLE[1] * M / 2 + 3.5))
_palas_w = WL(PD.PALAS_HOF)
_palas_tueren = hof_tueren(_palas_w)
_andacht = []
for k_ in range(5):
    reihe_, platz_ = divmod(k_, 3)
    reihe_ = -reihe_
    q_ = (_portal[0] + _kap_u[0] * reihe_ * 1.4 + _kap_n[0] * (platz_ - 1) * 1.3,
          _portal[1] + _kap_u[1] * reihe_ * 1.4 + _kap_n[1] * (platz_ - 1) * 1.3)
    if any(_drin(q_, r_) for r_ in _HINDERNISSE):
        continue
    sonst_ = None
    for abst_ in (3.0, 4.5, 2.2):
        v_ = (q_[0] + _kap_u[0] * abst_ + _kap_n[0] * (platz_ - 1) * 0.8, q_[1] + _kap_u[1] * abst_ + _kap_n[1] * (platz_ - 1) * 0.8)
        if not any(_drin(v_, r_) for r_ in _HINDERNISSE) and strecke_frei(v_, q_) and all(math.dist(v_, a_) > 1.2 for a_ in _andacht):
            sonst_ = v_
            break
    if sonst_ is None:
        continue
    _andacht.append(sonst_)
    blick_ = blick_zu(_portal, _kap_c)
    heim_ = naechste_tuer(sonst_, _palas_tueren) or sonst_
    person(f"Andacht{k_}", BL, round(sonst_[0], 2), PD.H_KERNBURG, round(sonst_[1], 2),
           hl_name("Ordensbruder" if k_ % 2 else "Ordensschwester", k_ % 2 == 0), "ritter_burg", 1, "0.14, 0.14, 0.16, 1",
           sichtbar_wenn="alarm<2",
           ablauf={"morgengrauen": (p3([sonst_], PD.H_KERNBURG), ["haltung=reden"]),
                   "mittag": (p3([q_], PD.H_KERNBURG), [f"blick={blick_}", "haltung=knien"]),
                   "nachmittag": (p3([sonst_], PD.H_KERNBURG), ["haltung=reden"]),
                   "stille_stunde": (p3([heim_], PD.H_KERNBURG), ["weg"])})

N("HofTiere", "Node3D", "Drachenstein/Burgen", "script = ExtResource(\"29_ausstattung\")\nstuecke = PackedFloat32Array("
  + ", ".join(f"{v:.6g}" for v in HOF_TIERE) + ")")
print("Hofleben:", _hl, "Leute,", len(HOF_TIERE) // 5, "Tiere")
