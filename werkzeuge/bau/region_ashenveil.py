"""Baut szenen/welt/region_ashenveil.tscn. Aufruf: python3 werkzeuge/bau/region_ashenveil.py

Ashenveil nach dem Grundriss (docs/bilder/grundriss-ashenveil.webp), ohne Drehung: Norden oben.
1 Bildpunkt des Plans = 0,2 m, Ursprung ist die Mitte der Burg. Die Burginsel liegt auf Höhe 0,5,
der Knoten "Burg" hebt alles darauf, sodass lokal y = 0 der Hofboden ist.
Unter dem Überdachten Innenhof liegen die Kapelle der Stille (A) und der Fluchttunnel (B) in die Sümpfe.
"""
from pathlib import Path
exec(open(Path(__file__).resolve().parent / "grundlage.py", encoding="utf-8").read())
lade_hoehen("gelaende_ashenveil")

LOCH_HOF = (-24.75, -3.0, 7.0)       # über dem Rampenloch im Hof: dort kein Wasser zeichnen
LOCH_AUSSTIEG = (-5.25, -90.0, 11.0)  # über dem offenen Ausstieg des Tunnels
grundgeruest("gelaende_ashenveil", '''region_id = "ashenveil"
wasserspiegel = -1.0
wasser_meldung = "Der Morast verschluckt jeden, der den Weg verlässt."
grenze_min = Vector2(-240, -190)
grenze_max = Vector2(240, 199)
grenze_meldung = "Dahinter liegen nur Nebel und Sumpf. Hier geht niemand weiter."
karte_ursprung = Vector2(372, 749)
karte_meter_pro_pixel = 60.0''', wasser_name="Moorwasser", wasser_hoehe=-1, wasser_groesse=(600, 500),
             wasser_parameter=f"""
shader_parameter/farbe_tief = Vector3(0.05, 0.07, 0.05)
shader_parameter/farbe_hell = Vector3(0.13, 0.16, 0.11)
shader_parameter/wellenhoehe = 0.03
shader_parameter/loch_mitte = Vector2({LOCH_HOF[0]}, {LOCH_HOF[1]})
shader_parameter/loch_radius = {LOCH_HOF[2]}
shader_parameter/loch2_mitte = Vector2({LOCH_AUSSTIEG[0]}, {LOCH_AUSSTIEG[1]})
shader_parameter/loch2_radius = {LOCH_AUSSTIEG[2]}""", nebel=0.012, gelaende_parameter="""
shader_parameter/sand = Vector3(0.55, 0.55, 0.45)
shader_parameter/gras = Vector3(0.8, 0.82, 0.7)
shader_parameter/gras_trocken = Vector3(0.75, 0.72, 0.55)""")
E("Script", "res://szenen/welt/wasserdicht.gd", "19_wasserdicht")

BODEN = 0.5   # Höhe der Burginsel
B = "Burg"
N(B, "Node3D", ".", T(0, BODEN, 0))
LH = lambda x, z: H(x, z) - BODEN

# ---------- Mauern und Ecktürme (27–30), Wehrgänge innen entlang der Mauern ----------
mauerzug("Mauer", B, [(-64, 32), (-88, 32), (-88, -42), (88, -42), (88, 32), (46, 32)], 10, luecken={3: (0.608, 4.0)})
for nr, (x, z) in [(27, (-88, 32)), (28, (-88, -42)), (29, (88, -42)), (30, (88, 32))]:
    zyl(f"Wachturm{nr}", B, x, 6, z, 7, 16, "Material_mauer", 8)
    schild(f"SchildTurm{nr}", B, x, 15, z, f"{nr} · Wachturm", 36)
for name, x, z in [("WehrgangNord", 0, -37), ("WehrgangWest", -83, -5), ("WehrgangOst", 84.5, -5)]:
    schild(f"Schild{name}", B, x, 3, z, "Offene Gänge (Wehrgänge)", 32)

