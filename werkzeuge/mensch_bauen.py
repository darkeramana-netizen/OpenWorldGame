"""Baut realistische Menschen aus dem MakeHuman-Grundkörper (CC0) für szenen/figuren/figur.gd.

Quelle: MakeHuman 1.x (https://github.com/makehumancommunity/makehuman, Ordner makehuman/data: base.obj, Ziele in
targets/macrodetails, Skelett rigs/default.mhskel mit default_weights.mhw) und die MakeHuman-Systemassets
(makehuman_system_assets_cc0.zip von files.makehumancommunity.org: Haut, Haare, Augen, Brauen, Wimpern). Alles CC0.

Ablauf:
  1. Grundkörper laden (Dezimeter, A-Haltung), Makro-Ziele wie in MakeHuman mischen (Geschlecht, Alter, Muskeln,
     Gewicht, Größe, Herkunft).
  2. Haare, Augen, Brauen und Wimpern als Proxies anpassen (.mhclo: jede Ecke hängt an drei Ecken des Körpers).
  3. Kleidung aus der Hilfsgeometrie des Grundkörpers schneiden (Strumpfhose, Rock) – Kittel, Beinlinge, Gürtel, Schuhe;
     die Haut darunter fällt weg.
  4. An das Skelett der Quaternius-Figuren binden (65 Knochen wie modelle/figuren/Superhero_Male_FullBody.gltf), damit
     die vorhandenen Animationen (modelle/figuren/animationen.glb) laufen: Die Knochen behalten Ausrichtung und
     Ruhelage (T-Haltung) der Quaternius-Figur, ihre Längen kommen vom MakeHuman-Körper. Die Bindungsmatrizen
     beschreiben die A-Haltung des Körpers; die Gewichte kommen aus dem MakeHuman-Skelett (163 Knochen, auf die 65
     Quaternius-Knochen zusammengelegt). Der Körper wird so skaliert, dass das Becken so hoch sitzt wie bei Quaternius.
  5. Als glTF nach modelle/figuren/menschen/<name>/ schreiben.

Aufruf aus dem Projektordner (braucht numpy, Pillow):
    python3 werkzeuge/mensch_bauen.py MH_DATA SYSTEM_ASSETS name [geschlecht=1 alter=25 muskeln=0.5 gewicht=0.5
                                      groesse=0.5 haut=young_caucasian_male haare=short02 augen=brown brauen=eyebrow001]
MH_DATA: Ordner makehuman/data aus dem MakeHuman-Repository, SYSTEM_ASSETS: entpacktes Systemasset-Paket.
"""
import json, sys, shutil
from pathlib import Path
import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
Q_KOERPER = REPO / "modelle" / "figuren" / "Superhero_Male_FullBody.gltf"


# ---------- MakeHuman lesen ----------

def lies_obj(datei):
    """Ecken, UV, Flächen (Liste von (Gruppe, [Ecken], [UV])) einer OBJ-Datei."""
    v, vt, f = [], [], []
    gruppe = ""
    for z in open(datei, encoding="utf-8", errors="replace"):
        t = z.split()
        if not t:
            continue
        if t[0] == "v":
            v.append([float(x) for x in t[1:4]])
        elif t[0] == "vt":
            vt.append([float(x) for x in t[1:3]])
        elif t[0] == "g":
            gruppe = t[1] if len(t) > 1 else ""
        elif t[0] == "f":
            ecken = [int(x.split("/")[0]) - 1 for x in t[1:]]
            uvs = [int(x.split("/")[1]) - 1 if "/" in x and x.split("/")[1] else -1 for x in t[1:]]
            f.append((gruppe, ecken, uvs))
    return np.array(v, np.float64), np.array(vt, np.float64), f


def lies_ziel(datei):
    idx, d = [], []
    for z in open(datei, encoding="utf-8", errors="replace"):
        if z.startswith("#") or not z.strip():
            continue
        t = z.split()
        idx.append(int(t[0])); d.append([float(x) for x in t[1:4]])
    return np.array(idx, dtype=np.int64), np.array(d, dtype=np.float64).reshape(-1, 3)


def makro_gewichte(geschlecht, alter_jahre, muskeln, gewicht):
    """Gewichte der Makro-Ziele wie in MakeHuman (apps/humanmodifier.py, MacroModifier)."""
    g = {"female": 1.0 - geschlecht, "male": geschlecht}
    if alter_jahre < 25:
        a = 0.1875 + (alter_jahre - 11) / (25 - 11) * (0.5 - 0.1875) if alter_jahre >= 11 else (alter_jahre - 1) / 10 * 0.1875
    else:
        a = 0.5 + (alter_jahre - 25) / (90 - 25) * 0.5
    a = min(max(a, 0.0), 1.0)
    if a < 0.1875:
        al = {"baby": (0.1875 - a) / 0.1875, "child": a / 0.1875}
    elif a < 0.5:
        c = (0.5 - a) / (0.5 - 0.1875)
        al = {"child": c, "young": 1.0 - c}
    else:
        al = {"young": (1.0 - a) / 0.5, "old": (a - 0.5) / 0.5}
    def drei(x, namen):
        if x < 0.5:
            return {namen[0]: (0.5 - x) * 2.0, namen[1]: 1.0 - (0.5 - x) * 2.0}
        return {namen[1]: 1.0 - (x - 0.5) * 2.0, namen[2]: (x - 0.5) * 2.0}
    mu = drei(muskeln, ("minmuscle", "averagemuscle", "maxmuscle"))
    ge = drei(gewicht, ("minweight", "averageweight", "maxweight"))
    return g, al, mu, ge


