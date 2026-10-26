# ---------- Schwarzer Bergfried ----------
# Begehbarer Turm nach dem Schnitt: Unterbau (Ebenen -4 bis -1), Schwelle, Schaft, Krone.
BF = "SchwarzerBergfried"
BF_WINKEL = round(math.degrees(math.atan2(95 - 135, 212 - 250)), 2)  # Richtung zur Brücke: Eingang und Treppentür
BF_BODEN = [-24, -18, -12, -6, 0, 8, 15, 22, 29, 37, 44, 53, 60, 68]
BF_NUMMERN = list(range(-4, 9))
BF_NAMEN = ["Sonderzellen", "Zellentrakt", "Zisternen", "Interne Sicherung", "Schwelle", "Wachring",
            "Unterkünfte", "Ausbildung", "Archive", "Stillebene", "Thronsaal", "Vorbereitung", "Observatorium"]
BF_RADIEN = [20, 20, 20, 20, 20, 19, 18.5, 18, 17.5, 17, 19, 20, 20.5]
BF_STAERKEN = [10, 10, 10, 10, 8, 5, 5, 5, 5, 5, 3, 3, 3]
liste = lambda werte, typ: f"{typ}(" + ", ".join(str(w) for w in werte) + ")"
N(BF, "Node3D", ".", f"""{T(250, -17.8, 135)}
script = ExtResource("14_turm")
ebenen_nummern = {liste(BF_NUMMERN, "PackedInt32Array")}
ebenen_namen = PackedStringArray({", ".join('"%s"' % n for n in BF_NAMEN)})
boden_hoehen = {liste(BF_BODEN, "PackedFloat32Array")}
aussen_radien = {liste(BF_RADIEN, "PackedFloat32Array")}
wandstaerken = {liste(BF_STAERKEN, "PackedFloat32Array")}
eingaenge = PackedVector2Array(0, {BF_WINKEL})
achteck_winkel = {BF_WINKEL}
treppen_winkel = {BF_WINKEL}
saeulen_radius = 1.9
wasserdicht = true
material_wand = SubResource("Material_basalt")
material_boden = SubResource("Material_boden")
material_rampe = SubResource("Material_holz")""")

def polar(r, winkel, y):
    a = math.radians(winkel)
    return (round(r*math.cos(a), 3), y, round(r*math.sin(a), 3))

def mobel(name, ebene, r, winkel, sx, sy, sz, mat, ausrichtung="radial", kollision=True, eltern=BF):
    """Möbelstück im Bergfried: Position in Polarkoordinaten, steht auf dem Boden der Ebene."""
    y = BF_BODEN[BF_NUMMERN.index(ebene)] + sy / 2
    x, _, z = polar(r, winkel, y)
    gier = -winkel if ausrichtung == "radial" else -winkel + 90
    box(name, eltern, x, y, z, sx, sy, sz, mat, gier=gier, kollision=kollision)

# Zellen im Unterbau: Trennwände und Gitter
for ebene, anzahl in [(-4, 4), (-3, 8)]:
    for k in range(anzahl):
        w = BF_WINKEL + 180 / anzahl + k * 360 / anzahl
        mobel(f"Trennwand{ebene + 5}_{k}", ebene, 6.5, w, 3.8, 4.5, 0.4, "Material_basalt")
        mobel(f"Gitter{ebene + 5}_{k}", ebene, 4.9, w + 180 / anzahl, 0.1, 3.0, 2.2, "Material_metall", "tangential", False)
for k, w in enumerate([-60, 30, 120]):
    mobel(f"Zisterne{k}", -2, 6.6, BF_WINKEL + 60 + w, 2.6, 0.15, 3.0, "Material_wasser_becken", kollision=False)
    mobel(f"ZisterneRand{k}", -2, 6.6, BF_WINKEL + 60 + w, 3.2, 0.5, 3.6, "Material_basalt")
mobel("Wachtisch", -1, 7.0, BF_WINKEL + 120, 1.0, 1.0, 2.4, "Material_holz")
mobel("Waffenstaender", -1, 8.0, BF_WINKEL + 200, 0.4, 2.0, 2.0, "Material_metall")
for k in range(8):
    mobel(f"Wachposten{k}", 1, 11.4, BF_WINKEL + 22.5 + k * 45, 0.6, 1.2, 1.4, "Material_holz")
for k in range(10):
    mobel(f"Bett{k}", 2, 10.6, BF_WINKEL + 30 + k * 30, 2.0, 0.6, 0.9, "Material_stoff")
for k in range(4):
    mobel(f"Lehrtisch{k}", 3, 8.0, BF_WINKEL + 60 + k * 60, 1.2, 0.9, 2.6, "Material_holz")
    mobel(f"Uebungspuppe{k}", 3, 10.0, BF_WINKEL + 90 + k * 60, 0.5, 1.8, 0.5, "Material_stoff")
for k in range(12):
    mobel(f"Regal{k}", 4, 9.6, BF_WINKEL + 30 + k * 27, 2.6, 3.4, 0.6, "Material_holz")