# ---------- Südtrakt mit Torhaus (14), Fallgitter und Zugbrücke ----------
gebaeude_lokal("Kueche", B, -51, 35, 26, 14, 8, text="12 · Küche")
gebaeude_lokal("Vorratslager", B, -28, 35, 20, 14, 7, mat="Material_holz", text="13 · Vorratslager")
box("TorhausWestwand", B, -15.5, 4, 35, 5, 10, 14, "Material_mauer")
box("TorhausOstwand", B, 5.5, 4, 35, 5, 10, 14, "Material_mauer")
gebaeude_lokal("Waffenlager", B, 16, 35, 16, 14, 7, mat="Material_holz", text="15 · Waffenlager")
gebaeude_lokal("Schmiede", B, 35, 35, 22, 14, 7, mat="Material_mauer", text="16 · Schmiede")
N("Torhaus", "CSGCombiner3D", B, "use_collision = true")
zyl("Turm", B + "/Torhaus", -5, 6, 35, 8, 16, "Material_mauer", 12, kollision=False)
N("Durchgang", "CSGBox3D", B + "/Torhaus", f"{T(-5, 2.5, 35)}\noperation = 2\nsize = Vector3(4.4, 5, 18)")
schild("SchildTorhaus", B, -5, 17, 35, "14 · Torhaus (Haupttor) · 17 Wachstube · 18 Kommandoraum", 36)
tuerblatt("Fallgitter", B, -5, 40, 0, 1, "eid_waechter", "Fallgitter",
          "Das Fallgitter bleibt unten. Nach Ashenveil hinein kommen nur Wächter des Ordens.", 4.4, 4.8)
SUED = (-5, 66)
rampe("Zugbruecke", B, (-5, 0.0, 43), (SUED[0], round(LH(*SUED), 2), SUED[1]), 4.4, 0.6)
schild("SchildZugbruecke", B, -5, 3, 50, "Zugbrücke mit Fallgitter (Haupteingang)", 36)

# ---------- Westtrakt: Reithalle, Marstall, Futterkammern, Heuboden ----------
raum_lokal("Reithalle", B, -77, -36, -54, -9, 9, [("O", -30)], schild_text="1 · Große Reithalle", licht=True)
raum_lokal("Marstall", B, -54, -36, -42, 11, 6, [("W", -30), ("O", -20)], schild_text="2 · Marstall", licht=True)
for k, z in enumerate([-33, -27, -14, -8, -2, 4, 8]):
    pferd(f"Pferd{k}", B + "", -51.5, 0, z, 0)
gebaeude_lokal("Futterkammer1", B, -71.5, -4, 11, 8, 5, mat="Material_holz", text="3 · Futterkammer I")
gebaeude_lokal("Futterkammer2", B, -60, -4, 12, 8, 5, mat="Material_holz", text="4 · Futterkammer II")
gebaeude_lokal("Futterkammer3", B, -65.5, 5.5, 23, 9, 5, mat="Material_holz", text="5 · Futterkammer III")
gebaeude_lokal("Heuboden", B, -61, 16, 28, 10, 7, mat="Material_holz", text="6 · Heuboden")

# ---------- Nordreihe: Sattlerei, Waffenkammer, Zeugkammer, Waffenschmiede ----------
for name, x, sx, text in [("Sattlerei", -31, 14, "7 · Sattlerei"), ("Waffenkammer", -17, 14, "8 · Waffenkammer (leicht)"),
                          ("Zeugkammer", -3, 14, "9 · Zeugkammer"), ("Waffenschmiede", 22.5, 17, "19 · Waffenschmiede / Werkstatt")]:
    gebaeude_lokal(name, B, x, -32.5, sx, 9, 6, text=text)

# ---------- Osttrakt: Rüstkammern, Schmiede, Unterkünfte, Kernspeicher, Nebeneingang ----------
gebaeude_lokal("ErweiterteRuestkammern", B, 44, -23.5, 16, 23, 8, mat="Material_mauer", text="20 · Erweiterte Rüstkammern")
gebaeude_lokal("SchmiedeOst", B, 73, -25.5, 14, 9, 6, mat="Material_mauer", text="21 · Schmiede (Ost)")
box("Esse", B, 73, 0.8, -20.4, 2, 1.6, 1.2, "Material_feuer")
gebaeude_lokal("Mannschaftsunterkuenfte", B, 58, -5.5, 46, 29, 8, text="22 · Mannschaftsunterkünfte")
gebaeude_lokal("Kernspeicher", B, 58, 15.5, 46, 13, 9, mat="Material_holz", text="23 · Kernspeicher (Getreide)")
for k, z in enumerate([-1, 7]):
    box(f"PforteTurm{k}", B, 88, 5, z, 4.5, 14, 4.5, "Material_mauer")
tuerblatt("Nebeneingang", B, 90.4, 3, 1, 0, "ashenveil_nebeneingang", "Nebeneingang",
          "Der Nebeneingang ist verriegelt. Seit dem Verrat von 1065 öffnet ihn nachts nur, wer beide Wachgruppen auf seiner Seite hat.", 4.0, 4.5)