def baue_koerper(mh, geschlecht, alter, muskeln, gewicht, groesse, herkunft="caucasian"):
    v, vt, f = lies_obj(mh / "3dobjs" / "base.obj")
    g, al, mu, ge = makro_gewichte(geschlecht, alter, muskeln, gewicht)
    ziele = mh / "targets" / "macrodetails"
    neu = v.copy()
    def addiere(datei, w):
        if w <= 1e-4 or not datei.exists():
            return
        i, d = lies_ziel(datei)
        neu[i] += d * w
    for gn, gw in g.items():
        for an, aw in al.items():
            addiere(ziele / f"{herkunft}-{gn}-{an}.target", gw * aw)
            for mn, mw in mu.items():
                for wn, ww in ge.items():
                    addiere(ziele / f"universal-{gn}-{an}-{mn}-{wn}.target", gw * aw * mw * ww)
                    if groesse != 0.5:
                        hn = "maxheight" if groesse > 0.5 else "minheight"
                        addiere(ziele / "height" / f"{gn}-{an}-{mn}-{wn}-{hn}.target",
                                gw * aw * mw * ww * abs(groesse - 0.5) * 2.0)
    return neu, vt, f


def passe_proxy(mhclo, koerper):
    """Ecken eines Proxies (Haare, Augen, Brauen …) auf den Körper setzen; gibt Ecken, Bezug (3 Ecken + Gewichte),
    OBJ und Material zurück."""
    kopf = {}
    bezug = []
    in_verts = False
    for z in open(mhclo, encoding="utf-8", errors="replace"):
        t = z.split()
        if not t or z.startswith("#"):
            continue
        if t[0] == "verts":
            in_verts = True
            continue
        if in_verts:
            if len(t) == 1 and t[0].lstrip("-").isdigit():
                bezug.append(([int(t[0])] * 3, [1.0, 0.0, 0.0], [0.0, 0.0, 0.0]))
                continue
            if len(t) == 9:
                bezug.append(([int(x) for x in t[:3]], [float(x) for x in t[3:6]], [float(x) for x in t[6:9]]))
                continue
            if t[0] in ("delete_verts", "weights", "vertexboneweights_file"):   # sonst Kopfzeilen mitten im Block
                in_verts = False
        kopf.setdefault(t[0], []).append(t[1:])
    skal = []
    for k, achse in (("x_scale", 0), ("y_scale", 1), ("z_scale", 2)):
        if k in kopf:
            a, b, d = kopf[k][0]
            skal.append(abs(koerper[int(a)][achse] - koerper[int(b)][achse]) / float(d))
        else:
            skal.append(1.0)
    skal = np.array(skal)
    ecken = np.array([sum(w * koerper[i] for i, w in zip(ix, ws)) + np.array(off) * skal for ix, ws, off in bezug])
    v, vt, f = lies_obj(mhclo.parent / kopf["obj_file"][0][0])
    mat = kopf.get("material", [[None]])[0][0]
    return ecken, bezug, vt, f, (mhclo.parent / mat) if mat else None


def lies_material(datei):
    m = {}
    if datei is None or not Path(datei).exists():
        return m
    for z in open(datei, encoding="utf-8", errors="replace"):
        t = z.split(None, 1)
        if len(t) == 2 and not z.startswith("#"):
            m[t[0]] = t[1].strip()
    return m


# ---------- Quaternius-Skelett ----------

def lies_quaternius():
    g = json.loads(Q_KOERPER.read_text())
    roh = (Q_KOERPER.parent / g["buffers"][0]["uri"]).read_bytes()
    sk = g["skins"][0]
    a = g["accessors"][sk["inverseBindMatrices"]]
    bv = g["bufferViews"][a["bufferView"]]
    ibm = np.frombuffer(roh, np.float32, a["count"] * 16, bv.get("byteOffset", 0) + a.get("byteOffset", 0))
    ibm = ibm.reshape(-1, 4, 4).transpose(0, 2, 1).astype(np.float64)
    namen = [g["nodes"][j]["name"] for j in sk["joints"]]
    eltern = {}
    for j in sk["joints"]:
        for c in g["nodes"][j].get("children", []):
            eltern[g["nodes"][c]["name"]] = g["nodes"][j]["name"]
    welt = {n: np.linalg.inv(m) for n, m in zip(namen, ibm)}
    return namen, eltern, welt


