"""Lädt Fotoscan-Modelle von Poly Haven (CC0) für die Ausstattung (szenen/welt/ausstattung.gd).

Für jedes Modell entstehen in modelle/ausstattung/<name>/ zwei Fassungen als glTF mit den Fotoscan-Texturen (1k):
  - <name>_nah.gltf: mit meshoptimizer auf 2500 Dreiecke je Meter Größe vereinfacht (400 bis --dreiecke, Vorgabe 3000)
  - <name>_fern.gltf: ein Sechstel davon (mindestens 150), für mehr als 30 m Abstand
Das Modell wird so verschoben, dass es mittig über dem Ursprung auf y = 0 steht; Maßstab und Ausrichtung bleiben wie im
Scan (Meter, Poly Haven schaut nach +z). Dazu modell.json: Ausdehnung (Meter), Dreiecke je Fassung, Quelle.
Welche Art welches Modell zeigt, steht in ausstattung.gd (SCANS).

Aufruf aus dem Projektordner (braucht numpy, meshoptimizer):
    python3 werkzeuge/modell_laden.py wine_barrel_01 wooden_crate_02 --dreiecke 2000
Danach: Godot einmal mit --headless --import starten. Quellen in modelle/ausstattung/QUELLEN.md.
"""
import json, sys, tempfile, urllib.request
from pathlib import Path
import numpy as np
import meshoptimizer as mo

args = sys.argv[1:]
DREIECKE = 3000
if "--dreiecke" in args:
    i = args.index("--dreiecke"); DREIECKE = int(args[i + 1]); del args[i:i + 2]
KOPF = {"User-Agent": "sorrowland-werkzeuge/1.0"}
REPO = Path(__file__).resolve().parent.parent
ZIEL = REPO / "modelle" / "ausstattung"
TYP = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
ANZ = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def lade(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=KOPF), timeout=900) as r:
        return r.read()


def lies_gltf(datei):
    """Alle Dreiecke je Material, in Weltlage (Knotenmatrizen angewandt): Material → (pos, nor, uv, idx)."""
    g = json.loads(datei.read_text())
    roh = (datei.parent / g["buffers"][0]["uri"]).read_bytes()

    def lies(i):
        a = g["accessors"][i]; bv = g["bufferViews"][a["bufferView"]]
        dt = TYP[a["componentType"]]; n = ANZ[a["type"]]
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", 0)
        if stride and stride != np.dtype(dt).itemsize * n:
            v = np.frombuffer(roh, np.uint8, a["count"] * stride, start).reshape(a["count"], stride)
            return v[:, :np.dtype(dt).itemsize * n].copy().view(dt).reshape(a["count"], n)
        return np.frombuffer(roh, dt, a["count"] * n, start).reshape(a["count"], n).copy()

    def matrix(k):
        if "matrix" in k:
            return np.array(k["matrix"], dtype=np.float64).reshape(4, 4).T
        t = np.array(k.get("translation", [0, 0, 0])); s = np.array(k.get("scale", [1, 1, 1]))
        x, y, z, w = k.get("rotation", [0, 0, 0, 1])
        r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                      [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                      [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
        m = np.eye(4); m[:3, :3] = r * s; m[:3, 3] = t
        return m

    teile = {}
    def besuche(ki, eltern):
        k = g["nodes"][ki]; m = eltern @ matrix(k)
        if "mesh" in k:
            for p in g["meshes"][k["mesh"]]["primitives"]:
                pos = lies(p["attributes"]["POSITION"]).astype(np.float64)
                nor = lies(p["attributes"]["NORMAL"]).astype(np.float64)
                uv = lies(p["attributes"]["TEXCOORD_0"]).astype(np.float64) if "TEXCOORD_0" in p["attributes"] \
                    else np.zeros((len(pos), 2))
                idx = lies(p["indices"]).reshape(-1, 3).astype(np.int64)
                pos = pos @ m[:3, :3].T + m[:3, 3]
                nor = nor @ np.linalg.inv(m[:3, :3])
                nor /= np.linalg.norm(nor, axis=1, keepdims=True) + 1e-12
                teile.setdefault(p.get("material", 0), []).append((pos, nor, uv, idx))
        for c in k.get("children", []):
            besuche(c, m)
    for wurzel in g["scenes"][g.get("scene", 0)]["nodes"]:
        besuche(wurzel, np.eye(4))
    zusammen = {}
    for mat, liste in teile.items():
        off = 0; P, N, U, I = [], [], [], []
        for pos, nor, uv, idx in liste:
            P.append(pos); N.append(nor); U.append(uv); I.append(idx + off); off += len(pos)
        zusammen[mat] = [np.concatenate(P), np.concatenate(N), np.concatenate(U), np.concatenate(I)]
    return g, zusammen


def vereinfache(pos, nor, uv, idx, ziel):
    """Auf etwa ziel Dreiecke; Nähte (UV, Normalen) bleiben, weil dort getrennte Ecken liegen."""
    if len(idx) <= ziel:
        return pos, nor, uv, idx
    flach = idx.astype(np.uint32).ravel()
    ecken = np.ascontiguousarray(pos.astype(np.float32))
    neu = np.zeros(len(flach), dtype=np.uint32)
    n = mo.simplify(neu, flach, ecken, len(flach), len(ecken), 12, ziel * 3, 0.02)
    if n > ziel * 3 * 1.5:   # Nähte bremsen: dann grob, aber am Ziel
        grob = np.zeros(len(flach), dtype=np.uint32)
        m = mo.simplify_sloppy(grob, flach, ecken, len(flach), len(ecken), 12, ziel * 3, 0.5)
        if 0 < m < n:
            neu, n = grob, m
    neu = neu[:n]
    benutzt, neu_idx = np.unique(neu, return_inverse=True)
    return pos[benutzt], nor[benutzt], uv[benutzt], neu_idx.reshape(-1, 3)


def schreibe(ziel_datei, teile, g_quelle, quelle_ordner):
    bin_ = bytearray(); views = []; accs = []
    def anh(arr, komp, ziel_typ):
        nonlocal bin_
        while len(bin_) % 4:
            bin_ += b"\0"
        daten = arr.astype(np.float32 if komp == 5126 else np.uint32).tobytes()
        views.append({"buffer": 0, "byteOffset": len(bin_), "byteLength": len(daten), "target": ziel_typ})
        bin_ += daten
        acc = {"bufferView": len(views) - 1, "componentType": komp, "count": int(arr.shape[0]),
               "type": {1: "SCALAR", 2: "VEC2", 3: "VEC3"}[arr.shape[1] if arr.ndim > 1 else 1]}
        if komp == 5126 and arr.ndim > 1 and arr.shape[1] == 3:
            acc["min"] = arr.min(0).tolist(); acc["max"] = arr.max(0).tolist()
        accs.append(acc); return len(accs) - 1
    bilder, texturen, materialien, prims = [], [], [], []
    bild_nr = {}
    def textur(uri):
        if uri not in bild_nr:
            bilder.append({"uri": uri}); texturen.append({"source": len(bilder) - 1, "sampler": 0})
            bild_nr[uri] = len(texturen) - 1
        return bild_nr[uri]
    def kopiere_material(mat):
        m = json.loads(json.dumps(mat))
        m.pop("extensions", None)
        def umbiegen(t):
            uri = g_quelle["images"][g_quelle["textures"][t["index"]]["source"]]["uri"]
            name = Path(uri).name
            (ziel_datei.parent / name).write_bytes((quelle_ordner / uri).read_bytes())
            t["index"] = textur(name)
            t.pop("extensions", None)
        for schluessel in ("normalTexture", "occlusionTexture", "emissiveTexture"):
            if schluessel in m:
                umbiegen(m[schluessel])
        pbr = m.get("pbrMetallicRoughness", {})
        for schluessel in ("baseColorTexture", "metallicRoughnessTexture"):
            if schluessel in pbr:
                umbiegen(pbr[schluessel])
        return m
    for mat, (pos, nor, uv, idx) in teile.items():
        materialien.append(kopiere_material(g_quelle["materials"][mat]) if g_quelle.get("materials") else {})
        prims.append({"attributes": {"POSITION": anh(pos, 5126, 34962), "NORMAL": anh(nor, 5126, 34962),
                                     "TEXCOORD_0": anh(uv, 5126, 34962)},
                      "indices": anh(idx.reshape(-1), 5125, 34963), "material": len(materialien) - 1})
    bin_name = ziel_datei.with_suffix(".bin").name
    (ziel_datei.parent / bin_name).write_bytes(bin_)
    gltf = {"asset": {"version": "2.0", "generator": "sorrowland modell_laden.py"}, "scene": 0,
            "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": ziel_datei.stem}],
            "meshes": [{"name": ziel_datei.stem, "primitives": prims}], "materials": materialien,
            "textures": texturen, "images": bilder, "samplers": [{"magFilter": 9729, "minFilter": 9987}],
            "buffers": [{"uri": bin_name, "byteLength": len(bin_)}], "bufferViews": views, "accessors": accs}
    ziel_datei.write_text(json.dumps(gltf))


