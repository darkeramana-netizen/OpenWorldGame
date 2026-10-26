"""Gemeinsame Bausteine für die Bauskripte der Regionen (siehe README in diesem Ordner).

Jedes Regionsskript führt diese Datei mit exec() aus und schreibt am Ende mit schreibe() die Szene.
"""
import json, math, random
from pathlib import Path
import numpy as np

BAU = Path(__file__).resolve().parent if "__file__" in globals() else Path.cwd()
REPO = BAU.parent.parent

def teil(name):
    """Führt ein Teilskript (z. B. teil_gravemarch.py) im selben Namensraum aus."""
    exec(open(BAU / name, encoding="utf-8").read(), globals())

ext = []      # (typ, pfad, id)
sub = []      # text
knoten = []   # text

def E(typ, pfad, i):
    ext.append(f'[ext_resource type="{typ}" path="{pfad}" id="{i}"]')
def _zeilen(text):
    """Entfernt Einrückung, damit Bausteine auch aus eingerückten Funktionen kommen dürfen."""
    return "\n".join(z.strip() for z in text.strip().split("\n"))
def S(text):
    sub.append(_zeilen(text))
def N(name, typ=None, parent=".", eigenschaften="", instanz=None, extra=""):
    kopf = f'[node name="{name}"'
    if typ: kopf += f' type="{typ}"'
    if parent is not None: kopf += f' parent="{parent}"'
    if extra: kopf += " " + extra
    if instanz: kopf += f' instance=ExtResource("{instanz}")'
    kopf += "]"
    knoten.append(kopf + ("\n" + _zeilen(eigenschaften) if eigenschaften.strip() else ""))

def T(x, y, z, gier=0.0, sx=1, sy=1, sz=1):
    """Transform mit Drehung um Y wie rotation_degrees.y in Godot.
    Die Szenendatei speichert die Basis zeilenweise."""
    a = math.radians(gier); c, s = math.cos(a), math.sin(a)
    f = lambda v: f"{v:.5g}"
    zeile0 = (c*sx, 0, s*sz)
    zeile2 = (-s*sx, 0, c*sz)
    return (f"transform = Transform3D({f(zeile0[0])}, 0, {f(zeile0[2])}, 0, {f(sy)}, 0, "
            f"{f(zeile2[0])}, 0, {f(zeile2[2])}, {f(x)}, {f(y)}, {f(z)})")

def box(name, parent, x, y, z, sx, sy, sz, mat, gier=0.0, kollision=True):
    N(name, "CSGBox3D", parent, f"""{T(x,y,z,gier)}
{"use_collision = true" if kollision else ""}
size = Vector3({sx}, {sy}, {sz})
material = SubResource("{mat}")""")

def zyl(name, parent, x, y, z, r, h, mat, seiten=8, kollision=True):
    N(name, "CSGCylinder3D", parent, f"""{T(x,y,z)}
{"use_collision = true" if kollision else ""}
radius = {r}
height = {h}
sides = {seiten}
material = SubResource("{mat}")""")

def schild(name, parent, x, y, z, text, groesse=64):
    N(name, "Label3D", parent, f"""{T(x,y,z)}
billboard = 1
pixel_size = 0.02
text = "{text}"
font_size = {groesse}
outline_size = 14""")

def person(name, parent, x, y, z, anzeige, dialog, kordel, tracht, gier=0.0):
    N(name, None, parent, f"""{T(x,y,z,gier)}
anzeige_name = "{anzeige}"
dialog_id = "{dialog}"
kordel = {kordel}
tracht = Color({tracht})""", instanz="4_person")

HOEHEN = {}

def lade_hoehen(ordner):
    """Liest die Höhendaten einer Region (daten/<ordner>/hoehen.r32 und hoehen.json) für H()."""
    info = json.load(open(REPO / "daten" / ordner / "hoehen.json"))
    HOEHEN.update(info)
    HOEHEN["werte"] = np.fromfile(REPO / "daten" / ordner / "hoehen.r32", dtype="<f4").reshape(info["tiefe"], info["breite"])

def H(x, z):
    fx = (x - HOEHEN["ursprung_x"]) / HOEHEN["abstand"]; fz = (z - HOEHEN["ursprung_z"]) / HOEHEN["abstand"]
    i, j = int(fx), int(fz); a, b = fx - i, fz - j
    w = HOEHEN["werte"]
    return float(w[j, i]*(1-a)*(1-b) + w[j, i+1]*a*(1-b) + w[j+1, i]*(1-a)*b + w[j+1, i+1]*a*b)

