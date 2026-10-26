# ---------- Gravemarch nach dem Grundriss ----------
# Der Plan ist um 180° gedreht: Das Äußere Torhaus (A) liegt im Nordosten am Weg aus Drachenstein,
# die Kernburg (G) im Süden. Umrechnung: x = -(px - 620) * 0,2, z = -(py - 255) * 0,26 (Bildpunkte
# des Plans, die Höhe ist gestreckt, weil der Plan schräg von oben gezeichnet ist).
# Lokale Koordinaten relativ zur Mitte (-600, -205); der Hügel liegt flach auf Höhe -4 (lokal 0).
GMX, GMZ = -600, -205
G = "Gravemarch"
N(G, "Node3D", ".", T(GMX, -4, GMZ))
LH = lambda x, z: H(GMX + x, GMZ + z) + 4  # Geländehöhe lokal

S('''[sub_resource type="StandardMaterial3D" id="Material_graben"]
albedo_color = Color(0.16, 0.22, 0.2, 1)
roughness = 0.15''')
S('''[sub_resource type="PlaneMesh" id="Mesh_graben"]
material = SubResource("Material_graben")
size = Vector2(220, 190)''')
N("Grabenwasser", "MeshInstance3D", G, f'{T(0, -7.5, 0)}\nmesh = SubResource("Mesh_graben")')

# --- Hauptmauer (Höhe wie im Plan: 15,6 m über dem Tal, hier 10 m über dem Hügel) ---
AUSSEN = [(51, -48.1), (64, -37.7), (41, -6.5), (31, 37.7), (22, 50.7), (4, 54.6), (-26, 52), (-43, 44.2),
          (-54, 39), (-60, 23.4), (-63, -11.7), (-65, -32.5), (-48, -40.3), (-36, -35), (-19, -37.7), (4, -45.5),
          (22, -35), (39, -45.5)]
HM = G + "/Hauptmauer"
N("Hauptmauer", "Node3D", G)
mauerzug("Mauer", HM, AUSSEN, 10, luecken={0: (0.5, 4.6)}, geschlossen=True)
for i, (x, z) in enumerate(AUSSEN):
    if i in (0, 1):
        continue  # am Torhaus stehen eigene Türme
    zyl(f"Turm{i}", HM, x, 6, z, 3.0 if i != 8 else 6.0, 16, "Material_mauer", 10)
schild("SchildBastei", HM, -54, 16, 39, "N · Nordost-Bastei", 40)  # Bastei des Plans (gedreht)

# --- A: Äußeres Torhaus mit Brücke über den Graben und Brückenpforte (2) ---
tx, tz = (51 + 64) / 2, (-48.1 + -37.7) / 2
ux, uz = 64 - 51, -37.7 + 48.1; ul = math.hypot(ux, uz); ux, uz = ux / ul, uz / ul   # entlang der Mauer
nx, nz = uz, -ux                                                                       # nach außen
TH = G + "/Torhaus"
N("Torhaus", "Node3D", G)
for seite in (-1, 1):
    box(f"Torturm{seite + 1}", TH, round(tx + ux * 4.4 * seite, 2), 6, round(tz + uz * 4.4 * seite, 2), 4.2, 16, 7,
        "Material_mauer", gier=round(gier_zu(ux, uz), 2))
box("Torbogen", TH, tx, 10.5, tz, 4.8, 3, 7, "Material_mauer", gier=round(gier_zu(ux, uz), 2))
schild("Schild", TH, round(tx + nx * 4, 2), 13.5, round(tz + nz * 4, 2), "A · Äußeres Torhaus", 40)
# Brücke: flach von der Torschwelle über die Böschung, dann schräg hinab zum Ufer jenseits des Grabens
d0, dk, d1 = -1.0, 9.5, 19.5
ufer = LH(tx + nx * d1, tz + nz * d1)
def deck(d):
    return 0.02 if d <= dk else 0.02 + (ufer - 0.02) * (d - dk) / (d1 - dk)
