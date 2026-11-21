# ---------- Flur um Drachenstein: Äcker, Getreide und Weiden entlang der Landstraßen (Mängelliste M6) ----------
# Mittelalterliche Streifenflur: An den Landstraßen liegen Blöcke aus schmalen, langen Feldstreifen (Gewanne), quer zur
# Straße. Jeder Streifen ist Acker (gepflügt, mit Furchen), Getreide (golden), Weide (helles, kurzes Gras) oder
# Brache (Wiese mit Blumen). Nur auf ebenem Land über dem Wasser, nicht an Stadt, Burg, Hafen und Vorwerk.
# Ergebnis: daten/gelaende/flur.png (doppelte Auflösung des Höhenrasters, 1,25 m): R Acker, G Getreide, B Weide/Wiese
# (0,5 Weide, 1 Wiese mit Blumen), A Richtung der Furchen (0 bis 180 Grad). Der Geländeshader und der Bewuchs lesen
# die Karte; die Blöcke selbst bleiben frei von Bäumen (FLUR_BLOECKE, region_drachenstein.py → bewuchs).
# Wird aus region_drachenstein.py nach teil_felsen.py ausgeführt (H, PD, WL, W, im_vieleck, abstand_linie, _wege).
import numpy as _np
from PIL import Image as _Bild, ImageDraw as _Zeichnen

_zufall_flur = random.Random(1347)
_LANDSTRASSEN = _wege[len(PD.BURGWEGE) + 1:]          # aus teil_felsen.py: Landstraßen vor den Toren
_ALLE_WEGE = _wege
_vw_halb = 46.0
_vwa_f = math.radians(PD.VORWERK_DREH)
_vorwerk_flaeche = [(PD.VORWERK[0] + lx * math.cos(_vwa_f) + lz * math.sin(_vwa_f),
                     PD.VORWERK[1] - lx * math.sin(_vwa_f) + lz * math.cos(_vwa_f))
                    for lx, lz in ((-_vw_halb, -_vw_halb), (_vw_halb, -_vw_halb), (_vw_halb, _vw_halb), (-_vw_halb, _vw_halb))]
_FLUR_SPERREN = [STADT_UMRISS, WL(PD.RINGMAUER), WL(PD.HAFEN_BEZIRK), _vorwerk_flaeche]
_x0, _z0 = HOEHEN["ursprung_x"], HOEHEN["ursprung_z"]
_x1 = _x0 + (HOEHEN["breite"] - 1) * HOEHEN["abstand"]
_z1 = _z0 + (HOEHEN["tiefe"] - 1) * HOEHEN["abstand"]

# Das Ordensvorwerk ist ein Gutshof: von ihm laufen Feldwege in vier Richtungen ins Land, an ihnen liegen seine Felder
FELDWEGE = []
for _k in range(4):
    _w = _vwa_f + _k * math.pi / 2 + 0.35
    _dx, _dz = math.cos(_w), math.sin(_w)
    FELDWEGE.append([(PD.VORWERK[0] + _dx * 52, PD.VORWERK[1] + _dz * 52), (PD.VORWERK[0] + _dx * 330, PD.VORWERK[1] + _dz * 330)])
_LANDSTRASSEN = _LANDSTRASSEN + FELDWEGE

FLUR_FELDER = []      # (Art, Vieleck, Richtung der Furchen in Grad); Art: 0 Acker, 1 Getreide, 2 Weide, 3 Wiese
FLUR_BLOECKE = []     # Umrisse der Blöcke (für den Bewuchs: dort keine Bäume)


def _flur_frei(x, z):
    if not (_x0 + 30 < x < _x1 - 30 and _z0 + 30 < z < _z1 - 30):
        return False
    h = H(x, z)
    if h < -16.5 or h > 45.0:
        return False
    steil = max(abs(H(x + 2.0, z) - H(x - 2.0, z)), abs(H(x, z + 2.0) - H(x, z - 2.0))) / 4.0
    if steil > 0.17:            # Felder dürfen an sanften Hängen liegen
        return False
    if any(im_vieleck((x, z), v) for v in _FLUR_SPERREN):
        return False
    if any(im_vieleck((x, z), b) for b in FLUR_BLOECKE):
        return False
    return min(abstand_linie(w, x, z) for w in _ALLE_WEGE) > 5.0


def _streifen(px, pz, ux, uz, nx, nz, breite, laenge):
    return [(px, pz), (px + ux * breite, pz + uz * breite), (px + ux * breite + nx * laenge, pz + uz * breite + nz * laenge),
            (px + nx * laenge, pz + nz * laenge)]


def _streifen_frei(v):
    (ax, az), (bx, bz), (cx, cz), (dx, dz) = v
    for i in range(5):
        for j in range(9):
            s, t = i / 4, j / 8
            x = ax + (bx - ax) * s + (dx - ax) * t
            z = az + (bz - az) * s + (dz - az) * t
            if not _flur_frei(x, z):
                return False
    return True


