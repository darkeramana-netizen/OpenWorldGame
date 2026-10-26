# ---------- Gravecrest nach dem Grundriss ----------
# Grundriss in Bildpunkten, umgerechnet: Torhaus-Ostkante (1240 px) liegt bei x = -630,
# die Mittellinie des Sporns (355 px) bei z = -365. 1 px = 0,119 m (halber Maßstab des Plans).
GC = "Gravecrest"
PX = 0.119
gx = lambda px: round(-630 - (1240 - px) * PX, 2)
gz = lambda py: round(-365 + (py - 355) * PX, 2)
N(GC, "Node3D", ".", T(0, 70.02, 0))
WAND = 0.6

def raum(name, px0, py0, px1, py1, hoehe, tueren, mat="Material_eis", schild_text="", licht=False, tuer_breite=2.2, tuer_hoehe=2.8):
    """Hohler Raum mit Dach. tueren: Liste (Seite, Lage in px) mit Seite N, S, O, W."""
    x0, x1, z0, z1 = gx(px0), gx(px1), gz(py0), gz(py1)
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    b, t = round(x1 - x0, 2), round(z1 - z0, 2)
    pfad = f"{GC}/{name}"
    N(name, "CSGCombiner3D", GC, f"{T(cx, 0, cz)}\nuse_collision = true")
    box("Aussen", pfad, 0, hoehe / 2, 0, b, hoehe, t, mat, kollision=False)
    N("Innen", "CSGBox3D", pfad, f"{T(0, (hoehe - 0.6 - 0.2) / 2, 0)}\noperation = 2\nsize = Vector3({round(b - 2*WAND, 2)}, {round(hoehe - 0.4, 2)}, {round(t - 2*WAND, 2)})")
    for k, (seite, lage) in enumerate(tueren):
        if seite in "NS":
            dx, dz, sx, sz = gx(lage) - cx, (-t / 2 if seite == "N" else t / 2), tuer_breite, WAND * 3
        else:
            dx, dz, sx, sz = (b / 2 if seite == "O" else -b / 2), gz(lage) - cz, WAND * 3, tuer_breite
        N(f"Tuer{k}", "CSGBox3D", pfad, f"{T(round(dx, 2), tuer_hoehe / 2 - 0.1, round(dz, 2))}\noperation = 2\nsize = Vector3({sx}, {tuer_hoehe}, {sz})")
    # Steinboden im Raum (zuletzt, damit ihn die Türen nicht ausschneiden)
    box("Boden", pfad, 0, 0.04, 0, round(b - 2*WAND, 2), 0.08, round(t - 2*WAND, 2), "Material_boden", kollision=False)
    if schild_text:
        N(f"Schild{name}", "Label3D", GC, f"""{T(cx, hoehe - 1.6, cz)}
billboard = 1
pixel_size = 0.006
text = "{schild_text}"
font_size = 48
outline_size = 10""")
    if licht:
        N(f"Licht{name}", "OmniLight3D", GC, f"{T(cx, hoehe - 1.2, cz)}\nlight_color = Color(1, 0.82, 0.6, 1)\nomni_range = {round(max(b, t) * 0.9, 1)}")
    return cx, cz

