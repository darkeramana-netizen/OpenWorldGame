# ---------- Details in den Höfen (27.11.2026) ----------
# Vor den Hofhäusern steht, was zu einem bewohnten Haus gehört: an einer Ecke die Regentonne, neben der Tür ein
# Kräuterkübel, an die Wand gelehntes Werkzeug, bei breiten Häusern eine Bank, über manchen Türen das Hängeschild
# eines Handwerks (Schenke, Schuster, Bäcker). In den Höfen: ein Pranger in der Vorburg, ein Bienenstand bei den
# Gemüsebeeten, Hundehütten, Pflastersteine bei den Steinmetzen und Gerüsten.
# Wird nach teil_drachenstein.py ausgeführt (HOFHAEUSER, _FORMEN, Sperrflächen), vor teil_burgleben.py: die neuen Stücke
# kommen in BURG_SPERREN, damit die Wege der Leute um sie herum führen.
random.seed(2712)
HOF_DETAILS = []
_HD_GROESSE = {67: (0.85, 0.85), 68: (1.05, 0.5), 44: (1.7, 0.6), 72: (1.1, 0.6), 69: (2.1, 0.7), 70: (1.0, 1.3),
               71: (1.0, 1.0), 73: (1.7, 1.2)}


def _hd_frei(r_, eigenes, hof_w):
    if not all(_im_poly(q_, hof_w) for q_ in r_):
        return False
    andere_ = [h_ for h_, hh_ in zip(_haeuser_w, HOFHAEUSER) if hh_ is not eigenes] if len(_haeuser_w) == len(HOFHAEUSER) \
        else _haeuser_w
    for l_ in (andere_, _feste_w, _treppen_w, _tueren_w, BURG_SPERREN, _vorplaetze_w):
        if any(_ueberlappen_plan(r_, f_) for f_ in l_):
            return False
    if any(abstand_linie(w_, *q_) < 0.8 for w_ in _alle_wege_w for q_ in r_):
        return False
    return True


def _hd_setze(art, x, y, z, gier, r_=None):
    HOF_DETAILS.append((art, round(x, 2), round(y, 2), round(z, 2), round(gier % 360.0, 1)))
    if r_ is not None:
        BURG_SPERREN.append(r_)


_hd_hoefe = [(n_, WL(h_), b_) for n_, h_, b_ in _hoefe]


def _hd_hof(q):
    for n_, w_, b_ in _hd_hoefe:
        if _drin_hof(q, w_):
            return n_, w_, b_
    return None


def _drin_hof(q, poly):
    x, z = q
    innen = False
    for (x1, z1), (x2, z2) in zip(poly, poly[1:] + poly[:1]):
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
            innen = not innen
    return innen


_zaehler_hd = {}
for haus_ in HOFHAEUSER:
    x_, y_, z_, g_, f_ = haus_
    hof_ = _hd_hof((x_, z_))
    if hof_ is None:
        continue
    _, hof_w_, _ = hof_
    b_, t_ = _FORMEN[f_]
    a_ = math.radians(g_)
    u_ = (math.sin(a_), math.cos(a_))           # zur Straße
    n_ = (math.cos(a_), -math.sin(a_))
    fd_ = (t_ + 0.7) / 2

    def vor(lat, tief):
        return (x_ + u_[0] * (fd_ + tief) + n_[0] * lat, z_ + u_[1] * (fd_ + tief) + n_[1] * lat)
    seiten_ = [-1, 1]
    random.shuffle(seiten_)
    belegt_ = []
    # Regentonne an einer Ecke
    if random.random() < 0.65:
        for s_ in seiten_:
            lat_ = s_ * (b_ / 2 - 0.35)
            if abs(lat_) < 1.7:
                continue
            q_ = vor(lat_, 0.45)
            r_ = _rechteck_w(*q_, 0.85, 0.85, g_)
            if _hd_frei(r_, haus_, hof_w_):
                _hd_setze(67, *q_[:1], y_, q_[1], random.uniform(0, 360), r_)
                belegt_.append(s_)
                break
    # neben der Tür: Bank (breite Häuser), Kräuterkübel oder Werkzeug
    for s_ in seiten_:
        wahl_ = random.random()
        art_, breite_, tief_ = (44, 1.7, 0.6) if b_ >= 6.4 and wahl_ < 0.35 else ((68, 1.05, 0.5) if wahl_ < 0.7 else (72, 1.1, 0.6))
        if random.random() < 0.25:
            continue
        lat_ = s_ * (1.3 + breite_ / 2)
        if abs(lat_) + breite_ / 2 > b_ / 2 + 0.3 or (s_ in belegt_ and abs(lat_) + breite_ / 2 > b_ / 2 - 0.85):
            continue
        q_ = vor(lat_, tief_ / 2 + 0.05)
        r_ = _rechteck_w(*q_, breite_, tief_, g_)
        if _hd_frei(r_, haus_, hof_w_):
            _hd_setze(art_, q_[0], y_, q_[1], g_ + (180.0 if art_ == 44 else 0.0), r_)
            _zaehler_hd[art_] = _zaehler_hd.get(art_, 0) + 1
    # Hängeschild über der Tür eines Handwerks (Schenke, Schuster, Bäcker)
    if random.random() < 0.28:
        q_ = vor(random.choice((-1, 1)) * 1.0, -0.05)
        _hd_setze(random.choice((74, 75, 76)), q_[0], y_ + 2.75, q_[1], g_)

