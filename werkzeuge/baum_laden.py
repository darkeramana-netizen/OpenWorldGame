"""Lädt einen Baum-Fotoscan von Poly Haven (CC0) und macht daraus spieltaugliche Bäume für szenen/welt/bewuchs.gd.

Die Scans haben 1 bis 17 Millionen Dreiecke, das Laub besteht aus einzeln modellierten Blättern bzw. Nadelzweigen ohne
Transparenz. Daraus entstehen zwei Fassungen (nah und fern), je ein glTF in modelle/baeume/<name>/:
  - Holz (Stamm, Äste): mit meshoptimizer vereinfacht, Fotoscan-Texturen bleiben.
  - Laub: Die Blätter werden zu Büscheln zusammengefasst (k-means über die Blattmitten). Einige typische Büschel werden
    von vorn in eine Textur mit Transparenz gezeichnet (4 Kacheln, Python-Rasterung mit den Blatt-UVs); jedes Büschel
    wird zu zwei gekreuzten Karten an seinem Ort und in seiner Ebene. Normalen der Karten zeigen von der Kronenmitte
    weg, damit die Krone wie ein Ganzes beleuchtet wird.
Dazu baum.json: Höhe des Modells (Meter), damit bewuchs.gd auf die gewünschte Baumhöhe skaliert.

Aufruf aus dem Projektordner (braucht numpy, scipy, Pillow, meshoptimizer):
    python3 werkzeuge/baum_laden.py fir_tree_01 island_tree_01
Weitere Angaben: --buesche 220 (Laubkarten nah), --holz 3000 (Dreiecke Holz nah), --karten 2 (gekreuzte Karten je
Büschel), --gross 115 (Kartengröße in Prozent der Büschelausdehnung). Nadelbäume: --buesche 420 --karten 3 --gross 170. --busch: nur die Krone auf dem Boden, als Busch
(Ordner <name>_busch). Quellen in modelle/baeume/QUELLEN.md.
"""
import json, sys, tempfile, urllib.request
from pathlib import Path
import numpy as np
import meshoptimizer as mo
from PIL import Image
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

args = sys.argv[1:]
def angabe(name, vorgabe):
    if name in args:
        i = args.index(name); wert = args[i + 1]; del args[i:i + 2]; return int(wert)
    return vorgabe
BUESCHE = angabe("--buesche", 220)
HOLZ = angabe("--holz", 3000)
KARTEN = angabe("--karten", 2)          # gekreuzte Karten je Büschel (Nadelbäume: 3, die Zweige liegen flach)
GROSS = angabe("--gross", 115) / 100.0  # Kartengröße im Verhältnis zur Ausdehnung des Büschels
BUSCH = "--busch" in args               # nur die Krone, auf den Boden gesetzt (ein Busch), Ordner <name>_busch
if BUSCH:
    args.remove("--busch")
