"""Erzeugt modelle/natur/pilze/pilze.gltf: Pilzbüschel für Baumstämme und Waldboden (eigene Geometrie, kein Scan).

Drei Büschel als eigene Meshes: braune Hallimasche (viele kleine), rote Fliegenpilze mit weißen Tupfen (einzeln, groß)
und helle Baumschwämme (Konsolen, die seitlich am Stamm wachsen). Aufruf: python3 werkzeuge/pilze_erzeugen.py"""
import json, math, random, struct
from pathlib import Path

ZIEL = Path(__file__).resolve().parents[1] / "modelle" / "natur" / "pilze"
random.seed(31)


def hut(cx, cy, cz, r, h, teile=14, ringe=5, schief=0.0):
    """Gewölbter Hut (oben) mit flacher Unterseite. Gibt (Punkte, Normalen, Dreiecke oben, Dreiecke unten)."""
    p, n, oben, unten = [], [], [], []
    for i in range(ringe + 1):
        w = (i / ringe) * math.pi / 2
        for k in range(teile):
            a = 2 * math.pi * k / teile
            x, z = math.cos(a) * math.sin(w) * r, math.sin(a) * math.sin(w) * r
            y = math.cos(w) * h
            p.append((cx + x, cy + y + x * schief, cz + z))
            nn = (math.cos(a) * math.sin(w) / r, math.cos(w) / h, math.sin(a) * math.sin(w) / r)
            l = math.sqrt(sum(c * c for c in nn))
            n.append(tuple(c / l for c in nn))
    for i in range(ringe):
        for k in range(teile):
            a, b = i * teile + k, i * teile + (k + 1) % teile
            c, d = a + teile, b + teile
            oben += [a, c, b, b, c, d]
    # Unterseite: Fächer von der Mitte zum Rand
    mitte = len(p)
    p.append((cx, cy - h * 0.1, cz)); n.append((0, -1, 0))
    rand0 = ringe * teile
    for k in range(teile):
        q = p[rand0 + k]
        p.append(q); n.append((0, -1, 0))
    for k in range(teile):
        unten += [mitte, mitte + 1 + k, mitte + 1 + (k + 1) % teile]
    return p, n, oben, unten


def stiel(cx, cy, cz, r, h, teile=8):
    p, n, d = [], [], []
    for j, y in enumerate((cy, cy + h)):
        rr = r * (1.15 if j == 0 else 0.9)
        for k in range(teile):
            a = 2 * math.pi * k / teile
            p.append((cx + math.cos(a) * rr, y, cz + math.sin(a) * rr)); n.append((math.cos(a), 0, math.sin(a)))
    for k in range(teile):
        a, b = k, (k + 1) % teile
        d += [a, b, a + teile, b, b + teile, a + teile]
    return p, n, d


class Teil:
    def __init__(self):
        self.p, self.n, self.d = [], [], []

    def dazu(self, p, n, d):
        o = len(self.p)
        self.p += p; self.n += n; self.d += [o + i for i in d]


def buschel(art):
    """Ein Büschel: Teile je Material (hut, unten, stiel, tupfen)."""
    teile = {k: Teil() for k in ("hut", "unten", "stiel", "tupfen")}
    if art == "hallimasch":
        for _ in range(9):
            x, z = random.uniform(-0.12, 0.12), random.uniform(-0.12, 0.12)
            hs = random.uniform(0.04, 0.09)
            r = random.uniform(0.025, 0.05)
            s = stiel(x, 0, z, r * 0.22, hs); teile["stiel"].dazu(*s)
            p, n, o, u = hut(x, hs, z, r, r * 0.55)
            teile["hut"].dazu(p, n, o); teile["unten"].dazu(p, n, u)
    elif art == "fliegenpilz":
        for x, z, hs, r in [(0, 0, 0.13, 0.07), (0.09, 0.05, 0.08, 0.045)]:
            s = stiel(x, 0, z, r * 0.2, hs); teile["stiel"].dazu(*s)
            p, n, o, u = hut(x, hs, z, r, r * 0.5)
            teile["hut"].dazu(p, n, o); teile["unten"].dazu(p, n, u)
            for _ in range(7):
                a, w = random.uniform(0, 2 * math.pi), random.uniform(0.2, 1.2)
                px_, pz_ = x + math.cos(a) * math.sin(w) * r * 1.02, z + math.sin(a) * math.sin(w) * r * 1.02
                py_ = hs + math.cos(w) * r * 0.5 * 1.04
                tp, tn, to, _ = hut(px_, py_, pz_, 0.008, 0.003, teile=6, ringe=1)
                teile["tupfen"].dazu(tp, tn, to)
    else:  # baumschwamm: halbe Konsolen, seitlich (nach +z) vom Stamm weg
        for y, r in [(0.0, 0.09), (0.07, 0.07), (0.13, 0.05)]:
            p, n, o, u = hut(0, y, 0.0, r, r * 0.3, schief=0.0)
            # nur die vordere Hälfte (z > 0)
            p = [(x, y_, abs(z_) * 1.0) for x, y_, z_ in p]
            teile["hut"].dazu(p, n, o); teile["unten"].dazu(p, n, u)
    return teile