mx, mz = tx + nx * (d0 + dk) / 2, tz + nz * (d0 + dk) / 2
box("BrueckeFlach", TH, round(mx, 2), -0.28, round(mz, 2), dk - d0, 0.6, 4.2, "Material_holz", gier=round(gier_zu(nx, nz), 2))
laenge = d1 + 0.6 - dk
neigung = math.atan2(ufer - 0.02, d1 - dk)
md = (dk + d1 + 0.6) / 2
my = deck(md) - 0.3 * math.cos(neigung)
md += 0.3 * math.sin(neigung)
N("Bruecke", "CSGBox3D", TH, f"""{T_kipp(round(tx + nx * md, 3), round(my, 3), round(tz + nz * md, 3), gier_zu(nx, nz), math.degrees(neigung))}
use_collision = true
size = Vector3({round(laenge / math.cos(neigung), 2)}, 0.6, 4.2)
material = SubResource("Material_holz")""")
for k, d in enumerate([8.5, 14.5]):
    oben = deck(d) - 0.65
    box(f"Pfeiler{k}", TH, round(tx + nx * d, 2), round((oben - 9.5) / 2, 2), round(tz + nz * d, 2), 1.4, round(oben + 9.5, 2), 3.4,
        "Material_mauer", gier=round(gier_zu(nx, nz), 2))
for seite in (-1, 1):
    px, pz = tx + nx * (d1 + 1) + ux * 3.4 * seite, tz + nz * (d1 + 1) + uz * 3.4 * seite
    box(f"Pforte{seite + 1}", TH, round(px, 2), round(ufer + 3, 2), round(pz, 2), 2.4, 7, 2.4, "Material_mauer")
box("PforteBogen", TH, round(tx + nx * (d1 + 1), 2), round(ufer + 5.5, 2), round(tz + nz * (d1 + 1), 2), 9.2, 1.4, 2.4,
    "Material_mauer", gier=round(gier_zu(ux, uz), 2))
schild("SchildPforte", TH, round(tx + nx * (d1 + 1), 2), round(ufer + 8, 2), round(tz + nz * (d1 + 1), 2), "2 · Brückenpforte", 40)
PFORTE = (tx + nx * (d1 + 3), ufer, tz + nz * (d1 + 3))

# --- M: Alte Mauer (mittlerer Ring) mit Tor am Zwinger und einem zugemauerten Scheintor ---
MITTE = [(27.6, 44.5), (29, 4), (18, -4), (-4, -9), (-24, -3), (-32, 8), (-34, 30), (-40.5, 47.5)]
MR = G + "/AlteMauer"
N("AlteMauer", "Node3D", G)
mauerzug("Mauer", MR, MITTE, 8, 2.2, luecken={0: ((44.5 - 18) / 40.5, 4.0)})
for i, (x, z) in enumerate(MITTE[1:-1]):
    zyl(f"Turm{i}", MR, x, 5, z, 2.4, 12, "Material_mauer", 10)
schild("SchildTor", MR, 31, 9, 18, "Tor der Alten Mauer", 36)
schild("SchildZwinger", MR, 34, 4, 0, "5 · Zwinger (Enge Gasse)", 36)
tuerblatt("Scheintor", MR, -14.4, -7.8, -0.29, -0.96, "gravemarch_scheintor", "Tor in der Alten Mauer",
          "Das Tor rührt sich nicht. Dahinter ist es zugemauert, seit Jahrhunderten schon.")

# --- F: Innerer Wehrgang (Ring um Burghof und Kernburg) mit geknicktem Tor (6) ---
INNEN = [(15.5, 53.5), (13, 26), (-2, 12), (-20, 12), (-27, 30), (-30.5, 51.5)]
IR = G + "/InnererRing"
N("InnererRing", "Node3D", G)
mauerzug("Mauer", IR, INNEN, 9, 2.4, luecken={2: (0.5, 3.6)})
for i, (x, z) in enumerate(INNEN[2:-1]):
    zyl(f"Turm{i}", IR, x, 5.5, z, 2.4, 13, "Material_mauer", 10)
