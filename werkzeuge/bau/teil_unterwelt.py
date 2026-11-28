# --- Der Untergrund von Drachenstein (szenen/welt/unterwelt.gd), erste Ausbaustufe (27.11.2026) ---
# Lore (docs/01-lore-bibel.md): „Darunter Kapelle, Krypta, Zisternen. Gebaut auf den Ruinen von Burg Sorrow.“
#
#   Palashof:  Gruftabgang neben der Drachenkapelle → Vorraum → Krypta der Großmeister (Sarkophage, Grabnischen, Altar)
#              Krypta → Rundkammer → Beinhaus; Rundkammer → Stufengang hinab → Rundkammer unter der Oberburg
#   Oberburg:  Zisterne (Säulenhalle mit Becken, unter dem Ziehbrunnen, Schacht hinauf)
#              Zisterne → Wendeltreppe (20 m) → Rundkammer → Riegeltür → Untergrundhafen (Abkürzung, von oben zu öffnen)
#   Tiefer:    hinter dem Sarkophag des Wulfric Dane eine Geheimtür → alter Stufengang → Ruinen von Burg Sorrow
#              (Halle mit eingestürzten Jochen, alte Kapelle mit dem Wappen der Ordnung von Sorrow, verbranntes Archiv
#              hinter einer verschlossenen Tür, ein verschütteter Gang nach Osten)
#   Schmuggler: der verschüttete Gang ist freigegraben (Einsturzhöhle) → Felsstieg hinab → Lager der Schmuggler →
#              Bootsgrotte → Meereshöhle an der Klippe (Mund zum Meer); vom Lager eine verschlossene Kammer mit Pulver
#              und Musketen (Kriegsgüter für Valdrenn, die Rufer)
#
# Alle Lagen in Weltkoordinaten; der Knoten Unterwelt steht im Ursprung. Die Treppenhäuschen schneiden das Gelände
# genau aus (gelaende.gd, schnitte).

E("Script", "res://szenen/welt/unterwelt.gd", "62_unterwelt")
E("Script", "res://szenen/welt/geheimtuer.gd", "63_geheimtuer")
E("Script", "res://szenen/welt/fluegel.gd", "64_fluegel")
E("Material", "res://material/holz.tres", "65_holz_mat")
E("Material", "res://material/metall.tres", "66_metall_mat")

UW_GW, UW_GA, UW_AB, UW_REG, UW_SCH, UW_SCHNITTE, UW_STUECKE, UW_FM = [], [], [], [], [], [], [], []


def _rahmen(c, gier):
    a = math.radians(gier)
    u, n = (math.sin(a), math.cos(a)), (math.cos(a), -math.sin(a))
    return lambda su, sn: (round(c[0] + u[0] * su + n[0] * sn, 3), round(c[1] + u[1] * su + n[1] * sn, 3))


def uw_raum(c, gier, laenge, breite, boden, wand, stich, art, joch, zier):
    UW_GW.extend([round(c[0], 3), round(c[1], 3), round(gier, 3), laenge, breite, round(boden, 3), wand, stich, art, joch, zier])
    return _rahmen(c, gier)


def uw_gang(a, ya, b, yb, breite=1.6, hoehe=2.8, art=0, fackeln=1):
    UW_GA.extend([a[0], round(ya, 3), a[1], b[0], round(yb, 3), b[1], breite, hoehe, art, fackeln])


def uw_abgang(tuer, gier, boden, breite, laenge, regel="tuer"):
    """Steinhäuschen über einer Treppe; Gier zeigt hinein. Schneidet das Gelände unter dem Häuschen aus."""
    UW_AB.extend([tuer[0], tuer[1], round(gier, 3), round(boden, 3), breite, laenge, 0])
    UW_REG.append(regel)
    a = math.radians(gier)
    halb_l = laenge / 2.0 + 0.25
    m = (tuer[0] + math.sin(a) * halb_l - math.sin(a) * 0.25, tuer[1] + math.cos(a) * halb_l - math.cos(a) * 0.25)
    UW_SCHNITTE.extend([round(m[0], 3), round(m[1], 3), round(gier, 3), round(halb_l, 3), round(breite / 2.0 + 0.3, 3)])
    _feste_w.append(_rechteck_w(m[0], m[1], breite + 1.6, laenge + 1.6, gier))


def rund_punkt(c, r, gier):
    """Punkt am Rand einer Rundkammer (0,25 m innerhalb der Wand) in Richtung gier"""
    a = math.radians(gier)
    return (round(c[0] + math.sin(a) * (r - 0.25), 3), round(c[1] + math.cos(a) * (r - 0.25), 3))


def gier_von(a, b):
    return math.degrees(math.atan2(b[0] - a[0], b[1] - a[1]))


def wendel_oben(gier, hoehe):
    stufen = max(1, round(hoehe / 0.2))
    return gier + 30.0 + (stufen - 1) * 360.0 / 18 + 40.0


def uw_stueck(art, p, y, gier):
    UW_STUECKE.extend([art, p[0], round(y, 3), p[1], round(gier, 2)])


def uw_lesbar(name, p, y, anzeige, dialog, aktion="Lesen"):
    N(name, "StaticBody3D", "UnterweltDinge", f"""{T(p[0], y, p[1])}
script = ExtResource("16_lesbar")
anzeige_name = "{anzeige}"
aktion_text = "{aktion}"
dialog_id = "{dialog}\"""")