for _strasse in _LANDSTRASSEN:
    for (_ax, _az), (_bx, _bz) in zip(_strasse, _strasse[1:]):
        _l = math.dist((_ax, _az), (_bx, _bz))
        if _l < 30:
            continue
        _ux, _uz = (_bx - _ax) / _l, (_bz - _az) / _l
        _t = _zufall_flur.uniform(5, 25)
        while _t < _l - 20:
            for _seite in (-1, 1):
                _nx, _nz = -_uz * _seite, _ux * _seite
                _anzahl = _zufall_flur.randint(4, 7)
                _laenge = _zufall_flur.uniform(55, 105)
                _ab = _zufall_flur.uniform(7.0, 10.0)            # Abstand von der Straße (Rain)
                _px, _pz = _ax + _ux * _t + _nx * _ab, _az + _uz * _t + _nz * _ab
                _gesetzt = []
                for _k in range(_anzahl):
                    _br = _zufall_flur.uniform(10.0, 16.0)
                    for _lg in (_laenge, _laenge * 0.75, _laenge * 0.55, _laenge * 0.4):
                        _v = _streifen(_px, _pz, _ux, _uz, _nx, _nz, _br, _lg)
                        if _streifen_frei(_v):
                            _gesetzt.append(_v)
                            break
                    _px, _pz = _px + _ux * (_br + 0.8), _pz + _uz * (_br + 0.8)   # schmaler Rain zwischen den Streifen
                if len(_gesetzt) >= 2:
                    _winkel = math.degrees(math.atan2(_nz, _nx)) % 180.0
                    for _v in _gesetzt:
                        _art = _zufall_flur.choices((0, 1, 2, 3), (0.3, 0.36, 0.18, 0.16))[0]
                        FLUR_FELDER.append((_art, _v, _winkel))
                    # Umriss des Blocks: alle Streifenecken, als konvexe Hülle
                    _pts = [q for v in _gesetzt for q in v]
                    _pts.sort()
                    def _kreuz(o, a, b):
                        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
                    _unten, _oben = [], []
                    for q in _pts:
                        while len(_unten) >= 2 and _kreuz(_unten[-2], _unten[-1], q) <= 0:
                            _unten.pop()
                        _unten.append(q)
                    for q in reversed(_pts):
                        while len(_oben) >= 2 and _kreuz(_oben[-2], _oben[-1], q) <= 0:
                            _oben.pop()
                        _oben.append(q)
                    FLUR_BLOECKE.append([(round(x, 2), round(z, 2)) for x, z in _unten[:-1] + _oben[:-1]])
            _t += _zufall_flur.uniform(60, 90)

# Flurkarte schreiben (1,25 m je Bildpunkt)
_FAKTOR = 2
_bw, _bt = (HOEHEN["breite"] - 1) * _FAKTOR + 1, (HOEHEN["tiefe"] - 1) * _FAKTOR + 1
_kanal = {k: _Bild.new("L", (_bw, _bt), 0) for k in "RGBA"}
_zeichner = {k: _Zeichnen.Draw(b) for k, b in _kanal.items()}


def _bildpunkt(q):
    return ((q[0] - _x0) / HOEHEN["abstand"] * _FAKTOR, (q[1] - _z0) / HOEHEN["abstand"] * _FAKTOR)


for _art, _v, _winkel in FLUR_FELDER:
    _p = [_bildpunkt(q) for q in _v]
    if _art == 0:
        _zeichner["R"].polygon(_p, fill=255)
    elif _art == 1:
        _zeichner["G"].polygon(_p, fill=255)
    else:
        _zeichner["B"].polygon(_p, fill=128 if _art == 2 else 255)
    _zeichner["A"].polygon(_p, fill=int(_winkel / 180.0 * 255) % 256)
_flur = _Bild.merge("RGBA", [_kanal[k] for k in "RGBA"])
_flur.save(REPO / "daten" / "gelaende" / "flur.png")
_imp = REPO / "daten" / "gelaende" / "flur.png.import"
if not _imp.exists():
    _imp.write_text((REPO / "daten" / "gelaende" / "maske.png.import").read_text(encoding="utf-8")
                    .replace("maske.png", "flur.png").replace('uid="uid://co1aarjlngtft"\n', ""), encoding="utf-8")
E("Texture2D", "res://daten/gelaende/flur.png", "48_flur")
for _i, _eintrag in enumerate(sub):
    if 'id="Material_gelaende"' in _eintrag:
        sub[_i] = _eintrag + '\nshader_parameter/flur = ExtResource("48_flur")\nshader_parameter/mit_flur = true'
print("Flur:", len(FLUR_BLOECKE), "Blöcke,", len(FLUR_FELDER), "Streifen (Acker, Getreide, Weide, Wiese):",
      [sum(1 for f in FLUR_FELDER if f[0] == a) for a in range(4)])