# Palas-Block (West)
raum("Audienzsaal", 170, 210, 255, 305, 9, [("O", 260)], schild_text="3 · Audienzsaal", licht=True)
raum("Kaisersaal", 255, 210, 330, 305, 9, [("W", 260), ("O", 260), ("S", 292)], schild_text="1 · Kaisersaal", licht=True)
raum("ImperialeGemaecher", 330, 210, 375, 305, 9, [("W", 260), ("S", 352)], schild_text="2 · Imperiale Gemächer", licht=True)
raum("Halle", 330, 305, 380, 395, 9, [("N", 352), ("O", 350), ("W", 350), ("S", 352)], schild_text="Halle des Palas")
raum("KapelleDesSorrow", 260, 305, 330, 395, 9, [("O", 350), ("W", 350), ("N", 292)], schild_text="8 · Kapelle des Sorrow", licht=True)
raum("Garderobe", 165, 305, 260, 395, 9, [("O", 350), ("S", 195)], schild_text="6 · Garderobe", licht=True)
raum("Bibliothek", 165, 395, 225, 470, 9, [("N", 195), ("O", 432)], schild_text="4 · Bibliothek", licht=True)
raum("Schreibstube", 225, 395, 295, 470, 9, [("W", 432), ("O", 432)], schild_text="5 · Schreibstube und Archiv", licht=True)
raum("Speisesaal", 295, 395, 380, 470, 9, [("W", 432), ("N", 352)], schild_text="7 · Speisesaal", licht=True)
# Oberer Hof: Gebäude im Norden (Tür nach Süden) und Süden (Tür nach Norden)
raum("Brunnenhaus", 385, 232, 418, 275, 5, [("S", 401)], schild_text="14 · Brunnenhaus")
raum("SchmiedeOben", 420, 232, 478, 282, 6, [("S", 449)], schild_text="9 · Schmiede", licht=True)
raum("Ruestungskammer", 480, 228, 535, 282, 6, [("S", 507)], schild_text="12 · Garderobe und Rüstungskammer")
raum("Wachraum", 572, 232, 618, 282, 6, [("S", 595)], schild_text="11 · Wachraum und Waffenpflege")
raum("ApothekeOben", 383, 428, 452, 478, 6, [("N", 417)], schild_text="10 · Apotheke", licht=True)
raum("WachzimmerOben", 500, 425, 578, 478, 6, [("N", 539)], schild_text="13 · Wachzimmer")
# Unterer Hof
raum("Kaserne", 818, 205, 888, 272, 7, [("S", 853)], schild_text="18 · Kaserne", licht=True)
raum("ApothekeUnten", 915, 215, 975, 272, 6, [("S", 945)], schild_text="16 · Apotheke")
raum("Lager", 975, 225, 1035, 285, 6, [("S", 1005)], schild_text="16 · Apotheke (Vorräte)")
raum("WachzimmerUnten", 1078, 248, 1132, 300, 6, [("S", 1105)], schild_text="17 · Wachzimmer")
raum("WerkstattNord", 1138, 255, 1172, 300, 6, [("S", 1155)], schild_text="23 · Werkstätten")
raum("SchmiedeUnten", 778, 278, 832, 340, 6, [("O", 309)], schild_text="15 · Schmiede", licht=True)
raum("BrunnenhausUnten", 778, 385, 826, 430, 5, [("O", 407)], schild_text="24 · Brunnenhaus")
raum("Speicher", 815, 425, 888, 488, 7, [("N", 851)], schild_text="21 · Große Speicher")
raum("Staelle", 935, 440, 1012, 488, 6, [("N", 973)], schild_text="22 · Ställe und Tierhof")
raum("Akademie", 1033, 410, 1095, 472, 7, [("N", 1064)], schild_text="19 · Akademie", licht=True)
raum("Badehaus", 1095, 415, 1132, 468, 6, [("N", 1113)], schild_text="20 · Badehaus", licht=True)
raum("WerkstattSued", 1138, 420, 1172, 470, 6, [("N", 1155)], schild_text="23 · Werkstätten")
# Torhaus mit Durchgang und Fallgatter
raum("Torhaus", 1172, 300, 1240, 410, 13, [("W", 355), ("O", 355)], schild_text="26 · Torhaus", tuer_breite=4.4, tuer_hoehe=4.8)
N("Fallgatter", "StaticBody3D", GC, f"""{T(gx(1215), 2.4, gz(355))}
script = ExtResource("15_tor")
bedingung = "gravecrest_zugang"
anzeige_name = "Fallgatter"
text_geschlossen = "Das Fallgatter ist unten. Ohne Auftrag kommt hier niemand hinein."
""")
for k in range(5):
    box(f"Stab{k}", GC + "/Fallgatter", 0, 0, -1.8 + k * 0.9, 0.15, 4.8, 0.15, "Material_metall", kollision=False)
box("Querstab", GC + "/Fallgatter", 0, 1.2, 0, 0.15, 0.15, 4.4, "Material_metall", kollision=False)
S('''[sub_resource type="BoxShape3D" id="Form_fallgatter"]
size = Vector3(0.4, 4.8, 4.4)''')
N("Form", "CollisionShape3D", GC + "/Fallgatter", 'shape = SubResource("Form_fallgatter")')
box("Zugbruecke", GC, -621, -0.32, -364.8, 19, 0.6, 5, "Material_holz")
# Türme
for name, px, py, r in [("TorturmNord", 1225, 298, 3.3), ("TorturmSued", 1225, 417, 3.3), ("TurmPalasNord", 373, 200, 3.4),
                        ("TurmPalasSued", 367, 492, 3.4), ("TurmOstNord", 1043, 213, 3.4), ("TurmOstSued", 1040, 482, 3.4)]:
    zyl(name, GC, gx(px), 8, gz(py), r, 16, "Material_eis", 12)
# Wehrmauern entlang der Kanten, und vom Donjon zu den Außenmauern
for name, a, b, py in [("MauerNordWest", 375, 640, 198), ("MauerNordOst", 725, 1172, 205),
                       ("MauerSuedWest", 375, 640, 494), ("MauerSuedOst", 725, 1172, 490)]:
    box(name, GC, (gx(a) + gx(b)) / 2, 3, gz(py), round(gx(b) - gx(a), 2), 6, 1.2, "Material_eis")