OST = (113, 3)
rampe("ZugbrueckeOst", B, (90.8, 0.0, 3), (OST[0], round(LH(*OST), 2), OST[1]), 3.6, 0.6)
schild("SchildNebeneingang", B, 96, 4, 3, "Zugbrücke (Nebeneingang)", 36)

# ---------- Überdachter Großer Innenhof (10) und Untere Rüstkammern (11) ----------
gebaeude_lokal("UntereRuestkammern", B, -5.5, 18.5, 51, 7, 6, text="11 · Untere Rüstkammern")
for x in [-33, -24, -15, -6, 3, 12, 21]:
    for z in [-20, 16]:
        box(f"Pfosten{x + 40}_{z + 30}", B, x, 4.5, z, 0.8, 9, 0.8, "Material_holz")
for z in [-11, -2, 7]:
    for x in [-33, 21]:
        box(f"Pfosten{x + 40}_{z + 30}", B, x, 4.5, z, 0.8, 9, 0.8, "Material_holz")
box("Hofdach", B, -6, 9.3, -2, 56, 0.6, 38, "Material_holz", kollision=False)
schild("SchildInnenhof", B, -6, 7.5, -16, "10 · Überdachter Großer Innenhof", 40)
box("Kartentisch", B, 8, 0.45, -5.5, 3, 0.9, 2, "Material_papier")

# Boden des Hofs über der Grube, mit dem Loch für die Rampe hinunter
N("Hofboden", "CSGCombiner3D", B, "use_collision = true")
box("Platte", B + "/Hofboden", -15, -0.9, -2.5, 40, 1.8, 20, "Material_boden", kollision=False)
N("Loch", "CSGBox3D", B + "/Hofboden", f"{T(-24.75, -0.9, -3)}\noperation = 2\nsize = Vector3(10.9, 4, 3.5)")
box("GelaenderN", B, -24.75, 0.55, -4.9, 11.2, 1.1, 0.3, "Material_holz")
box("GelaenderS", B, -24.75, 0.55, -1.1, 11.2, 1.1, 0.3, "Material_holz")
box("GelaenderO", B, -19.15, 0.55, -3, 0.3, 1.1, 4.1, "Material_holz")
zyl("Brunnen", B, -6, 0.5, 4, 1.3, 1.0, "Material_mauer", 12)

# ---------- Unterbau (A): Vorraum und Kapelle der Stille, Rampe hinunter ----------
U = -7.0          # Boden unter der Erde (lokal)
DECKE = -1.8      # Unterkante des Hofbodens
UB = B + "/Unterbau"
N("Unterbau", "Node3D", B)
box("Boden", UB, -15, U - 0.4, -2.5, 40, 0.8, 20, "Material_boden")
hoehe_ub = DECKE - U
for name, x, z, sx, sz in [("WandNordWest", -21.125, -12.25, 27.75, 0.5), ("WandNordOst", 0.875, -12.25, 8.25, 0.5),
                           ("WandSued", -15, 7.25, 40, 0.5), ("WandWest", -34.75, -2.5, 0.5, 20), ("WandOst", 4.75, -2.5, 0.5, 20)]:
    box(name, UB, x, (U + DECKE) / 2, z, sx, hoehe_ub, sz, "Material_basalt")
N("Trennwand", "CSGCombiner3D", UB, "use_collision = true")
box("Wand", UB + "/Trennwand", -12, (U + DECKE) / 2, -2.5, 0.5, hoehe_ub, 19.5, "Material_basalt", kollision=False)
N("Tuer", "CSGBox3D", UB + "/Trennwand", f"{T(-12, U + 1.5, -3)}\noperation = 2\nsize = Vector3(1, 3, 3)")
rampe("Rampe", UB, (-30, 0.0, -3), (-12.5, U, -3), 3.2)
for k, x in enumerate([-2, 1]):
    for j, z in enumerate([-8, -5, -1, 2]):
        box(f"Bank{k}_{j}", UB, x - 5, U + 0.25, z, 0.6, 0.5, 2.2, "Material_holz")
