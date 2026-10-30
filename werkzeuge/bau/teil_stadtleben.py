# ---------- Stadtleben: Bewohner von Drachenstein mit Tagesablauf ----------
# Die Leute wohnen in den Stadthäusern (HAEUSER aus teil_drachenstein.py), gehen morgens zur Arbeit oder
# auf den Markt und abends wieder heim. Die Streifen des Ordens gehen Runden, nachts die Nachtstreife.
# Alle Wege laufen über das Wegenetz (die Straßen WEGE, dazu Markt und Kais). Ein Prüfer am Ende meldet,
# wenn ein Weg durch ein Haus oder einen Stand führt.

SL = "Personen/Stadtleben"
N("Stadtleben", "Node3D", "Personen")

KAI_Y = PD.H_HAFEN
P = lambda *pp: [W(p) for p in pp]
# Wegenetz im Plan (Bildpunkte): die Straßen, dazu Wege über den Markt um Stände, Brunnen und Schmiede herum,
# und der Westkai am Hafenbecken
_RING = [(504, 518), (506.3, 512.3), (512, 510), (517.7, 512.3), (520, 518), (517.7, 523.7), (512, 526), (506.3, 523.7), (504, 518)]   # um den Brunnen
NETZ = STRASSEN + [P(*l) for l in [
    [(458, 482), (458, 500), (458, 518), (458, 555)],                                    # Westseite des Markts
    [(563, 482), (563, 500), (563, 518), (563, 555)],                                    # Ostseite
    [(458, 482), (512, 483), (563, 482)], [(458, 555), (512, 552), (563, 555)],          # Nord- und Südseite
    [(458, 518), (504, 518)], [(520, 518), (563, 518)], _RING,
    # Anschlüsse der Gassen an den Platz
    [(455, 480), (458, 482)], [(566, 478), (563, 482)], [(566, 500), (563, 500)],
    [(456, 558), (458, 555)], [(512, 556), (512, 552)], [(568, 556), (563, 555)],
    # Hafen: Kaiweg von der Hafenpforte zum Hafentor, durch das Tor auf den Weg unter den Felsen
    PD.KAIWEG, [(750, 424), (750, 422)],
    PD.WEG_UNTEN, PD.RAMPE_BURGHOF2, PD.WEG_NORDWEST,
    # Durch den II. Burghof zum Tor des III. Burghofs und zum Tor des Hofs aus Akt I
    [(540, 335), (545, 295), (600, 250), (636, 228), (655, 228), (673, 228), (690, 228)],
]]

# Hindernisse: (Mitte x, Mitte z, Breite, Tiefe, Gier) als Rechtecke, Kreise als (x, z, Radius)
def _bau(pp, laenge, breite, gier=0):
    x, z = W(pp)
    return (x, z, breite, laenge, gier)
RECHTECKE = [(h[0], h[2], HAUSFORMEN[h[5]][0], HAUSFORMEN[h[5]][1] + 2 * VORKRAGUNG, h[3]) for h in HAEUSER] + [
    (x, z, 3.4, 2.4, 0) for x, z in STAENDE] + [
    (x, z, 0.9 if art != 2 else 1.3, 0.9, gier) for art, x, y, z, gier in AUSSTATTUNG if art in (0, 1, 2)] + [
    (x, z, 1.8, 3.2, gier) for art, x, y, z, gier in AUSSTATTUNG if art == 4] + [
    (x, z, 3.4, 2.4, 0) for x, z in STAENDE_MEHR] + [
    _bau(PD.ST_MARIEN[0], PD.ST_MARIEN[1] * PD.MASSSTAB, PD.ST_MARIEN[2] * PD.MASSSTAB, 0), _bau(PD.ST_MARIEN_TURM, 8, 8)] + [
    _bau(PD.SPEICHER[0], PD.SPEICHER[1] * PD.MASSSTAB, PD.SPEICHER[2] * PD.MASSSTAB, 0)]
KREISE = [(MARKT_MITTE[0], MARKT_MITTE[1], 2.4)]


def hoehe(x, z):
    return round(H(x, z), 2)


def _projektion(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / (dx * dx + dz * dz)))
    return (a[0] + dx * t, a[1] + dz * t)