mobel("Lesetisch", 4, 6.8, BF_WINKEL + 180, 1.4, 0.95, 2.2, "Material_holz")
# Namensbuch auf dem Lesetisch
y_nb = BF_BODEN[BF_NUMMERN.index(4)]
nx, _, nz = polar(6.8, BF_WINKEL + 180, 0)
N("Namensbuch", "StaticBody3D", BF, f"""{T(nx, y_nb + 1.0, nz, -(BF_WINKEL + 180))}
script = ExtResource("16_lesbar")
anzeige_name = "Das Namensbuch"
dialog_id = "namensbuch\"""")
box("Buch", BF + "/Namensbuch", 0, 0.08, 0, 0.6, 0.16, 0.8, "Material_papier", kollision=False)
S('''[sub_resource type="BoxShape3D" id="Form_buch"]
size = Vector3(0.8, 0.3, 1.0)''')
N("Form", "CollisionShape3D", BF + "/Namensbuch", 'shape = SubResource("Form_buch")')
# Ebene 5, die Stillebene, bleibt vollständig leer.
mobel("Tafel", 6, 10.0, BF_WINKEL + 180, 1.2, 0.9, 8.0, "Material_holz", "tangential")
mobel("Stuhl", 6, 13.0, BF_WINKEL + 180, 0.8, 1.4, 0.8, "Material_holz")
for k in range(3):
    mobel(f"Kartentisch{k}", 7, 9.5, BF_WINKEL + 90 + k * 90, 1.4, 0.95, 2.4, "Material_holz")
mobel("Fernrohr", 8, 12.0, BF_WINKEL + 180, 0.4, 2.2, 0.4, "Material_metall")
mobel("Sternkarte", 8, 9.0, BF_WINKEL + 120, 1.4, 0.95, 2.4, "Material_papier")
# Auf dem Dach: das Feuerbecken für das erste Feuer
fx, _, fz = polar(9.0, BF_WINKEL + 180, 0)
N("Feuerbecken", "StaticBody3D", BF, f"""{T(fx, 68, fz)}
script = ExtResource("16_lesbar")
anzeige_name = "Feuerbecken des ersten Feuers"
aktion_text = "Ansehen"
dialog_id = "feuerbecken\"""")
zyl("Becken", BF + "/Feuerbecken", 0, 0.6, 0, 1.6, 1.2, "Material_metall", 12, False)
zyl("Asche", BF + "/Feuerbecken", 0, 1.22, 0, 1.4, 0.05, "Material_basalt", 12, False)
S('''[sub_resource type="CylinderShape3D" id="Form_becken"]
height = 1.2
radius = 1.6''')
N("Form", "CollisionShape3D", BF + "/Feuerbecken", f'{T(0, 0.6, 0)}\nshape = SubResource("Form_becken")')
# Tor in der Außenmauer: verschlossen, bis der Bergwächter es öffnet
tx, _, tz = polar(16.2, BF_WINKEL, 0)
N("Tor", "StaticBody3D", BF, f"""{T(tx, 2.5, tz, -BF_WINKEL)}
script = ExtResource("15_tor")
bedingung = "bergfried_zugang"
anzeige_name = "Tor des Bergfrieds"
text_geschlossen = "Das Tor ist verschlossen. Nur der Bergwächter öffnet es."
""")
box("Fluegel", BF + "/Tor", 0, 0, 0, 0.5, 5, 4, "Material_holz", kollision=False)
S('''[sub_resource type="BoxShape3D" id="Form_tor_bergfried"]
size = Vector3(0.5, 5, 4)''')
N("Form", "CollisionShape3D", BF + "/Tor", 'shape = SubResource("Form_tor_bergfried")')
# Leofa Marsh, Hüterin der Stille, in den Archiven
lx, _, lz = polar(6.8, BF_WINKEL + 150, 0)
person("LeofaMarsh", BF, lx, y_nb, lz, "Hüterin der Stille Leofa Marsh", "leofa_marsh", 3, "0.1, 0.1, 0.12, 1", gier=-(BF_WINKEL + 150) + 90)
# Die Stillebene als Ort
S('''[sub_resource type="CylinderShape3D" id="Form_stillebene"]
height = 6.0
radius = 11.0''')
N("Stillebene", "Area3D", BF, f'''{T(0, 40, 0)}
script = ExtResource("13_ort")
ortsname = "Die Stillebene"
untertitel = "Vollständig leer. Ohne Zweck außer dem Innehalten."''')
N("Form", "CollisionShape3D", BF + "/Stillebene", 'shape = SubResource("Form_stillebene")')
# Äußere Mauer der Insel mit Durchgang zur Brücke
N("AeussereMauer", "CSGCombiner3D", BF, "use_collision = true")
zyl("Ring", BF + "/AeussereMauer", 0, 3, 0, 31, 6, "Material_basalt", 16, False)
N("Innen", "CSGCylinder3D", BF + "/AeussereMauer", """transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 3, 0)
operation = 2
radius = 29.5
height = 7.0
sides = 16""")
_dg = polar(30.05, BF_WINKEL, 2.5)
N("Durchgang", "CSGBox3D", BF + "/AeussereMauer", f"""{T(_dg[0], 2.5, _dg[2], -BF_WINKEL)}
operation = 2
size = Vector3(6, 5, 6)""")
schild("Schild", BF, 0, 76, 0, "Schwarzer Bergfried", 96)
