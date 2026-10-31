# ---------- Naturdetails rund um Drachenstein (szenen/welt/felsen.gd) ----------
# Fotoscans von Poly Haven (modelle/natur/, CC0) und eigene Pilze (werkzeuge/pilze_erzeugen.py): umgestürzte Stämme mit
# Pilzen und Moos, Wurzelstöcke, Sträucher, Farne, Brennnesseln und trockene Äste. Sie liegen gehäuft in Waldflecken
# (eigenes Rauschen) und an Waldrändern, nicht in Stadt, Burgbezirk und Hafen, nicht auf Wegen und nicht im Wasser.
# Wird aus region_drachenstein.py nach teil_felsen.py ausgeführt (nutzt _frei, _wege, _tore, _gefaelle, _abstand).

NATURMODELLE = [
    "res://modelle/natur/dead_tree_trunk/dead_tree_trunk.gltf",            # 0 dünner Stamm, 3 m
    "res://modelle/natur/dead_tree_trunk_02/dead_tree_trunk_02.gltf",      # 1 dicker Stamm, 4 m
    "res://modelle/natur/root_cluster_01/root_cluster_01.gltf",            # 2 Wurzelstock
    "res://modelle/natur/dry_branches_medium_01/dry_branches_medium_01.gltf#0",
    "res://modelle/natur/dry_branches_medium_01/dry_branches_medium_01.gltf#1",
    "res://modelle/natur/dry_branches_medium_01/dry_branches_medium_01.gltf#2",
    "res://modelle/natur/pilze/pilze.gltf#0",                              # 6 Hallimasch
    "res://modelle/natur/pilze/pilze.gltf#1",                              # 7 Fliegenpilz
    "res://modelle/natur/pilze/pilze.gltf#2",                              # 8 Baumschwamm
] + [f"res://modelle/natur/shrub_02/shrub_02.gltf#{k}" for k in range(4)] \
  + [f"res://modelle/natur/shrub_03/shrub_03.gltf#{k}" for k in range(4)] \
  + ["res://modelle/natur/shrub_04/shrub_04.gltf"] \
  + [f"res://modelle/natur/nettle_plant/nettle_plant.gltf#{k}" for k in range(6)] \
  + [f"res://modelle/pflanzen/fern_02/fern_02.gltf#{k}" for k in range(4)] \
  + [f"res://modelle/pflanzen/moss_01/moss_01.gltf#{k}" for k in range(12)]
STAMM, STAMM_DICK, WURZEL = 0, 1, 2
AESTE = [3, 4, 5]
HALLIMASCH, FLIEGENPILZ, SCHWAMM = 6, 7, 8
STRAUCH_GROSS = list(range(9, 13))
STRAUCH_KLEIN = list(range(13, 17)) + [17]
NESSEL = list(range(18, 24))
FARN_N = list(range(24, 28))
MOOS_N = list(range(28, 40))

random.seed(2207)
_ring = WL(PD.RINGMAUER)


def _rauschen(x, z, f, saat):
    """Weiches Wertrauschen 0..1 (für Waldflecken)."""
    def zufall(i, j):
        return ((math.sin(i * 127.1 + j * 311.7 + saat * 74.7) * 43758.5453) % 1.0 + 1.0) % 1.0
    gx, gz = x * f, z * f
    i, j = math.floor(gx), math.floor(gz)
    u, v = gx - i, gz - j
    u, v = u * u * (3 - 2 * u), v * v * (3 - 2 * v)
    a, b = zufall(i, j), zufall(i + 1, j)
    c, d = zufall(i, j + 1), zufall(i + 1, j + 1)
    return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v


def _wald(x, z):
    return _rauschen(x, z, 0.012, 1) * 0.65 + _rauschen(x, z, 0.04, 2) * 0.35


NATUR = []


def _setze(m, x, y, z, gier, neigung, groesse):
    NATUR.append((m, round(x, 2), round(y, 2), round(z, 2), round(gier, 1), round(neigung, 1), round(groesse, 2)))