def uw_durchsuchbar(name, p, y, anzeige, dialog, aktion="Durchsuchen"):
    N(name, "StaticBody3D", "UnterweltDinge", f"""{T(p[0], y, p[1])}
script = ExtResource("24_durchsuchbar")
anzeige_name = "{anzeige}"
aktion_text = "{aktion}"
dialog_id = "{dialog}\"""")


def uw_tuer(name, p, y, gier, breite, regel, bedingung, anzeige, hoehe=2.7, kaempfer=0.0, anzahl=1):
    N(name, "Node3D", "UnterweltDinge", f"""{T(p[0], y, p[1], gier)}
script = ExtResource("64_fluegel")
breite = {breite}
hoehe = {hoehe}
kaempfer = {kaempfer}
anzahl = {anzahl}
staerke = 0.09
winkel_offen = 95.0
regel = "{regel}"
bedingung = "{bedingung}"
anzeige_name = "{anzeige}"
reichweite = 2.2
mat_holz = ExtResource("65_holz_mat")
mat_metall = ExtResource("66_metall_mat")""")


# ---------- Krypta unter der Drachenkapelle ----------
# Die Krypta liegt fest (ihre Lage vor dem Umbau der Kapelle am 28.11.2026; die Gänge zu Rundkammer, Beinhaus und
# den Ruinen von Sorrow hängen an ihr); die neue Kapelle steht schräg darüber
KAP_C = (19.22, -93.59)
KAP_G = 147.8
KP = _rahmen(KAP_C, KAP_G)                      # u entlang der Krypta (+u zum Altar hin), n quer
# Rahmen der Kapelle darüber (u zum Portal, n quer)
KAPN_C = W(PD.DRACHENKAPELLE[0])
KAPN_G = -PD.DRACHENKAPELLE[3] % 360.0
KAPN = _rahmen(KAPN_C, KAPN_G)
H_KRYPTA = 8.6
KR_L, KR_B = 16.0, 11.0
uw_raum(KAP_C, KAP_G, KR_L, KR_B, H_KRYPTA, 2.4, 2.0, 0, 4.0, 1 | 2)

# Gruftabgang: ein Anbau an der Südseite der Kapelle, die Tür neben dem Portal zum Palashof (Rückmeldung 28.11.2026: das
# Häuschen stand abseits in einer Gasse). Die Treppe läuft an der Kapelle entlang nach Osten hinab, unten ein kurzer
# Gang, der von der Seite durch die Längswand in die Krypta tritt (zwischen zwei Sarkophagen)
_ga_tuer = KAPN(6.5, -(PD.KAPELLE_BREITE / 2.0 + 1.45))
_ga_boden = round(H(*_ga_tuer), 3)
uw_abgang(_ga_tuer, KAPN_G + 180.0, _ga_boden, 1.6, 6.2)
_ga_unten = KAPN(6.5 - 13.0, -(PD.KAPELLE_BREITE / 2.0 + 1.45))
_ga_vor = KP(4.0, -KR_B / 2.0 - 1.6)
uw_gang(_ga_tuer, _ga_boden, _ga_unten, H_KRYPTA)
uw_gang(_ga_unten, H_KRYPTA, _ga_vor, H_KRYPTA)
uw_gang(_ga_vor, H_KRYPTA, KP(4.0, -KR_B / 2.0), H_KRYPTA)
schild("SchildGruft", "UnterweltDinge", *(lambda p: (p[0], _ga_boden + 4.3, p[1]))(KAPN(6.5 + 0.7, -(PD.KAPELLE_BREITE / 2.0 + 1.45))),
       "Gruft der Großmeister", 32)

# Sarkophage (Art 58, Kopf zum Portal) mit Inschriften; der des Wulfric Dane steht vor der Geheimtür
_sarkophage = [((4.0, 3.45), "grab_wulfric_dane", "Sarkophag des Wulfric Dane"),
               ((-2.0, 3.67), "grab_osmund_rhee", "Sarkophag des Osmund Rhee"),
               ((-2.0, -3.67), "grab_hartwin_brand", "Sarkophag des Hartwin Brand"),
               ((2.0, -3.67), "grab_mechthild_arn", "Sarkophag der Mechthild Arn"),
               ((6.0, -3.67), "grab_ansgar_vale", "Ein unbeschriebener Sarkophag")]
for k_, ((su_, sn_), dlg_, anz_) in enumerate(_sarkophage):
    uw_stueck(58, KP(su_, sn_), H_KRYPTA, KAP_G)
    uw_lesbar(f"Grabinschrift{k_}", KP(su_ + 1.35, sn_), H_KRYPTA + 0.6, anz_, dlg_)
uw_stueck(61, KP(7.25, 0.0), H_KRYPTA, KAP_G + 180.0)           # Altar an der Stirnwand, Vorderseite zum Raum
uw_lesbar("KryptaAltar", KP(6.5, 0.0), H_KRYPTA + 1.0, "Altar der Krypta", "krypta_altar", "Ansehen")
for su_, sn_ in [(6.6, 1.3), (6.6, -1.3), (5.6, 3.45), (-3.6, 3.67), (0.6, -3.67)]:
    uw_stueck(60, KP(su_, sn_), H_KRYPTA, KAP_G)

