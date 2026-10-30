# ---------- Burgfeste Drachenstein nach dem Grundriss (docs/bilder/grundriss-drachenstein.webp) ----------
# Fünf Burgen gestaffelt den Berg hinauf (werkzeuge/bau/plan_drachenstein.py hat die Planpunkte):
#   I   Untere Burg (Marktviertel) und V Hafenbezirk: teil_stadt.py
#   II  Mittlere Burg (Wolfsfeste): Kernhof (2) mit dem Inneren Burghof aus Akt I (burg_hof.tscn) und Palas (6)
#   III Oberer Burg (Drachenhorst): Urkern (1) mit Bergfried, Kapelle (7), Hoher Zwinger, Aussichtsplattform
#   Äußerer Zwinger (3) mit dem Treppentor hinab zum Markt, Ostterrasse (4)
#   IV  Vorburg/Löwenward: äußerer Ring, teil_stadt.py
# Der Weg hinauf: Kernhof → Nordtor → Rampe im Mittleren Zwinger → Zwingertor → Hoher Zwinger → Rampe →
# Tor der Oberen Burg → Rampe → Urkerntor.
import sys
sys.path.insert(0, str(BAU))
import plan_drachenstein as PD
teil("teil_mauern.py")

W = PD.welt
WL = PD.welt_liste
DS = "Drachenstein"
N(DS, "Node3D", ".")
BG = DS + "/Burgen"
N("Burgen", "Node3D", DS)

def ramp(name, a, b, breite=4.0):
    """Rampe zwischen zwei Punkten (x, y, z) mit Stützmauer darunter."""
    rampe(name, BG, a, b, breite, 0.6, "Material_boden")
    # Stützmauer in Stufen, jede bleibt unter der Rampe
    laenge = math.hypot(b[0] - a[0], b[2] - a[2])
    unten = min(a[1], b[1]) - 1.0
    for k in range(4):
        t0, t1 = 0.12 + 0.2 * k, 0.32 + 0.2 * k
        oben = a[1] + (b[1] - a[1]) * (t0 if b[1] > a[1] else t1) - 0.7
        if oben - unten < 0.5:
            continue
        t = (t0 + t1) / 2
        box(f"{name}Stuetze{k}", BG, round(a[0] + (b[0] - a[0]) * t, 2), round((unten + oben) / 2, 2), round(a[2] + (b[2] - a[2]) * t, 2),
            round(laenge * 0.2, 2), round(oben - unten, 2), breite - 0.4, "Material_mauer", gier=round(gier_zu(b[0] - a[0], b[2] - a[2]), 2))

def entlang(p0, p1, t, versatz, gegen):
    """Punkt auf der Strecke p0-p1 (Anteil t), um 'versatz' zur Seite von 'gegen' verschoben."""
    x, z = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
    dx, dz = p1[0] - p0[0], p1[1] - p0[1]
    l = math.hypot(dx, dz)
    nx, nz = -dz / l, dx / l
    if (gegen[0] - x) * nx + (gegen[1] - z) * nz < 0:
        nx, nz = -nx, -nz
    return x + nx * versatz, z + nz * versatz

# --- II Mittlere Burg: Kernhof (Sechseck) um den Inneren Burghof aus Akt I ---
KH = WL(PD.KERNHOF)
# Tore: nach Osten zum Äußeren Zwinger, nach Nordwesten hinauf, nach Südwesten zur Vorburg
mauerring("Kernhof", BG, KH, 8.0, dicke=3.0, geschlossen=True, mitte=(0, 0), turm_r=4.0,
         tore={4: (0.5, 6.0, "Kernhoftor"), 1: (0.45, 5.0, ""), 6: (0.55, 5.0, "")})
schild("SchildKernhof", BG, 0, 9.5, 52, "Kernhof · Mittlere Burg (Wolfsfeste)", 40)
# Palas (6) an der Nordseite des Kernhofs
kh_n0, kh_n1 = KH[2], KH[3]
px_, pz_ = entlang(kh_n0, kh_n1, 0.5, 13, (0, 0))
steinbau("Palas", BG, px_, pz_, 42, 13, 14, gier=gier_zu(kh_n1[0] - kh_n0[0], kh_n1[1] - kh_n0[1]) + 90,
         mat="Material_hell", dachhoehe=8)