for gx in range(-360, 330, 3):
    for gz in range(-520, 555, 3):
        x, z = gx + random.uniform(-1.4, 1.4), gz + random.uniform(-1.4, 1.4)
        h = H(x, z)
        if h < -18.0 or h > 60:
            continue
        s = _gefaelle(x, z)[2]
        if s > 0.6:
            continue
        w = _wald(x, z)
        if w < 0.42 and random.random() > 0.15:
            continue
        im_zwinger = im_vieleck((x, z), _ring)
        if any(im_vieleck((x, z), v) for v in _frei) or (im_zwinger and (random.random() > 0.35 or s > 0.45)):
            continue
        if _abstand((x, z), _wege) < 4.0 or min(math.dist((x, z), t) for t in _tore) < 8.0:
            continue
        dicht = max(0.0, (w - 0.42) / 0.58)
        wurf = random.random()
        if im_zwinger:
            # im Zwinger: Gras, Nesseln und kleine Sträucher, nah an Mauern und Felsen dichter
            if wurf < 0.25:
                _setze(random.choice(STRAUCH_KLEIN + NESSEL + FARN_N), x, h - 0.05, z, random.uniform(0, 360), 0,
                       random.uniform(0.8, 1.3))
            continue
        if wurf < 0.012 * (0.3 + dicht):
            # umgestürzter Stamm mit Pilzen und Moos
            m = random.choice([STAMM, STAMM_DICK, STAMM_DICK])
            g = random.uniform(0.9, 1.6) if m == STAMM_DICK else random.uniform(1.2, 2.4)
            gier = random.uniform(0, 360)
            dicke = (1.06 if m == STAMM_DICK else 0.29) * g
            _setze(m, x, h - dicke * 0.18, z, gier, 0, g)
            a = math.radians(gier)
            lx, lz = math.cos(a), -math.sin(a)          # entlang des Stamms (lokal x)
            laenge = (4.05 if m == STAMM_DICK else 3.05) * g
            for _ in range(random.randint(2, 5)):
                t = random.uniform(-0.4, 0.4) * laenge
                px, pz = x + lx * t, z + lz * t
                art = random.choice([HALLIMASCH, HALLIMASCH, SCHWAMM, MOOS_N[0]])
                if art == SCHWAMM:
                    seite = random.choice((-1, 1))
                    _setze(SCHWAMM, px - lz * dicke * 0.48 * seite, h + dicke * 0.3, pz + lx * dicke * 0.48 * seite,
                           math.degrees(math.atan2(-lz * seite, lx * seite)) + 90, 0, random.uniform(1.0, 2.2))
                elif art == HALLIMASCH:
                    _setze(HALLIMASCH, px, h - dicke * 0.18 + dicke * 0.95, pz, random.uniform(0, 360), 0, random.uniform(1.0, 1.8))
                else:
                    _setze(random.choice(MOOS_N), px, h - dicke * 0.18 + dicke * 0.9, pz, random.uniform(0, 360), 0,
                           random.uniform(2.0, 3.5) * min(1.0, dicke))
            # Brennnesseln und Farn am Stamm
            for _ in range(random.randint(1, 4)):
                t = random.uniform(-0.5, 0.5) * laenge
                seite = random.choice((-1, 1)) * random.uniform(0.6, 1.4)
                px, pz = x + lx * t - lz * seite, z + lz * t + lx * seite
                _setze(random.choice(NESSEL + FARN_N), px, H(px, pz) - 0.05, pz, random.uniform(0, 360), 0,
                       random.uniform(0.8, 1.4))
        elif wurf < 0.018 * (0.3 + dicht):
            _setze(WURZEL, x, h - 0.4, z, random.uniform(0, 360), 0, random.uniform(0.6, 1.1))
        elif wurf < 0.03 * (0.3 + dicht):
            _setze(random.choice([FLIEGENPILZ, HALLIMASCH]), x, h - 0.02, z, random.uniform(0, 360), 0, random.uniform(1.0, 1.6))
        elif wurf < 0.06 * (0.2 + dicht):
            _setze(random.choice(AESTE), x, h - 0.05, z, random.uniform(0, 360), 0, random.uniform(0.8, 1.4))
        elif wurf < 0.13 * (0.2 + dicht):
            _setze(random.choice(FARN_N), x, h - 0.05, z, random.uniform(0, 360), 0, random.uniform(0.9, 1.6))
        elif wurf < 0.17 * (0.2 + dicht):
            _setze(random.choice(STRAUCH_GROSS), x, h - 0.1, z, random.uniform(0, 360), 0, random.uniform(0.6, 1.1))
        elif wurf < 0.22 * (0.15 + dicht):
            _setze(random.choice(STRAUCH_KLEIN + NESSEL), x, h - 0.05, z, random.uniform(0, 360), 0, random.uniform(0.8, 1.5))

N("Natur", "Node3D", DS, f"""script = ExtResource("30_felsen")
modelle = PackedStringArray({", ".join(f'"{p}"' for p in NATURMODELLE)})
stuecke = PackedFloat32Array({", ".join(f"{v:.6g}" for st in NATUR for v in st)})
sichtweite = 300.0
kachel = 64.0""")
_zaehl = lambda ms: sum(1 for n in NATUR if n[0] in ms)
print("Natur:", len(NATUR), "Stücke –", "Stämme", _zaehl([STAMM, STAMM_DICK]), "Wurzeln", _zaehl([WURZEL]),
      "Pilze", _zaehl([HALLIMASCH, FLIEGENPILZ, SCHWAMM]), "Sträucher", _zaehl(STRAUCH_GROSS + STRAUCH_KLEIN),
      "Nesseln", _zaehl(NESSEL), "Farn", _zaehl(FARN_N), "Moos", _zaehl(MOOS_N), "Äste", _zaehl(AESTE))