# Geheimtür in der Längswand hinter Wulfric Dane: erst wenn man seine Inschrift gelesen hat, fällt die Fuge auf
_gt = KP(4.0, KR_B / 2.0)
N("GeheimtuerKrypta", "StaticBody3D", "UnterweltDinge", f"""{T(_gt[0], H_KRYPTA, _gt[1], KAP_G - 90.0)}
script = ExtResource("63_geheimtuer")
breite = 1.44
hoehe = 2.42
dicke = 0.5
stein = "bruchstein"
flag = "geheimgang_krypta"
bedingung = "hinweis_sorrow"
anzeige_name = "Eine Fuge hinter dem Sarkophag"
meldung_auf = "Du stemmst dich gegen den Stein. Er gibt nach und gleitet knirschend in die Mauer. Kalte Luft steigt aus der Tiefe."
akte = "Hinter dem Sarkophag des Wulfric Dane einen geheimen Gang in die Tiefe gefunden."
richtung = 1""")

# ---------- Rundkammer, Beinhaus, Stufengang zur Oberburg ----------
R2 = KP(-16.5, 0.0)
uw_raum(R2, 0.0, 5.0, 5.0, H_KRYPTA, 3.0, 1.6, 6, 0.0, 2)
uw_gang(KP(-KR_L / 2.0, 0.0), H_KRYPTA, KP(-14.25, 0.0), H_KRYPTA, fackeln=0)
# Beinhaus westlich der Rundkammer (Länge entlang Welt-x): Gebeinstapel an den Längswänden, Kerzen, ein Totenspruch
BH_C = (round(R2[0] - 12.4, 3), R2[1])
BH = uw_raum(BH_C, 90.0, 9.0, 6.0, H_KRYPTA, 2.2, 1.6, 0, 3.0, 8)
uw_gang((round(BH_C[0] + 4.5, 3), BH_C[1]), H_KRYPTA, rund_punkt(R2, 2.5, -90.0), H_KRYPTA, fackeln=0)
for su_ in (-3.3, -1.1, 1.1, 3.3):
    for sn_, g_ in ((2.68, 0.0), (-2.68, 180.0)):
        uw_stueck(59, BH(su_, sn_), H_KRYPTA, g_)
uw_stueck(59, BH(-4.18, 0.0), H_KRYPTA, 90.0)                       # Stirnwand: Rücken nach -x
for su_, sn_ in [(-2.2, 0.0), (0.0, 1.2), (2.4, -1.0)]:
    uw_stueck(60, BH(su_, sn_), H_KRYPTA, 0.0)
uw_lesbar("BeinhausTafel", BH(-3.7, 0.0), H_KRYPTA + 1.2, "Tafel über den Gebeinen", "beinhaus_tafel")

# Stufengang: von der Rundkammer erst eben, dann in Stufen hinab zu einer Rundkammer unter der Oberburg
WT_HOEHE = 22.0                                       # Wendeltreppe: 110 Stufen, der obere Ausgang zeigt nach Westen
H_ZISTERNE = round(PD.H_HAFEN + 0.04 + WT_HOEHE, 3)   # = Boden des Untergrundhafens + Höhe der Wendeltreppe
R1 = (6.0, -40.0)
_d = (R1[0] - R2[0], R1[1] - R2[1])
_dl = math.hypot(*_d)
_d = (_d[0] / _dl, _d[1] / _dl)
_a = (round(R2[0] + _d[0] * 2.25, 3), round(R2[1] + _d[1] * 2.25, 3))
_m = (round(_a[0] + _d[0] * 14.0, 3), round(_a[1] + _d[1] * 14.0, 3))
_b = (round(R1[0] - _d[0] * 2.25, 3), round(R1[1] - _d[1] * 2.25, 3))
uw_gang(_a, H_KRYPTA, _m, H_KRYPTA)
uw_gang(_m, H_KRYPTA, _b, H_ZISTERNE)
uw_raum(R1, 0.0, 5.0, 5.0, H_ZISTERNE, 3.0, 1.6, 6, 0.0, 2)