zyl("AlterWehrturm", IR, 13, 8, 26, 3.6, 18, "Material_basalt", 10)
schild("SchildWehrturm", IR, 13, 19, 26, "4 · Alter Wehrturm", 36)
box("Prallwand", IR, -11, 2.5, 16.5, 8, 5, 0.8, "Material_mauer")   # zwingt hinter dem Tor zum Abbiegen
box("Prallwand2", IR, -6.6, 2.5, 14.2, 0.8, 5, 5.4, "Material_mauer")
schild("SchildTor", IR, -11, 10.5, 11, "6 · Geknicktes Tor", 36)

# --- G: Kernburg mit Burghof (E), Donjon (18), Palas mit Großer Halle (14, 15), Bibliothek (17) ---
KB = G + "/Kernburg"
N("Kernburg", "Node3D", G)
N("Donjon", "Node3D", KB, f"""{T(2, 0, 43)}
script = ExtResource("14_turm")
ebenen_nummern = PackedInt32Array(0, 1, 2, 3)
ebenen_namen = PackedStringArray("Wachstube", "Waffenkammer", "Kommandantur", "Ausguck")
boden_hoehen = PackedFloat32Array(0, 5.5, 11, 16.5, 22)
aussen_radien = PackedFloat32Array(9, 9, 9, 9)
wandstaerken = PackedFloat32Array(2.5, 2.5, 2.5, 2.5)
eingaenge = PackedVector2Array(0, -135)
eingang_breite = 3.0
eingang_hoehe = 4.0
treppen_winkel = -135.0
treppenhaus_radius = 3.6
saeulen_radius = 1.4
material_wand = SubResource("Material_basalt")
material_boden = SubResource("Material_boden")
material_rampe = SubResource("Material_holz")""")
box("Kartentisch", KB + "/Donjon", 0, 11.48, 4.6, 2.6, 0.95, 1.4, "Material_papier")
for k in range(3):
    box(f"Waffenstaender{k}", KB + "/Donjon", -4.4 + k * 2.2, 6.5, 4.4, 0.4, 2.0, 1.6, "Material_metall")
schild("SchildDonjon", KB, 2, 26, 43, "18 · Donjon", 40)
gebaeude_lokal("Palas", KB, -16, 47.5, 16, 7, 12, text="14 · Palas · 15 · Große Halle")
zyl("Treppenturm", KB, -6, 8.5, 51.5, 2.0, 19, "Material_mauer", 8)
raum_lokal("Bibliothek", KB, -21, 31, -9, 40, 7, [("N", -15)], schild_text="17 · Bibliothek / Archiv", licht=True)
for k in range(4):
    box(f"Regal{k}", KB, -19.6 + k * 2.9, 1.7, 38.9, 2.2, 3.4, 0.6, "Material_holz")
box("Lesepult", KB, -15, 0.5, 35.5, 2.0, 1.0, 1.0, "Material_holz")
zyl("Brunnen", KB, -14, 0.5, 24, 1.3, 1.0, "Material_mauer", 12)
schild("SchildBurghof", KB, -14, 5, 24, "E · Burghof", 40)
# 3 · Vorhof mit Halle: offene Halle auf Pfosten
for k, (x, z) in enumerate([(-1, 24), (5, 24), (-1, 30), (5, 30)]):
    box(f"HallePfosten{k}", KB, x, 2, z, 0.5, 4, 0.5, "Material_holz")
box("HalleDach", KB, 2, 4.2, 27, 7.4, 0.4, 7.4, "Material_holz", kollision=False)
# 19 · Verborgene Pforte in der Hauptmauer hinter dem Palas
tuerblatt("VerborgenePforte", KB, -28 + 0.417 * 1.45, 51.1 - 0.909 * 1.45, 0.417, -0.909, "gravemarch_pforte",
          "Verborgene Pforte", "Eine schmale Pforte, kaum zu sehen. Sie ist von außen verriegelt.", 1.6, 2.6)

