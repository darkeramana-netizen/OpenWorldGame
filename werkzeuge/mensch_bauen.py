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
try:
    import meshoptimizer as mo
except ImportError:
    mo = None

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


def quaternion(rq):
    tr = np.trace(rq)
    if tr > 0:
        sq = np.sqrt(tr + 1.0) * 2
        return [(rq[2, 1] - rq[1, 2]) / sq, (rq[0, 2] - rq[2, 0]) / sq, (rq[1, 0] - rq[0, 1]) / sq, 0.25 * sq]
    i = int(np.argmax(np.diag(rq)))
    j_, k_ = (i + 1) % 3, (i + 2) % 3
    sq = np.sqrt(1.0 + rq[i, i] - rq[j_, j_] - rq[k_, k_]) * 2
    qq = [0.0, 0.0, 0.0]
    qq[i] = 0.25 * sq; qq[j_] = (rq[j_, i] + rq[i, j_]) / sq; qq[k_] = (rq[k_, i] + rq[i, k_]) / sq
    return qq + [(rq[k_, j_] - rq[j_, k_]) / sq]


def rock_ketten(V, rock_ids, mitte, oben, unten, ketten=12, glieder=4):
    """Knochenketten für einen Rock (Federknochen, SpringBoneSimulator3D in figur.gd): ketten Ketten rund um die
    Hüfte, je glieder Gelenke von der Taille (oben) bis zum Saum (unten), auf der Rockfläche. Gibt die Gelenkorte
    [kette][glied] zurück."""
    p = V[rock_ids]
    winkel = np.arctan2(p[:, 0] - mitte[0], p[:, 2] - mitte[2])
    orte = []
    for c in range(ketten):
        w = -np.pi + (c + 0.5) * 2 * np.pi / ketten
        dw = np.abs((winkel - w + np.pi) % (2 * np.pi) - np.pi)
        kette = []
        for k in range(glieder):
            y = oben + (unten - oben) * k / (glieder - 1)
            sel = (dw < np.pi / ketten * 1.5) & (np.abs(p[:, 1] - y) < 0.06)
            if sel.sum() == 0:
                sel = dw < np.pi / ketten * 1.5
            rr = np.median(np.hypot(p[sel, 0] - mitte[0], p[sel, 2] - mitte[2]))
            kette.append(np.array([mitte[0] + np.sin(w) * rr, y, mitte[2] + np.cos(w) * rr]))
        orte.append(kette)
    return orte


def verschleiss(pos, nor, art, zufall):
    """Gebrauchsspuren als Eckfarbe (multipliziert die Stofffarbe): Schmutz am Saum und an den Knien, fleckige
    Stellen, an Schultern ausgeblichen; Leder: hellere Scheuerstellen. art: "stoff", "leder"."""
    rng = np.random.default_rng(zufall.randint(0, 1 << 30))
    def wellen(freq, n=6):
        w = np.zeros(len(pos))
        for _ in range(n):
            d = rng.normal(size=3); d /= np.linalg.norm(d)
            w += np.sin(pos @ d * freq * rng.uniform(0.7, 1.3) + rng.uniform(0, 6.3))
        return w / n
    y = pos[:, 1]
    hell = np.ones(len(pos))
    if art == "leder":
        hell *= 1.0 + 0.18 * np.clip(wellen(14.0) * 2.0 - 0.6, 0, 1)        # abgescheuert
        hell *= 1.0 + 0.12 * np.clip((0.06 - y) / 0.06, 0, 1)                  # Staub an den Sohlen
        farbe = np.stack([hell, hell * 0.97, hell * 0.93], axis=1)
        return np.clip(np.column_stack([farbe, np.ones(len(pos))]), 0, 2)
    saum = np.clip((0.4 - y) / 0.35, 0, 1) ** 1.5                              # Straßenstaub und Dreck unten
    flecken = np.clip(wellen(9.0) * 2.2 - 1.0, 0, 1) * zufall.uniform(0.3, 0.8)
    knie = np.clip(1.0 - np.abs(y - 0.5) / 0.08, 0, 1) * (nor[:, 2] > 0.3)
    sonne = np.clip(nor[:, 1], 0, 1) * np.clip((y - 1.2) / 0.2, 0, 1)        # Schultern und Rücken oben
    fleckig = 1.0 + 0.06 * wellen(4.0)                                           # ungleichmäßig gefärbt
    dunkel = (1.0 - 0.38 * saum * zufall.uniform(0.6, 1.0)) * (1.0 - 0.22 * flecken) * (1.0 - 0.15 * knie)
    r_ = dunkel * fleckig * (1.0 + 0.12 * sonne)
    farbe = np.stack([r_ * (1.0 - 0.03 * saum), r_ * (1.0 - 0.06 * saum), r_ * (1.0 - 0.1 * saum)], axis=1)
    return np.clip(np.column_stack([farbe, np.ones(len(pos))]), 0, 2)


def bahn_flaeche(oberflaeche, mitte_z, seite, y_oben, y_unten, b_oben, b_unten, haengt_ab, spalten, zeilen,
                 abstand, falten):
    """Gitter einer Stoffbahn vor (seite 1) oder hinter (seite -1) dem Körper: oberhalb von haengt_ab liegt sie am
    Körper an, darunter hängt sie lotrecht vom Gürtel; leichte Falten. Gibt Ecken [zeilen, spalten, 3]."""
    from scipy.spatial import cKDTree
    s_ = oberflaeche[(oberflaeche[:, 2] - mitte_z) * seite > 0]
    baum = cKDTree(s_[:, :2])
    g = np.zeros((zeilen, spalten, 3))
    for zi in range(zeilen):
        y = y_oben + (y_unten - y_oben) * zi / (zeilen - 1)
        b = b_oben + (b_unten - b_oben) * zi / (zeilen - 1)
        for si in range(spalten):
            x = -b / 2 + b * si / (spalten - 1)
            idx = baum.query_ball_point([x, y], 0.05)
            if not idx:
                idx = [baum.query([x, y])[1]]
            zs = s_[idx, 2]
            z = (zs.max() if seite > 0 else zs.min()) + seite * abstand
            g[zi, si] = (x, y, z)
    # unterhalb des Gürtels lotrecht: nie näher am Körper als am Gürtel
    guertel_zeile = min(range(zeilen), key=lambda zi: abs(g[zi, 0, 1] - haengt_ab))
    for zi in range(guertel_zeile + 1, zeilen):
        t = (haengt_ab - g[zi, 0, 1]) / max(haengt_ab - y_unten, 0.05)
        g[zi, :, 2] = seite * np.maximum(seite * g[zi, :, 2], seite * g[guertel_zeile, :, 2]) + \
            seite * falten * t * np.sin(g[zi, :, 0] / 0.09 * 2 * np.pi)
    return g, guertel_zeile


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