# ---------- Zisterne unter der Oberburg ----------
# genau unter dem Ziehbrunnen der Oberburg (der schöpft aus ihr)
ZI_C, ZI_L, ZI_B = (3.0, -2.0), 18.0, 14.0
ZI = uw_raum(ZI_C, 0.0, ZI_L, ZI_B, H_ZISTERNE, 3.2, 2.6, 2, 4.6, 2 | 32)
uw_gang((6.0, -37.75), H_ZISTERNE, (6.0, round(ZI_C[1] - ZI_L / 2.0, 3)), H_ZISTERNE)
uw_lesbar("ZisterneBauinschrift", ZI(-ZI_L / 2.0 + 0.4, -1.4), H_ZISTERNE + 1.7, "Bauinschrift", "zisterne_inschrift")
# Schacht des Ziehbrunnens der Oberburg, falls er über der Zisterne steht
if "Oberburg" in BURG_BRUNNEN:
    _bw = BURG_BRUNNEN["Oberburg"]
    _lu, _ln = _bw[1] - ZI_C[1], _bw[0] - ZI_C[0]
    if abs(_lu) < ZI_L / 2.0 - 2.4 and abs(_ln) < ZI_B / 2.0 - 2.4:
        # Höhe des Gewölbes am Schacht (dieselbe Rechnung wie unterwelt.gd, _kreuzjoch): tiefste Stelle am Rand
        _nu, _nb = max(1, round(ZI_L / 4.6)), max(1, round(ZI_B / 4.6))
        _su, _sb = ZI_L / _nu, ZI_B / _nb
        def _gewoelbe_y(lu_, ln_):
            i_ = min(_nu - 1, max(0, int((lu_ + ZI_L / 2.0) / _su)))
            j_ = min(_nb - 1, max(0, int((ln_ + ZI_B / 2.0) / _sb)))
            x_ = lu_ - (-ZI_L / 2.0 + (i_ + 0.5) * _su)
            z_ = ln_ - (-ZI_B / 2.0 + (j_ + 0.5) * _sb)
            fx_ = math.sqrt(max(0.0, 1.0 - (x_ / (_su / 2.0)) ** 2))
            fz_ = math.sqrt(max(0.0, 1.0 - (z_ / (_sb / 2.0)) ** 2))
            return H_ZISTERNE + 3.2 + 2.6 * max(fx_, fz_)
        _unten = min(_gewoelbe_y(_lu + 0.75 * math.cos(w_), _ln + 0.75 * math.sin(w_)) for w_ in [k_ * math.pi / 8 for k_ in range(16)])
        UW_SCH.extend([round(_bw[0], 3), round(_bw[1], 3), 0.7, round(_unten - 0.05, 3), round(H(*_bw) - 0.3, 3)])

# (Der Zisternenabgang im Hof der Oberburg ist entfallen: die Zisterne erreicht man über die Krypta und vom Hafen.)

# Wendeltreppe hinab zum Untergrundhafen: unten von Norden aus der Rundkammer vor dem Hafenstollen, oben nach Westen
WT_C, WT_R = (19.5, 0.5), 2.3
H_UH = round(PD.H_HAFEN + 0.04, 3)
uw_raum(WT_C, 180.0, WT_R * 2.0, WT_R * 2.0, H_UH, WT_HOEHE, 0.0, 5, 0.0, 2)
_wt_oben = wendel_oben(180.0, WT_HOEHE)
assert abs(((_wt_oben - 270.0) + 180.0) % 360.0 - 180.0) < 0.01, _wt_oben
uw_gang(rund_punkt(WT_C, WT_R, _wt_oben), H_ZISTERNE, (round(ZI_C[0] + ZI_B / 2.0, 3), WT_C[1]), H_ZISTERNE)
R0 = (19.5, -9.5)
uw_raum(R0, 0.0, 5.0, 5.0, H_UH, 3.0, 1.6, 6, 0.0, 2)
uw_gang(rund_punkt(WT_C, WT_R, 180.0), H_UH, rund_punkt(R0, 2.5, 0.0), H_UH)
# Stollen zur Tür in der Rückwand der Hafenhalle (flache Decke, so breit und hoch wie die Tür)
_uh_wand = (round(UH_MUND[0] - UH_LAENGE - 1.5, 3), UH_MUND[1])
uw_gang(_uh_wand, H_UH, rund_punkt(R0, 2.5, 90.0), H_UH, breite=2.6, hoehe=3.2, art=3, fackeln=0)
uw_tuer("RiegeltuerHafen", (round(_uh_wand[0] - 1.6, 3), _uh_wand[1]), H_UH, -90.0, 2.5, "riegel", "riegel_hafenstollen",
        "Die Tür zum Hafen", hoehe=3.1, anzahl=2)

# ---------- Ruinen von Burg Sorrow (hinter der Geheimtür) ----------
H_SORROW = -1.0
_s1_a = KP(4.0, KR_B / 2.0)
_s1_b = KP(4.0, KR_B / 2.0 + 26.0)
uw_gang(_s1_a, H_KRYPTA, _s1_b, H_SORROW, breite=1.4, hoehe=2.4, art=2, fackeln=0)
RH_G = KAP_G + 90.0                                   # Halle: Länge in Richtung des Gangs
RH_C = KP(4.0, KR_B / 2.0 + 26.0 + 10.0)
RH = uw_raum(RH_C, RH_G, 20.0, 12.0, H_SORROW, 3.0, 2.4, 3, 4.0, 16 | 8)
# alte Kapelle von Sorrow hinter der Halle
_s2_a = RH(10.0, 0.0)
_s2_b = RH(15.0, 0.0)
uw_gang(_s2_a, H_SORROW, _s2_b, H_SORROW, breite=1.4, hoehe=2.4, art=2, fackeln=0)
AK = uw_raum(RH(21.0, 0.0), RH_G, 12.0, 8.0, H_SORROW, 3.4, 2.0, 3, 4.0, 16 | 8)
uw_stueck(61, AK(5.0, 0.0), H_SORROW, RH_G + 180.0)
uw_lesbar("SorrowWappen", AK(5.7, 0.0), H_SORROW + 1.8, "Ein Wappenstein über dem Altar", "sorrow_wappen", "Ansehen")
uw_stueck(63, AK(1.0, 2.2), H_SORROW, RH_G + 70.0)
uw_stueck(62, AK(-3.0, -2.6), H_SORROW, 20.0)
# verbranntes Archiv seitlich der Halle, hinter einer verschlossenen Tür
_s3_a = RH(0.0, 6.0)
_s3_b = RH(0.0, 10.0)
uw_gang(_s3_a, H_SORROW, _s3_b, H_SORROW, breite=1.4, hoehe=2.4, art=2, fackeln=0)
AR = uw_raum(RH(0.0, 13.5), RH_G + 90.0, 7.0, 6.0, H_SORROW, 2.4, 1.6, 3, 3.5, 16 | 8 | 4)
uw_tuer("ArchivTuer", RH(0.0, 7.2), H_SORROW, RH_G + 90.0, 1.36, "schloss", "schluessel_sorrow_archiv",
        "Die eisenbeschlagene Tür", kaempfer=1.7)