schild("SchildPalas", BG, round(px_, 2), 24, round(pz_, 2), "Palas", 40)

MB = WL(PD.MITTLERE_BURG)
mauerring("MittlereBurg", BG, MB, 10.0, dicke=3.0, geschlossen=True, mitte=(0, 0), turm_r=5.0,
         tore={3: (0.85, 7.0, "Tor der Wolfsfeste"), 5: (0.46, 6.0, "Westtor der Wolfsfeste"), 0: (0.6, 6.0, "Zwingertor")})
# Rampe im Mittleren Zwinger vom Nordwesttor des Kernhofs hinauf zum Zwingertor (Hoher Zwinger, +18)
z0, z1 = MB[0], MB[1]
oben_x, oben_z = entlang(z0, z1, 0.6, 3.5, (0, 0))
unten_x, unten_z = entlang(z0, z1, 0.6 - 40 / math.dist(z0, z1), 7.5, (0, 0))
ramp("RampeZwinger", (unten_x, PD.H_MITTLERER_ZWINGER, unten_z), (oben_x, PD.H_HOHER_ZWINGER, oben_z), 4.5)
# Absatz hinter dem oberen Ende der Rampe, durch das Zwingertor hindurch
_rl = math.hypot(oben_x - unten_x, oben_z - unten_z)
_rx, _rz = (oben_x - unten_x) / _rl, (oben_z - unten_z) / _rl
# Absatz am oberen Ende der Rampe, seitlich durch das Zwingertor in den Hohen Zwinger
_wx, _wz = entlang(z0, z1, 0.6, -1.0, (0, 0))
_wx, _wz = _wx - z0[0] - (z1[0] - z0[0]) * 0.6, _wz - z0[1] - (z1[1] - z0[1]) * 0.6   # Richtung nach außen
box("AbsatzZwinger", BG, round(oben_x + _rx * 2.5 + _wx * 1.5, 2), PD.H_HOHER_ZWINGER - 0.3, round(oben_z + _rz * 2.5 + _wz * 1.5, 2),
    5, 0.6, 10, "Material_boden", gier=round(gier_zu(_rx, _rz), 2))

# --- Äußerer Zwinger (3) mit dem Treppentor hinab zum Markt ---
AZ = WL(PD.AEUSSERER_ZWINGER)
# Nur der Teil unterhalb der Oberen Burg ist eine eigene Mauer (oben schließt die Obere Burg an)
mauerring("AeussererZwinger", BG, AZ[:-1], 9.0, dicke=3.0, mitte=(0, 0), turm_r=4.5,
         tore={7: (0.5, 7.0, "Treppentor"), 3: (0.2, 6.0, "Zwingerpforte")})
# Die große Treppe: vom Markt durch das Tor der Stadtmauer hinauf zum Treppentor (nur Optik, begehbar ist das
# Gelände, das der Geländeerzeuger unter ihr zur geraden Rampe formt)
_ta, _tb = W(PD.TREPPE[0]), W(PD.TREPPE[-1])
N("Treppe", "Node3D", BG, f"""script = ExtResource("28_burgbau")
treppen = PackedFloat32Array({_zahlen([_ta[0], _ta[1], PD.H_MARKT_OBEN, _tb[0], _tb[1], PD.H_ZWINGER, 8.0])})
kollision = false""")
schild("SchildAeussererZwinger", BG, *(lambda p: (round(p[0], 1), 4.0, round(p[1], 1)))(W((560, 410))), "Äußerer Zwinger", 40)