# ---------- Haut: Vielfalt, Poren, Glanz ----------

def uv_maske(groesse, flaechen, vt, wert_je_ecke, unschaerfe):
    """Malt einen Wert je Körperecke in die UV-Karte (je Dreieck der Mittelwert) und weicht ihn auf."""
    from PIL import ImageDraw, ImageFilter
    klein = groesse // 4
    im = Image.new("L", (klein, klein), 0)
    zeichner = ImageDraw.Draw(im)
    for ecken, uvs in flaechen:
        w = float(np.mean([wert_je_ecke[e] for e in ecken]))
        if w <= 0.002:
            continue
        punkte = [(vt[t][0] * klein, (1.0 - vt[t][1]) * klein) for t in uvs if t >= 0]
        if len(punkte) >= 3:
            zeichner.polygon(punkte, fill=int(min(w, 1.0) * 255))
    im = im.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(unschaerfe))
    return np.asarray(im.resize((groesse, groesse), Image.BILINEAR), np.float32) / 255.0


def bearbeite_haut(farbe_bild, ziel, flaechen, vt, V, kopf, maenner, zufall, opt):
    """Aus der MakeHuman-Haut eine eigene je Figur: Bräune an Gesicht, Hals und Händen, Röte an Nase, Wangen und
    Ohren, Bartschatten, Sommersprossen oder Flecken, Schmutz an den Händen; dazu Normalkarte (Poren, Falten aus der
    Farbe und feinem Rauschen) und Rauheit (Stirn, Nase, Lippen glänzen). Schreibt haut.jpg, haut_normal.png,
    haut_rau.png."""
    from PIL import ImageFilter
    g = 1024
    a = np.asarray(Image.open(farbe_bild).convert("RGB").resize((g, g), Image.LANCZOS), np.float32) / 255.0
    hx, hy, hz = kopf
    n = len(V)
    vorn = np.clip((V[:, 2] - hz - 0.02) / 0.06, 0, 1)                       # Gesichtsseite des Kopfes
    am_kopf = (V[:, 1] > hy - 0.03).astype(np.float32)
    gesicht = am_kopf * vorn
    hals = ((V[:, 1] > hy - 0.16) & (V[:, 1] <= hy - 0.03)).astype(np.float32)
    haende = np.zeros(n, np.float32)
    ids_arm = {i for ecken, _ in flaechen for i in ecken}
    # Hände: weit außen und unterhalb der Hüfte in der A-Haltung
    haende[(np.abs(V[:, 0]) > 0.33) & (V[:, 1] < 1.05)] = 1.0
    unterarm = ((np.abs(V[:, 0]) > 0.25) & (V[:, 1] < 1.2)).astype(np.float32)
    # Gesichtspunkte aus der Form: die Nasenspitze ist der vorderste Punkt in der Mitte des Kopfes
    mittig = (np.abs(V[:, 0] - hx) < 0.015) & (V[:, 1] > hy) & (V[:, 1] < hy + 0.3)
    nase_y = float(V[mittig][np.argmax(V[mittig][:, 2]), 1])
    mund_y = nase_y - 0.035
    kinn_y = nase_y - 0.075
    # Kopf: vom Kinn (mit dem Bereich unter dem Kinn) aufwärts; das Kopfgelenk sitzt bei MakeHuman auf Nasenhöhe
    am_kopf = (V[:, 1] > kinn_y - 0.05).astype(np.float32)
    gesicht = am_kopf * vorn
    nase = gesicht * np.clip(1.0 - np.hypot(V[:, 0] - hx, (V[:, 1] - (nase_y + 0.005)) * 0.8) / 0.03, 0, 1)
    wangen = gesicht * np.clip(1.0 - np.abs(np.abs(V[:, 0] - hx) - 0.045) / 0.025, 0, 1) * \
        np.clip(1.0 - np.abs(V[:, 1] - (nase_y - 0.012)) / 0.03, 0, 1)
    ohren = am_kopf * np.clip((np.abs(V[:, 0] - hx) - 0.065) / 0.01, 0, 1) * np.clip(1 - np.abs(V[:, 1] - nase_y) / 0.04, 0, 1)
    # Bart: Kinn, Kieferlinie bis zu den Ohren, unter dem Kinn; oben bis knapp unter die Wangenknochen
    seitlich = np.clip(1.0 - (np.abs(V[:, 0] - hx) - 0.055) / 0.02, 0, 1)
    bart = am_kopf * np.clip((V[:, 2] - hz + 0.02) / 0.04, 0, 1) * seitlich * \
        np.clip(((nase_y - 0.03) - V[:, 1]) / 0.015, 0, 1) * np.clip((V[:, 1] - (kinn_y - 0.035)) / 0.015, 0, 1)
    am_kopf_ = am_kopf
    oberlippe = gesicht * np.clip(1.0 - np.abs(V[:, 1] - (mund_y + 0.014)) / 0.007, 0, 1) * \
        np.clip(1.0 - np.abs(V[:, 0] - hx) / 0.03, 0, 1)
    lippen = gesicht * np.clip(1.0 - np.abs(V[:, 1] - mund_y) / 0.007, 0, 1) * np.clip(1.0 - np.abs(V[:, 0] - hx) / 0.026, 0, 1)
    stirn = gesicht * np.clip((V[:, 1] - (nase_y + 0.05)) / 0.03, 0, 1) * np.clip(1.0 - np.abs(V[:, 0] - hx) / 0.06, 0, 1)
    m = lambda w, b: uv_maske(g, flaechen, vt, w, b)
    M_sonne = m(np.maximum.reduce([gesicht, hals * 0.8, haende, unterarm * 0.5]), 6)
    M_rot = m(np.maximum.reduce([nase, wangen * 0.8, ohren]), 5)
    bart = np.maximum(bart, oberlippe) * (1.0 - np.clip(lippen * 2.5, 0, 1))      # die Lippen bleiben frei
    M_bart = m(bart, 3)
    M_haende = m(haende, 4)
    M_glanz = m(np.maximum.reduce([nase, stirn, lippen]), 4)
    M_lippen = m(lippen, 2)
    M_gesicht = m(gesicht, 4)

    braeune = float(opt.get("braeune", zufall.uniform(0.1, 0.6)))
    roete = float(opt.get("roete", zufall.uniform(0.1, 0.55)))
    bartschatten = float(opt.get("bart", zufall.uniform(0.3, 0.9) if maenner else 0.0))
    sprossen = float(opt.get("sommersprossen", zufall.choice([0.0, 0.0, 0.0, 0.5, 0.9])))
    schmutz = float(opt.get("schmutz", zufall.uniform(0.0, 0.6)))
    ton = np.array([float(x) for x in opt.get("hautton", "%.3f,%.3f,%.3f" % tuple(
        np.array([1.0, 1.0, 1.0]) + zufall.uniform(-0.06, 0.04) + np.array([0.0, zufall.uniform(-0.03, 0.01), zufall.uniform(-0.05, 0.0)]))).split(",")])

    rng = np.random.default_rng(zufall.randint(0, 1 << 30))
    def rauschen(skala, glatt):
        z = rng.random((g // skala + 2, g // skala + 2)).astype(np.float32)
        im = Image.fromarray((z * 255).astype(np.uint8)).resize((g, g), Image.BICUBIC)
        if glatt:
            im = im.filter(ImageFilter.GaussianBlur(glatt))
        return np.asarray(im, np.float32) / 255.0
    fleckig = rauschen(24, 6)                                           # ungleichmäßige Bräune
    a = a * ton
    sonne = M_sonne[..., None] * braeune * (0.75 + 0.5 * fleckig[..., None])
    a = a * (1.0 - sonne) + a * np.array([0.9, 0.8, 0.72]) * sonne       # gebräunt: etwas dunkler, wärmer
    rot = M_rot[..., None] * roete
    a = a * (1.0 - rot * 0.5) + np.array([0.75, 0.32, 0.28]) * a.mean(axis=2, keepdims=True) * 1.6 * rot * 0.5
    if bartschatten > 0:
        stoppeln = rauschen(1, 0) > (0.55 - 0.25 * bartschatten)
        b = M_bart[..., None] * bartschatten * (0.55 + 0.45 * stoppeln[..., None])
        a = a * (1.0 - b * 0.4) + np.array([0.2, 0.19, 0.19]) * b * 0.4
    if sprossen > 0:
        punkte = (rauschen(3, 0) > 0.86).astype(np.float32)
        punkte = np.asarray(Image.fromarray((punkte * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255
        f = (np.maximum(M_gesicht, M_sonne * 0.5) * punkte * sprossen)[..., None]
        a = a * (1.0 - f * 0.45) + a * np.array([0.7, 0.48, 0.32]) * f * 0.45
    if schmutz > 0:
        dreck = M_haende[..., None] * schmutz * (0.5 + 0.5 * rauschen(16, 3)[..., None])
        a = a * (1.0 - dreck * 0.5) + np.array([0.22, 0.18, 0.13]) * dreck * 0.5
    a = a * (1.0 + (M_lippen[..., None] * np.array([0.08, -0.05, -0.03])))
    # feine Unregelmäßigkeit überall (Haut ist nie gleichmäßig)
    a = a * (0.96 + 0.08 * rauschen(6, 1.5)[..., None])
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(ziel / "haut.jpg", quality=92)

    # Normalkarte: Hochpass der Helligkeit (Falten, Poren der Vorlage) plus feine Poren
    hell = a.mean(axis=2)
    weich = np.asarray(Image.fromarray((hell * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5)), np.float32) / 255
    # Falten der Vorlage schwach, Poren fein (ein Bildpunkt sind etwa 2 mm im Gesicht)
    hoehe = (hell - weich) * 0.6 + (rauschen(1, 0.4) - 0.5) * 0.05
    dx = np.roll(hoehe, -1, 1) - np.roll(hoehe, 1, 1)
    dy = np.roll(hoehe, -1, 0) - np.roll(hoehe, 1, 0)
    staerke = 1.0
    nrm = np.stack([-dx * staerke, dy * staerke, np.ones_like(dx)], axis=2)
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8)).save(ziel / "haut_normal.png", optimize=True)
    # Rauheit (glTF: G-Kanal), Metall 0
    rau = 0.62 - 0.2 * M_glanz - 0.12 * M_lippen + 0.06 * (rauschen(4, 1) - 0.5) + 0.1 * (M_haende * schmutz)
    mr = np.zeros((g, g, 3), np.float32); mr[..., 1] = np.clip(rau, 0.25, 0.9)
    Image.fromarray((mr * 255).astype(np.uint8)).save(ziel / "haut_rau.png", optimize=True)
    return {"braeune": round(braeune, 2), "roete": round(roete, 2), "bart": round(bartschatten, 2),
            "sommersprossen": sprossen, "schmutz": round(schmutz, 2)}, {"bart": bart}


# ---------- Selbst gezeichnete Texturen: Barthaar, Kettengeflecht ----------

def zeichne_barthaar(datei, zufall):
    """Kachel aus vielen kurzen, leicht gebogenen Haaren (weiß, die Figur färbt), Alpha zwischen den Haaren."""
    from PIL import ImageDraw, ImageFilter
    g = 512
    im = Image.new("RGBA", (g, g), (255, 255, 255, 0))
    z = ImageDraw.Draw(im)
    for _ in range(9000):
        x, y = zufall.uniform(0, g), zufall.uniform(0, g)
        laenge = zufall.uniform(10, 34)
        w = zufall.gauss(1.57, 0.35)             # meist nach unten
        hell = int(zufall.uniform(150, 255))
        punkte = []
        for k in range(5):
            t = k / 4
            punkte.append((x + np.cos(w + 0.3 * t * zufall.uniform(-1, 1)) * laenge * t, y + np.sin(w) * laenge * t))
        for dx in (-g, 0, g):                    # kachelbar
            for dy in (-g, 0, g):
                z.line([(px + dx, py + dy) for px, py in punkte], fill=(hell, hell, hell, int(zufall.uniform(150, 255))),
                       width=2)
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(datei, optimize=True)


def zeichne_kettengeflecht(farbe_datei, normal_datei):
    """Kachel aus versetzten Ringen (8 x 8): Farbe mit Lücken (Alpha), Normalkarte aus der Ringhöhe."""
    g, n = 256, 8
    yy, xx = np.mgrid[0:g, 0:g].astype(np.float32)
    hoehe = np.zeros((g, g), np.float32)
    zelle = g / n
    for zi in range(-1, n + 1):
        for si in range(-1, n + 1):
            cx = (si + 0.5 * (zi % 2)) * zelle
            cy = zi * zelle * 0.9
            d = np.hypot(xx - cx, (yy - cy) * 1.15)
            ring = np.clip(1.0 - np.abs(d - zelle * 0.42) / (zelle * 0.13), 0, 1)
            hoehe = np.maximum(hoehe, ring * (0.7 + 0.3 * np.cos((xx - cx) / zelle * 2.0)))
    alpha = (hoehe > 0.08).astype(np.float32)
    hell = 0.35 + 0.55 * hoehe
    rgba = np.stack([hell * 0.78, hell * 0.79, hell * 0.82, alpha], axis=2)
    Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA").save(farbe_datei, optimize=True)
    dx = np.roll(hoehe, -1, 1) - np.roll(hoehe, 1, 1)
    dy = np.roll(hoehe, -1, 0) - np.roll(hoehe, 1, 0)
    nrm = np.stack([-dx * 3, dy * 3, np.ones_like(dx)], axis=2)
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8)).save(normal_datei, optimize=True)


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
        if n in ("root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head"):
            korrektur[n] = np.eye(3)      # Rumpf, Hals, Kopf: in A- und T-Haltung gleich
        elif k is None:
            korrektur[n] = korrektur[qeltern[n]]
        else:
            korrektur[n] = drehung_von_zu(QP[k] - QP[n], MHP[k] - MHP[n])
    for n in qnamen:   # Blätter erst nach den Eltern
        if hauptkind(n, kinder) is None and n not in ("root", "Head"):
            korrektur[n] = korrektur[qeltern[n]]

    # Federknochen für den Rock (Kittelrock oder Kleid): eigene Ketten am Becken, die Rockecken hängen an ihnen
    kleidung = opt.get("kleidung", "kittel")
    zusatz = []        # (Name, Eltern, Bindung 4x4)
    rock_ids = sorted({e for g_, ecken, _ in flaechen if g_ == "helper-skirt" for e in ecken})
    if kleidung != "keine" and rock_ids:
        taille_ = MHP["spine_01"][1]
        lang_ = 0.5 if kleidung == "kittel" else 0.1
        # A-Linie: zum Saum hin weiter (echte Kleider und Kittel sind unten weit, sonst tritt das Bein vorn heraus)
        huefte_ = MHP["thigh_l"][1]
        weite_ = 0.6 if kleidung == "kleid" else 0.4
        mx_, mz_ = MHP["pelvis"][0], MHP["pelvis"][2]
        for i in rock_ids:
            t_ = min(max((huefte_ - V[i][1]) / max(huefte_ - lang_, 0.1), 0.0), 1.0)
            f_ = 1.0 + weite_ * t_ ** 1.3
            # Falten: der Stoff wirft zum Saum hin Wellen rund um den Körper
            f_ *= 1.0 + 0.05 * t_ * np.sin(np.arctan2(V[i][0] - mx_, V[i][2] - mz_) * (13 if kleidung == "kleid" else 10))
            V[i][0] = mx_ + (V[i][0] - mx_) * f_
            V[i][2] = mz_ + (V[i][2] - mz_) * f_
        orte = rock_ketten(V, rock_ids, MHP["pelvis"], taille_ - 0.035, lang_ + 0.02)
        for c, kette in enumerate(orte):
            for k, ort in enumerate(kette):
                runter = (kette[k + 1] - ort) if k + 1 < len(kette) else (ort - kette[k - 1])
                yb = runter / np.linalg.norm(runter)
                xb = np.cross(yb, [0.0, 1.0, 0.0]); xb = xb / (np.linalg.norm(xb) + 1e-9)
                zb = np.cross(xb, yb)
                b = np.eye(4); b[:3, 0] = xb; b[:3, 1] = yb; b[:3, 2] = zb; b[:3, 3] = ort
                zusatz.append((f"rock_{c}_{k}", "pelvis" if k == 0 else f"rock_{c}_{k - 1}", b))
        # Rockecken: zwischen den beiden nächsten Ketten (Winkel) und den beiden nächsten Gliedern (Höhe)
        ketten_n, glieder_n = len(orte), len(orte[0])
        basis_ = len(qnamen)
        mitte_ = MHP["pelvis"]
        for i in rock_ids:
            q = V[i]
            wi = np.arctan2(q[0] - mitte_[0], q[2] - mitte_[2])
            cf = (wi + np.pi) / (2 * np.pi) * ketten_n - 0.5
            c0 = int(np.floor(cf)) % ketten_n; c1 = (c0 + 1) % ketten_n; fc = cf - np.floor(cf)
            t = (q[1] - (taille_ - 0.035)) / ((lang_ + 0.02) - (taille_ - 0.035)) * (glieder_n - 1)
            t = min(max(t, 0.0), glieder_n - 1.001)
            k0 = int(t); fk = t - k0
            # das Stück zwischen Glied k0 und k0+1 dreht sich mit Glied k0; zum nächsten Glied hin weich überblenden
            gk = {k0: 1.0 - 0.5 * fk, min(k0 + 1, glieder_n - 1): 0.5 * fk}
            d = {}
            # vorn und hinten (dort schwingen die Beine durch) folgt der Stoff stärker den Beinen, seitlich freier
            BEIN_ANTEIL = 0.55 + 0.3 * abs(np.cos(wi))
            # am Bund folgt der Stoff nur dem Becken (sonst reißt er beim Gehen unter dem Gürtel auf), zur Hüfte hin
            # wächst der Anteil der Beine
            tb = min(max((taille_ - 0.035 - q[1]) / max(taille_ - 0.035 - (huefte_ - 0.08), 0.05), 0.0), 1.0)
            BEIN_ANTEIL *= tb * tb * (3.0 - 2.0 * tb)
            for c, wc in ((c0, 1.0 - fc), (c1, fc)):
                for k, wk in gk.items():
                    j = basis_ + c * glieder_n + k
                    d[j] = d.get(j, 0.0) + wc * wk * (1.0 - BEIN_ANTEIL)
            # ein Teil folgt den Beinen (Gewichte aus MakeHuman), sonst liefe das ausschreitende Bein durch den Stoff
            for j, wv in zip(*ecken_jw[i]):
                if wv > 0:
                    d[j] = d.get(j, 0.0) + wv * BEIN_ANTEIL
            p_ = sorted(d.items(), key=lambda kv: -kv[1])[:4]
            sm = sum(x for _, x in p_)
            ecken_jw[i] = ([j for j, _ in p_] + [0] * (4 - len(p_)), [x / sm for _, x in p_] + [0.0] * (4 - len(p_)))
    # Überkleidung als schwingende Stoffbahnen: Schürze (Leinen), Lederschürze (Schmied), Wappenrock (vorn und hinten)
    ueber = opt.get("ueber", "")
    bahnen = []        # (Teilname, Materialschlüssel, Gitter, Gewichte je Ecke)
    verdecker = []     # (Seite, unten, oben, halbe Breite oben, unten): dahinter fällt der Rock weg
    if ueber and kleidung != "keine" and rock_ids:
        from scipy.spatial import cKDTree
        tights_ids = sorted({e for g_, ecken, _ in flaechen if g_ == "helper-tights" for e in ecken})
        oberflaeche = np.vstack([V[[i for i in tights_ids if V[i][1] > taille_ - 0.05]], V[rock_ids]])
        ober_ids = [i for i in tights_ids if V[i][1] > taille_ - 0.05] + list(rock_ids)
        baum_o = cKDTree(oberflaeche)
        unten_ = lang_ + 0.03
        plaene = {"schuerze": [("Schuerze", "schuerze", 1, taille_ + 0.01, max(unten_ - 0.06, 0.3), 0.34, 0.44)],
                  "lederschuerze": [("Lederschuerze", "lederschuerze", 1, taille_ + 0.33, 0.42, 0.3, 0.44)],
                  "wappenrock": [("Wappenrock", "wvorn", 1, MHP["neck_01"][1] - 0.06, 0.46, 0.36, 0.44),
                                 ("Wappenrock_hinten", "whinten", -1, MHP["neck_01"][1] - 0.06, 0.46, 0.36, 0.44)]}[ueber]
        for teilname, praefix, seite, y_o, y_u, b_o, b_u in plaene:
            spalten, zeilen, ketten, glieder = 9, 14, 4, 4
            ROCK_ANTEIL = 0.8
            g, gz = bahn_flaeche(oberflaeche, MHP["pelvis"][2], seite, y_o, y_u, b_o, b_u, taille_, spalten, zeilen,
                                 0.045 if praefix == "lederschuerze" else 0.04, 0.012)
            # Ketten: an 4 Spalten, Glieder von der Gürtelzeile bis zum Saum
            reihen = [gz + int(round((zeilen - 1 - gz) * k / (glieder - 1))) for k in range(glieder)]
            spalten_k = [int(round((spalten - 1) * c / (ketten - 1))) for c in range(ketten)]
            erster = len(qnamen) + len(zusatz)
            for c, sk in enumerate(spalten_k):
                for k, zr in enumerate(reihen):
                    ort = g[zr, sk]
                    runter = (g[reihen[k + 1], sk] - ort) if k + 1 < glieder else (ort - g[reihen[k - 1], sk])
                    yb = runter / np.linalg.norm(runter)
                    xb = np.cross(yb, [0.0, 0.0, 1.0]); xb /= (np.linalg.norm(xb) + 1e-9)
                    zb = np.cross(xb, yb)
                    b = np.eye(4); b[:3, 0] = xb; b[:3, 1] = yb; b[:3, 2] = zb; b[:3, 3] = ort
                    zusatz.append((f"{praefix}_{c}_{k}", "pelvis" if k == 0 else f"{praefix}_{c}_{k - 1}", b))
            gewichte = []
            for zi in range(zeilen):
                for si in range(spalten):
                    _, naechste = baum_o.query(g[zi, si])
                    unter = ecken_jw[ober_ids[naechste]]
                    if zi <= gz:              # oberhalb des Gürtels: liegt an, folgt dem Körper
                        gewichte.append(unter)
                        continue
                    cf = si / (spalten - 1) * (ketten - 1)
                    c0 = min(int(cf), ketten - 2); fc = cf - c0
                    tf = (zi - gz) / (zeilen - 1 - gz) * (glieder - 1)
                    k0 = min(int(tf), glieder - 1); fk = tf - k0
                    gk = {k0: 1.0 - 0.5 * fk, min(k0 + 1, glieder - 1): 0.5 * fk}
                    d = {}
                    for c, wc in ((c0, 1.0 - fc), (c0 + 1, fc)):
                        for k, wk in gk.items():
                            j = erster + c * glieder + k
                            d[j] = d.get(j, 0.0) + wc * wk * (1.0 - ROCK_ANTEIL)
                    for j, wv in zip(*unter):    # der größte Teil folgt dem Rock darunter (und damit den Beinen)
                        if wv > 0:
                            d[j] = d.get(j, 0.0) + wv * ROCK_ANTEIL
                    p_ = sorted(d.items(), key=lambda kv: -kv[1])[:4]
                    sm = sum(x for _, x in p_)
                    gewichte.append(([j for j, _ in p_] + [0] * (4 - len(p_)), [x / sm for _, x in p_] + [0.0] * (4 - len(p_))))
            bahnen.append((teilname, praefix, g, gewichte))
            verdecker.append((seite, y_u + 0.03, taille_, b_o / 2 - 0.03, b_u / 2 - 0.03))
    alle = qnamen + [z[0] for z in zusatz]

    import random as _random
    import zlib
    zufall_ = _random.Random(zlib.crc32(name.encode()))
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
    bindung = {}
    for n in qnamen:
        b = np.eye(4); b[:3, :3] = korrektur[n] @ R[n]; b[:3, 3] = MHP[n]
        bindung[n] = b
        ibm.append(np.linalg.inv(b).T.reshape(-1))
    # Zusatzknochen: in der Ruhelage so zum Eltern wie in der Bindung
    ruhe = {n: welt_t(n) for n in qnamen}
    for n, e, b in zusatz:
        ruhe[n] = ruhe[e] @ np.linalg.inv(bindung[e]) @ b
        bindung[n] = b
        lokal = np.linalg.inv(ruhe[e]) @ ruhe[n]
        gl.g["nodes"].append({"name": n, "translation": lokal[:3, 3].tolist(), "rotation": quaternion(lokal[:3, :3])})
        knoten_von[n] = len(gl.g["nodes"]) - 1
        gl.g["nodes"][knoten_von[e]].setdefault("children", []).append(knoten_von[n])
        ibm.append(np.linalg.inv(b).T.reshape(-1))
    gl.g["skins"].append({"joints": [knoten_von[n] for n in alle], "skeleton": knoten_von["root"],
                          "inverseBindMatrices": gl.acc(np.array(ibm), 5126, "MAT4")})

    FERN_ANTEIL = 0.22        # ferne Fassung (ab 20 m in figur.gd): etwa ein Fünftel der Dreiecke
    def teil(teilname, pos, tex, jw, tri, mat, nor=None, abnutzung=None, fern=True):
        if nor is None:
            nor = normalen(pos, tri)
        farben = verschleiss(pos, nor, abnutzung, zufall_) if abnutzung else None
        _teil_schreiben(teilname, pos, tex, jw, tri, mat, nor, farben)
        if fern and mo is not None and len(tri) > 300 and teilname not in ("Augen", "Brauen", "Wimpern"):
            flach = tri.astype(np.uint32).ravel()
            ziel_n = int(len(flach) * FERN_ANTEIL) // 3 * 3
            neu = np.zeros(len(flach), dtype=np.uint32)
            n = mo.simplify(neu, flach, np.ascontiguousarray(pos.astype(np.float32)), len(flach), len(pos), 12, ziel_n, 0.02)
            if n > ziel_n * 1.5:
                grob = np.zeros(len(flach), dtype=np.uint32)
                m_ = mo.simplify_sloppy(grob, flach, np.ascontiguousarray(pos.astype(np.float32)), len(flach), len(pos), 12, ziel_n, 0.1)
                if 0 < m_ < n:
                    neu, n = grob, m_
            neu = neu[:n]
            if n >= 3:
                benutzt, idx = np.unique(neu, return_inverse=True)
                _teil_schreiben(teilname + "_fern", pos[benutzt], tex[benutzt], [jw[i] for i in benutzt],
                                idx.reshape(-1, 3), mat, nor[benutzt], None if farben is None else farben[benutzt])

    def _teil_schreiben(teilname, pos, tex, jw, tri, mat, nor, farben):
        j = np.array([x[0] for x in jw]); wt = np.array([x[1] for x in jw])
        extra = {}
        if farben is not None:
            extra["COLOR_0"] = gl.acc(farben, 5126, "VEC4", 34962)
        prim = {"attributes": {**extra, "POSITION": gl.acc(pos, 5126, "VEC3", 34962, True), "NORMAL": gl.acc(nor, 5126, "VEC3", 34962),
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
    haut_info, haut_masken = bearbeite_haut(sysa / "skins" / haut / hm["diffuseTexture"], ziel,
                               [(e, t) for g_, e, t in flaechen if g_ == "body"], vt, V, MHP["Head"], not w, zufall_, opt)
    m_haut = gl.material("Haut", "haut.jpg", rau=1.0, normal_uri="haut_normal.png")
    gl.g["materials"][m_haut]["pbrMetallicRoughness"]["metallicRoughnessTexture"] = {"index": gl.textur("haut_rau.png")}
    koerper_fl = [(e, t) for g_, e, t in flaechen if g_ == "body"]

    # Kleidung aus der Hilfsgeometrie: Kittel (Rumpf, Arme, Rock bis zum Knie), Beinlinge, Gürtel, Schuhe
    if kleidung != "keine":
        from scipy.spatial import cKDTree
        stoffe = REPO / "modelle" / "figuren" / "menschen" / "stoffe"
        lade_stoffe(stoffe)
        rel = lambda n: f"../stoffe/{n}"
        farbe_kittel = [float(x) for x in opt.get("kittelfarbe", "0.42,0.34,0.24").split(",")] + [1.0]
        farbe_bein = [float(x) for x in opt.get("beinfarbe", "0.2,0.18,0.16").split(",")] + [1.0]
        m_kittel = gl.material("Kittel", rel("kittel_farbe.jpg"), farbe_kittel, rau=0.95, normal_uri=rel("kittel_normal.jpg"),
                               doppelt=True)
        m_bein = gl.material("Beinlinge", rel("beinlinge_farbe.jpg"), farbe_bein, rau=0.95, normal_uri=rel("beinlinge_normal.jpg"))
        m_leder = gl.material("Leder", rel("leder_farbe.jpg"), (0.75, 0.62, 0.5, 1.0), rau=0.7, normal_uri=rel("leder_normal.jpg"))
        haupt = lambda i: alle[ecken_jw[i][0][0]]                 # Knochen mit dem größten Gewicht
        hand = lambda i: sum(ww for jj, ww in zip(*ecken_jw[i]) if alle[jj].startswith(("hand", "thumb", "index",
                                                                                          "middle", "ring", "pinky")))
        oben_k = ("spine", "clavicle", "upperarm", "lowerarm")
        unten_k = ("thigh", "calf", "foot", "ball")
        taille = MHP["spine_01"][1]
        hals = MHP["neck_01"][1] + 0.005          # runder Halsausschnitt eng am Hals, auf fester Höhe
        rock_lang = 0.5 if kleidung == "kittel" else 0.1     # Kittel bis zum Knie, Kleid bis zum Knöchel
        def ist_oben_roh(i):
            h = haupt(i)
            # beim Kleid reicht das Oberteil auch über Gesäß und Hüfte (dort fehlen die Beinlinge, sonst Haut am Bund)
            becken = h == "pelvis" or (kleidung == "kleid" and h.startswith("thigh"))
            return (h.startswith(oben_k + ("neck",)) or (becken and V[i][1] > taille - 0.13)) and hand(i) < 0.25
        def ist_oben(i):
            return ist_oben_roh(i) and V[i][1] < hals
        def ist_unten(i):
            h = haupt(i)
            # Beinlinge bis zur Taille: der Rock schwingt (Federknochen) und weicht den Beinen aus
            if kleidung == "kleid" and V[i][1] > rock_lang + 0.2:   # unter dem langen Kleid unsichtbar
                return False
            # bis in den Schuh hinein (sonst bliebe am Knöchel ein Streifen Haut)
            return h.startswith(("thigh", "calf")) or (h == "pelvis" and V[i][1] <= taille + 0.02) or \
                (ist_schuh(i) and V[i][1] > 0.055)
        def ist_schuh(i):
            h = haupt(i)
            return h.startswith(("foot", "ball")) or (h.startswith("calf") and V[i][1] < 0.12)
        hose_fl = [(e, t) for g_, e, t in flaechen if g_ == "helper-tights"]
        # Übergang bis zum Stoffmodul (docs/technik-weg.md): unter dem Kittel die Oberschenkel 1,5 cm schmaler, damit
        # sie beim Gehen nicht durch den Rock stechen; unter dem Saum unverändert
        if kleidung == "kittel":
            bein_ids = [i for i in sorted({i for g_, e, _ in flaechen if g_ in ("body", "helper-tights") for i in e})
                        if haupt(i).startswith(("thigh", "pelvis")) and rock_lang + 0.06 < V[i][1] < taille - 0.06]
            if bein_ids:
                tri_bein = np.array(dreiecke([e for g_, e, _ in flaechen if g_ in ("body", "helper-tights")]))
                n_bein = normalen(V, tri_bein)
                for i in bein_ids:
                    t_ = min((V[i][1] - (rock_lang + 0.06)) / 0.08, 1.0)
                    V[i] -= n_bein[i] * 0.015 * t_
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
            teil(teilname, pos, tex, jw, tri, mat, nor, "leder" if mat == m_leder else "stoff")
            return set(ecken_ids)
        oben_ids = stueck(hose_fl, ist_oben_roh, 0.011, m_kittel, "Kittel", 3.0, deckel=hals)
        oben_ids = {i for i in oben_ids if V[i][1] < hals}
        def hinter_bahn(i):
            q = V[i]
            for seite_, unten, oben, b_oben, b_unten in verdecker:
                if (q[2] - MHP["pelvis"][2]) * seite_ > 0 and unten < q[1] < oben:
                    t = (oben - q[1]) / max(oben - unten, 0.01)
                    if abs(q[0]) < b_oben + (b_unten - b_oben) * t:
                        return True
            return False
        panzer = opt.get("panzer", "")
        if panzer == "kettenhemd":
            if not (stoffe / "kette_farbe.png").exists():
                zeichne_kettengeflecht(stoffe / "kette_farbe.png", stoffe / "kette_normal.png")
            m_kette = gl.material("Kettenhemd", rel("kette_farbe.png"), (0.85, 0.86, 0.9, 1.0), rau=0.45,
                                  normal_uri=rel("kette_normal.png"), alpha="MASK", doppelt=True)
            gl.g["materials"][m_kette]["pbrMetallicRoughness"]["metallicFactor"] = 0.85
            KETTE_UNTEN = 0.58           # das Kettenhemd reicht bis zur Mitte des Oberschenkels
            stueck(rock_fl, lambda i: rock_lang <= V[i][1] <= KETTE_UNTEN + 0.03 and not hinter_bahn(i), 0.006,
                   m_kittel, "Kittelrock", 3.0)
            stueck(rock_fl, lambda i: KETTE_UNTEN <= V[i][1] <= taille - 0.035 and not hinter_bahn(i), 0.011,
                   m_kette, "Kettenhemd_rock", 9.0)
            stueck(hose_fl, lambda i: ist_oben_roh(i) and V[i][1] < hals - 0.01, 0.02, m_kette, "Kettenhemd", 9.0)
        else:
            stueck(rock_fl, lambda i: rock_lang <= V[i][1] <= taille - 0.035 and not hinter_bahn(i), 0.006, m_kittel,
                   "Kittelrock", 3.0)
        # Flicken: kleine Stücke in anderem Ton an Ellbogen und Rock
        flicken = int(opt.get("flicken", zufall_.choice([0, 1, 1, 2, 3])))
        if flicken and panzer == "":
            ton = [c * zufall_.uniform(0.75, 1.25) for c in farbe_kittel[:3]] + [1.0]
            m_flicken = gl.material("Flicken", rel("beinlinge_farbe.jpg"), ton, rau=0.95,
                                    normal_uri=rel("beinlinge_normal.jpg"), doppelt=True)
            orte_f = [MHP["lowerarm_l"], MHP["lowerarm_r"]]
            for _ in range(3):
                wf = zufall_.uniform(-np.pi, np.pi)
                orte_f.append(MHP["pelvis"] + np.array([np.sin(wf) * 0.2, -0.25 - zufall_.uniform(0, 0.15), np.cos(wf) * 0.2]))
            zufall_.shuffle(orte_f)
            for nr, ort in enumerate(orte_f[:flicken]):
                fl_ = hose_fl if ort[1] > taille else rock_fl
                abst = 0.015 if ort[1] > taille else 0.01
                naechste = min(((e, t) for e, t in fl_), key=lambda f_: np.linalg.norm(V[f_[0]].mean(0) - ort))
                mitte_f = V[naechste[0]].mean(0)
                stueck(fl_, lambda i, m_=mitte_f: np.linalg.norm(V[i] - m_) < 0.06 and not hinter_bahn(i), abst,
                       m_flicken, f"Flicken{nr}", 3.0)
        unten_ids = stueck(hose_fl, ist_unten, 0.003, m_bein, "Beinlinge", 3.0)
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
            teil("Schuhe", pos, tex, jw, tri, m_leder, nor, "leder")
        # Überkleidung (schwingende Bahnen)
        if bahnen:
            m_schuerze = gl.material("Schuerze", rel("kittel_farbe.jpg"), (0.8, 0.77, 0.68, 1.0), rau=0.95,
                                     normal_uri=rel("kittel_normal.jpg"), doppelt=True)
            m_wappen = gl.material("Wappen", rel("kittel_farbe.jpg"), (0.55, 0.1, 0.08, 1.0), rau=0.9,
                                   normal_uri=rel("kittel_normal.jpg"), doppelt=True)
            m_lederbahn = gl.material("Lederbahn", rel("leder_farbe.jpg"), (0.7, 0.58, 0.46, 1.0), rau=0.75,
                                      normal_uri=rel("leder_normal.jpg"), doppelt=True)
            for teilname, praefix, g, gewichte in bahnen:
                zeilen, spalten = g.shape[:2]
                pos = g.reshape(-1, 3)
                tex = np.column_stack([pos[:, 0] * 2.5, pos[:, 1] * 2.5])
                tri = []
                for zi in range(zeilen - 1):
                    for si in range(spalten - 1):
                        a_ = zi * spalten + si; b_ = a_ + 1; c_ = a_ + spalten; d_ = c_ + 1
                        # Vorderseite nach außen: vorn (+z) gegen, hinten (-z) mit dem Uhrzeigersinn der Zeilen
                        tri += [(a_, c_, b_), (b_, c_, d_)] if praefix != "whinten" else [(a_, b_, c_), (b_, d_, c_)]
                tri = np.array(tri)
                mat = m_lederbahn if praefix == "lederschuerze" else m_wappen if praefix.startswith("w") else m_schuerze
                teil(teilname, pos, tex, gewichte, tri, mat, None, "leder" if mat == m_lederbahn else "stoff")
        # Haut unter der Kleidung weglassen: Ecken nahe an benutztem Stoff
        bedeckt_von = np.array(sorted(oben_ids | unten_ids)) if (oben_ids | unten_ids) else np.zeros(0, int)
        bedeckt = set(schuh_ids)
        if len(bedeckt_von):
            # nur Haut, die selbst zum Kleiderbereich gehört und Stoff dicht über sich hat (sonst Löcher am Saum)
            baum = cKDTree(V[bedeckt_von])
            d, _ = baum.query(V[koerper_ids])
            unter = lambda i: (ist_oben(i) and hand(i) < 0.12 and V[i][1] < hals - 0.012) or ist_unten(i)
            bedeckt |= {i for i, dd in zip(koerper_ids, d) if dd < 0.025 and unter(i)}
        # Beine und Becken unter dem Rock weglassen (sonst stechen sie beim Gehen durch den Stoff)
        if kleidung == "kleid":
            bedeckt |= {i for i in koerper_ids if (haupt(i).startswith(("thigh", "calf")) or haupt(i) == "pelvis")
                        and rock_lang + 0.2 < V[i][1] < MHP["thigh_l"][1] - 0.04}   # Gesäß und Hüfte bleiben (kein Durchblick am Bund)
        koerper_fl = [(e, t) for e, t in koerper_fl if not all(i in bedeckt for i in e)]
    pos, tex, jw, tri = zerlege_nach_uv(V, vt, koerper_fl, ecken_jw)
    teil("Koerper", pos, tex, jw, tri, m_haut)
    # Bart: zwei Schichten über Kinn, Wangen und Oberlippe mit selbst gezeichnetem Barthaar
    bart_art = opt.get("bart_art", "keiner" if w else zufall_.choice(["keiner", "kurz", "voll"]))
    if bart_art != "keiner":
        stoffe_b = REPO / "modelle" / "figuren" / "menschen" / "stoffe"
        stoffe_b.mkdir(parents=True, exist_ok=True)
        if not (stoffe_b / "barthaar.png").exists():
            zeichne_barthaar(stoffe_b / "barthaar.png", _random.Random(7))
        hm_ = lies_material(sysa / "hair" / haare / f"{haare}.mhmat") if haare != "keine" else {}
        ton_b = (0.25, 0.18, 0.12)
        if hm_.get("diffuseTexture"):
            hb = np.asarray(Image.open(sysa / "hair" / haare / hm_["diffuseTexture"]).convert("RGBA").resize((128, 128)), np.float32) / 255
            gw_ = hb[..., 3:4]
            ton_b = tuple(float(x) for x in (hb[..., :3] * gw_).sum((0, 1)) / max(float(gw_.sum()), 1.0))
        m_bart = gl.material("Bart", "../stoffe/barthaar.png", tuple(ton_b) + (1.0,), rau=0.8, alpha="MASK", doppelt=True)
        maske_b = haut_masken["bart"]
        schwelle = 0.25 if bart_art == "voll" else 0.45
        bart_fl = [e for g_, e, _ in flaechen if g_ == "body" and all(maske_b[i] > schwelle for i in e)]
        if bart_fl:
            ids_b = sorted({i for e in bart_fl for i in e})
            tri_b = np.array(dreiecke(bart_fl))
            n_b = normalen(V, tri_b)
            for schicht, abst in enumerate([0.002, 0.006] if bart_art == "voll" else [0.0015]):
                vb = V.copy(); vb[ids_b] += n_b[ids_b] * abst
                pos, nor, tex, jw, tri = zerlege_kasten(vb, n_b, bart_fl, ecken_jw, 12.0)
                teil(f"Bart{schicht}", pos, tex, jw, tri, m_bart, nor, fern=False)
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
        normal_h = hm2.get("normalmapTexture") or ("%s_normal.png" % haare if (sysa / "hair" / haare / f"{haare}_normal.png").exists() else None)
        m_haare = gl.material("Haare", bild(sysa / "hair" / haare / hm2["diffuseTexture"], "haare.png", 1024),
                              alpha="MASK", doppelt=True, rau=0.6,
                              normal_uri=bild(sysa / "hair" / haare / normal_h, "haare_normal.png", 1024) if normal_h else None)
        proxy(sysa / "hair" / haare / f"{haare}.mhclo", "Haare", m_haare)

    gl.schreibe(ziel / f"{name}.gltf")
    info = {"quelle": "MakeHuman 1.x (CC0)", "geschlecht": geschlecht, "alter": alter, "muskeln": muskeln,
            "gewicht": gewicht, "groesse": groesse, "haut": haut, "haare": haare, "massstab": round(float(s), 4),
            "hoehe_m": round(float((v[koerper_ids, 1].max() - boden) * s), 3), "haut_merkmale": haut_info,
            "kleidung": kleidung, "ueber": ueber, "bart": bart_art, "panzer": opt.get("panzer", "")}
    (ziel / "mensch.json").write_text(json.dumps(info, indent=1))
    print("gebaut:", name, info)


if __name__ == "__main__":
    main()