# --- Zwischen Alter Mauer und Innerem Ring: Kapellenbezirk (O), Wasserwerk und Zisternen (K) ---
MB = G + "/Kapellenbezirk"
N("Kapellenbezirk", "Node3D", G)
raum_lokal("KapelleStAlrik", MB, 4, -3, 14, 6.5, 8, [("S", 9)], schild_text="16 · Kapelle St. Alriks", licht=True)
box("Altar", MB, 9, 0.6, -1.8, 2.2, 1.2, 1.0, "Material_hell")
zyl("Glockenturm", MB, 13, 7, -3, 1.6, 14, "Material_hell", 8)
gebaeude_lokal("Wasserwerk", MB, 21, 38, 8, 7, 7, mat="Material_mauer", text="K · Wasserwerk")
box("ZisterneRand", MB, 20, 0.3, 27.5, 6.4, 0.6, 6.4, "Material_mauer")
box("Zisterne", MB, 20, 0.62, 27.5, 5.4, 0.05, 5.4, "Material_wasser_becken", kollision=False)
schild("SchildZisterne", MB, 20, 3, 27.5, "21 · Zisternenhof", 36)

# --- Vorburg (B) und die Viertel zwischen Hauptmauer und Alter Mauer ---
VB = G + "/Vorburg"
N("Vorburg", "Node3D", G)
zyl("BrunnenMittlererHof", VB, -12, 0.5, -24, 1.3, 1.0, "Material_mauer", 12)
schild("SchildMittlererHof", VB, -12, 5, -24, "D · Mittlerer Hof", 40)
gebaeude_lokal("Schmiede", VB, -26, -16, 7, 6, 5, mat="Material_mauer", text="11 · Schmiedegasse")
box("Esse", VB, -26, 0.8, -12.4, 1.6, 1.6, 1.2, "Material_feuer")
schild("SchildMarkt", VB, -50, 5, -18, "C · Alter Markt", 40)
for k, (x, z) in enumerate([(-55, -24), (-46, -24), (-55, -12), (-45, -11)]):
    box(f"Stand{k}", VB, x, 0.5, z, 3, 1.0, 2, "Material_holz")
    box(f"StandDach{k}", VB, x, 2.4, z, 3.4, 0.15, 2.4, "Material_stoff", kollision=False)
gebaeude_lokal("Muehle", VB, -55, 5, 8, 9, 8, mat="Material_holz", text="22 · Mühle & Wehr")
N("Wasserrad", "CSGCylinder3D", VB, f"""transform = Transform3D(0, -1, 0, 1, 0, 0, 0, 0, 1, -67.5, -3.5, 5)
radius = 3.5
height = 1.2
sides = 12
material = SubResource("Material_holz")""")
gebaeude_lokal("Wachhaus", VB, -50, 24, 7, 7, 6, mat="Material_mauer", text="8 · Wachhaus")
gebaeude_lokal("Speicherhof", VB, -44, 34, 6, 9, 7, mat="Material_holz", text="10 · Speicherhof")
schild("SchildVorburg", VB, 24, 6, -22, "B · Vorburg & Handwerkerviertel", 40)
schild("SchildHandwerk", VB, -2, 5, -38, "7 · Handwerkergasse", 36)

# --- Außenwerke: Südliches Vorwerk (I), unechtes Südtor (23), Verfallener Vorhof (L) ---
AW = G + "/Aussenwerke"
N("Aussenwerke", "Node3D", G)
bogen = [(-8 + 6 * math.cos(math.radians(a)), -57 + 6 * math.sin(math.radians(a))) for a in range(0, -181, -30)]
mauerzug("Vorwerk", AW, bogen, 6, 1.6)
schild("SchildVorwerk", AW, -8, 8, -59, "I · Südliches Vorwerk", 40)
tuerblatt("VermauertesTor", AW, -9, -42.9, -0.32, -0.95, "gravemarch_vermauert", "Altes Tor",
          "Hinter dem Tor ist Mauerwerk. Das Vorwerk führt ins Nichts.")
box("Suedtor", AW, -35, 5, -63, 10, 14, 7, "Material_mauer")
for k in (-1, 1):
    zyl(f"SuedtorTurm{k + 1}", AW, -35 + 6.5 * k, 7, -63, 2.4, 18, "Material_mauer", 8)