N("Gedenkstein", "StaticBody3D", UB, f"""{T(3.6, U + 0.9, -3, 180)}
script = ExtResource("16_lesbar")
anzeige_name = "Gedenkstein von 1065"
dialog_id = "gedenkstein_ashenveil\"""")
box("Stein", UB + "/Gedenkstein", 0, 0, 0, 0.6, 1.8, 1.4, "Material_hell", kollision=False)
bereich("Form_gedenkstein", 0.6, 1.8, 1.4)
N("Form", "CollisionShape3D", UB + "/Gedenkstein", 'shape = SubResource("Form_gedenkstein")')
licht("LichtKapelle", UB, -3, DECKE - 0.6, -3, 14)
licht("LichtVorraum", UB, -22, DECKE - 0.6, -6, 12)
schild("SchildKapelle", UB, -3, DECKE - 1.0, 5, "A · Unterirdische Kapelle (der Stille)", 32)

# ---------- Fluchttunnel (B) unter Mauer und Graben hindurch in die Sümpfe ----------
TX0, TX1 = -7.0, -3.5     # Innenmaße des Tunnels
TM = (TX0 + TX1) / 2
TD = U + 2.8              # Unterkante der Abdeckung
for z0 in range(-12, -80, -4):
    z1 = max(z0 - 4, -80)
    zm = (z0 + z1) / 2
    oben = min(LH(-12, zm), LH(2, zm), 0.0)
    oben = max(oben, TD + 0.25)
    box(f"Decke{-z0}", UB, -5, (TD + oben) / 2, zm, 10, round(oben - TD, 2), z0 - z1, "Material_basalt")
box("TunnelBoden", UB, -5, U - 0.4, -46.25, 10, 0.8, 67.5, "Material_boden")
for name, x in [("TunnelWandWest", TX0 - 0.25), ("TunnelWandOst", TX1 + 0.25)]:
    box(name, UB, x, (U + TD) / 2, -46.25, 0.5, TD - U, 67.5, "Material_basalt")
for k, z in enumerate([-25, -45, -65]):
    licht(f"LichtTunnel{k}", UB, TM, TD - 0.4, z, 9)
schild("SchildTunnel", UB, TM, TD - 0.8, -16, "B · Fluchttunnel (zu den Sümpfen)", 28)
AUS = -100
aus_y = round(LH(-6, -104), 2)
rampe("Ausstieg", UB, (TM, U, -80), (TM, aus_y, AUS), 3.0)
box("Absatz", UB, TM, aus_y - 0.4, AUS - 2, 4, 0.8, 4, "Material_basalt")
for name, x in [("AusstiegWandWest", TX0 - 0.25), ("AusstiegWandOst", TX1 + 0.25)]:
    box(name, UB, x, (U + aus_y + 1) / 2, -90, 0.5, aus_y + 1 - U, 20, "Material_basalt")
box("AusstiegSturz", UB, TM, aus_y + 2.6, AUS + 0.3, 5, 0.6, 1.2, "Material_basalt")
for k in (-1, 1):
    box(f"AusstiegPfosten{k + 1}", UB, TM + 2.2 * k, aus_y + 1.2, AUS + 0.3, 0.6, 2.4, 1.2, "Material_basalt")
schild("SchildAusstieg", UB, TM, aus_y + 4, AUS, "Verdeckter Ausgang", 32)
# Hier gilt man nicht als ertrunken, obwohl man unter dem Wasser des Moors ist.
for name, mitte, groesse in [("Wasserdicht", (-15, -4, -2.5), (42, 9, 22)), ("WasserdichtTunnel", (-5.25, -4, -57), (10, 9, 96))]:
    N(name, "Node3D", UB, f'{T(*mitte)}\nscript = ExtResource("19_wasserdicht")\ngroesse = Vector3{groesse}')

# ---------- Außerhalb: Reiterin am Damm ----------
N("Personen", "Node3D", ".")
ANKUNFT = (-4.3, round(H(-4.3, 190) + 0.2, 2), 190)   # auf dem Damm
person("Reiterin", "Personen", -5.5, round(H(-5.5, 184), 2), 184, "Reiterin Ilka Sand", "reiterin_ashenveil", 2, "0.25, 0.22, 0.18, 1", gier=180)
pferd("PferdReiterin", "Personen", -9.6, round(H(-9.6, 184.5), 2), 184.5, -90)
TW = (-3.4, 48)
person("TorwacheSued", "Personen", TW[0], round(BODEN + (LH(*SUED)) * (TW[1] - 43) / (SUED[1] - 43), 2), TW[1],
       "Wachführer Henk Brask", "torwache_ashenveil", 2, "0.2, 0.22, 0.18, 1", gier=180)