uw_durchsuchbar("ArchivTruhe", AR(2.2, 1.6), H_SORROW + 0.5, "Eine verkohlte Truhe", "sorrow_archiv_truhe")
uw_lesbar("ArchivUrkunde", AR(-1.8, -1.9), H_SORROW + 0.9, "Ein halb verbranntes Blatt", "sorrow_archiv_blatt")
uw_stueck(1, AR(2.2, 1.6), H_SORROW, RH_G + 90.0)
uw_stueck(62, AR(-2.0, 1.8), H_SORROW, 50.0)
# in der Halle: ein Toter mit dem Schlüssel, Schutt, verstreute Gebeine
uw_stueck(63, RH(-4.0, -3.2), H_SORROW, RH_G + 100.0)
uw_durchsuchbar("SorrowToter", RH(-4.0, -3.2), H_SORROW + 0.3, "Ein Toter in verrostetem Kettenhemd", "sorrow_toter")
for su_, sn_, g_ in [(-7.0, 3.5, 10.0), (3.0, 4.0, 70.0), (6.5, -3.8, 130.0)]:
    uw_stueck(62, RH(su_, sn_), H_SORROW, g_)
uw_stueck(63, RH(5.0, 2.0), H_SORROW, RH_G - 40.0)
# verschütteter Gang nach Osten: die Schmuggler haben sich hindurchgegraben (Schmugglerhöhlen, unten)
_s4_a = RH(-2.0, -6.0)
_s4_b = RH(-2.0, -15.0)
uw_gang(_s4_a, H_SORROW, _s4_b, H_SORROW, breite=1.4, hoehe=2.4, art=2, fackeln=0)

# ---------- Der alte Weinkeller unter dem Palas ----------
# Längs zur alten Kapelle von Sorrow ausgerichtet, vom Palas her seit Langem zugemauert (Kellerbuch). Ein Durchbruch im
# Fels führt von der Kapelle neben dem Altar hinauf an seine Stirnwand.
H_WEINKELLER = 6.0
WK = uw_raum(AK(28.5, 1.0), RH_G, 20.0, 7.0, H_WEINKELLER, 2.0, 2.2, 1, 4.0, 2 | 4)
uw_gang(AK(6.0, 2.5), H_SORROW, AK(18.5, 2.5), H_WEINKELLER, breite=1.5, hoehe=2.4, art=1, fackeln=0)
# Lagerfässer vor den Nischen (je Feld eins, quer zur Wand), kleine Fässer, Kisten, ein Tisch mit dem Kellerbuch
for i_ in range(5):
    su_ = -10.0 + (i_ + 0.5) * 4.0
    for sn_ in (2.65, -2.65):
        if i_ == 0 and sn_ < 0:
            continue
        uw_stueck(64, WK(su_, sn_), H_WEINKELLER, RH_G + 90.0)
for su_, sn_, art_ in [(-7.9, -2.9, 0), (-6.95, -2.95, 0), (9.2, 1.0, 1), (9.2, 2.6, 1), (9.3, -2.8, 2), (3.8, -0.9, 0)]:
    uw_stueck(art_, WK(su_, sn_), H_WEINKELLER, RH_G + 10.0 * su_)
uw_stueck(45, WK(-1.5, 0.0), H_WEINKELLER, RH_G)
uw_stueck(60, WK(-1.5, 0.35), H_WEINKELLER + 0.78, 0.0)
uw_lesbar("Kellerbuch", WK(-1.5, -0.3), H_WEINKELLER + 0.9, "Das Kellerbuch", "weinkeller_buch")
uw_durchsuchbar("UralterWein", WK(6.0, -2.0), H_WEINKELLER + 0.7, "Ein Fass mit Kreidezeichen", "weinkeller_fass", "Anzapfen")

# ---------- Schmugglerhöhlen (27.11.2026) ----------
# Hinter der nördlichen Meereshöhle an der Ostklippe: ein Felsgang auf Meereshöhe in eine Bootsgrotte, darüber das Lager
# der Schmuggler, daneben hinter einer verschlossenen Tür die Kammer mit der Ware (Pulver, Musketen: Kriegsgüter, die
# nach Valdrenn gehen). Vom Lager ein langer Felsstieg hinauf in eine Einsturzhöhle am Ende des verschütteten Gangs der
# Ruinen von Burg Sorrow, durch den sich die Schmuggler gegraben haben.