# Quaternius-Knochen → MakeHuman-Gelenk (Kopf eines MH-Knochens, oder ("tail", Knochen), oder Mittel mehrerer)
def mh_ort(qname, J):
    s = "L" if qname.endswith("_l") else "R"
    basis = qname[:-2] if qname.endswith(("_l", "_r")) else qname
    finger = {"thumb": 1, "index": 2, "middle": 3, "ring": 4, "pinky": 5}
    feste = {"spine_01": "spine04", "spine_02": "spine03", "spine_03": "spine02", "neck_01": "neck01", "Head": "head",
             "clavicle": "clavicle.%s", "upperarm": "upperarm01.%s", "lowerarm": "lowerarm01.%s", "hand": "wrist.%s",
             "thigh": "upperleg01.%s", "calf": "lowerleg01.%s", "foot": "foot.%s"}
    if basis in feste:
        return J["kopf"](feste[basis] % s if "%s" in feste[basis] else feste[basis])
    if basis == "pelvis":
        return (J["kopf"]("upperleg01.L") + J["kopf"]("upperleg01.R")) / 2.0 - np.array([0, 0.03, 0])
    if basis == "root":
        p = (J["kopf"]("upperleg01.L") + J["kopf"]("upperleg01.R")) / 2.0
        return np.array([0.0, J["boden"], p[2]])
    if basis == "ball":
        return np.mean([J["kopf"](f"toe{i}-1.{s}") for i in range(1, 6)], axis=0)
    if basis == "ball_leaf":
        return np.mean([J["schwanz"](f"toe{i}-1.{s}") for i in range(1, 6)], axis=0)
    teile = basis.split("_")
    if teile[0] in finger:
        n = int(teile[1])
        fi = finger[teile[0]]
        if n <= 3:
            return J["kopf"](f"finger{fi}-{n}.{s}")
        return J["schwanz"](f"finger{fi}-3.{s}")
    raise KeyError(qname)


def mh_zu_q(mhname, mh_eltern):
    """Auf welchen Quaternius-Knochen fällt das Gewicht eines MakeHuman-Knochens?"""
    s = "_l" if mhname.endswith(".L") else "_r"
    b = mhname.split(".")[0]
    feste = {"root": "pelvis", "spine05": "pelvis", "pelvis": "pelvis", "spine04": "spine_01", "spine03": "spine_02",
             "spine02": "spine_03", "spine01": "spine_03", "breast": "spine_03", "neck01": "neck_01",
             "neck02": "neck_01", "neck03": "neck_01", "head": "Head", "clavicle": "clavicle", "shoulder01": "clavicle",
             "upperarm01": "upperarm", "upperarm02": "upperarm", "lowerarm01": "lowerarm", "lowerarm02": "lowerarm",
             "wrist": "hand", "upperleg01": "thigh", "upperleg02": "thigh", "lowerleg01": "calf", "lowerleg02": "calf",
             "foot": "foot"}
    if b in feste:
        q = feste[b]
        return q if q in ("pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head") else q + s
    if b.startswith("metacarpal"):
        return "hand" + s
    if b.startswith("finger"):
        fi, n = b[6:].split("-")
        name = {"1": "thumb", "2": "index", "3": "middle", "4": "ring", "5": "pinky"}[fi]
        return f"{name}_0{n}{s}"
    if b.startswith("toe"):
        return "ball" + s
    e = mh_eltern.get(mhname)
    return mh_zu_q(e, mh_eltern) if e else "pelvis"


def drehung_von_zu(a, b):
    a = a / np.linalg.norm(a); b = b / np.linalg.norm(b)
    v = np.cross(a, b); c = float(np.dot(a, b))
    if c < -0.9999:
        achse = np.cross(a, [1, 0, 0]) if abs(a[0]) < 0.9 else np.cross(a, [0, 1, 0])
        achse /= np.linalg.norm(achse)
        return 2 * np.outer(achse, achse) - np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx / (1.0 + c)


# Hauptkind je Knochen (für die Richtung)
def hauptkind(q, kinder):
    k = kinder.get(q, [])
    if not k:
        return None
    for bevorzugt in ("spine_01", "spine_02", "spine_03", "neck_01", "Head", "upperarm", "lowerarm", "hand", "middle_01",
                      "calf", "foot", "ball", "ball_leaf"):
        for c in k:
            if c.startswith(bevorzugt):
                return c
    return k[0]


# ---------- glTF schreiben ----------

