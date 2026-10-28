# ---------- Stadtleben: Bewohner von Drachenstein mit Tagesablauf ----------
# Die Leute wohnen in den Stadthäusern (HAEUSER aus teil_drachenstein.py), gehen morgens zur Arbeit oder
# auf den Markt und abends wieder heim. Die Streifen des Ordens gehen Runden, nachts die Nachtstreife.
# Alle Wege laufen über das Wegenetz (die Straßen WEGE, dazu Markt und Kais). Ein Prüfer am Ende meldet,
# wenn ein Weg durch ein Haus oder einen Stand führt.

SL = "Personen/Stadtleben"
N("Stadtleben", "Node3D", "Personen")

KAI_Y = -17.8
NORDKAI_Z = -20.4
SUEDKAI_Z = 19.5
NETZ = STRASSEN + [
    [(0, 56), (0, 80)],                                            # über den Vorplatz zum Weg nach Gravemarch
    [(98, 0), (99, -12), (100, NORDKAI_Z), (146, NORDKAI_Z)],     # Nordkai bis vor das Zollhaus
    [(98, 0), (99, 12), (100, SUEDKAI_Z), (156, SUEDKAI_Z)],      # Südkai mit den Pollern
    [(58, 22), (68, 17), (68, 7.5)],                               # zwischen den Ständen auf den Markt
    [(68, 7.5), (73.5, 2), (68, -3.5), (62.5, 2), (68, 7.5)],      # Ring um den Brunnen
    [(73.5, 2), (75, 4)],
]

# Hindernisse: (Mitte x, Mitte z, Breite, Tiefe, Gier) als Rechtecke, Kreise als (x, z, Radius)
RECHTECKE = [(h[0], h[2], HAUSFORMEN[h[5]][0], HAUSFORMEN[h[5]][1] + 2 * VORKRAGUNG, h[3]) for h in HAEUSER] + [
    (60, -8, 3, 2, 0), (72, -9, 3, 2, 0), (62, 13, 3, 2, 0), (76, 12, 3, 2, 0),
    (80, 38, 20, 10, -20), (70.6, 41.6, 6, 6, 0), (100, -42, 16, 10, 0),
    (114, -24.5, 16, 6.5, 0), (154, -24.5, 10, 6, 0)]
KREISE = [(68, 2, 2.4)]


def hoehe(x, z):
    return KAI_Y if x >= 99 and (z <= NORDKAI_Z + 0.5 or z >= SUEDKAI_Z - 0.5) else round(H(x, z), 2)


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
    pruefe_weg("Tür", weg(t, (0, 40))[:2])
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

TOR_BURG = (0, 40)
WACHWECHSEL = (-6, 48)   # neben dem Burgtor auf dem Vorplatz, nicht im Durchgang
BRUNNEN = (68, 2)
MARKTPLAETZE = [(64, -1), (71.5, 6.5), (65, 9), (73, -2.5), (69, -5), (63, 4), (74, 7.5), (70, 9.5)]
AM_BRUNNEN = [(64.6, 2), (71.4, 2), (68, 5.4), (68, -1.4)]
VOR_DER_KIRCHE = [(60, 33), (62, 30), (58.5, 30.5), (61, 35.5)]
FARBEN = ["0.42, 0.33, 0.24, 1", "0.3, 0.35, 0.42, 1", "0.45, 0.4, 0.3, 1", "0.35, 0.28, 0.32, 1",
          "0.28, 0.36, 0.28, 1", "0.5, 0.42, 0.34, 1", "0.38, 0.3, 0.2, 1", "0.32, 0.32, 0.36, 1"]
ORDEN = "0.12, 0.12, 0.14, 1"

# --- Händler an den Ständen (Stand 1 gehört Grete Lohm). Bei Alarm bleiben die Märkte leer. ---
for i, (name, anzeige, stand, blick) in enumerate([
        ("Fischhaendlerin", "Fischhändlerin Marit Hoff", (72, -6.4), 180),
        ("Toepfer", "Töpfer Benno Kalk", (62, 15.6), 0),
        ("Tuchhaendler", "Tuchhändler Ansgar Weel", (76, 15.4), 0)]):
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
KINDERKREIS = [(round(68 + 4.4 * math.cos(math.radians(w)), 2), round(2 + 4.4 * math.sin(math.radians(w)), 2))
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
STADT_NORD = runde(WACHWECHSEL, (-50, 18), (0, 56), (22, 90))
MARKT_HAFEN = runde(WACHWECHSEL, (58, 22), (98, 0), (140, SUEDKAI_Z), (98, 0), (20, -40))
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

# --- Hafen: Fischer am Südkai, Träger am Nordkai, ein Kaufmann aus Velmund unter Aufsicht ---
for i, (name, anzeige) in enumerate([("FischerKlaas", "Fischer Klaas Wend"), ("FischerinTora", "Fischerin Tora Lunk"),
                                     ("FischerHinnerk", "Fischer Hinnerk Saal")]):
    stadtmensch(name, anzeige, "hafen", 0, FARBEN[(i + 1) % 8], wohnung(), {
        "morgengrauen": ((112 + 14 * i, SUEDKAI_Z + 1.2), ["blick=180"]),
        "stille_stunde": ("heim", ["weg"]),
    }, sichtbar_wenn="alarm<3")
for i, (name, anzeige) in enumerate([("TraegerOle", "Hafenträger Jonte Pahl"), ("TraegerinMieke", "Hafenträgerin Mieke Strand")]):
    tragen = [(104 + 6 * i, NORDKAI_Z), (126 + 8 * i, NORDKAI_Z), (104 + 6 * i, NORDKAI_Z)]
    stadtmensch(name, anzeige, "hafen", 0, FARBEN[(i + 4) % 8], wohnung(), {
        "morgengrauen": (tragen, []),
        "stille_stunde": ("heim", ["weg"]),
    }, sichtbar_wenn="alarm<3")
person("KaufmannVelmund", SL, 132, KAI_Y, NORDKAI_Z, "Kaufmann Teodor Vass aus Velmund", "kaufmann_velmund", 0,
       "0.5, 0.2, 0.18, 1", gier=0, sichtbar_wenn="alarm<2")
person("Hafenaufsicht", SL, 143, KAI_Y, NORDKAI_Z, "Hafenwächter Gunnar Fleet", "hafenaufsicht", 1, ORDEN, gier=-90)

# --- Kirche, Rathaus, ein Flüchtling ---
stadtmensch("Kuester", "Küster Anselm Rohr", "kuester", 0, "0.2, 0.2, 0.22, 1", wohnung(), {
    "morgengrauen": ((62.5, 34), ["blick=-110"]),
    "nacht": ("heim", ["weg"]),
})
person("Ratsdiener", SL, 100, KAI_Y, -36, "Ratsdiener Oswin Pfahl", "ratsdiener", 0, "0.3, 0.2, 0.35, 1", gier=0)
person("Fluechtling", SL, 45.5, round(H(45.5, -16.5), 2), -16.5, "Jana Brook, Flüchtling aus dem Süden", "fluechtling", 0,
       "0.4, 0.36, 0.3, 1", gier=-130)

anzahl_stadtleute = sum(1 for k in knoten if f'parent="{SL}"' in k)
print("Stadtleute:", anzahl_stadtleute, "in", len(_belegt), "Häusern")
for f in FEHLWEGE:
    print("WARNUNG Weg:", f)