# --- Ostterrasse (4): spätmittelalterliche Verdichtung mit Wohnbauten ---
for k, (pp, laenge, breite, g) in enumerate([((745, 210), 26, 10, 20), ((760, 260), 22, 10, 30), ((780, 330), 28, 11, 35),
                                             ((735, 380), 20, 10, 10), ((800, 390), 22, 10, 45)]):
    x, z = W(pp)
    steinbau(f"Ostbau{k}", BG, x, z, laenge, breite, 9, gier=g, mat="Material_hell", dach="Material_dach")

# --- III Oberer Burg (Drachenhorst) ---
OBB = WL(PD.OBERE_BURG)
mauerring("ObereBurgMauer", BG, OBB, 10.0, dicke=3.5, mitte=W((610, 140)), turm_r=5.5)
# Abschlussmauer zum Hohen Zwinger (Futtermauer zwischen +18 und +34) mit Tor
FUTTER = [OBB[-1], OBB[0]]
mauerring("ObereBurgFutter", BG, FUTTER, 6.0, dicke=3.0, mitte=W((610, 140)), tore={0: (0.79, 6.0, "Tor der Oberen Burg")})
# Rampe im Hohen Zwinger hinauf zum Tor der Oberen Burg
f0, f1 = FUTTER
tor_x, tor_z = f0[0] + (f1[0] - f0[0]) * 0.79, f0[1] + (f1[1] - f0[1]) * 0.79
ux, uz = (f1[0] - f0[0]) / math.dist(f0, f1), (f1[1] - f0[1]) / math.dist(f0, f1)
nx, nz = uz, -ux                                   # von der Mauer nach Osten (Hoher Zwinger)
if nx < 0:
    nx, nz = -nx, -nz
# Die Rampe läuft an der Mauer entlang (im schmalen Hohen Zwinger ist quer kein Platz) und endet auf einem Absatz vor dem Tor
ramp("RampeObereBurg", (tor_x + nx * 5 - ux * 48, PD.H_HOHER_ZWINGER, tor_z + nz * 5 - uz * 48),
     (tor_x + nx * 5 - ux * 6, PD.H_OBERE_BURG, tor_z + nz * 5 - uz * 6), 4.5)
# Der Absatz reicht durch das Tor, über die Kante zwischen den Terrassen
box("AbsatzObereBurg", BG, round(tor_x + nx * 1.45 - ux * 1.2, 2), PD.H_OBERE_BURG - 0.3, round(tor_z + nz * 1.45 - uz * 1.2, 2), 9.6, 0.6, 10.9,
    "Material_boden", gier=round(gier_zu(ux, uz), 2))

# Urkern (1): ältester Teil, Ring mit Rundtürmen, darin der Bergfried
UK = WL(PD.URKERN)
UK_MITTE = W((628, 140))
mauerring("Urkern", BG, UK, 12.0, dicke=3.5, geschlossen=True, mitte=UK_MITTE, turm_r=4.5,
         tore={4: (0.85, 5.0, "Urkerntor")}, mat="Material_basalt")
# Rampe in der Oberen Burg zum Urkerntor, an der Ostseite des Urkerns entlang
u0, u1 = UK[4], UK[5]
gx, gz = u0[0] + (u1[0] - u0[0]) * 0.85, u0[1] + (u1[1] - u0[1]) * 0.85
UK_ABSTAND = 6.5                                   # Rampe so weit vor der Mauer (dort ist das Gelände eben)
ox, oz = entlang(u0, u1, 0.85, -UK_ABSTAND, UK_MITTE)
ux2, uz2 = (u1[0] - u0[0]) / math.dist(u0, u1), (u1[1] - u0[1]) / math.dist(u0, u1)
ramp("RampeUrkern", (ox - ux2 * 36, PD.H_OBERE_BURG, oz - uz2 * 36), (ox - ux2 * 3, PD.H_URKERN, oz - uz2 * 3), 4.0)
_aus = (UK_ABSTAND - 4) / 2 / UK_ABSTAND          # Absatz von der Rampe bis 4 m hinter das Tor
box("AbsatzUrkern", BG, round(gx + (ox - gx) * _aus, 2), PD.H_URKERN - 0.3, round(gz + (oz - gz) * _aus, 2), 6, 0.6, UK_ABSTAND + 4, "Material_boden",
    gier=round(gier_zu(ux2, uz2), 2))