tuerblatt("Scheintor", AW, -35, -66.7, 0, -1, "gravemarch_suedtor", "Südtor",
          "Ein prächtiges Tor ohne Durchgang. Dahinter ist nur Stein. Wer es aufbrechen will, verliert Zeit und Leute.", 4.0, 5.5)
schild("SchildSuedtor", AW, -35, 14, -67, "23 · Südtor (unecht)", 40)
mauerzug("Vorhof", AW, [(41, -6.5), (60, -2), (60, 24), (33, 26)], 6, 2.0, verfallen=True)
zyl("VorhofTurm", AW, 60, 2, -2, 3, 8, "Material_mauer", 8)
schild("SchildVorhof", AW, 50, 6, 12, "L · Verfallener Vorhof", 40)

# --- Häuser in den Vierteln, Wege bleiben frei ---
WEGE_GM = [[(tx - nx * 2, tz - nz * 2), (45, -28), (35, -8), (33, 18), (20, 16), (0, 10), (-11, 8), (-11, 12)],
           [(45, -28), (20, -25), (-12, -24), (-30, -21), (-50, -18), (-53, 10), (-49, 30), (-44, 42)],
           [(-12, -24), (-3, -38)], [(20, -25), (24, -40)], [(0, 10), (-20, 2)], [(20, 16), (24, 30)]]
MAUERN_GM = [AUSSEN + [AUSSEN[0]], MITTE, INNEN]
def in_vieleck(pkt, x, z):
    innen = False
    for i in range(len(pkt)):
        (x1, z1), (x2, z2) = pkt[i], pkt[(i+1) % len(pkt)]
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
            innen = not innen
    return innen
BELEGT = [(-60, -30, -40, -6), (-62, -1, -46, 11), (-55, 19, -38, 40), (-31, -21, -20, -10), (-19, -31, -5, -17),
          (2, -5, 16, 9), (15, 22, 26, 43)]
HG = G + "/Haeuser"
N("Haeuser", "Node3D", G)
random.seed(950)
gm_haeuser = 0
for gx_ in range(-62, 64, 8):
    for gz_ in range(-46, 40, 8):
        x = gx_ + random.uniform(-1.5, 1.5); z = gz_ + random.uniform(-1.5, 1.5)
        if not in_vieleck(AUSSEN, x, z) or in_vieleck(INNEN + [(-26, 52), (4, 54.6)], x, z):
            continue
        if any(a <= x <= c and b <= z <= d for a, b, c, d in BELEGT):
            continue
        if min(abstand_linie(w, x, z) for w in WEGE_GM) < 5.0 or min(abstand_linie(m, x, z) for m in MAUERN_GM) < 5.2:
            continue
        naechst = min(WEGE_GM, key=lambda w: abstand_linie(w, x, z))
        best = None
        for (x1, z1), (x2, z2) in zip(naechst, naechst[1:]):
            dx, dz = x2-x1, z2-z1
            t = max(0, min(1, ((x-x1)*dx + (z-z1)*dz) / (dx*dx + dz*dz)))
            px, pz = x1 + dx*t, z1 + dz*t
            if best is None or math.hypot(px-x, pz-z) < best[0]:
                best = (math.hypot(px-x, pz-z), px, pz)
        gier = round(math.degrees(math.atan2(best[1] - x, best[2] - z)) / 90) * 90
        gm_haeuser += 1
        N(f"Haus{gm_haeuser}", None, HG, T(round(x, 2), 0, round(z, 2), gier, 0.6, 0.8 + 0.12*(gm_haeuser % 3), 0.6), instanz="12_haus")
print("Häuser in Gravemarch:", gm_haeuser)
schild("Schild", G, -5, 32, 43, "Gravemarch")

# Personen: Wächterin vor der Brückenpforte, Archivarin in der Bibliothek
ESME = (GMX + PFORTE[0] + ux * 3, -4 + PFORTE[1], GMZ + PFORTE[2] + uz * 3)
ARCHIVARIN = (GMX - 15, -4, GMZ + 37.5)