def hoehle_rand(c, gier, laenge, breite, ziel):
    """Punkt am Rand einer Höhle (Ellipse, 0,25 m innerhalb der Wand) in Richtung ziel"""
    a = math.radians(gier)
    u, n = (math.sin(a), math.cos(a)), (math.cos(a), -math.sin(a))
    d = (ziel[0] - c[0], ziel[1] - c[1])
    dl = math.hypot(*d)
    d = (d[0] / dl, d[1] / dl)
    cu, cn = (d[0] * u[0] + d[1] * u[1]) / (laenge / 2.0), (d[0] * n[0] + d[1] * n[1]) / (breite / 2.0)
    r = 1.0 / math.sqrt(cu * cu + cn * cn)
    return (round(c[0] + d[0] * (r - 0.25), 3), round(c[1] + d[1] * (r - 0.25), 3))


# Mund an der Klippe (die nördliche Meereshöhle aus teil_stadt.py)
_mh = MEERESHOEHLE_OFFEN
MUND_FUSS = (_mh[0], _mh[1])
MUND_GIER = math.degrees(math.atan2(_mh[2], _mh[3]))
MUND_BREITE, MUND_HOEHE, MUND_STEIG = _mh[5], _mh[6], _mh[4]
H_MUND = -19.4
_mund_tief = 6.0
UW_FM.extend([MUND_FUSS[0], MUND_FUSS[1], round(MUND_GIER, 3), H_MUND, MUND_BREITE, MUND_HOEHE, MUND_STEIG, _mund_tief])
_mo = (math.sin(math.radians(MUND_GIER)), math.cos(math.radians(MUND_GIER)))
_sm = (MUND_FUSS[0] + _mo[0] * (1.6 - _mund_tief) / 2.0, MUND_FUSS[1] + _mo[1] * (1.6 - _mund_tief) / 2.0)
UW_SCHNITTE.extend([round(_sm[0], 3), round(_sm[1], 3), round(MUND_GIER, 3), round((1.6 + _mund_tief) / 2.0, 3), round(MUND_BREITE / 2.0 + 3.0, 3)])
_mund_innen = (round(MUND_FUSS[0] + _mo[0], 3), round(MUND_FUSS[1] + _mo[1], 3))

# Bootsgrotte, Lager, Warenkammer, Einsturzhöhle
G1_C = (round(MUND_FUSS[0] - _mo[0] * 15.75, 3), round(MUND_FUSS[1] - _mo[1] * 15.75, 3))
G1 = uw_raum(G1_C, MUND_GIER, 16.0, 12.0, H_MUND, 3.2, 3.5, 4, 0.0, 2)
uw_gang(_mund_innen, H_MUND, hoehle_rand(G1_C, MUND_GIER, 16.0, 12.0, _mund_innen), H_MUND,
        breite=round(MUND_BREITE + 0.4, 2), hoehe=MUND_HOEHE, art=1, fackeln=0)
H_LAGER = -17.0
G2_C = (round(G1_C[0] - _mo[0] * 23.0, 3), round(G1_C[1] - _mo[1] * 23.0, 3))
G2 = uw_raum(G2_C, MUND_GIER, 14.0, 11.0, H_LAGER, 3.0, 3.0, 4, 0.0, 2)
uw_gang(hoehle_rand(G1_C, MUND_GIER, 16.0, 12.0, G2_C), H_MUND, hoehle_rand(G2_C, MUND_GIER, 14.0, 11.0, G1_C), H_LAGER,
        breite=2.2, hoehe=2.8, art=1, fackeln=0)
G3_C = G2(0.0, 13.5)                      # quer zur Grotte, auf der Seite +n des Lagers
G3_G = MUND_GIER - 90.0
G3 = uw_raum(G3_C, G3_G, 8.0, 7.0, H_LAGER, 2.6, 2.2, 4, 0.0, 8)
_t2_a = hoehle_rand(G2_C, MUND_GIER, 14.0, 11.0, G3_C)
_t2_b = hoehle_rand(G3_C, G3_G, 8.0, 7.0, G2_C)
uw_gang(_t2_a, H_LAGER, _t2_b, H_LAGER, breite=1.6, hoehe=2.4, art=1, fackeln=0)
_t2_m = ((_t2_a[0] + _t2_b[0]) / 2.0, (_t2_a[1] + _t2_b[1]) / 2.0)
uw_tuer("TuerWarenkammer", (round(_t2_m[0], 3), round(_t2_m[1], 3)), H_LAGER, round(gier_von(_t2_a, _t2_b), 2), 1.54, "schloss",
        "schluessel_schmuggler", "Die beschlagene Bohlentür", kaempfer=1.6)
J_C = RH(-2.0, -18.75)
J = uw_raum(J_C, RH_G, 9.0, 8.0, H_SORROW, 2.8, 2.5, 4, 0.0, 8)
uw_gang(hoehle_rand(J_C, RH_G, 9.0, 8.0, G2_C), H_SORROW, hoehle_rand(G2_C, MUND_GIER, 14.0, 11.0, J_C), H_LAGER,
        breite=1.5, hoehe=2.4, art=1, fackeln=1)

# Einsturzhöhle: Schutt beiseitegeräumt, Hackspuren
for (su_, sn_), g_ in [((-2.3, 1.6), 20.0), ((2.6, -0.8), 75.0), ((-0.6, -2.6), 140.0)]:
    uw_stueck(62, J(su_, sn_), H_SORROW, g_)
uw_stueck(1, J(2.4, 1.8), H_SORROW, 30.0)
uw_lesbar("SchmugglerDurchbruch", RH(-2.0, -15.9), H_SORROW + 1.0, "Frische Hackspuren im Schutt", "schmuggler_durchbruch", "Ansehen")

