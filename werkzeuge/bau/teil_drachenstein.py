# ---------- Burgfeste Drachenstein nach dem Grundriss (docs/bilder/grundriss-drachenstein-2.webp) ----------
# Auf einem Felsgrat hintereinander (werkzeuge/bau/plan_drachenstein.py hat die Planpunkte):
#   I. Vorburg (12. Jh.) mit zwei Rundtürmen · II. Burghof (14. Jh.) · III. Burghof mit dem Hof aus Akt I ·
#   Kernburg mit Bergfried, Palas, Drachenkapelle, Burgküche und Zeughaus, umgeben von der Zwingermauer.
#   Die Ringmauer umschließt den Grat: Torhaus Nord, Halbturm, Wehrturm, Zwinger, Rondell, Hafentor (Wassertor).
# Der Weg hinauf (blaue Linie im Grundriss): Stadt → Burgstraßentor → am Halbturm vorbei hinauf (dort kommt der Weg
# vom Torhaus Nord dazu) → außen um die ganze Burg → Rampe → Rampentor (II. Burghof) → III. Burghof → Burgtor →
# Zwingerweg um die Kernburg → Kernburgtor. Unten zweigt der Weg zum Südtor der Vorburg ab.
# Die Höfe sind gestaffelt (Schnitt B-B): Vorburg 0, II. Burghof +6, III. Burghof +14, Kernburg +38.
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
M = PD.MASSSTAB


def turmmasse(pp, r, ueber):
    """Rundturm am Planpunkt: [x, z, unten, oben] – unten unter dem tiefsten Gelände, oben über dem höchsten."""
    x, z = W(pp)
    werte = [H(x + dx, z + dz) for dx in (-r, 0, r) for dz in (-r, 0, r)]
    return [x, z, min(werte) - 2.5, max(werte) + ueber]


def tor_an(punkte, p, breite, name):
    """Tor für mauerring: {Kantenindex: (Anteil, Breite, Name)} an der Kante des Linienzugs, die dem Planpunkt p
    am nächsten liegt (punkte und p im Plan)."""
    bester = None
    for i, (a, b) in enumerate(zip(punkte, punkte[1:])):
        dx, dy = b[0] - a[0], b[1] - a[1]
        t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)))
        d = math.dist(p, (a[0] + dx * t, a[1] + dy * t))
        if bester is None or d < bester[0]:
            bester = (d, i, t)
    return {bester[1]: (round(bester[2], 3), breite, name)}


def tore_an(punkte, *tore):
    erg = {}
    for p, breite, name in tore:
        erg.update(tor_an(punkte, p, breite, name))
    return erg


def gebaeude(name, eltern, bau, hoehe, boden, mat="Material_mauer", dach="Material_dach_schiefer", dachhoehe=None, art=None):
    """Bau aus dem Plan: ((Mitte), Länge entlang Plan-x, Breite, Drehung)."""
    (pp, laenge, breite, dreh) = bau
    x, z = W(pp)
    # Länge entlang Plan-x = Welt -z; steinbau legt die Länge entlang lokal z, Gier 0 → Welt z
    return steinbau(name, eltern, x, z, laenge * M, breite * M, hoehe, gier=-dreh, mat=mat, dach=dach,
                    dachhoehe=dachhoehe, boden=boden, art=art)


MITTE_BURG = W(PD.MITTE)
# --- Ringmauer um den Grat ---
RING = PD.RINGMAUER + [PD.RINGMAUER[0]]
mauerring("Ringmauer", BG, WL(RING), 9.0, dicke=3.0, mitte=MITTE_BURG,
         tore=tore_an(RING, (PD.TORE["Torhaus Nord"], 6.0, "Torhaus Nord"), (PD.TORE["Hafentor"], 16.0, "Hafentor"),
                      (PD.TORE["Nordtor"], 6.0, "Nordtor"), (PD.TORE["Burgstraßentor"], 6.0, "Burgstraßentor")))