# Bergfried des Urkerns
bx, bz = UK_MITTE[0] - 6, UK_MITTE[1] - 8
N("BergfriedUrkern", "Node3D", BG, f"""script = ExtResource("28_burgbau")
torbauten = PackedFloat32Array({_zahlen([bx, bz, 1, 0, PD.H_URKERN - 2, PD.H_URKERN + 42, 15, 15, 1, 1.0])})
stein = \"basalt\"""")
schild("SchildBergfried", BG, round(bx, 2), PD.H_URKERN + 60, round(bz, 2), "Bergfried (Urkern)", 56)
# Kapelle (7) am Urkern
KP = WL(PD.KAPELLE_URKERN)
mauerring("KapelleMauer", BG, KP, 8.0, dicke=2.5, geschlossen=True, mitte=W((559, 146)), mat="Material_basalt")
kx, kz = W((559, 146))
steinbau("Kapelle", BG, kx, kz, 18, 10, 9, gier=90, mat="Material_hell", boden=PD.H_URKERN)
schild("SchildKapelle", BG, round(kx, 2), PD.H_URKERN + 16, round(kz, 2), "Kapelle", 40)

# Aussichtsplattform: hoher Turm mit Spitzhelm an der Spitze der Oberen Burg
ax_, az_ = W(PD.AUSSICHTSPLATTFORM)
N("Aussichtsturm", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen([ax_, az_, PD.H_OBERE_BURG - 4, PD.H_OBERE_BURG + 27, 6.5, 1, 14])})""")
schild("SchildAussicht", BG, ax_, PD.H_OBERE_BURG + 45, az_, "Aussichtsplattform", 48)
# Bauten in der Oberen Burg: Speicher, Zeughaus, Wohnbau
for k, (pp, laenge, breite, g, name) in enumerate([((540, 85), 30, 11, -30, "Speicher"), ((680, 95), 26, 10, 25, "Zeughaus"),
                                                   ((690, 165), 24, 10, 75, "Wohnbau")]):
    x, z = W(pp)
    steinbau(f"Obere{name}", BG, x, z, laenge, breite, 10, gier=g, boden=PD.H_OBERE_BURG)

# Übungsplatz mit zwei Puppen in der Oberen Burg (Stufe 4, Kampf)
OB = DS + "/ObererBurg"
UEB = W((525, 175))
N("ObererBurg", "Node3D", DS, T(round(UEB[0], 2), PD.H_OBERE_BURG, round(UEB[1], 2)))
for k, x in enumerate([-2.5, 2.5]):
    gegner(f"Uebungspuppe{k + 1}", OB, x, 0, 0, "Übungspuppe", waffe="puppe", tracht="0.55, 0.45, 0.3, 1")
schild("SchildUebungsplatz", OB, 0, 3.5, 4, "Übungsplatz", 40)

# Hoher Zwinger: Zisterne (9) und Brunnenhaus (15)
zx, zz = W(PD.ZISTERNE)
zyl("Zisterne", BG, zx, PD.H_HOHER_ZWINGER + 0.5, zz, 4.0, 1.2, "Material_mauer", 16)
zyl("ZisterneWasser", BG, zx, PD.H_HOHER_ZWINGER + 1.05, zz, 3.4, 0.1, "Material_wasser_becken", 16, False)
bx_, bz_ = W(PD.BRUNNENHAUS)
steinbau("Brunnenhaus", BG, bx_, bz_, 10, 8, 6, gier=30, boden=PD.H_HOHER_ZWINGER, mat="Material_hell", dach="Material_dach")
schild("SchildHoherZwinger", BG, *(lambda p: (round(p[0], 1), PD.H_HOHER_ZWINGER + 4, round(p[1], 1)))(W((590, 225))), "Hoher Zwinger", 40)

# --- I Untere Burg, V Hafen, IV Löwenward und Vorburg: die Stadt ---
teil("teil_stadt.py")
zinnen_schreiben(DS)
