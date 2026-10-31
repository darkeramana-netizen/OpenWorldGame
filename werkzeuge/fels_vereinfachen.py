"""Liest ein Poly-Haven-glTF (modelle/felsen/), vereinfacht jedes Mesh (meshoptimizer, behält UV/Normalen) und schreibt ein neues glTF
mit einer .bin daneben; die Texturen werden kopiert. Aufruf: fels_vereinfachen.py quelle.gltf zielordner dreiecke"""
import sys, json, shutil, struct
from pathlib import Path
import numpy as np
import meshoptimizer as mo

quelle, ziel, ziel_dreiecke = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3])
nur_form = len(sys.argv) > 4   # Kollision: nur Positionen, ohne Material und Bilder
g = json.loads(quelle.read_text())
roh = (quelle.parent / g["buffers"][0]["uri"]).read_bytes()
TYP = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
ANZ = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}

def lies(i):
    a = g["accessors"][i]; bv = g["bufferViews"][a["bufferView"]]
    dt = TYP[a["componentType"]]; n = ANZ[a["type"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0) or np.dtype(dt).itemsize * n
    if stride == np.dtype(dt).itemsize * n:
        arr = np.frombuffer(roh, dt, a["count"] * n, start).reshape(a["count"], n)
    else:
        arr = np.array([np.frombuffer(roh, dt, n, start + k * stride) for k in range(a["count"])])
    return arr.copy()

gesamt = sum(lies(p["indices"]).size // 3 for m in g["meshes"] for p in m["primitives"])
anteil = min(1.0, ziel_dreiecke / gesamt)
neu_bin = bytearray(); views = []; accs = []

def anhaengen(arr, ziel_typ, komp):
    global neu_bin
    while len(neu_bin) % 4: neu_bin += b"\0"
    off = len(neu_bin); daten = arr.astype(np.float32 if komp == 5126 else np.uint32).tobytes()
    neu_bin += daten
    views.append({"buffer": 0, "byteOffset": off, "byteLength": len(daten), **({"target": ziel_typ} if ziel_typ else {})})
    acc = {"bufferView": len(views) - 1, "componentType": komp, "count": int(arr.shape[0]),
           "type": {1: "SCALAR", 2: "VEC2", 3: "VEC3", 4: "VEC4"}[arr.shape[1] if arr.ndim > 1 else 1]}
    if komp == 5126 and arr.ndim > 1 and arr.shape[1] == 3:
        acc["min"] = arr.min(0).tolist(); acc["max"] = arr.max(0).tolist()
    accs.append(acc); return len(accs) - 1

for m in g["meshes"]:
    for p in m["primitives"]:
        idx = lies(p["indices"]).reshape(-1).astype(np.uint32)
        pos = lies(p["attributes"]["POSITION"]).astype(np.float32)
        ziel_idx = max(3, int(idx.size * anteil) // 3 * 3)
        aus = np.zeros(idx.size, dtype=np.uint32)
        n = mo.simplify(aus, idx, pos, target_index_count=ziel_idx, target_error=0.02)
        aus = aus[:n]
        benutzt = np.unique(aus); karte = np.full(pos.shape[0], -1, np.int64); karte[benutzt] = np.arange(benutzt.size)
        neu_attr = {}
        for name, ai in p["attributes"].items():
            if name not in (("POSITION",) if nur_form else ("POSITION", "NORMAL", "TEXCOORD_0", "TANGENT")):
                continue
            werte = lies(ai).astype(np.float32)[benutzt]
            neu_attr[name] = anhaengen(werte, 34962, 5126)
        p["attributes"] = neu_attr
        if nur_form:
            p.pop("material", None)
        p["indices"] = anhaengen(karte[aus].astype(np.uint32).reshape(-1, 1), 34963, 5125)
        print(f"  {m.get('name')}: {idx.size // 3} → {n // 3} Dreiecke")

g["accessors"] = accs; g["bufferViews"] = views
ziel.mkdir(parents=True, exist_ok=True)
name = quelle.stem.replace("_2k", "") + ("_form" if nur_form else "")
if nur_form:
    for k in ("images", "textures", "materials", "samplers"):
        g.pop(k, None)
g["buffers"] = [{"uri": name + ".bin", "byteLength": len(neu_bin)}]
(ziel / (name + ".bin")).write_bytes(bytes(neu_bin))
for bild in g.get("images", []):
    q = quelle.parent / bild["uri"]; neu = Path(bild["uri"]).name; bild["uri"] = neu
    shutil.copy(q, ziel / neu)
(ziel / (name + ".gltf")).write_text(json.dumps(g, indent=1))
print("geschrieben:", ziel / (name + ".gltf"))