person("Komtur", "Personen", 8, BODEN, -8, "Komtur Arvid Rask", "komtur_ashenveil", 3, "0.12, 0.13, 0.1, 1", gier=180)
person("WacheOst1", "Personen", 84, BODEN, 0.6, "Wache Lene Ott", "wache_ostpforte_ashenveil", 1, "0.2, 0.22, 0.18, 1", gier=-90)
person("WacheOst2", "Personen", 84, BODEN, 5.4, "Wache Piet Varn", "wache_ostpforte_ashenveil", 1, "0.3, 0.2, 0.15, 1", gier=-90)

# ---------- Orte ----------
N("Orte", "Node3D", ".")
for i, (name, untertitel, x, y, z, sx, sy, sz) in enumerate([
    ("Nebelmoor", "Nur ein Weg führt durch die Sümpfe zum Tor.", 0, 0, 120, 480, 40, 150),
    ("Ashenveil", "Im Sumpf geboren, im Sumpf unbesiegt.", 0, 2, -3, 200, 20, 100),
    ("Überdachter Innenhof", "Schutz vor Wind, Regen und Feuer.", -6, 3, -2, 54, 6, 36),
    ("Kapelle der Stille", "Unter dem Hof, seit dem Wiederaufbau um 1080.", -3.5, -4, -2.5, 16, 5, 19),
    ("Fluchttunnel", "Zu den verborgenen Ausgängen in den Sümpfen.", TM, -4.5, -46, 3.5, 4, 66),
]):
    bereich(f"Form_ort{i+1}", sx, sy, sz)
    N(f"Ort{i+1}", "Area3D", "Orte", f'''{T(x, y, z)}
script = ExtResource("13_ort")
ortsname = "{name}"
untertitel = "{untertitel}"''')
    N("Form", "CollisionShape3D", f"Orte/Ort{i+1}", f'shape = SubResource("Form_ort{i+1}")')

# ---------- Bewuchs: fahles Moor, wenige krumme Bäume; die Burg bleibt frei ----------
bewuchs(frei_rechtecke=[(0, -3, 210, 110)], wald_anteil=0.08, offen_dichte=3.0, nadel_anteil=0.3, busch_dichte=14.0,
        laub_farbe="Color(0.85, 0.85, 0.7, 1)")

# ---------- Sprungpunkte (Entwicklermenü, F10) ----------
N("Sprungpunkte", "Node3D", ".")
for name, x, y, z in [("Damm (Ankunft)", ANKUNFT[0], ANKUNFT[1] + 0.3, ANKUNFT[2]), ("Haupttor", -5, 1.2, 52),
                      ("Überdachter Innenhof", 0, 1.0, -10), ("Kapelle der Stille", -6, U + BODEN + 0.5, -3),
                      ("Fluchttunnel, Ausgang", -6, round(H(-6, -106), 2) + 0.5, -106), ("Nebeneingang (außen)", 100, 1.0, 3),
                      ("Marstall", -48, 1.0, -12)]:
    N(name.replace(",", "").replace(" ", "_").replace("(", "").replace(")", ""), "Marker3D", "Sprungpunkte",
      f'{T(x, y, z)}\nmetadata/anzeige = "{name}"')

# ---------- Ankunft, Spieler und Oberfläche ----------
N("Ankuenfte", "Node3D", ".")
N("von_drachenstein", "Marker3D", "Ankuenfte", T(*ANKUNFT), extra='groups=["ankunft"]')
ankunft("von_riverlock", 222, 3.5, 90)
ankunft("von_suedstrasse", 222, 3.5, 90)
ankunft("von_kuestenweg", -5.4, 188, 0)
ankunft("heilstube", 10, -10, hoch=0.8)
uebergang("ZumKuestenweg", (-1, round(H(-1, 196.5) + 2, 2), 196.5), (24, 30, 5), "kuestenweg", "von_ashenveil",
          (-7.2, round(H(-7.2, 180) + 0.5, 2), 180), bedingung="")
uebergang("ZurSuedstrasse", (236, round(H(236, 5.5) + 2, 2), 5.5), (10, 30, 24), "suedstrasse", "von_ashenveil",
          (215, round(H(215, 2.3) + 0.5, 2), 2.3), bedingung="")
schild("SchildKuestenweg", ".", 4, round(H(4, 192) + 3, 2), 192, "Küstenweg → Drachenstein 70 km", 48)
schild("SchildSuedstrasse", ".", 214, round(H(214, -2) + 3, 2), -2, "Südstraße → Riverlock 185 km", 48)
spieler_und_oberflaeche(*ANKUNFT)
schreibe("region_ashenveil.tscn")