for name, a, b in [("DonjonMauerNord", 198, 278), ("DonjonMauerSued", 422, 494)]:
    box(name, GC, gx(683), 3, (gz(a) + gz(b)) / 2, 1.2, 6, round(gz(b) - gz(a), 2), "Material_eis")
# Brunnen in den Höfen
for name, px, py in [("BrunnenOben", 490, 385), ("BrunnenUnten", 960, 375)]:
    zyl(name, GC, gx(px), 0.5, gz(py), 1.3, 1.0, "Material_mauer", 12)
# Donjon (25): achteckig, Eingänge zu beiden Höfen, Signalfeuerplattform oben
N("Donjon", "Node3D", GC, f"""{T(gx(683), 0, gz(350))}
script = ExtResource("14_turm")
ebenen_nummern = PackedInt32Array(0, 1, 2)
ebenen_namen = PackedStringArray("Wachstube", "Kartenkammer", "Notunterkunft")
boden_hoehen = PackedFloat32Array(0, 6, 11.5, 17)
aussen_radien = PackedFloat32Array(9, 9, 9)
wandstaerken = PackedFloat32Array(2.5, 2.5, 2.5)
eingaenge = PackedVector2Array(0, 0, 0, 180)
eingang_breite = 3.0
eingang_hoehe = 4.0
treppen_winkel = 90.0
treppenhaus_radius = 3.6
saeulen_radius = 1.4
material_wand = SubResource("Material_eis")
material_boden = SubResource("Material_boden")
material_rampe = SubResource("Material_holz")""")
box("Kartentisch", GC + "/Donjon", -5.5, 6.48, 0, 1.6, 0.95, 2.6, "Material_papier")
for k in range(4):
    box(f"Pritsche{k}", GC + "/Donjon", -5.0, 11.8, -3 + k * 2, 2.0, 0.6, 0.9, "Material_stoff")
N("Signalfeuer", "Node3D", GC + "/Donjon", T(-4.5, 17, 0))
zyl("Becken", GC + "/Donjon/Signalfeuer", 0, 0.5, 0, 1.2, 1.0, "Material_feuer", 10)
# Einrichtung einiger Räume
box("Thron", GC, gx(318), 1.2, gz(258), 1.4, 2.4, 1.4, "Material_holz")
box("Teppich", GC, gx(290), 0.03, gz(258), 7, 0.05, 2.2, "Material_stoff", kollision=False)
box("Tafel", GC, gx(338), 0.48, gz(432), 6.5, 0.95, 1.4, "Material_holz")
for k in range(3):
    box(f"Regal{k}", GC, gx(175), 1.7, gz(410 + k * 20), 0.6, 3.4, 2.0, "Material_holz")
box("Altar", GC, gx(270), 0.6, gz(350), 1.0, 1.2, 2.0, "Material_hell")
box("Amboss", GC, gx(449), 0.45, gz(262), 0.6, 0.9, 1.0, "Material_metall")
box("Esse", GC, gx(805), 0.8, gz(300), 1.6, 1.6, 2.0, "Material_feuer")
for k in range(4):
    box(f"Pritsche{k}", GC, gx(830 + k * 15), 0.3, gz(220), 1.0, 0.6, 2.0, "Material_stoff")
for k in range(3):
    box(f"Pult{k}", GC, gx(1050 + k * 15), 0.45, gz(450), 1.2, 0.9, 0.8, "Material_holz")
box("Wasserbecken", GC, gx(1113), 0.05, gz(445), 3.0, 0.1, 4.0, "Material_wasser_becken", kollision=False)
for k in range(3):
    box(f"Kiste{k}", GC, gx(830 + k * 18), 0.5, gz(465), 1.4, 1.0, 1.4, "Material_holz")
# Flaschenzug an der Westseite: Balken über dem Abgrund, Seil, Korb
box("FlaschenzugBalken", GC, gx(140), 9.5, gz(300), 9.0, 0.5, 0.5, "Material_holz", kollision=False)
box("FlaschenzugSeil", GC, gx(100), -4.5, gz(300), 0.08, 28, 0.08, "Material_holz", kollision=False)
box("FlaschenzugKorb", GC, gx(100), -19, gz(300), 1.6, 1.4, 1.6, "Material_holz", kollision=False)
schild("Schild", GC, gx(683), 30, gz(350), "Gravecrest")
# Komtur Torben Wick im Audienzsaal
person("TorbenWick", GC, gx(212), 0, gz(258), "Komtur Torben Wick", "torben_wick", 3, "0.18, 0.2, 0.24, 1", gier=-90)