def _netz_graph():
    g = {}
    for linie in NETZ:
        for a, b in zip(linie, linie[1:]):
            d = math.dist(a, b)
            g.setdefault(a, {})[b] = d
            g.setdefault(b, {})[a] = d
    return g


def weg(von, nach):
    """Kürzester Weg über das Netz von einem Punkt zum anderen (Punkte als (x, z))."""
    if math.dist(von, nach) < 0.3:
        return [von]
    g = {k: dict(v) for k, v in _netz_graph().items()}
    segmente = [(a, b) for linie in NETZ for a, b in zip(linie, linie[1:])]
    anschluss = []
    for p in (von, nach):
        a, b = min(segmente, key=lambda s: math.dist(p, _projektion(p, *s)))
        q = _projektion(p, a, b)
        for e in (a, b):
            g.setdefault(q, {})[e] = math.dist(q, e)
            g[e][q] = math.dist(q, e)
        anschluss.append((q, a, b))
    (q1, a1, b1), (q2, a2, b2) = anschluss
    if {a1, b1} == {a2, b2}:
        g[q1][q2] = g[q2][q1] = math.dist(q1, q2)
    # Dijkstra
    dist, vorher, offen = {q1: 0}, {}, {q1}
    while offen:
        u = min(offen, key=dist.get)
        offen.remove(u)
        if u == q2:
            break
        for v, w in g[u].items():
            if dist[u] + w < dist.get(v, 1e9):
                dist[v] = dist[u] + w
                vorher[v] = u
                offen.add(v)
    pfad = [q2]
    while pfad[-1] != q1:
        pfad.append(vorher[pfad[-1]])
    punkte = [von] + pfad[::-1] + [nach]
    ergebnis = []
    for p in punkte:
        if not ergebnis or math.dist(ergebnis[-1], p) > 0.3:
            ergebnis.append(p)
    return ergebnis


def in_hindernis(x, z, rand=0.45):
    for cx, cz, sx, sz, gier in RECHTECKE:
        a = math.radians(gier)
        dx, dz = x - cx, z - cz
        lx = dx * math.cos(a) - dz * math.sin(a)
        lz = dx * math.sin(a) + dz * math.cos(a)
        if abs(lx) < sx / 2 + rand and abs(lz) < sz / 2 + rand:
            return (cx, cz)
    for cx, cz, r in KREISE:
        if math.dist((x, z), (cx, cz)) < r + rand:
            return (cx, cz)
    return None


FEHLWEGE = []

def pruefe_weg(name, punkte):
    for a, b in zip(punkte, punkte[1:]):
        n = max(1, int(math.dist(a, b) / 0.5))
        for i in range(n + 1):
            x, z = a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n
            h = in_hindernis(x, z)
            if h:
                FEHLWEGE.append(f"{name}: ({x:.1f}, {z:.1f}) in Hindernis bei {h}")
                return


def tuer(haus):
    x, y, z, gier, _, form = haus
    a = math.radians(gier)
    vor = HAUSFORMEN[form][1] / 2 + 1.0
    return (round(x + math.sin(a) * vor, 2), round(z + math.cos(a) * vor, 2))


def p3(punkte):
    return [(round(x, 2), hoehe(x, z), round(z, 2)) for x, z in punkte]


REIHENFOLGE = ["morgengrauen", "vormittag", "mittag", "nachmittag", "stille_stunde", "nacht"]

def stadtmensch(name, anzeige, dialog, kordel, tracht, zuhause, plan, sichtbar_wenn="", tempo=None, groesse=None):
    """plan: {abschnitt: (Ziel, zusätze)}. Ziel ist ein Punkt (x, z), "heim" oder eine Runde aus runde().
    Die Wege sucht weg() über das Netz, jeweils vom Ziel des vorigen Abschnitts aus (über Mitternacht hinweg)."""
    ablauf = {}
    letzter = [a for a in REIHENFOLGE if a in plan][-1]
    ende = lambda ziel: zuhause if ziel == "heim" else (ziel[0] if isinstance(ziel, list) else ziel)
    pos = ende(plan[letzter][0])
    for abschnitt in REIHENFOLGE:
        if abschnitt not in plan:
            continue
        ziel, extra = plan[abschnitt]
        if isinstance(ziel, list):
            hin = weg(pos, ziel[0])
            punkte = hin + ziel[1:]
            extra = [f"runde={len(hin) - 1}"] + list(extra)
        else:
            punkte = weg(pos, ende(ziel))
        pruefe_weg(name, punkte)
        ablauf[abschnitt] = (p3(punkte), extra)
        pos = ende(ziel)
    x, z = zuhause
    person(name, SL, x, hoehe(x, z), z, anzeige, dialog, kordel, tracht, sichtbar_wenn=sichtbar_wenn,
           ablauf=ablauf, tempo=tempo, groesse=groesse)