def verarbeite(name):
    info = json.loads(lade(f"https://api.polyhaven.com/files/{name}"))
    g = info["gltf"]["1k"]["gltf"]
    tmp = Path(tempfile.gettempdir()) / "sorrowland_modelle" / name
    tmp.mkdir(parents=True, exist_ok=True)
    quelle = tmp / Path(g["url"]).name
    if not quelle.exists():
        quelle.write_bytes(lade(g["url"]))
    for pfad, teil in g["include"].items():
        (tmp / pfad).parent.mkdir(parents=True, exist_ok=True)
        if not (tmp / pfad).exists() or (tmp / pfad).stat().st_size != teil["size"]:
            (tmp / pfad).write_bytes(lade(teil["url"]))
    gq, teile = lies_gltf(quelle)
    alle = np.concatenate([t[0] for t in teile.values()])
    lo, hi = alle.min(0), alle.max(0)
    versatz = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    for t in teile.values():
        t[0] = t[0] - versatz
    ziel = ZIEL / name
    ziel.mkdir(parents=True, exist_ok=True)
    gesamt = sum(len(t[3]) for t in teile.values())
    ergebnis = {"groesse": [round(float(v), 3) for v in hi - lo], "quelle": f"https://polyhaven.com/a/{name}",
                "dreiecke_scan": int(gesamt)}
    # kleine Dinge brauchen weniger Dreiecke: 2500 je Meter der größten Ausdehnung, höchstens --dreiecke
    nah = int(min(DREIECKE, max(400, 2500 * float((hi - lo).max()))))
    for fassung, dreiecke in (("nah", nah), ("fern", max(120, nah // 6))):
        neu = {m: vereinfache(*t, max(24, int(dreiecke * len(t[3]) / gesamt))) for m, t in teile.items()}
        schreibe(ziel / f"{name}_{fassung}.gltf", neu, gq, quelle.parent)
        ergebnis[fassung] = int(sum(len(t[3]) for t in neu.values()))
    (ziel / "modell.json").write_text(json.dumps(ergebnis, indent=1))
    print("übernommen:", name, ergebnis)


for name in args:
    verarbeite(name)