# Bootsgrotte: ein hochgezogenes Boot, Ware am Rand, Netze
uw_stueck(7, G1(2.0, 3.4), H_MUND + 0.35, MUND_GIER - 10.0)
for (su_, sn_), art_ in [((-3.0, -4.0), 0), ((-2.2, -4.3), 0), ((-1.4, -4.4), 1), ((-5.0, 2.8), 1), ((-4.3, 3.5), 2),
                         ((-5.6, 1.9), 1), ((0.6, -4.6), 2)]:
    uw_stueck(art_, G1(su_, sn_), H_MUND, MUND_GIER + 15.0 * su_)
uw_stueck(37, G1(4.0, -4.6), H_MUND, MUND_GIER + 180.0)
uw_stueck(38, G1(5.4, -3.7), H_MUND, 0.0)

# Lager: Feuer in der Mitte, Schlafplätze, Tisch mit der Kiste, Vorräte; zwei Schmuggler
uw_stueck(65, G2(0.0, 0.5), H_LAGER, 0.0)
licht("LagerfeuerSchein", "UnterweltDinge", *(lambda p: (p[0], H_LAGER + 1.0, p[1]))(G2(0.0, 0.5)), 12.0)
for (su_, sn_), g_ in [((-3.8, 2.6), MUND_GIER), ((-4.4, -2.7), MUND_GIER - 15.0), ((2.6, 3.5), MUND_GIER + 95.0)]:
    uw_stueck(66, G2(su_, sn_), H_LAGER, g_)
uw_stueck(45, G2(3.0, -2.8), H_LAGER, MUND_GIER)
uw_stueck(60, G2(3.0, -2.5), H_LAGER + 0.78, 0.0)
for (su_, sn_), art_ in [((-5.0, 3.9), 1), ((-4.2, 4.3), 1), ((-5.2, 4.6), 0), ((4.8, 2.4), 0), ((5.1, 1.5), 0),
                         ((4.6, -3.6), 2), ((-1.0, -4.6), 1)]:
    uw_stueck(art_, G2(su_, sn_), H_LAGER, MUND_GIER + 20.0 * su_)
uw_durchsuchbar("SchmugglerKiste", G2(3.0, -2.8), H_LAGER + 1.0, "Eine Kiste auf dem Tisch", "schmuggler_kiste")
uw_lesbar("SchmugglerInschrift", G2(-5.6, -1.6), H_LAGER + 1.6, "Eingeritzte Worte in der Felswand", "schmuggler_inschrift", "Ansehen")
for k_, (su_, sn_) in enumerate([(-1.8, -1.4), (1.4, 2.0)]):
    p_ = G2(su_, sn_)
    gegner(f"Schmuggler{k_ + 1}", "UnterweltDinge", p_[0], H_LAGER + 0.1, p_[1], "Schmuggler", waffe="saebel",
           flag="schmuggler_lager", gier=MUND_GIER + 90.0 + 140.0 * k_, tracht="0.22, 0.2, 0.18, 1")

# Warenkammer: Pulverfässer, Kisten mit Musketen, Spieße
for (su_, sn_), art_, g_ in [((-2.0, -2.3), 1, 0.0), ((-1.2, -2.5), 1, 10.0), ((-2.2, -1.5), 1, 80.0), ((-2.6, 2.2), 0, 0.0),
                             ((-1.9, 2.5), 0, 0.0), ((-2.9, 1.4), 0, 0.0), ((0.8, -2.7), 13, G3_G + 90.0), ((1.4, 2.6), 48, G3_G - 90.0)]:
    uw_stueck(art_, G3(su_, sn_), H_LAGER, g_)
uw_durchsuchbar("SchmugglerMusketen", G3(-1.6, -2.0), H_LAGER + 0.9, "Lange Kisten mit Teerzeichen", "schmuggler_musketen", "Öffnen")


# ---------- Stadtkeller (27.11.2026) ----------
# Der Keller eines Händlers am Vorburgplatz in der oberen Stadt: gewölbt, ganz unter dem Haus, Zugang über ein
# verschlossenes Kellerhäuschen auf dem Platz (den Schlüssel haben die Schmuggler in ihrer Warenkammer). Hier verschwindet
# die Ware aus den Höhlen in die Stadt (Hehlerbuch). Hinter einer Geheimtür ein alter Fluchtgang unter die Vorburg zu
# einer Rundkammer unter ihrem Ziehbrunnen.
SK_C = (74.2, 142.9)                      # unter dem Haus (Stadthaeuser, Form 10 x 11 m)
H_SK = -15.0
SK = uw_raum(SK_C, 0.0, 8.0, 7.0, H_SK, 1.8, 1.3, 1, 4.0, 2 | 4)
_sk_tuer = (74.0, 156.5)
_sk_boden = H(*_sk_tuer)
uw_abgang(_sk_tuer, 180.0, _sk_boden, 1.6, 6.2, "schloss:schluessel_hehlerkeller")
uw_gang(_sk_tuer, _sk_boden, (74.0, round(SK_C[1] + 4.0, 3)), H_SK)
schild("SchildHehlerkeller", "UnterweltDinge", 74.0, _sk_boden + 4.3, 157.2, "Keller", 32)
# Ware, Fässer, ein Tisch mit dem Hehlerbuch, eine Geldkiste
for (su_, sn_), art_, g_ in [((-2.2, 2.7), 64, 90.0), ((1.8, 2.7), 64, 90.0), ((-3.0, -2.6), 1, 10.0), ((-2.2, -2.8), 1, -5.0),
                             ((-3.1, -1.8), 2, 90.0), ((2.6, -2.7), 0, 0.0), ((3.2, -2.3), 0, 0.0), ((0.4, -2.9), 1, 30.0)]:
    uw_stueck(art_, SK(su_, sn_), H_SK, g_)