def H_bereich(x, z, hx, hz, gier=0.0):
    """Kleinste und größte Höhe unter einer gedrehten Grundfläche (halbe Maße hx, hz)."""
    a = math.radians(gier); c, s = math.cos(a), math.sin(a)
    werte = []
    for u in (-hx, 0, hx):
        for v in (-hz, 0, hz):
            werte.append(H(x + c*u + s*v, z - s*u + c*v))
    return min(werte), max(werte)

def gier_zu(dx, dz):
    """rotation_degrees.y, damit die lokale x-Achse in Richtung (dx, dz) zeigt."""
    return -math.degrees(math.atan2(dz, dx))


def abstand_linie(linie, x, z):
    best = 1e9
    for (x1, z1), (x2, z2) in zip(linie, linie[1:]):
        dx, dz = x2-x1, z2-z1
        t = max(0, min(1, ((x-x1)*dx + (z-z1)*dz) / (dx*dx + dz*dz)))
        best = min(best, math.hypot(x - x1 - dx*t, z - z1 - dz*t))
    return best

def bereich(id_, sx, sy, sz):
    S(f'''[sub_resource type="BoxShape3D" id="{id_}"]
size = Vector3({sx}, {sy}, {sz})''')

def schreibe(szene):
    """Schreibt die gesammelte Szene nach szenen/welt/<szene>."""
    text = f'[gd_scene load_steps={len(ext)+len(sub)+1} format=3]\n\n' + "\n".join(ext) + "\n\n" + "\n\n".join(sub) + "\n\n" + "\n\n".join(knoten) + "\n"
    open(REPO / "szenen" / "welt" / szene, "w", encoding="utf-8").write(text)
    print(szene, "– Knoten:", len(knoten))

def T_kipp(x, y, z, gier, neigung):
    """Wie T, zusätzlich um die lokale z-Achse geneigt (für schräge Brücken)."""
    a, b = math.radians(gier), math.radians(neigung)
    ry = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])
    rz = np.array([[math.cos(b), -math.sin(b), 0], [math.sin(b), math.cos(b), 0], [0, 0, 1]])
    m = ry @ rz
    f = lambda v: f"{v:.5g}"
    return "transform = Transform3D(" + ", ".join(f(v) for v in m.flatten()) + f", {f(x)}, {f(y)}, {f(z)})"

zaehler = {}
def mauerzug(name, eltern, punkte, hoehe, dicke=2.5, luecken=None, geschlossen=False, verfallen=False):
    """Mauer entlang eines Linienzugs in Stücken bis 16 m. luecken: {Kantenindex: (Anteil, Breite)}."""
    luecken = luecken or {}
    pkt = punkte + [punkte[0]] if geschlossen else punkte
    for i in range(len(pkt) - 1):
        (x1, z1), (x2, z2) = pkt[i], pkt[i+1]
        laenge = math.hypot(x2 - x1, z2 - z1)
        abschnitte = [(0.0, 1.0)]
        if i in luecken:
            m, b = luecken[i]
            h = b / 2 / laenge
            abschnitte = [(0.0, m - h), (m + h, 1.0)]
        for t0, t1 in abschnitte:
            n = max(1, math.ceil(laenge * (t1 - t0) / 16))
            for k in range(n):
                u0 = t0 + (t1 - t0) * k / n; u1 = t0 + (t1 - t0) * (k + 1) / n
                ax, az = x1 + (x2-x1)*u0, z1 + (z2-z1)*u0
                bx, bz = x1 + (x2-x1)*u1, z1 + (z2-z1)*u1
                zaehler[name] = zaehler.get(name, 0) + 1
                nr = zaehler[name]
                h_oben = hoehe
                if verfallen:
                    if nr % 3 == 2:
                        continue  # eingestürzt
                    h_oben = hoehe * (0.45 + 0.25 * (nr % 2))
                ueber = 0 if (k == n - 1 and t1 < 1.0) or (k == 0 and t0 > 0.0) else 1.2
                box(f"{name}{nr}", eltern, round((ax+bx)/2, 2), round((h_oben - 2) / 2, 2), round((az+bz)/2, 2),
                    round(math.hypot(bx-ax, bz-az) + ueber, 2), round(h_oben + 2, 2), dicke, "Material_mauer",
                    gier=round(gier_zu(bx - ax, bz - az), 2))