# An den Hofmauern (werkplatz aus teil_drachenstein.py): Ecken mit Hausrat (Werkzeug, Regentonne, Eimer), Bienenstände,
# Steinlager; was stelle() dabei in BURG_AUSSTATTUNG einträgt, kommt hierher (deren Knoten ist schon geschrieben)
_A_GROESSE.update({67: (0.8, 0.8), 68: (1.0, 0.45), 69: (2.1, 0.65), 70: (1.0, 1.25), 71: (0.95, 0.95), 72: (1.1, 0.6),
                   73: (1.6, 1.1)})
_hd_vorher = len(BURG_AUSSTATTUNG)
_hd_gruppen = {"Vorburg": ["hausrat", "hausrat", "bienen", "stein"], "Mittelburg": ["hausrat", "hausrat", "bienen", "hausrat"],
               "Oberburg": ["hausrat", "stein", "hausrat"], "Palas": ["hausrat", "hausrat", "hausrat", "stein"]}
_hd_teile = {"hausrat": [(72, 0.0, 0.35, 0), (67, 1.45, 0.5, 0), (51, -1.05, 0.35, 0)],
             "bienen": [(69, 0.0, 0.45, 0)],
             "stein": [(73, 0.0, 0.7, 0), (50, 1.4, 0.4, 0)]}
for n_, hof_w_, boden_ in _hd_hoefe:
    for k_, g_ in enumerate(_hd_gruppen.get(n_, [])):
        werkplatz(f"Hofecke {n_} {k_}", _hd_teile[g_], hof_w_, boden_, tiefe=0.2)
for st_ in BURG_AUSSTATTUNG[_hd_vorher:]:
    HOF_DETAILS.append(tuple(st_))
del BURG_AUSSTATTUNG[_hd_vorher:]

# Im Hof frei stehend: Pranger (Vorburg), Bienenstand bei den Beeten, Hundehütten, Pflastersteine am Gerüst
def _hd_frei_stehend(art, hof_name, nahe=None, weite=(1.0, 8.0), versuche=300):
    for n_, hof_w_, boden_ in _hd_hoefe:
        if n_ != hof_name:
            continue
        xs_ = [q[0] for q in hof_w_]
        zs_ = [q[1] for q in hof_w_]
        b_, t_ = _HD_GROESSE[art]
        for _ in range(versuche):
            if nahe is not None:
                w_ = random.uniform(0, math.tau)
                rr_ = random.uniform(*weite)
                q_ = (nahe[0] + math.cos(w_) * rr_, nahe[1] + math.sin(w_) * rr_)
            else:
                q_ = (random.uniform(min(xs_), max(xs_)), random.uniform(min(zs_), max(zs_)))
            g_ = random.choice((0.0, 90.0, 180.0, 270.0)) + random.uniform(-12, 12)
            r_ = _rechteck_w(*q_, b_ + 0.4, t_ + 0.4, g_)
            if _flaeche_frei(r_, hof_w_, rand=1.8, wegabstand=1.2):
                _hd_setze(art, q_[0], boden_, q_[1], g_, r_)
                return True
    return False


_hd_frei_stehend(71, "Vorburg")
_beete = [(a[1], a[3]) for a in BURG_AUSSTATTUNG if a[0] == 43]
for hof_n_ in ("Mittelburg", "Vorburg"):
    for bx_, bz_ in _beete:
        if _hd_hof((bx_, bz_)) and _hd_hof((bx_, bz_))[0] == hof_n_ and _hd_frei_stehend(69, hof_n_, nahe=(bx_, bz_), weite=(2.0, 6.0)):
            break
for hof_n_ in ("Vorburg", "Mittelburg", "Oberburg", "Palas"):
    _hd_frei_stehend(70, hof_n_)
_steinmetz = [(a[1], a[3]) for a in BURG_AUSSTATTUNG if a[0] in (47, 55)]
for sx_, sz_ in _steinmetz:
    h_ = _hd_hof((sx_, sz_))
    if h_:
        _hd_frei_stehend(73, h_[0], nahe=(sx_, sz_), weite=(2.0, 5.0))

N("HofDetails", "Node3D", BG, "script = ExtResource(\"29_ausstattung\")\nzellgroesse = 64.0\nzell_laden_ab = 240.0\n"
  "stuecke = PackedFloat32Array(" + ", ".join(f"{v:.6g}" for st_ in HOF_DETAILS for v in st_) + ")")
from collections import Counter as _Counter
print("Hofdetails:", len(HOF_DETAILS), dict(sorted(_Counter(a[0] for a in HOF_DETAILS).items())))