def runde(*ziele):
    """Geschlossene Runde über das Netz durch die Ziele und zurück zum ersten."""
    punkte = [ziele[0]]
    for a, b in zip(ziele, ziele[1:] + (ziele[0],)):
        punkte += weg(a, b)[1:]
    return punkte


# Wohnungen: Häuser, deren Tür einen freien Weg zur nächsten Straße hat. In einem Haus wohnen bis zu drei.
def _frei_zur_strasse(t):
    vorher = len(FEHLWEGE)
    pruefe_weg("Tür", weg(t, MARKT_MITTE)[:2])
    frei = len(FEHLWEGE) == vorher
    del FEHLWEGE[vorher:]
    return frei and not in_hindernis(*t, rand=0.3)

random.seed(1754)
WOHNUNGEN = [tuer(h) for h in HAEUSER]
WOHNUNGEN = [t for t in WOHNUNGEN if _frei_zur_strasse(t)]
random.shuffle(WOHNUNGEN)
_belegt = {}
def wohnung():
    for t in sorted(WOHNUNGEN, key=lambda t: _belegt.get(t, 0)):
        if _belegt.get(t, 0) < 3:
            _belegt[t] = _belegt.get(t, 0) + 1
            return t
    raise SystemExit(f"Keine freie Wohnung mehr ({len(WOHNUNGEN)} Häuser)")

def _blick(von, nach):
    return round(math.degrees(math.atan2(nach[0] - von[0], nach[1] - von[1])))

def _richtung(p, ziel, abstand):
    d = math.dist(p, ziel)
    return (round(p[0] + (ziel[0] - p[0]) * abstand / d, 2), round(p[1] + (ziel[1] - p[1]) * abstand / d, 2))

WACHWECHSEL = W((655, 250))   # im III. Burghof vor dem Tor des Hofs, nicht im Durchgang
BRUNNEN = MARKT_MITTE
def _freier_platz(stand, abstand):
    """Ein Platz neben dem Stand, zu dem möglichst viele Wege vom Brunnen und von den Markträndern frei sind."""
    bester, beste_fehler = None, 99
    for dx, dz in ((0, 1), (0, -1), (1, 0), (-1, 0), (0.7, 0.7), (-0.7, 0.7), (0.7, -0.7), (-0.7, -0.7)):
        p = (round(stand[0] + dx * abstand, 2), round(stand[1] + dz * abstand, 2))
        if in_hindernis(*p, rand=0.3):
            continue
        vorher = len(FEHLWEGE)
        for von in P((504, 518), (458, 500), (563, 500)):
            pruefe_weg("Platz", weg(von, p))
        fehler = len(FEHLWEGE) - vorher
        del FEHLWEGE[vorher:]
        if fehler < beste_fehler:
            bester, beste_fehler = p, fehler
    if bester is None:
        raise SystemExit(f"Kein freier Platz am Stand {stand}")
    return bester

MARKTPLAETZE = [_freier_platz(STAENDE[k], 3.2) for k in (4, 5, 0, 1, 2, 3)] + P((470, 518), (552, 518))   # die ersten nah am Brunnen
AM_BRUNNEN = [(round(MARKT_MITTE[0] + dx, 2), round(MARKT_MITTE[1] + dz, 2)) for dx, dz in ((-3.4, 0), (3.4, 0), (0, 3.4), (0, -3.4))]
VOR_DER_KIRCHE = P((366, 490), (367, 484), (365, 478), (366, 472))   # auf dem Weg zum Portal an der Westseite
FARBEN = ["0.42, 0.33, 0.24, 1", "0.3, 0.35, 0.42, 1", "0.45, 0.4, 0.3, 1", "0.35, 0.28, 0.32, 1",
          "0.28, 0.36, 0.28, 1", "0.5, 0.42, 0.34, 1", "0.38, 0.3, 0.2, 1", "0.32, 0.32, 0.36, 1"]