uw_stueck(45, SK(0.5, 0.2), H_SK, 90.0)
uw_stueck(60, SK(0.2, 0.4), H_SK + 0.78, 0.0)
uw_lesbar("Hehlerbuch", SK(0.6, 0.0), H_SK + 0.9, "Ein Rechnungsbuch", "hehlerbuch")
uw_durchsuchbar("HehlerGeldkiste", SK(0.4, -2.9), H_SK + 0.6, "Eine kleine eisenbeschlagene Kiste", "hehler_geldkiste")
# Geheimtür in der Westwand (zur Vorburg), erst nach dem Hehlerbuch zu finden
_sk_gt = SK(1.0, -3.5)
N("GeheimtuerHehlerkeller", "StaticBody3D", "UnterweltDinge", f"""{T(_sk_gt[0], H_SK, _sk_gt[1], 90.0)}
script = ExtResource("63_geheimtuer")
breite = 1.44
hoehe = 2.42
dicke = 0.5
stein = "bruchstein"
flag = "fluchtgang_vorburg"
bedingung = "hehlerbuch_gelesen"
anzeige_name = "Ein Regal, das nicht an der Wand steht"
meldung_auf = "Hinter dem Regal gibt die Wand nach. Ein schmaler, alter Gang führt nach Westen."
akte = "Im Keller des Hehlers am Vorburgplatz einen alten Gang nach Westen gefunden."
richtung = 1""")
# Alter Fluchtgang zur Rundkammer unter dem Brunnen der Vorburg
if "Vorburg" in BURG_BRUNNEN:
    _vb = BURG_BRUNNEN["Vorburg"]
    R6 = (round(_vb[0], 3), round(_vb[1], 3))
    uw_raum(R6, 0.0, 5.0, 5.0, H_SK, 2.6, 1.4, 6, 0.0, 8)
    # erst gerade nach Westen aus der Kellerwand, in einer kleinen Kammer knickt der Gang zum Brunnen ab
    R7 = (62.0, _sk_gt[1])
    uw_raum(R7, 0.0, 4.0, 4.0, H_SK, 2.4, 1.2, 6, 0.0, 8)
    uw_gang(_sk_gt, H_SK, rund_punkt(R7, 2.0, 90.0), H_SK, breite=1.4, hoehe=2.4, art=2, fackeln=0)
    uw_gang(rund_punkt(R7, 2.0, gier_von(R7, R6)), H_SK, rund_punkt(R6, 2.5, gier_von(R6, R7)), H_SK, breite=1.4, hoehe=2.4, art=2,
            fackeln=0)
    UW_SCH.extend([R6[0], R6[1], 0.7, round(H_SK + 2.6 + 1.4 - 0.3, 3), round(H(*_vb) - 0.3, 3)])
    uw_stueck(63, (round(R6[0] + 1.2, 3), round(R6[1] - 0.8, 3)), H_SK, 40.0)
    uw_lesbar("FluchtgangInschrift", (round(R6[0] - 1.9, 3), R6[1]), H_SK + 1.6, "Eine Inschrift neben dem Gang", "fluchtgang_inschrift")

# ---------- Knoten ----------
N("Unterwelt", "Node3D", ".", f"""script = ExtResource("62_unterwelt")
gewoelbe = PackedFloat32Array({_zahlen(UW_GW)})
gaenge = PackedFloat32Array({_zahlen(UW_GA)})
abgaenge = PackedFloat32Array({_zahlen(UW_AB)})
abgang_regeln = PackedStringArray({", ".join(f'"{r_}"' for r_ in UW_REG)})
schaechte = PackedFloat32Array({_zahlen(UW_SCH)})
felsmuender = PackedFloat32Array({_zahlen(UW_FM)})""")
# Inschriften, Türen, Schilder und Ausstattung hängen an einem eigenen Knoten (burgbau.gd räumt beim Bauen alle Kinder
# des Bauknotens weg); er wurde oben schon mit ihnen angelegt und kommt vor das erste von ihnen
_uw_erstes = next(i_ for i_, t_ in enumerate(knoten) if 'parent="UnterweltDinge"' in t_)
knoten.insert(_uw_erstes, '[node name="UnterweltDinge" type="Node3D" parent="."]')
N("UnterweltAusstattung", "Node3D", "UnterweltDinge", "script = ExtResource(\"29_ausstattung\")\nstuecke = PackedFloat32Array("
  + _zahlen(UW_STUECKE) + ")")
# Gelände: genaue Schnitte unter den Treppenhäuschen
_gi = next(i_ for i_, t_ in enumerate(knoten) if t_.startswith('[node name="Gelaende"'))
knoten[_gi] += f"\nschnitte = PackedFloat32Array({_zahlen(UW_SCHNITTE)})"