# Türme der Ringmauer: Wehrturm, Zwinger, Rondell und weitere Rundtürme; Halbturm eckig
_tuerme = []
for pp, r, dach in [(PD.WEHRTURM, 6.0, 0), ((1190, 55), 6.0, 1), ((1230, 140), 6.5, 1), (PD.RONDELL, 10.0, 0),
                    ((880, 60), 5.0, 1), ((560, 100), 5.0, 1), ((330, 180), 5.0, 1), ((470, 376), 4.5, 0),
                    ((1000, 393), 5.0, 1)]:
    x, z = W(pp)
    unten = min(H(x + dx, z + dz) for dx in (-r, 0, r) for dz in (-r, 0, r)) - 2.5
    oben = max(H(x + dx, z + dz) for dx in (-r, 0, r) for dz in (-r, 0, r)) + 14
    _tuerme += [x, z, unten, oben, r, dach, r * 1.8]
hx, hz = W(PD.HALBTURM)
_hb = H(hx, hz)
N("RingmauerTuerme", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_tuerme)})
torbauten = PackedFloat32Array({_zahlen([hx, hz, 1, 0, _hb - 6, _hb + 13, 11, 11, 1, 1.0])})""")
schild("SchildHalbturm", BG, hx, _hb + 30, hz, "Halbturm", 40)
schild("SchildWehrturm", BG, *(lambda p: (p[0], H(*p) + 26, p[1]))(W(PD.WEHRTURM)), "Wehrturm", 40)
schild("SchildRondell", BG, *(lambda p: (p[0], H(*p) + 26, p[1]))(W(PD.RONDELL)), "Rondell", 40)

# --- I. Vorburg (12. Jh.) mit zwei Rundtürmen ---
VB = PD.VORBURG + [PD.VORBURG[0]]
mauerring("Vorburg", BG, WL(VB), 8.0, dicke=3.0, mitte=W((385, 290)),
         tore=tore_an(VB, (PD.TORE["Tor zur Vorburg"], 5.0, "Tor zur Vorburg"),
                      (PD.TORE["Tor des II. Burghofs"], 5.0, "")))
_vt = []
for pp, r in [((318, 250), 7.0), ((350, 358), 5.5)]:
    x, z = W(pp)
    _vt += [x, z, H(x, z) - 8, PD.H_VORBURG + 13, r, 1, r * 1.6]
N("VorburgTuerme", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_vt)})""")
for k, bau in enumerate(PD.VORBURG_BAUTEN):
    gebaeude(f"Vorburgbau{k}", BG, bau, 7, PD.H_VORBURG, dach="Material_dach")
schild("SchildVorburg", BG, *(lambda p: (p[0], PD.H_VORBURG + 9, p[1]))(W((390, 300))), "I. Vorburg", 40)

# --- II. Burghof (14. Jh.); die Wand zur Vorburg gehört zur Vorburg ---
B2 = PD.BURGHOF2[1:] + [PD.BURGHOF2[0]]
mauerring("BurghofZwei", BG, WL(B2), 9.0, dicke=3.0, mitte=W((560, 260)),
         tore=tore_an(B2, (PD.TORE["Rampentor"], 5.0, "Rampentor"), (PD.TORE["Tor des III. Burghofs"], 6.0, "")))
for k, bau in enumerate(PD.BURGHOF2_BAUTEN):
    gebaeude(f"Burghof2Bau{k}", BG, bau, 8, PD.H_BURGHOF2)
schild("SchildBurghof2", BG, *(lambda p: (p[0], PD.H_BURGHOF2 + 9, p[1]))(W((560, 262))), "II. Burghof", 40)

# --- III. Burghof um den Hof aus Akt I; die Wand zum II. Burghof gehört zum II. ---
mauerring("BurghofDrei", BG, WL(PD.BURGHOF3), 10.0, dicke=3.0, mitte=MITTE_BURG,
         tore=tor_an(PD.BURGHOF3, PD.TORE["Burgtor"], 6.0, "Burgtor"))
schild("SchildBurghof3", BG, 0, PD.H_KERNHOF + 13, -36, "III. Burghof", 40)