ORDEN = "0.12, 0.12, 0.14, 1"

# --- Händler an den Ständen (Stand 1 gehört Grete Lohm). Bei Alarm bleiben die Märkte leer. ---
for i, (name, anzeige, k) in enumerate([("Fischhaendlerin", "Fischhändlerin Marit Hoff", 1),
                                        ("Toepfer", "Töpfer Benno Kalk", 2), ("Tuchhaendler", "Tuchhändler Ansgar Weel", 3)]):
    stand = _freier_platz(STAENDE[k], 2.2)
    blick = _blick(stand, STAENDE[k])
    stadtmensch(name, anzeige, "stadt_haendler", 0, FARBEN[i + 2], wohnung(), {
        "morgengrauen": (stand, [f"blick={blick}"]),
        "stille_stunde": ("heim", ["weg"]),
    }, sichtbar_wenn="alarm<2")

# --- Bürgerinnen und Bürger: vormittags Markt, mittags Brunnen, nachmittags Kirche oder daheim ---
BUERGER = [("Hedda", "Hedda Korn"), ("Wilm", "Wilm Asch"), ("Fenja", "Fenja Torb"), ("Gerd", "Gerd Ulm"),
           ("Liese", "Liese Braun"), ("Konrad", "Konrad Vehl"), ("Alke", "Alke Damm"), ("Ruben", "Ruben Stieg")]
for i, (name, anzeige) in enumerate(BUERGER):
    plan = {
        "morgengrauen": ("heim", ["weg"]),
        "vormittag": (MARKTPLAETZE[i], []),
        "mittag": (AM_BRUNNEN[i % 4] if i % 2 == 0 else MARKTPLAETZE[(i + 3) % 8], []),
        "nachmittag": (VOR_DER_KIRCHE[i % 4], []) if i % 3 == 0 else ("heim", ["weg"]),
        "stille_stunde": ("heim", ["weg"]),
    }
    stadtmensch(f"Buerger{name}", anzeige, "stadt_buerger", 0, FARBEN[i], wohnung(), plan, sichtbar_wenn="alarm<2")

# --- Handwerker arbeiten vor ihrer Werkstatt ---
for i, (name, anzeige) in enumerate([("Schmied", "Schmied Harm Eckel"), ("Schusterin", "Schusterin Nele Pfriem"),
                                     ("Boettcher", "Böttcher Ewald Daube"), ("Baecker", "Bäcker Lorenz Krume")]):
    tuer_punkt = wohnung()
    stadtmensch(name, anzeige, "stadt_handwerker", 0, FARBEN[(i + 5) % 8], tuer_punkt, {
        "morgengrauen": (tuer_punkt, []),
        "stille_stunde": ("heim", ["weg"]),
    }, sichtbar_wenn="alarm<3")

# --- Kinder spielen um den Brunnen ---
KINDERKREIS = [(round(MARKT_MITTE[0] + 4.4 * math.cos(math.radians(w)), 2), round(MARKT_MITTE[1] + 4.4 * math.sin(math.radians(w)), 2))
               for w in range(0, 360, 45)]
for i, (name, anzeige) in enumerate([("Pim", "Pim, ein Junge aus dem Marktviertel"),
                                     ("Ylva", "Ylva, ein Mädchen aus dem Marktviertel"),
                                     ("Mats", "Mats, ein Junge aus dem Hafenviertel")]):
    kreis = KINDERKREIS[i * 3:] + KINDERKREIS[:i * 3]
    kreis = kreis + [kreis[0]]
    stadtmensch(f"Kind{name}", anzeige, "stadt_kind", 0, FARBEN[(i * 3) % 8], wohnung(), {
        "vormittag": (kreis, []),
        "mittag": ("heim", ["weg"]),
        "nachmittag": (kreis[::-1], []),
        "stille_stunde": ("heim", ["weg"]),
    }, sichtbar_wenn="alarm<2", tempo=2.2, groesse=0.68)