FARBEN = {
    "hallimasch": {"hut": (0.55, 0.38, 0.2), "unten": (0.85, 0.78, 0.62), "stiel": (0.8, 0.72, 0.55), "tupfen": (1, 1, 1)},
    "fliegenpilz": {"hut": (0.75, 0.08, 0.04), "unten": (0.95, 0.93, 0.85), "stiel": (0.95, 0.94, 0.88), "tupfen": (0.97, 0.96, 0.92)},
    "baumschwamm": {"hut": (0.62, 0.52, 0.38), "unten": (0.9, 0.86, 0.74), "stiel": (0.8, 0.7, 0.5), "tupfen": (1, 1, 1)},
}

gltf = {"asset": {"version": "2.0", "generator": "werkzeuge/pilze_erzeugen.py"}, "scene": 0, "scenes": [{"nodes": []}],
        "nodes": [], "meshes": [], "materials": [], "accessors": [], "bufferViews": [], "buffers": []}
daten = bytearray()


def puffer(werte, fmt, typ, anzahl, ziel, minmax=None):
    global daten
    while len(daten) % 4:
        daten += b"\0"
    off = len(daten)
    daten += struct.pack("<" + fmt * len(werte), *werte)
    gltf["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(daten) - off, "target": ziel})
    acc = {"bufferView": len(gltf["bufferViews"]) - 1, "componentType": 5126 if fmt == "f" else 5125, "count": anzahl,
           "type": typ}
    if minmax:
        acc["min"], acc["max"] = minmax
    gltf["accessors"].append(acc)
    return len(gltf["accessors"]) - 1


for art in ("hallimasch", "fliegenpilz", "baumschwamm"):
    teile = buschel(art)
    prims = []
    for mat, t in teile.items():
        if not t.d:
            continue
        gltf["materials"].append({"name": f"{art}_{mat}", "pbrMetallicRoughness": {
            "baseColorFactor": list(FARBEN[art][mat]) + [1.0], "metallicFactor": 0.0, "roughnessFactor": 0.85},
            "doubleSided": True})
        flach = [c for q in t.p for c in q]
        mins = [min(q[i] for q in t.p) for i in range(3)]
        maxs = [max(q[i] for q in t.p) for i in range(3)]
        pos = puffer(flach, "f", "VEC3", len(t.p), 34962, (mins, maxs))
        nor = puffer([c for q in t.n for c in q], "f", "VEC3", len(t.n), 34962)
        idx = puffer(t.d, "I", "SCALAR", len(t.d), 34963)
        prims.append({"attributes": {"POSITION": pos, "NORMAL": nor}, "indices": idx,
                      "material": len(gltf["materials"]) - 1})
    gltf["meshes"].append({"name": art, "primitives": prims})
    gltf["nodes"].append({"name": art, "mesh": len(gltf["meshes"]) - 1})
    gltf["scenes"][0]["nodes"].append(len(gltf["nodes"]) - 1)

ZIEL.mkdir(parents=True, exist_ok=True)
gltf["buffers"].append({"uri": "pilze.bin", "byteLength": len(daten)})
(ZIEL / "pilze.bin").write_bytes(bytes(daten))
(ZIEL / "pilze.gltf").write_text(json.dumps(gltf, indent=1))
print("geschrieben:", ZIEL / "pilze.gltf", len(daten), "Bytes")