def tuerblatt(name, eltern, x, z, nx, nz, bedingung, anzeige, text, breite=3.0, hoehe=4.0):
    """Verschlossenes Tor (tor.gd) auf einer Mauerseite; (nx, nz) zeigt von der Mauer weg."""
    N(name, "StaticBody3D", eltern, f"""{T(round(x, 2), hoehe / 2, round(z, 2), round(gier_zu(nx, nz), 2))}
script = ExtResource("15_tor")
bedingung = "{bedingung}"
anzeige_name = "{anzeige}"
text_geschlossen = "{text}"
""")
    box("Fluegel", f"{eltern}/{name}", 0, 0, 0, 0.4, hoehe, breite, "Material_holz", kollision=False)
    for k in (-1, 1):
        box(f"Band{k + 1}", f"{eltern}/{name}", 0.22, hoehe * 0.25 * k, 0, 0.06, 0.15, breite * 0.9, "Material_metall", kollision=False)
    S(f'''[sub_resource type="BoxShape3D" id="Form_{name}"]
size = Vector3(0.4, {hoehe}, {breite})''')
    N("Form", "CollisionShape3D", f"{eltern}/{name}", f'shape = SubResource("Form_{name}")')

def raum_lokal(name, eltern, x0, z0, x1, z1, hoehe, tueren, schild_text="", licht=False, mat="Material_hell"):
    """Hohler Raum mit Dach; tueren: (Seite N/S/O/W, Lage entlang der Seite in lokalen Metern)."""
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    b, t = x1 - x0, z1 - z0
    pfad = f"{eltern}/{name}"
    N(name, "CSGCombiner3D", eltern, f"{T(cx, 0, cz)}\nuse_collision = true")
    box("Aussen", pfad, 0, hoehe / 2, 0, b, hoehe, t, mat, kollision=False)
    N("Innen", "CSGBox3D", pfad, f"{T(0, (hoehe - 0.8) / 2, 0)}\noperation = 2\nsize = Vector3({round(b - 1.2, 2)}, {round(hoehe - 0.4, 2)}, {round(t - 1.2, 2)})")
    for k, (seite, lage) in enumerate(tueren):
        if seite in "NS":
            dx, dz, sx, sz = lage - cx, (-t / 2 if seite == "N" else t / 2), 2.2, 1.8
        else:
            dx, dz, sx, sz = (b / 2 if seite == "O" else -b / 2), lage - cz, 1.8, 2.2
        N(f"Tuer{k}", "CSGBox3D", pfad, f"{T(round(dx, 2), 1.3, round(dz, 2))}\noperation = 2\nsize = Vector3({sx}, 2.8, {sz})")
    box("Boden", pfad, 0, 0.04, 0, round(b - 1.2, 2), 0.08, round(t - 1.2, 2), "Material_boden", kollision=False)
    if schild_text:
        schild(f"Schild{name}", eltern, cx, hoehe + 1.5, cz, schild_text, 40)
    if licht:
        N(f"Licht{name}", "OmniLight3D", eltern, f"{T(cx, hoehe - 1.2, cz)}\nlight_color = Color(1, 0.82, 0.6, 1)\nomni_range = {round(max(b, t) * 0.9, 1)}")

def gebaeude_lokal(name, eltern, x, z, sx, sz, hoehe, mat="Material_hell", gier=0.0, text=""):
    box(name, eltern, x, (hoehe - 1) / 2, z, sx, hoehe + 1, sz, mat, gier=gier)
    if text:
        schild(f"Schild{name}", eltern, x, hoehe + 2, z, text, 40)