# --- Streifen des Ordens: tags zwei, nachts zwei, aus der Burg und zurück ---
STADT_NORD = runde(WACHWECHSEL, *P((300, 447), (250, 555), (400, 590)))          # Westviertel um St. Marien
MARKT_HAFEN = runde(WACHWECHSEL, *P((563, 500), (505, 610), (606, 500), (680, 428)))
for name, anzeige, kordel, strecke, schicht in [
        ("StreifeHahn", "Wächter Bertolt Hahn", 1, STADT_NORD, "tag"),
        ("StreifeKiel", "Wächterin Sanne Kiel", 1, MARKT_HAFEN, "tag"),
        ("StreifeMarten", "Wächter Ivo Marten", 1, STADT_NORD, "nacht"),
        ("StreifeStrom", "Wächterin Dagny Strom", 1, MARKT_HAFEN, "nacht")]:
    if schicht == "tag":
        plan = {"morgengrauen": (strecke, []), "stille_stunde": ("heim", ["weg"])}
    else:
        plan = {"morgengrauen": ("heim", ["weg"]), "nacht": (strecke, [])}
    stadtmensch(name, anzeige, "streife", kordel, ORDEN, WACHWECHSEL, plan)

# --- Hafen: Fischer und Träger am Westkai, ein Kaufmann aus Velmund unter Aufsicht am Docklager ---
for i, (name, anzeige) in enumerate([("FischerKlaas", "Fischer Klaas Wend"), ("FischerinTora", "Fischerin Tora Lunk"),
                                     ("FischerHinnerk", "Fischer Hinnerk Saal")]):
    stadtmensch(name, anzeige, "hafen", 0, FARBEN[(i + 1) % 8], wohnung(), {
        "morgengrauen": (W((650 + 35 * i, 442)), ["blick=90"]),
        "stille_stunde": ("heim", ["weg"]),
    }, sichtbar_wenn="alarm<3")
for i, (name, anzeige) in enumerate([("TraegerOle", "Hafenträger Jonte Pahl"), ("TraegerinMieke", "Hafenträgerin Mieke Strand")]):
    tragen = P((640 + 10 * i, 434), (720 + 8 * i, 426), (640 + 10 * i, 434))
    stadtmensch(name, anzeige, "hafen", 0, FARBEN[(i + 4) % 8], wohnung(), {
        "morgengrauen": (tragen, []),
        "stille_stunde": ("heim", ["weg"]),
    }, sichtbar_wenn="alarm<3")
KAUFMANN = W((722, 440))
person("KaufmannVelmund", SL, KAUFMANN[0], hoehe(*KAUFMANN), KAUFMANN[1], "Kaufmann Teodor Vass aus Velmund",
       "kaufmann_velmund", 0, "0.5, 0.2, 0.18, 1", gier=-90, sichtbar_wenn="alarm<2")
AUFSICHT = W((730, 440))
person("Hafenaufsicht", SL, AUFSICHT[0], hoehe(*AUFSICHT), AUFSICHT[1], "Hafenwächter Gunnar Fleet", "hafenaufsicht", 1,
       ORDEN, gier=_blick(AUFSICHT, KAUFMANN))

# --- Kirche, Rathaus, ein Flüchtling ---
KUESTER = W((366, 496))
stadtmensch("Kuester", "Küster Anselm Rohr", "kuester", 0, "0.2, 0.2, 0.22, 1", wohnung(), {
    "morgengrauen": (KUESTER, [f"blick={_blick(KUESTER, W(PD.ST_MARIEN[0]))}"]),
    "nacht": ("heim", ["weg"]),
})
RATSDIENER = W((560, 540))
person("Ratsdiener", SL, RATSDIENER[0], hoehe(*RATSDIENER), RATSDIENER[1], "Ratsdiener Oswin Pfahl", "ratsdiener", 0,
       "0.3, 0.2, 0.35, 1", gier=_blick(RATSDIENER, MARKT_MITTE))
FLUECHTLING = W((462, 552))
person("Fluechtling", SL, FLUECHTLING[0], hoehe(*FLUECHTLING), FLUECHTLING[1], "Jana Brook, Flüchtling aus dem Süden",
       "fluechtling", 0, "0.4, 0.36, 0.3, 1", gier=_blick(FLUECHTLING, MARKT_MITTE))

# Prüfen, ob das Wegenetz selbst durch Bauten führt
for linie in NETZ:
    pruefe_weg("Netz", linie)

anzahl_stadtleute = sum(1 for k in knoten if f'parent="{SL}"' in k)
print("Stadtleute:", anzahl_stadtleute, "in", len(_belegt), "Häusern")
for f in FEHLWEGE:
    print("WARNUNG Weg:", f)