# --- Zwinger und Kernburg ---
ZW = PD.ZWINGER_KERNBURG[1:]        # die Wand am III. Burghof gehört zu diesem
mauerring("Zwingermauer", BG, WL(ZW), 8.0, dicke=3.0, mitte=W((990, 220)), turm_r=0.0)
# Quermauer im südlichen Zwinger: Dort endet der Zwingerweg oben, westlich davon liegt der Zwinger unten
mauerring("Quermauer", BG, WL([(945, 296), (945, 340)]), 6.0, dicke=2.5, mitte=W((990, 220)))
_zt = []
for pp in [(965, 88), (1152, 130), (1112, 322), (895, 332)]:
    _zt += turmmasse(pp, 4.5, 12) + [4.5, 1, 8]
KB = PD.KERNBURG + [PD.KERNBURG[0]]
mauerring("Kernburg", BG, WL(KB), 12.0, dicke=3.5, mitte=W((990, 220)),
         tore=tor_an(KB, PD.TORE["Kernburgtor"], 5.0, "Kernburgtor"))
for pp in [(912, 138), (1100, 150), (1102, 280), (896, 288)]:
    m = turmmasse(pp, 4.5, 0)
    _zt += m[:3] + [PD.H_KERNBURG + 17, 4.5, 1, 9]
N("KernburgTuerme", "Node3D", BG, f"""script = ExtResource("28_burgbau")
tuerme = PackedFloat32Array({_zahlen(_zt)})""")

# Bergfried der Kernburg: hoher eckiger Turm mit Pechnasen und Zeltdach
bx, bz = W(PD.BERGFRIED_KERNBURG)
N("BergfriedKernburg", "Node3D", BG, f"""script = ExtResource("28_burgbau")
torbauten = PackedFloat32Array({_zahlen([bx, bz, 1, 0, PD.H_KERNBURG - 2, PD.H_KERNBURG + 38, 16, 16, 1, 1.1])})""")
schild("SchildBergfriedKernburg", BG, bx, PD.H_KERNBURG + 62, bz, "Bergfried", 56)
gebaeude("Palas", BG, PD.PALAS, 15, PD.H_KERNBURG, mat="Material_hell", dachhoehe=9)
gebaeude("Drachenkapelle", BG, PD.DRACHENKAPELLE, 11, PD.H_KERNBURG, mat="Material_hell", art=1, dachhoehe=8)
gebaeude("Burgkueche", BG, PD.BURGKUECHE, 7, PD.H_KERNBURG, dach="Material_dach")
gebaeude("Zeughaus", BG, PD.ZEUGHAUS, 8, PD.H_KERNBURG)
for name, pp, text in [("SchildPalas", (995, 155), "Palas"), ("SchildKapelle", (1075, 215), "Drachenkapelle"),
                       ("SchildKueche", (905, 252), "Burgküche"), ("SchildZeughaus", (1030, 260), "Zeughaus")]:
    x, z = W(pp)
    schild(name, BG, x, PD.H_KERNBURG + 22, z, text, 40)
schild("SchildKernburg", BG, *(lambda p: (p[0], PD.H_KERNBURG + 10, p[1]))(W((975, 225))), "Kernburg", 44)

# Übungsplatz mit zwei Puppen im Hof der Kernburg (Stufe 4, Kampf)
OB = DS + "/ObererBurg"
UEB = W((960, 225))
N("ObererBurg", "Node3D", DS, T(round(UEB[0], 2), PD.H_KERNBURG, round(UEB[1], 2)))
for k, x in enumerate([-2.5, 2.5]):
    gegner(f"Uebungspuppe{k + 1}", OB, x, 0, 0, "Übungspuppe", waffe="puppe", tracht="0.55, 0.45, 0.3, 1")
schild("SchildUebungsplatz", OB, 0, 3.5, 4, "Übungsplatz", 40)

# --- Stadt und Hafen ---
teil("teil_stadt.py")
zinnen_schreiben(DS)