class Gltf:
    def __init__(self):
        self.bin = bytearray(); self.views = []; self.accs = []; self.g = {"asset": {"version": "2.0",
            "generator": "sorrowland mensch_bauen.py"}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [],
            "meshes": [], "materials": [], "textures": [], "images": [], "samplers": [{"magFilter": 9729,
            "minFilter": 9987}], "skins": []}

    def acc(self, arr, komp, typ, ziel=None, minmax=False):
        while len(self.bin) % 4:
            self.bin += b"\0"
        dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[komp]
        daten = np.ascontiguousarray(arr.astype(dt)).tobytes()
        v = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(daten)}
        if ziel:
            v["target"] = ziel
        self.views.append(v); self.bin += daten
        a = {"bufferView": len(self.views) - 1, "componentType": komp, "count": int(arr.shape[0]), "type": typ}
        if minmax:
            a["min"] = arr.min(0).tolist(); a["max"] = arr.max(0).tolist()
        self.accs.append(a)
        return len(self.accs) - 1

    def textur(self, uri):
        self.g["images"].append({"uri": uri})
        self.g["textures"].append({"source": len(self.g["images"]) - 1, "sampler": 0})
        return len(self.g["textures"]) - 1

    def material(self, name, farb_uri=None, farbe=(1, 1, 1, 1), rau=0.8, alpha=None, doppelt=False, normal_uri=None):
        m = {"name": name, "pbrMetallicRoughness": {"baseColorFactor": list(farbe), "metallicFactor": 0.0,
                                                    "roughnessFactor": rau}, "doubleSided": doppelt}
        if farb_uri:
            m["pbrMetallicRoughness"]["baseColorTexture"] = {"index": self.textur(farb_uri)}
        if normal_uri:
            m["normalTexture"] = {"index": self.textur(normal_uri)}
        if alpha == "MASK":
            m["alphaMode"] = "MASK"; m["alphaCutoff"] = 0.4
        elif alpha == "BLEND":
            m["alphaMode"] = "BLEND"
        self.g["materials"].append(m)
        return len(self.g["materials"]) - 1

    def schreibe(self, datei):
        name = datei.with_suffix(".bin").name
        (datei.parent / name).write_bytes(self.bin)
        self.g["buffers"] = [{"uri": name, "byteLength": len(self.bin)}]
        self.g["bufferViews"] = self.views; self.g["accessors"] = self.accs
        datei.write_text(json.dumps(self.g))


def dreiecke(flaechen):
    out = []
    for ecken in flaechen:
        for i in range(1, len(ecken) - 1):
            out.append((ecken[0], ecken[i], ecken[i + 1]))
    return out


def normalen(pos, tri):
    n = np.zeros_like(pos)
    a, b, c = pos[tri[:, 0]], pos[tri[:, 1]], pos[tri[:, 2]]
    fn = np.cross(b - a, c - a)
    for k in range(3):
        np.add.at(n, tri[:, k], fn)
    return n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-12)


def zerlege_nach_uv(ecken_pos, uv, flaechen, gewichte_je_ecke):
    """OBJ-Flächen (Ecke + UV getrennt indiziert) in glTF-Ecken (je Paar eine) umwandeln."""
    paare = {}
    pos, tex, jw, tri = [], [], [], []
    for ecken, uvs in flaechen:
        ids = []
        for e, t in zip(ecken, uvs):
            k = (e, t)
            if k not in paare:
                paare[k] = len(pos)
                pos.append(ecken_pos[e]); tex.append(uv[t] if t >= 0 else (0.0, 0.0)); jw.append(gewichte_je_ecke[e])
            ids.append(paare[k])
        tri.extend(dreiecke([ids]))
    return np.array(pos), np.array(tex), jw, np.array(tri)


# ---------- Stoffe (Poly Haven, CC0) ----------

STOFFE = {"kittel": "cotton_jersey", "beinlinge": "poly_wool_herringbone", "leder": "brown_leather"}


def lade_stoffe(ordner):
    """Farb- und Normalkarte (1k) je Stoff; die Farbe wird entsättigt (die Figur färbt mit baseColorFactor)."""
    import urllib.request
    ordner.mkdir(parents=True, exist_ok=True)
    kopf = {"User-Agent": "sorrowland-werkzeuge/1.0"}
    for name, ph in STOFFE.items():
        if (ordner / f"{name}_farbe.jpg").exists():
            continue
        info = json.loads(urllib.request.urlopen(urllib.request.Request(f"https://api.polyhaven.com/files/{ph}", headers=kopf)).read())
        for art, ziel in (("Diffuse", "farbe"), ("nor_gl", "normal")):
            url = info[art]["1k"]["jpg"]["url"]
            daten = urllib.request.urlopen(urllib.request.Request(url, headers=kopf)).read()
            (ordner / f"{name}_{ziel}.jpg").write_bytes(daten)
        if name != "leder":   # Leder behält sein Braun
            im = Image.open(ordner / f"{name}_farbe.jpg").convert("RGB")
            a = np.asarray(im, np.float32)
            grau = a.mean(axis=2, keepdims=True)
            grau = grau / max(1.0, grau.mean()) * 170.0          # mittleres Grau, Muster bleibt
            Image.fromarray(np.clip(np.repeat(grau, 3, axis=2), 0, 255).astype(np.uint8)).save(ordner / f"{name}_farbe.jpg", quality=90)


def zerlege_kasten(pos_alle, nor_alle, flaechen, gewichte_je_ecke, kachel):
    """Flächen mit Kastenprojektion (je Fläche die Achse ihrer Normale; kachel: Wiederholungen je Meter);
    die Normalen bleiben glatt (nor_alle)."""
    paare = {}
    pos, nor, tex, jw, tri = [], [], [], [], []
    for ecken in flaechen:
        p = pos_alle[ecken]
        fn = np.cross(p[1] - p[0], p[2] - p[0])
        a = int(np.argmax(np.abs(fn)))
        ids = []
        for e in ecken:
            k = (e, a)
            if k not in paare:
                paare[k] = len(pos)
                q = pos_alle[e]
                pos.append(q); nor.append(nor_alle[e]); jw.append(gewichte_je_ecke[e])
                tex.append((q[(a + 1) % 3] * kachel, q[(a + 2) % 3] * kachel))
            ids.append(paare[k])
        tri.extend(dreiecke([ids]))
    return np.array(pos), np.array(nor), np.array(tex), jw, np.array(tri)