# Büschel, Holz, Karten je Büschel, Kartengröße: Die Fernfassung hat weniger, aber größere Büschel, damit die
# Kronen aus der Ferne dicht bleiben
FASSUNGEN = {"nah": (BUESCHE, HOLZ, KARTEN, GROSS),
             "fern": (max(40, BUESCHE // 3), max(300, HOLZ // 6), max(1, KARTEN - 1), GROSS * (1.3 if KARTEN > 2 else 1.5))}
# (Laubbäume fern: eine Karte je Büschel, dafür größer; jede überlagerte Karte kostet die Grafikkarte einen Durchgang)
KACHEL = 512
KOPF = {"User-Agent": "sorrowland-werkzeuge/1.0"}
ZIEL = Path(__file__).resolve().parent.parent / "modelle" / "baeume"
TYP = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
ANZ = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def lade(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=KOPF), timeout=900) as r:
        return r.read()


# ---------- glTF lesen ----------

def lies_gltf(datei):
    g = json.loads(datei.read_text())
    roh = (datei.parent / g["buffers"][0]["uri"]).read_bytes()

    def lies(i):
        a = g["accessors"][i]; bv = g["bufferViews"][a["bufferView"]]
        dt = TYP[a["componentType"]]; n = ANZ[a["type"]]
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", 0)
        if stride and stride != np.dtype(dt).itemsize * n:
            roh_v = np.frombuffer(roh, np.uint8, a["count"] * stride, start).reshape(a["count"], stride)
            return roh_v[:, :np.dtype(dt).itemsize * n].copy().view(dt).reshape(a["count"], n)
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

    teile = {}   # Material → Liste (pos, nor, uv, idx)
    def besuche(ki, eltern):
        k = g["nodes"][ki]; m = eltern @ matrix(k)
        if "mesh" in k:
            for p in g["meshes"][k["mesh"]]["primitives"]:
                pos = lies(p["attributes"]["POSITION"]).astype(np.float64)
                nor = lies(p["attributes"]["NORMAL"]).astype(np.float64)
                # die UV-Schicht mit Inhalt (bei manchen Scans ist TEXCOORD_0 überall gleich, die Ästeschicht in _1)
                uv = np.zeros((len(pos), 2))
                for schicht in ("TEXCOORD_0", "TEXCOORD_1"):
                    if schicht in p["attributes"]:
                        kandidat = lies(p["attributes"][schicht]).astype(np.float64)
                        if np.ptp(kandidat, axis=0).max() > 1e-6:
                            uv = kandidat
                            break
                idx = lies(p["indices"]).reshape(-1, 3).astype(np.int64)
                if np.ptp(uv, axis=0).max() <= 1e-6:   # keine UVs: aus dem Ort (Rinde wiederholt sich je halbem Meter)
                    uv = np.stack([(pos[:, 0] + pos[:, 2]) * 2.0, pos[:, 1] * 2.0], axis=1)
                pos = pos @ m[:3, :3].T + m[:3, 3]
                nor = nor @ np.linalg.inv(m[:3, :3])
                nor /= np.linalg.norm(nor, axis=1, keepdims=True) + 1e-12
                teile.setdefault(p["material"], []).append((pos, nor, uv, idx))
        for c in k.get("children", []):
            besuche(c, m)
    for wurzel in g["scenes"][g.get("scene", 0)]["nodes"]:
        besuche(wurzel, np.eye(4))
    zusammen = {}
    for mat, liste in teile.items():
        off = 0; P, N, U, I = [], [], [], []
        for pos, nor, uv, idx in liste:
            P.append(pos); N.append(nor); U.append(uv); I.append(idx + off); off += len(pos)
        zusammen[mat] = (np.concatenate(P), np.concatenate(N), np.concatenate(U), np.concatenate(I))
    return g, zusammen


# ---------- Holz vereinfachen ----------

def vereinfache(pos, nor, uv, idx, ziel):
    if len(idx) <= ziel:
        return pos, nor, uv, idx
    flach = idx.astype(np.uint32).ravel()
    ecken = np.ascontiguousarray(pos.astype(np.float32))
    neu = np.zeros(len(flach), dtype=np.uint32)
    n = mo.simplify(neu, flach, ecken, len(flach), len(ecken), 12, ziel * 3, 0.05)
    if n > ziel * 3 * 1.6:   # dünne Äste lassen sich mit Topologie kaum vereinfachen
        grob = np.zeros(len(flach), dtype=np.uint32)
        m = mo.simplify_sloppy(grob, flach, ecken, len(flach), len(ecken), 12, ziel * 3, 0.05)
        if 0 < m < n:
            neu, n = grob, m
    neu = neu[:n]
    benutzt, neu_idx = np.unique(neu, return_inverse=True)
    return pos[benutzt], nor[benutzt], uv[benutzt], neu_idx.reshape(-1, 3)


# ---------- Laub zu Büscheln ----------

def blaetter(pos, idx):
    """Zusammenhängende Teile (Blätter, Zweigstücke): je Dreieck die Nummer seines Teils."""
    r = np.concatenate([idx[:, 0], idx[:, 1]]); c = np.concatenate([idx[:, 1], idx[:, 2]])
    _, marke = connected_components(coo_matrix((np.ones(len(r)), (r, c)), shape=(len(pos), len(pos))), directed=False)
    return marke[idx[:, 0]]


def _naechste(punkte, mitten):
    zu = np.empty(len(punkte), np.int64)
    for s in range(0, len(punkte), 20000):   # blockweise, sonst wird die Abstandsmatrix zu groß
        teil = punkte[s:s + 20000]
        zu[s:s + 20000] = ((teil[:, None, :] - mitten[None, :, :]) ** 2).sum(-1).argmin(1)
    return zu


def kmeans(punkte, k, zufall):
    probe = punkte[zufall.choice(len(punkte), min(len(punkte), 20000), replace=False)]
    mitten = probe[zufall.choice(len(probe), k, replace=False)].copy()
    for _ in range(14):
        zu = _naechste(probe, mitten)
        for j in range(k):
            sel = probe[zu == j]
            if len(sel):
                mitten[j] = sel.mean(0)
    return _naechste(punkte, mitten)


def ebene(punkte):
    """Mitte und Achsen (u, v, n) der besten Ebene durch die Punkte."""
    m = punkte.mean(0)
    _, _, vt = np.linalg.svd(punkte - m, full_matrices=False)
    return m, vt[0], vt[1], vt[2]


def zeichne_bueschel(pos, uv, idx, bild):
    """Rastert die Dreiecke eines Büschels von vorn (Ebene der Blätter) in eine Kachel RGBA."""
    m, u, v, n = ebene(pos[idx].reshape(-1, 3))
    q = pos - m
    pu, pv, pn = q @ u, q @ v, q @ n
    halb = max(np.abs(pu[idx]).max(), np.abs(pv[idx]).max()) * 1.02
    px = (pu / halb * 0.5 + 0.5) * (KACHEL - 1)
    py = (0.5 - pv / halb * 0.5) * (KACHEL - 1)
    farbe = np.zeros((KACHEL, KACHEL, 4), np.float32)
    tiefe = np.full((KACHEL, KACHEL), -1e9, np.float32)
    th, tw = bild.shape[:2]
    for a, b, c in idx:
        xs = np.array([px[a], px[b], px[c]]); ys = np.array([py[a], py[b], py[c]])
        x0, x1 = int(max(0, np.floor(xs.min()))), int(min(KACHEL - 1, np.ceil(xs.max())))
        y0, y1 = int(max(0, np.floor(ys.min()))), int(min(KACHEL - 1, np.ceil(ys.max())))
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        det = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(det) < 1e-9:
            continue
        l0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / det
        l1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / det
        l2 = 1 - l0 - l1
        drin = (l0 >= 0) & (l1 >= 0) & (l2 >= 0)
        if not drin.any():
            continue
        t = l0 * pn[a] + l1 * pn[b] + l2 * pn[c]
        tu = (l0 * uv[a, 0] + l1 * uv[b, 0] + l2 * uv[c, 0]) % 1.0
        tv = (l0 * uv[a, 1] + l1 * uv[b, 1] + l2 * uv[c, 1]) % 1.0
        sx = np.clip((tu * tw).astype(int), 0, tw - 1); sy = np.clip((tv * th).astype(int), 0, th - 1)
        ausschnitt = tiefe[y0:y1 + 1, x0:x1 + 1]
        vorn = drin & (t > ausschnitt) & (bild[sy, sx, 3] > 0.5)   # durchsichtige Stellen der Blattkarten auslassen
        ausschnitt[vorn] = t[vorn]
        f = farbe[y0:y1 + 1, x0:x1 + 1]
        f[vorn, :3] = bild[sy[vorn], sx[vorn], :3]
        f[vorn, 3] = 1.0
    # Farbe in die durchsichtigen Ränder ausbreiten (sonst dunkle Säume in den Mipmaps)
    alpha = farbe[..., 3] > 0
    rgb = farbe[..., :3].copy()
    gefuellt = alpha.copy()
    for _ in range(24):
        if gefuellt.all():
            break
        summe = np.zeros_like(rgb); anzahl = np.zeros(gefuellt.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            summe += np.roll(np.roll(rgb * gefuellt[..., None], dy, 0), dx, 1)
            anzahl += np.roll(np.roll(gefuellt.astype(np.float32), dy, 0), dx, 1)
        neu = (~gefuellt) & (anzahl > 0)
        rgb[neu] = summe[neu] / anzahl[neu, None]
        gefuellt |= neu
    farbe[..., :3] = rgb
    return farbe


def baue_laub(pos, nor, uv, idx, bild, anzahl, karten, zufall, kacheln, gross):
    """Karten für die Büschel: Positionen, Normalen, UVs, Indizes."""
    teil = blaetter(pos, idx)
    teile = np.unique(teil)
    mitte_teil = np.zeros((teile.max() + 1, 3))
    np.add.at(mitte_teil, teil, pos[idx].mean(1))
    zaehl = np.bincount(teil, minlength=teile.max() + 1)
    mitte_teil = mitte_teil[teile] / zaehl[teile, None]
    k = min(anzahl, len(teile))
    zu_teil = kmeans(mitte_teil, k, zufall)
    zu_dreieck = zu_teil[np.searchsorted(teile, teil)]
    krone = pos[idx].reshape(-1, 3).mean(0)
    P, N, U, I = [], [], [], []
    for j in range(k):
        sel = idx[zu_dreieck == j]
        if len(sel) == 0:
            continue
        pk = pos[sel].reshape(-1, 3)
        m, u, v, n = ebene(pk)
        q = pk - m
        hu = np.percentile(np.abs(q @ u), 92) * gross + 0.05
        hv = np.percentile(np.abs(q @ v), 92) * gross + 0.05
        h = max(hu, hv)
        kachel = kacheln[zufall.integers(len(kacheln))]
        for kk in range(karten):
            if kk == 0:
                a1, a2 = u, v
            elif kk == 1:   # zweite Karte um die längere Achse gedreht (Volumen von der Seite)
                a1, a2 = u, n
            else:           # dritte quer dazu
                a1, a2 = v, n
            winkel = zufall.uniform(0, 2 * np.pi)
            c, s = np.cos(winkel), np.sin(winkel)
            b1, b2 = a1 * c + a2 * s, -a1 * s + a2 * c
            ecken = [m - b1 * h - b2 * h, m + b1 * h - b2 * h, m + b1 * h + b2 * h, m - b1 * h + b2 * h]
            basis = len(P)
            for e, (tu, tv) in zip(ecken, ((0, 1), (1, 1), (1, 0), (0, 0))):
                P.append(e)
                nn = e - krone; nn = nn / (np.linalg.norm(nn) + 1e-9)
                N.append(nn * 0.75 + np.array([0, 0.25, 0]))
                U.append((kachel[0] + tu * 0.5, kachel[1] + tv * 0.5))
            I += [(basis, basis + 1, basis + 2), (basis, basis + 2, basis + 3)]
    N = np.array(N); N /= np.linalg.norm(N, axis=1, keepdims=True)
    return np.array(P), N, np.array(U), np.array(I, dtype=np.int64)


# ---------- glTF schreiben ----------

def schreibe(ziel_datei, holz, laub, g_quelle, quelle_ordner, atlas_name, holz_im_atlas=False):
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
        if komp == 5126 and arr.shape[1] == 3:
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
        def umbiegen(t):
            uri = g_quelle["images"][g_quelle["textures"][t["index"]]["source"]]["uri"]
            name = Path(uri).name
            (ziel_datei.parent / name).write_bytes((quelle_ordner / uri).read_bytes())
            t["index"] = textur(name)
        for schluessel in ("normalTexture", "occlusionTexture", "emissiveTexture"):
            if schluessel in m:
                umbiegen(m[schluessel])
        pbr = m.get("pbrMetallicRoughness", {})
        for schluessel in ("baseColorTexture", "metallicRoughnessTexture"):
            if schluessel in pbr:
                umbiegen(pbr[schluessel])
        return m
    if holz_im_atlas:   # ein einziges Material: Holz mit der Farbe des Rindenfelds, an das Laub angehängt
        P, N, U, I = [laub[0]], [laub[1]], [laub[2]], [laub[3]]
        off = len(laub[0])
        for pos, nor, uv, idx in holz.values():
            P.append(pos); N.append(nor); U.append(np.tile([[10 / 1024, 10 / 1024]], (len(pos), 1))); I.append(idx + off)
            off += len(pos)
        laub = (np.concatenate(P), np.concatenate(N), np.concatenate(U), np.concatenate(I))
        holz = {}
    for mat, (pos, nor, uv, idx) in holz.items():
        materialien.append(kopiere_material(g_quelle["materials"][mat]))
        prims.append({"attributes": {"POSITION": anh(pos, 5126, 34962), "NORMAL": anh(nor, 5126, 34962),
                                     "TEXCOORD_0": anh(uv, 5126, 34962)},
                      "indices": anh(idx.reshape(-1), 5125, 34963), "material": len(materialien) - 1})
    pos, nor, uv, idx = laub
    materialien.append({"name": "laub", "doubleSided": True, "alphaMode": "MASK", "alphaCutoff": 0.25,
                        "pbrMetallicRoughness": {"baseColorTexture": {"index": textur(atlas_name)},
                                                 "metallicFactor": 0.0, "roughnessFactor": 0.85}})
    prims.append({"attributes": {"POSITION": anh(pos, 5126, 34962), "NORMAL": anh(nor, 5126, 34962),
                                 "TEXCOORD_0": anh(uv, 5126, 34962)},
                  "indices": anh(idx.reshape(-1), 5125, 34963), "material": len(materialien) - 1})
    bin_name = ziel_datei.with_suffix(".bin").name
    (ziel_datei.parent / bin_name).write_bytes(bin_)
    gltf = {"asset": {"version": "2.0", "generator": "sorrowland baum_laden.py"}, "scene": 0,
            "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": "baum"}],
            "meshes": [{"name": "baum", "primitives": prims}], "materials": materialien,
            "textures": texturen, "images": bilder, "samplers": [{"magFilter": 9729, "minFilter": 9987}],
            "buffers": [{"uri": bin_name, "byteLength": len(bin_)}], "bufferViews": views, "accessors": accs}
    ziel_datei.write_text(json.dumps(gltf))


def verarbeite(name):
    info = json.loads(lade(f"https://api.polyhaven.com/files/{name}"))
    g = info["gltf"]["1k"]["gltf"]
    # Zwischenspeicher: die Scans sind groß (bis 1 GB), ein zweiter Lauf lädt sie nicht noch einmal
    tmp = Path(tempfile.gettempdir()) / "sorrowland_baeume" / name
    tmp.mkdir(parents=True, exist_ok=True)
    if True:
        quelle = tmp / Path(g["url"]).name
        if not quelle.exists():
            quelle.write_bytes(lade(g["url"]))
        for pfad, teil in g["include"].items():
            (tmp / pfad).parent.mkdir(parents=True, exist_ok=True)
            if not (tmp / pfad).exists() or (tmp / pfad).stat().st_size != teil["size"]:
                (tmp / pfad).write_bytes(lade(teil["url"]))
        gq, teile = lies_gltf(quelle)
        # Laub: modellierte Blätter (BLEND) oder Blattkarten mit Transparenz (MASK, z. B. Sträucher)
        laub_mats = [m for m in teile if gq["materials"][m].get("alphaMode") in ("BLEND", "MASK")]
        holz_mats = [] if BUSCH else [m for m in teile if m not in laub_mats]
        if BUSCH:   # Krone auf den Boden: das Laub beginnt 0,2 m unter dem Boden
            unten = min(teile[m][0][:, 1].min() for m in laub_mats)
            for m in laub_mats:
                teile[m][0][:, 1] -= unten + 0.2
            teile = {m: teile[m] for m in laub_mats}
        alle = np.concatenate([teile[m][0] for m in teile])
        boden = alle[:, 1].min()
        for m in teile:   # Fuß auf y = 0
            teile[m][0][:, 1] -= boden
        hoehe = float(alle[:, 1].max() - boden)
        ziel = ZIEL / (name + "_busch" if BUSCH else name)
        ziel.mkdir(parents=True, exist_ok=True)
        # Laub: Atlas aus vier Büscheln (je eines aus jeder Laubart, sonst vier verschiedene)
        lm = laub_mats[0]
        # Laubarten zusammenlegen
        off = 0; P, N, U, I = [], [], [], []
        for m in laub_mats:
            p_, n_, u_, i_ = teile[m]; P.append(p_); N.append(n_); U.append(u_); I.append(i_ + off); off += len(p_)
        pos, nor, uv, idx = np.concatenate(P), np.concatenate(N), np.concatenate(U), np.concatenate(I)
        bild_uri = gq["images"][gq["textures"][gq["materials"][lm]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]]["uri"]
        bild = np.asarray(Image.open(quelle.parent / bild_uri).convert("RGBA"), np.float32) / 255.0
        zufall = np.random.default_rng(2207)
        teil = blaetter(pos, idx)
        teile_nr, zaehl = np.unique(teil, return_counts=True)
        # Büschel für den Atlas: die Blätter in je einer Kugel um vier zufällige Stellen der Krone
        atlas = np.zeros((KACHEL * 2, KACHEL * 2, 4), np.float32)
        mitten = pos[idx].mean(1)
        radius = (mitten.max(0) - mitten.min(0)).max() * 0.09
        for kk, (ox, oy) in enumerate(((0, 0), (1, 0), (0, 1), (1, 1))):
            for _ in range(20):
                stelle = mitten[zufall.integers(len(mitten))]
                sel = idx[np.linalg.norm(mitten - stelle, axis=1) < radius]
                if len(sel) > 200:
                    break
            atlas[oy * KACHEL:(oy + 1) * KACHEL, ox * KACHEL:(ox + 1) * KACHEL] = zeichne_bueschel(pos, uv, sel, bild)
        # Rindenfeld oben links im Atlas: Die Fernfassung zeichnet ihr Holz damit, im selben Material wie das Laub
        holz_bild = None
        for m in holz_mats:
            pbr = gq["materials"][m].get("pbrMetallicRoughness", {})
            if "baseColorTexture" in pbr:
                uri = gq["images"][gq["textures"][pbr["baseColorTexture"]["index"]]["source"]]["uri"]
                holz_bild = np.asarray(Image.open(quelle.parent / uri).convert("RGB"), np.float32) / 255.0
                break
        rinde = holz_bild.reshape(-1, 3).mean(0) if holz_bild is not None else np.array([0.3, 0.24, 0.18])
        if not holz_mats:
            print("  (kein Holz: nur Laubkarten)")
        atlas[2:18, 2:18, :3] = rinde
        atlas[2:18, 2:18, 3] = 1.0
        atlas_name = f"{ziel.name}_laub_atlas.png"
        Image.fromarray((np.clip(atlas, 0, 1) * 255).astype(np.uint8), "RGBA").save(ziel / atlas_name, optimize=True)
        kacheln = [(0.0, 0.0), (0.5, 0.0), (0.0, 0.5), (0.5, 0.5)]
        ergebnis = {"hoehe": round(hoehe, 3), "quelle": f"https://polyhaven.com/a/{name}"}
        for fassung, (buesche, holz_ziel, karten, gross) in FASSUNGEN.items():
            holz_dreiecke = sum(len(teile[m][3]) for m in holz_mats)
            holz = {}
            for m in holz_mats:
                p_, n_, u_, i_ = teile[m]
                anteil = len(i_) / max(1, holz_dreiecke)
                holz[m] = vereinfache(p_, n_, u_, i_, max(60, int(holz_ziel * anteil)))
            laub = baue_laub(pos, nor, uv, idx, bild, buesche, karten, np.random.default_rng(31), kacheln, gross)
            datei = ziel / f"{ziel.name}_{fassung}.gltf"
            schreibe(datei, holz, laub, gq, quelle.parent, atlas_name, holz_im_atlas=fassung == "fern")
            ergebnis[fassung] = {"dreiecke": int(sum(len(h[3]) for h in holz.values()) + len(laub[3]))}
        (ziel / "baum.json").write_text(json.dumps(ergebnis, indent=1))
        print("übernommen:", ziel.name, ergebnis)


for name in args:
    verarbeite(name)