def grundgeruest(gelaende_ordner, region_eigenschaften="", wasser_name="Meer", wasser_hoehe=-20,
                 wasser_groesse=(2600, 2200), wasser_parameter=""):
    """Gemeinsame Ressourcen und die Wurzel einer Region: Himmel, Licht, Gelände und Wasserfläche."""
    E("Script", "res://szenen/welt/tageslicht.gd", "1_tageslicht")
    E("Script", "res://szenen/welt/gelaende.gd", "2_gelaende")
    E("PackedScene", "res://szenen/welt/burg_hof.tscn", "3_hof")
    E("PackedScene", "res://szenen/figuren/person.tscn", "4_person")
    E("PackedScene", "res://szenen/spieler/spieler.tscn", "5_spieler")
    E("PackedScene", "res://szenen/oberflaeche/hud.tscn", "6_hud")
    E("PackedScene", "res://szenen/oberflaeche/pausemenue.tscn", "7_pause")
    E("Shader", "res://szenen/welt/gelaende.gdshader", "8_gelaende_shader")
    E("Texture2D", f"res://daten/{gelaende_ordner}/maske.png", "9_maske")
    E("Shader", "res://szenen/welt/wasser.gdshader", "10_wasser")
    E("Script", "res://szenen/welt/auf_gelaende.gd", "11_auf_gelaende")
    E("PackedScene", "res://szenen/welt/haus.tscn", "12_haus")
    E("Script", "res://szenen/welt/ort.gd", "13_ort")
    E("Script", "res://szenen/welt/turm.gd", "14_turm")
    E("Script", "res://szenen/welt/tor.gd", "15_tor")
    E("Script", "res://szenen/welt/lesbar.gd", "16_lesbar")
    E("PackedScene", "res://szenen/oberflaeche/entwickler.tscn", "17_entwickler")
    E("Script", "res://szenen/welt/region.gd", "18_region")

    S('''[sub_resource type="ProceduralSkyMaterial" id="Himmel_material"]
    sky_top_color = Color(0.32, 0.42, 0.56, 1)
    sky_horizon_color = Color(0.68, 0.68, 0.66, 1)
    ground_bottom_color = Color(0.12, 0.11, 0.1, 1)
    ground_horizon_color = Color(0.68, 0.68, 0.66, 1)''')
    S('''[sub_resource type="Sky" id="Himmel"]
    sky_material = SubResource("Himmel_material")''')
    S('''[sub_resource type="Environment" id="Umgebung"]
    background_mode = 2
    sky = SubResource("Himmel")
    ambient_light_source = 3
    tonemap_mode = 2
    fog_enabled = true
    fog_light_color = Color(0.62, 0.64, 0.68, 1)
    fog_density = 0.0015''')
    S('''[sub_resource type="ShaderMaterial" id="Material_gelaende"]
    shader = ExtResource("8_gelaende_shader")
    shader_parameter/maske = ExtResource("9_maske")''')
    S(f'''[sub_resource type="ShaderMaterial" id="Material_wasser"]
    shader = ExtResource("10_wasser"){wasser_parameter}''')
    S(f'''[sub_resource type="PlaneMesh" id="Mesh_meer"]
    material = SubResource("Material_wasser")
    size = Vector2({wasser_groesse[0]}, {wasser_groesse[1]})
    subdivide_width = 120
    subdivide_depth = 100''')
    for name, farbe, rau in [("Material_mauer", "0.3, 0.29, 0.28", 1.0), ("Material_basalt", "0.12, 0.12, 0.14", 0.95),
                             ("Material_holz", "0.36, 0.25, 0.16", 0.9), ("Material_eis", "0.5, 0.53, 0.57", 0.85),
                             ("Material_hell", "0.55, 0.52, 0.47", 1.0), ("Material_feuer", "0.85, 0.45, 0.15", 0.6),
                             ("Material_kai", "0.38, 0.36, 0.33", 1.0), ("Material_boden", "0.42, 0.4, 0.37", 1.0),
                             ("Material_wasser_becken", "0.12, 0.22, 0.3", 0.1), ("Material_stoff", "0.45, 0.12, 0.1", 0.9),
                             ("Material_papier", "0.82, 0.76, 0.6", 0.9), ("Material_metall", "0.25, 0.25, 0.27", 0.4)]:
        S(f'''[sub_resource type="StandardMaterial3D" id="{name}"]
    albedo_color = Color({farbe}, 1)
    roughness = {rau}''')


    N("Region", "Node3D", None, 'script = ExtResource("18_region")\n' + region_eigenschaften)
    N("Umgebung", "WorldEnvironment", ".", 'environment = SubResource("Umgebung")')
    N("Mond", "DirectionalLight3D", ".", '''transform = Transform3D(0.866, 0, -0.5, 0.35, 0.714, 0.606, 0.357, -0.7, 0.618, 0, 60, 0)
    light_color = Color(0.55, 0.65, 0.95, 1)
    light_energy = 0.0''')
    N("Sonne", "DirectionalLight3D", ".", '''transform = Transform3D(1, 0, 0, 0, 0.5, 0.8660254, 0, -0.8660254, 0.5, 0, 60, 0)
    shadow_enabled = true
    directional_shadow_max_distance = 250.0
    script = ExtResource("1_tageslicht")
    umgebung = NodePath("../Umgebung")
    mond = NodePath("../Mond")''', extra='node_paths=PackedStringArray("umgebung", "mond")')
    N("Gelaende", "Node3D", ".", f'''script = ExtResource("2_gelaende")
    material = SubResource("Material_gelaende")
    daten = "res://daten/{gelaende_ordner}/"''')
    N(wasser_name, "MeshInstance3D", ".", f'''transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {wasser_hoehe}, 0)
    mesh = SubResource("Mesh_meer")''')


def spieler_und_oberflaeche(x, y, z):
    N("Spieler", None, ".", T(x, y, z), instanz="5_spieler")
    N("HUD", None, ".", 'spieler = NodePath("../Spieler")', instanz="6_hud", extra='node_paths=PackedStringArray("spieler")')
    N("Pausemenue", None, ".", "", instanz="7_pause")
    N("Entwickler", None, ".", "", instanz="17_entwickler")