# ---------- Hauptteil ----------

def main():
    mh, sysa, name = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    opt = dict(a.split("=", 1) for a in sys.argv[4:])
    geschlecht = float(opt.get("geschlecht", 1.0)); alter = float(opt.get("alter", 25))
    muskeln = float(opt.get("muskeln", 0.5)); gewicht = float(opt.get("gewicht", 0.5))
    groesse = float(opt.get("groesse", 0.5))
    w = geschlecht < 0.5
    haut = opt.get("haut", "young_caucasian_female" if w else "young_caucasian_male")
    haare = opt.get("haare", "bob02" if w else "short02")
    augen = opt.get("augen", "brownlight"); brauen = opt.get("brauen", "eyebrow001")
    ziel = REPO / "modelle" / "figuren" / "menschen" / name
    ziel.mkdir(parents=True, exist_ok=True)

    v, vt, flaechen = baue_koerper(mh, geschlecht, alter, muskeln, gewicht, groesse)
    # Skelett und Gewichte von MakeHuman
    skel = json.loads((mh / "rigs" / "default.mhskel").read_text())
    mh_eltern = {b: d["parent"] for b, d in skel["bones"].items() if d["parent"]}
    gelenk = lambda n: v[skel["joints"][n]].mean(0)
    koerper_ids = sorted({e for g, ecken, _ in flaechen if g == "body" for e in ecken})
    boden = v[koerper_ids, 1].min()
    J = {"kopf": lambda b: gelenk(skel["bones"][b]["head"]), "schwanz": lambda b: gelenk(skel["bones"][b]["tail"]),
         "boden": boden}
    gw = json.loads((mh / "rigs" / "default_weights.mhw").read_text())["weights"]

    qnamen, qeltern, qwelt = lies_quaternius()
    qidx = {n: i for i, n in enumerate(qnamen)}
    # Maßstab: das Becken so hoch wie bei Quaternius (die Animationen setzen die Beckenhöhe)
    mh_becken = mh_ort("pelvis", J)
    s = (qwelt["pelvis"][1, 3] - qwelt["root"][1, 3]) / (mh_becken[1] - boden)
    verschiebe = np.array([0.0, -boden, 0.0])
    um = lambda p: (np.asarray(p) + verschiebe) * s
    V = um(v)
    MHP = {q: um(mh_ort(q, J)) for q in qnamen}

    # Gewichte je Körperecke auf die Quaternius-Knochen zusammenlegen
    je_ecke = [dict() for _ in range(len(v))]
    for b, liste in gw.items():
        q = mh_zu_q(b, mh_eltern)
        for i, wt in liste:
            je_ecke[i][q] = je_ecke[i].get(q, 0.0) + wt
    def vier(d):
        p = sorted(d.items(), key=lambda kv: -kv[1])[:4]
        sm = sum(x for _, x in p) or 1.0
        j = [qidx[k] for k, _ in p] + [0] * (4 - len(p))
        ww = [x / sm for _, x in p] + [0.0] * (4 - len(p))
        return j, ww
    ecken_jw = [vier(d) if d else ([qidx["pelvis"], 0, 0, 0], [1.0, 0, 0, 0]) for d in je_ecke]

    # Knochen: Ruhelage wie Quaternius (T-Haltung), Längen vom MakeHuman-Körper; Bindung in der A-Haltung
    kinder = {}
    for n in qnamen:
        if n in qeltern:
            kinder.setdefault(qeltern[n], []).append(n)
    R = {n: qwelt[n][:3, :3] / np.linalg.norm(qwelt[n][:3, :3], axis=0) for n in qnamen}
    QP = {n: qwelt[n][:3, 3] for n in qnamen}
    pos_t = {}
    for n in qnamen:
        e = qeltern.get(n)
        if e is None:
            pos_t[n] = QP[n].copy()
            continue
        dq = QP[n] - QP[e]
        lq = np.linalg.norm(dq)
        lm = np.linalg.norm(MHP[n] - MHP[e])
        pos_t[n] = pos_t[e] + (dq * (lm / lq) if lq > 1e-5 and n not in ("pelvis",) else dq)
    korrektur = {}
    for n in qnamen:
        k = hauptkind(n, kinder)
        if n == "root":
            korrektur[n] = np.eye(3)
        elif k is None:
            korrektur[n] = korrektur[qeltern[n]]
        else:
            korrektur[n] = drehung_von_zu(QP[k] - QP[n], MHP[k] - MHP[n])
    for n in qnamen:   # Blätter erst nach den Eltern
        if hauptkind(n, kinder) is None and n != "root":
            korrektur[n] = korrektur[qeltern[n]]

    gl = Gltf()
    knoten_von = {}
    gl.g["nodes"].append({"name": "Armature", "children": []})
    def welt_t(n):
        m = np.eye(4); m[:3, :3] = R[n]; m[:3, 3] = pos_t[n]; return m
    for n in qnamen:
        e = qeltern.get(n)
        lokal = np.linalg.inv(welt_t(e)) @ welt_t(n) if e else welt_t(n)
        rq = lokal[:3, :3]
        # Drehung als Quaternion (x, y, z, w)
        tr = np.trace(rq)
        if tr > 0:
            sq = np.sqrt(tr + 1.0) * 2; qw = 0.25 * sq
            qx = (rq[2, 1] - rq[1, 2]) / sq; qy = (rq[0, 2] - rq[2, 0]) / sq; qz = (rq[1, 0] - rq[0, 1]) / sq
        else:
            i = int(np.argmax(np.diag(rq)))
            j_, k_ = (i + 1) % 3, (i + 2) % 3
            sq = np.sqrt(1.0 + rq[i, i] - rq[j_, j_] - rq[k_, k_]) * 2
            qq = [0.0, 0.0, 0.0]
            qq[i] = 0.25 * sq; qq[j_] = (rq[j_, i] + rq[i, j_]) / sq; qq[k_] = (rq[k_, i] + rq[i, k_]) / sq
            qw = (rq[k_, j_] - rq[j_, k_]) / sq
            qx, qy, qz = qq
        gl.g["nodes"].append({"name": n, "translation": lokal[:3, 3].tolist(), "rotation": [qx, qy, qz, qw]})
        knoten_von[n] = len(gl.g["nodes"]) - 1
    for n in qnamen:
        e = qeltern.get(n)
        if e:
            gl.g["nodes"][knoten_von[e]].setdefault("children", []).append(knoten_von[n])
        else:
            gl.g["nodes"][0]["children"].append(knoten_von[n])
    ibm = []
    for n in qnamen:
        b = np.eye(4); b[:3, :3] = korrektur[n] @ R[n]; b[:3, 3] = MHP[n]
        ibm.append(np.linalg.inv(b).T.reshape(-1))
    gl.g["skins"].append({"joints": [knoten_von[n] for n in qnamen], "skeleton": knoten_von["root"],
                          "inverseBindMatrices": gl.acc(np.array(ibm), 5126, "MAT4")})

    def teil(teilname, pos, tex, jw, tri, mat, nor=None):
        if nor is None:
            nor = normalen(pos, tri)
        j = np.array([x[0] for x in jw]); wt = np.array([x[1] for x in jw])
        prim = {"attributes": {"POSITION": gl.acc(pos, 5126, "VEC3", 34962, True), "NORMAL": gl.acc(nor, 5126, "VEC3", 34962),
                               "TEXCOORD_0": gl.acc(np.column_stack([tex[:, 0], 1.0 - tex[:, 1]]), 5126, "VEC2", 34962),
                               "JOINTS_0": gl.acc(j, 5123, "VEC4", 34962), "WEIGHTS_0": gl.acc(wt, 5126, "VEC4", 34962)},
                "indices": gl.acc(tri.reshape(-1), 5125, "SCALAR", 34963), "material": mat}
        gl.g["meshes"].append({"name": teilname, "primitives": [prim]})
        gl.g["nodes"].append({"name": teilname, "mesh": len(gl.g["meshes"]) - 1, "skin": 0})
        gl.g["nodes"][0]["children"].append(len(gl.g["nodes"]) - 1)

    def bild(quelle, zielname, groesse=1024):
        im = Image.open(quelle)
        if max(im.size) > groesse:
            im = im.resize((groesse, groesse), Image.LANCZOS)
        if zielname.endswith(".jpg"):
            im.convert("RGB").save(ziel / zielname, quality=90)
        else:
            im.save(ziel / zielname, optimize=True)
        return zielname

    # Haut
    hm = lies_material(sysa / "skins" / haut / f"{haut}.mhmat")
    haut_bild = bild(sysa / "skins" / haut / hm["diffuseTexture"], "haut.jpg")
    m_haut = gl.material("Haut", haut_bild, rau=0.62)
    koerper_fl = [(e, t) for g_, e, t in flaechen if g_ == "body"]

    # Kleidung aus der Hilfsgeometrie: Kittel (Rumpf, Arme, Rock bis zum Knie), Beinlinge, Gürtel, Schuhe
    kleidung = opt.get("kleidung", "kittel")
    if kleidung != "keine":
        from scipy.spatial import cKDTree
        stoffe = REPO / "modelle" / "figuren" / "menschen" / "stoffe"
        lade_stoffe(stoffe)
        rel = lambda n: f"../stoffe/{n}"
        farbe_kittel = [float(x) for x in opt.get("kittelfarbe", "0.42,0.34,0.24").split(",")] + [1.0]
        farbe_bein = [float(x) for x in opt.get("beinfarbe", "0.2,0.18,0.16").split(",")] + [1.0]
        m_kittel = gl.material("Kittel", rel("kittel_farbe.jpg"), farbe_kittel, rau=0.95, normal_uri=rel("kittel_normal.jpg"))
        m_bein = gl.material("Beinlinge", rel("beinlinge_farbe.jpg"), farbe_bein, rau=0.95, normal_uri=rel("beinlinge_normal.jpg"))
        m_leder = gl.material("Leder", rel("leder_farbe.jpg"), (0.75, 0.62, 0.5, 1.0), rau=0.7, normal_uri=rel("leder_normal.jpg"))
        haupt = lambda i: qnamen[ecken_jw[i][0][0]]                 # Knochen mit dem größten Gewicht
        hand = lambda i: sum(ww for jj, ww in zip(*ecken_jw[i]) if qnamen[jj].startswith(("hand", "thumb", "index",
                                                                                          "middle", "ring", "pinky")))
        oben_k = ("spine", "clavicle", "upperarm", "lowerarm")
        unten_k = ("thigh", "calf", "foot", "ball")
        taille = MHP["spine_01"][1]
        hals = MHP["neck_01"][1] - 0.035          # Halsausschnitt auf fester Höhe
        rock_lang = 0.5 if kleidung == "kittel" else 0.1     # Kittel bis zum Knie, Kleid bis zum Knöchel
        def ist_oben_roh(i):
            h = haupt(i)
            return (h.startswith(oben_k + ("neck",)) or (h == "pelvis" and V[i][1] > taille - 0.13)) and hand(i) < 0.25
        def ist_oben(i):
            return ist_oben_roh(i) and V[i][1] < hals
        def ist_unten(i):
            h = haupt(i)
            # unter dem Rock keine Beinlinge (sie schimmerten beim Gehen durch), nur ein Stück über dem Saum
            return (h.startswith(("thigh", "calf")) or (h == "pelvis" and V[i][1] <= taille + 0.02)) and \
                not ist_schuh(i) and V[i][1] < rock_lang + 0.1
        def ist_schuh(i):
            h = haupt(i)
            return h.startswith(("foot", "ball")) or (h.startswith("calf") and V[i][1] < 0.12)
        hose_fl = [(e, t) for g_, e, t in flaechen if g_ == "helper-tights"]
        rock_fl = [(e, t) for g_, e, t in flaechen if g_ == "helper-skirt"]
        def stueck(fl, wahl, abstand, mat, teilname, uv_mal, deckel=None, band=None):
            sel = [(e, t) for e, t in fl if all(wahl(i) for i in e)]
            if deckel is not None:   # Flächen bis knapp über die Kante, die Ecken darüber auf die Kante ziehen (glatter Saum)
                sel = [(e, t) for e, t in sel if min(V[i][1] for i in e) < deckel]
            if band is not None:     # Ring: alle Flächen, die das Band schneiden, in der Höhe auf das Band drücken
                sel = [(e, t) for e, t in sel if min(V[i][1] for i in e) < band[1] and max(V[i][1] for i in e) > band[0]]
            if not sel:
                return set()
            ecken_ids = sorted({i for e, _ in sel for i in e})
            tri_g = np.array(dreiecke([e for e, _ in sel]))
            n_g = normalen(V, tri_g)          # glatt über die gemeinsamen Ecken
            verschoben = V.copy()
            verschoben[ecken_ids] += n_g[ecken_ids] * abstand
            if deckel is not None:
                verschoben[ecken_ids, 1] = np.minimum(verschoben[ecken_ids, 1], deckel)
            if band is not None:
                verschoben[ecken_ids, 1] = np.clip(verschoben[ecken_ids, 1], band[0], band[1])
            pos, nor, tex, jw, tri = zerlege_kasten(verschoben, n_g, [e for e, _ in sel], ecken_jw, uv_mal)
            teil(teilname, pos, tex, jw, tri, mat, nor)
            return set(ecken_ids)
        oben_ids = stueck(hose_fl, ist_oben_roh, 0.011, m_kittel, "Kittel", 3.0, deckel=hals)
        oben_ids = {i for i in oben_ids if V[i][1] < hals}
        stueck(rock_fl, lambda i: rock_lang <= V[i][1] <= taille - 0.035, 0.006, m_kittel, "Kittelrock", 3.0)
        unten_ids = stueck(hose_fl, ist_unten, 0.003, m_bein, "Beinlinge", 3.0) if kleidung == "kittel" else set()
        arm = lambda i: haupt(i).startswith(("upperarm", "lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky"))
        stueck(hose_fl, lambda i: not arm(i) and abs(V[i][1] - taille) < 0.15, 0.03, m_leder, "Guertel", 4.0,
               band=(taille - 0.025, taille + 0.025))
        schuh_ids = [i for i in koerper_ids if ist_schuh(i)]
        schuh_fl = [(e, t) for g_, e, t in flaechen if g_ == "body" and all(ist_schuh(i) for i in e)]
        if schuh_fl:
            ids_s = sorted({i for e, _ in schuh_fl for i in e})
            tri_s = np.array(dreiecke([e for e, _ in schuh_fl]))
            n_s = normalen(V, tri_s)
            vs = V.copy(); vs[ids_s] += n_s[ids_s] * 0.012
            pos, nor, tex, jw, tri = zerlege_kasten(vs, n_s, [e for e, _ in schuh_fl], ecken_jw, 4.0)
            teil("Schuhe", pos, tex, jw, tri, m_leder, nor)
        # Haut unter der Kleidung weglassen: Ecken nahe an benutztem Stoff
        bedeckt_von = np.array(sorted(oben_ids | unten_ids)) if (oben_ids | unten_ids) else np.zeros(0, int)
        bedeckt = set(schuh_ids)
        if len(bedeckt_von):
            # nur Haut, die selbst zum Kleiderbereich gehört und Stoff dicht über sich hat (sonst Löcher am Saum)
            baum = cKDTree(V[bedeckt_von])
            d, _ = baum.query(V[koerper_ids])
            unter = lambda i: (ist_oben(i) and hand(i) < 0.12 and V[i][1] < hals - 0.02) or \
                (kleidung == "kittel" and ist_unten(i))
            bedeckt |= {i for i, dd in zip(koerper_ids, d) if dd < 0.025 and unter(i)}
        # unter dem Rock die Beine (beim Kleid bis zum Knöchel)
        bedeckt |= {i for i in koerper_ids if (haupt(i).startswith(("thigh", "calf")) or
                                               (haupt(i) == "pelvis" and V[i][1] < taille)) and V[i][1] > rock_lang + 0.06}
        koerper_fl = [(e, t) for e, t in koerper_fl if not all(i in bedeckt for i in e)]
    pos, tex, jw, tri = zerlege_nach_uv(V, vt, koerper_fl, ecken_jw)
    teil("Koerper", pos, tex, jw, tri, m_haut)
    # Proxies: Augen, Brauen, Wimpern, Haare (jede Ecke erbt die Gewichte ihrer drei Bezugsecken)
    def proxy(datei, teilname, mat):
        if not datei.exists():
            print("fehlt:", datei); return
        pe, bezug, pvt, pf, _ = passe_proxy(datei, v)
        pjw = []
        for ix, ws, _ in bezug:
            d = {}
            for i, wv in zip(ix, ws):
                for jj, ww in zip(*ecken_jw[i]):
                    if ww > 0:
                        d[jj] = d.get(jj, 0.0) + ww * abs(wv)
            p = sorted(d.items(), key=lambda kv: -kv[1])[:4]
            sm = sum(x for _, x in p) or 1.0
            pjw.append(([k for k, _ in p] + [0] * (4 - len(p)), [x / sm for _, x in p] + [0.0] * (4 - len(p))))
        pos, tex, jw, tri = zerlege_nach_uv(um(pe), pvt, [(e, t) for _, e, t in pf], pjw)
        teil(teilname, pos, tex, jw, tri, mat)

    am = lies_material(sysa / "eyes" / "materials" / f"{augen}.mhmat")
    m_augen = gl.material("Augen", bild(sysa / "eyes" / "materials" / am["diffuseTexture"], "augen.png", 512), rau=0.15)
    proxy(sysa / "eyes" / "low-poly" / "low-poly.mhclo", "Augen", m_augen)
    bm = lies_material(sysa / "eyebrows" / brauen / f"{brauen}.mhmat")
    m_brauen = gl.material("Brauen", bild(sysa / "eyebrows" / brauen / bm["diffuseTexture"], "brauen.png", 512),
                           alpha="MASK", doppelt=True, rau=0.9)
    proxy(sysa / "eyebrows" / brauen / f"{brauen}.mhclo", "Brauen", m_brauen)
    wm = lies_material(sysa / "eyelashes" / "eyelashes01" / "eyelashes01.mhmat")
    m_wimpern = gl.material("Wimpern", bild(sysa / "eyelashes" / "eyelashes01" / wm["diffuseTexture"], "wimpern.png", 256),
                            alpha="MASK", doppelt=True, rau=0.9)
    proxy(sysa / "eyelashes" / "eyelashes01" / "eyelashes01.mhclo", "Wimpern", m_wimpern)
    if haare != "keine":
        hm2 = lies_material(sysa / "hair" / haare / f"{haare}.mhmat")
        m_haare = gl.material("Haare", bild(sysa / "hair" / haare / hm2["diffuseTexture"], "haare.png", 1024),
                              alpha="MASK", doppelt=True, rau=0.75)
        proxy(sysa / "hair" / haare / f"{haare}.mhclo", "Haare", m_haare)

    gl.schreibe(ziel / f"{name}.gltf")
    info = {"quelle": "MakeHuman 1.x (CC0)", "geschlecht": geschlecht, "alter": alter, "muskeln": muskeln,
            "gewicht": gewicht, "groesse": groesse, "haut": haut, "haare": haare, "massstab": round(float(s), 4),
            "hoehe_m": round(float((v[koerper_ids, 1].max() - boden) * s), 3)}
    (ziel / "mensch.json").write_text(json.dumps(info, indent=1))
    print("gebaut:", name, info)


if __name__ == "__main__":
    main()
