@tool
extends Node3D
## Ein begehbarer, achteckiger Turm: Ebenen mit Böden, Außenmauern mit Türen,
## ein Treppenhaus in der Mitte mit einer Wendelrampe um eine Säule, Zinnen auf dem Dach.
## Wird beim Start (und im Editor) aus den Werten unten gebaut, samt Kollision.
##
## Jede Ebene steigt mit einer vollen Umdrehung der Rampe zur nächsten. Die Türen zum
## Treppenhaus liegen auf allen Ebenen beim Winkel "treppen_winkel".
## Winkel in Grad, gemessen in der Ebene von +x nach +z.

## Nummer jeder Ebene, z. B. -4 bis 8. Der Ursprung liegt auf dem Boden von Ebene 0.
@export var ebenen_nummern: PackedInt32Array
@export var ebenen_namen: PackedStringArray
## Höhe jedes Bodens. Ein Eintrag mehr als Ebenen: der letzte ist das Dach.
@export var boden_hoehen: PackedFloat32Array
## Außenradius (Ecke des Achtecks) und Mauerstärke je Ebene.
@export var aussen_radien: PackedFloat32Array
@export var wandstaerken: PackedFloat32Array
## Türen in der Außenmauer: x = Ebenennummer, y = Winkel.
@export var eingaenge: PackedVector2Array
@export var eingang_breite: float = 4.0
@export var eingang_hoehe: float = 5.0
## Drehung des Achtecks: Eine Seite zeigt genau in diese Richtung.
@export var achteck_winkel: float = 0.0
@export var treppen_winkel: float = 0.0
@export var treppenhaus_radius: float = 4.6
@export var saeulen_radius: float = 1.2
@export var zinnen_hoehe: float = 1.6
@export var material_wand: Material
@export var material_boden: Material
@export var material_rampe: Material
## Der Turm reicht unter den Meeresspiegel (Unterbau des Bergfrieds). Dann gilt die
## Rettung aus dem Wasser in seinem Inneren nicht.
@export var wasserdicht: bool = false
@export var mit_licht: bool = true
@export var mit_schildern: bool = true
@export var neu_bauen: bool = false:
	set(_wert):
		_baue()

const TREPPENHAUS_WAND := 0.4
const TUER_TREPPE_BREITE := 1.9
const TUER_TREPPE_HOEHE := 2.8
const RAMPE_STAERKE := 0.3
const RAMPE_SCHRITT := 5.0  # Grad pro Rampenstück
const BODEN_STAERKE := 0.5
const SEGMENTE := 32

var _st_wand := SurfaceTool.new()
var _st_boden := SurfaceTool.new()
var _st_rampe := SurfaceTool.new()


func _ready() -> void:
	if wasserdicht:
		add_to_group("wasserdicht")
	_baue()


## Liegt dieser Punkt (waagerecht) innerhalb des Turms?
func enthaelt(punkt: Vector3) -> bool:
	var rel := punkt - global_position
	return Vector2(rel.x, rel.z).length() < aussen_radien[0]


func ebenen_anzahl() -> int:
	return ebenen_nummern.size()


## Höhe des Bodens einer Ebene (nach Nummer) in Turmkoordinaten.
func boden_von(nummer: int) -> float:
	var i := ebenen_nummern.find(nummer)
	return boden_hoehen[i] if i >= 0 else 0.0


func dach_hoehe() -> float:
	return boden_hoehen[boden_hoehen.size() - 1]


func _baue() -> void:
	if ebenen_nummern.is_empty() or boden_hoehen.size() != ebenen_nummern.size() + 1:
		return
	for kind in get_children():
		if kind.has_meta("turm_gebaut"):
			remove_child(kind)
			kind.queue_free()
	# Ein Mesh pro Ebene: So wirken die Lichter jeder Ebene auch im einfachen Renderer,
	# und Godot kann Ebenen außerhalb des Blickfelds weglassen.
	var alle_flaechen := PackedVector3Array()
	var n := ebenen_anzahl()
	for i in n:
		_beginne_mesh()
		_baue_mauer(i)
		_baue_boden(i)
		_baue_rampe(i)
		_baue_treppenhaus(i)
		alle_flaechen.append_array(_beende_mesh("Ebene_%d" % ebenen_nummern[i]))
	_beginne_mesh()
	_baue_dach()
	_baue_saeule()
	alle_flaechen.append_array(_beende_mesh("Dach"))

	var koerper := StaticBody3D.new()
	koerper.name = "Kollision"
	var form := CollisionShape3D.new()
	var flaechen := ConcavePolygonShape3D.new()
	flaechen.set_faces(alle_flaechen)
	flaechen.backface_collision = true
	form.shape = flaechen
	koerper.add_child(form)
	_neu(koerper)

	if mit_licht or mit_schildern:
		for i in n:
			_baue_licht_und_schild(i)


func _beginne_mesh() -> void:
	for st in [_st_wand, _st_boden, _st_rampe]:
		st.clear()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)


## Fügt das gebaute Teil als eigenes Mesh hinzu und gibt seine Dreiecke für die Kollision zurück.
func _beende_mesh(name: String) -> PackedVector3Array:
	var mesh := ArrayMesh.new()
	for paar in [[_st_wand, material_wand], [_st_boden, material_boden], [_st_rampe, material_rampe]]:
		var arrays: Array = (paar[0] as SurfaceTool).commit_to_arrays()
		var punkte: Variant = arrays[Mesh.ARRAY_VERTEX]
		if punkte == null or (punkte as PackedVector3Array).is_empty():
			continue  # z. B. das Dach hat keine Rampe
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, paar[1])
	var anzeige := MeshInstance3D.new()
	anzeige.name = name
	anzeige.mesh = mesh
	_neu(anzeige)
	return mesh.get_faces()


func _neu(knoten: Node) -> void:
	knoten.set_meta("turm_gebaut", true)
	add_child(knoten)


# ---------- Bauteile ----------

func _baue_mauer(i: int) -> void:
	var unten := boden_hoehen[i]
	var oben := boden_hoehen[i + 1]
	var r := aussen_radien[i]
	var staerke := wandstaerken[i]
	var apothem := r * cos(deg_to_rad(22.5))
	var laenge := 2.0 * apothem * tan(deg_to_rad(22.5)) + 0.05
	var tueren: Array[float] = []
	for e in eingaenge:
		if int(e.x) == ebenen_nummern[i]:
			tueren.append(e.y)
	for k in 8:
		var winkel := achteck_winkel + k * 45.0
		var mitte := apothem - staerke / 2.0
		var hat_tuer := false
		for t in tueren:
			if absf(angle_difference(deg_to_rad(t), deg_to_rad(winkel))) < deg_to_rad(22.5):
				hat_tuer = true
		if not hat_tuer:
			_quader_tangential(_st_wand, winkel, mitte, 0.0, laenge, unten, oben, staerke)
			continue
		# Seite mit Tür: zwei Wandstücke daneben und ein Sturz darüber.
		var seite := (laenge - eingang_breite) / 2.0
		var versatz := (eingang_breite + seite) / 2.0
		_quader_tangential(_st_wand, winkel, mitte, -versatz, seite, unten, oben, staerke)
		_quader_tangential(_st_wand, winkel, mitte, versatz, seite, unten, oben, staerke)
		_quader_tangential(_st_wand, winkel, mitte, 0.0, eingang_breite, unten + eingang_hoehe, oben, staerke)


func _baue_boden(i: int) -> void:
	var hoehe := boden_hoehen[i]
	var apothem := aussen_radien[i] * cos(deg_to_rad(22.5))
	var loch := 0.0 if i == 0 else treppenhaus_radius
	_ring(_st_boden, hoehe, loch, apothem)


func _baue_dach() -> void:
	var n := ebenen_anzahl()
	var hoehe := dach_hoehe()
	var r := aussen_radien[n - 1]
	var apothem := r * cos(deg_to_rad(22.5))
	_ring(_st_boden, hoehe, treppenhaus_radius, apothem)
	# Absatz über dem Treppenhaus: Nur das letzte Viertel vor der Ankunft der Rampe bleibt
	# offen, damit niemand auf dem Dach ins Treppenloch fällt.
	# Er reicht nur so weit, wie darunter auf der Rampe noch Kopffreiheit bleibt.
	var letzte_hoehe := hoehe - boden_hoehen[n - 1]
	var frei := clampf((letzte_hoehe - BODEN_STAERKE - 2.4) / letzte_hoehe * 360.0, 0.0, 300.0)
	_scheibe(_st_boden, hoehe, treppenhaus_radius, treppen_winkel, treppen_winkel + frei)
	# Brüstung mit Zinnen.
	var laenge := 2.0 * apothem * tan(deg_to_rad(22.5)) + 0.05
	for k in 8:
		var winkel := achteck_winkel + k * 45.0
		_quader_tangential(_st_wand, winkel, apothem - 0.5, 0.0, laenge, hoehe, hoehe + 1.0, 1.0)
		for z in [-1, 0, 1]:
			_quader_tangential(_st_wand, winkel, apothem - 0.5, z * laenge / 3.0, laenge / 6.0,
				hoehe + 1.0, hoehe + 1.0 + zinnen_hoehe, 1.0)


## Wand des Treppenhauses mit einer Tür auf jeder Ebene.
func _baue_treppenhaus(i: int) -> void:
	var unten := boden_hoehen[i]
	var oben := boden_hoehen[i + 1]
	var r := treppenhaus_radius - TREPPENHAUS_WAND / 2.0
	var schritt := 360.0 / SEGMENTE
	var laenge := 2.0 * treppenhaus_radius * tan(deg_to_rad(schritt / 2.0)) + 0.05
	var halbe_tuer := rad_to_deg(TUER_TREPPE_BREITE / 2.0 / treppenhaus_radius)
	for k in SEGMENTE:
		var winkel := treppen_winkel + (k + 0.5) * schritt
		if absf(rad_to_deg(angle_difference(deg_to_rad(winkel), deg_to_rad(treppen_winkel)))) < halbe_tuer + schritt / 2.0:
			_quader_tangential(_st_wand, winkel, r, 0.0, laenge, unten + TUER_TREPPE_HOEHE, oben, TREPPENHAUS_WAND)
		else:
			_quader_tangential(_st_wand, winkel, r, 0.0, laenge, unten, oben, TREPPENHAUS_WAND)


## Eine volle Umdrehung Rampe vom Boden dieser Ebene zum nächsten, als durchgehende
## Wendelfläche: Die Höhe am Ende einer Ebene ist genau die am Anfang der nächsten,
## dadurch gibt es keine Kanten, an denen die Spielfigur hängen bleibt.
func _baue_rampe(i: int) -> void:
	var unten := boden_hoehen[i]
	var oben := boden_hoehen[i + 1]
	var innen := saeulen_radius + 0.15
	var aussen := treppenhaus_radius - TREPPENHAUS_WAND - 0.05
	var stuecke := int(360.0 / RAMPE_SCHRITT)
	for j in stuecke:
		var wa := deg_to_rad(treppen_winkel + j * RAMPE_SCHRITT)
		var wb := deg_to_rad(treppen_winkel + (j + 1) * RAMPE_SCHRITT)
		var ya := lerpf(unten, oben, float(j) / stuecke)
		var yb := lerpf(unten, oben, float(j + 1) / stuecke)
		var ra := Vector3(cos(wa), 0.0, sin(wa))
		var rb := Vector3(cos(wb), 0.0, sin(wb))
		var ia := ra * innen + Vector3.UP * ya
		var oa := ra * aussen + Vector3.UP * ya
		var ib := rb * innen + Vector3.UP * yb
		var ob := rb * aussen + Vector3.UP * yb
		var tief := Vector3.DOWN * RAMPE_STAERKE
		var oben_normale := (oa - ia).cross(ib - ia).normalized()
		if oben_normale.y < 0.0:
			oben_normale = -oben_normale
		_viereck(_st_rampe, ia, oa, ob, ib, oben_normale)
		_viereck(_st_rampe, ia + tief, oa + tief, ob + tief, ib + tief, -oben_normale)
		_viereck(_st_rampe, oa, ob, ob + tief, oa + tief, (ra + rb).normalized())
		_viereck(_st_rampe, ia, ib, ib + tief, ia + tief, -(ra + rb).normalized())


func _baue_saeule() -> void:
	var unten := boden_hoehen[0]
	var oben := dach_hoehe() + 2.5
	var schritt := 360.0 / 16
	var laenge := 2.0 * saeulen_radius * tan(deg_to_rad(schritt / 2.0)) + 0.02
	for k in 16:
		_quader_tangential(_st_wand, k * schritt, saeulen_radius - 0.3, 0.0, laenge, unten, oben, 0.6)


func _baue_licht_und_schild(i: int) -> void:
	var unten := boden_hoehen[i]
	var hoehe := boden_hoehen[i + 1] - unten
	var innen := aussen_radien[i] * cos(deg_to_rad(22.5)) - wandstaerken[i]
	var gegenueber := deg_to_rad(treppen_winkel + 180.0)
	if mit_licht:
		var licht := OmniLight3D.new()
		licht.name = "Licht_%d" % ebenen_nummern[i]
		var abstand := (treppenhaus_radius + innen) / 2.0
		licht.position = Vector3(cos(gegenueber) * abstand, unten + hoehe * 0.75, sin(gegenueber) * abstand)
		licht.omni_range = innen * 2.6
		licht.light_energy = 2.4 if ebenen_nummern[i] >= 0 else 1.6
		licht.light_color = Color(1.0, 0.82, 0.6)
		_neu(licht)
		var treppenlicht := OmniLight3D.new()
		treppenlicht.name = "Treppenlicht_%d" % ebenen_nummern[i]
		treppenlicht.position = Vector3(0.0, unten + hoehe * 0.6, 0.0) + Vector3(cos(gegenueber), 0.0, sin(gegenueber)) * (treppenhaus_radius - 1.0)
		treppenlicht.omni_range = treppenhaus_radius * 2.5
		treppenlicht.light_energy = 1.2
		treppenlicht.light_color = Color(1.0, 0.8, 0.55)
		_neu(treppenlicht)
	if mit_schildern:
		var schild := Label3D.new()
		schild.name = "Schild_%d" % ebenen_nummern[i]
		var richtung := deg_to_rad(treppen_winkel)
		schild.position = Vector3(cos(richtung), 0.0, sin(richtung)) * (treppenhaus_radius + 0.6) + Vector3.UP * (unten + 3.2)
		schild.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		schild.pixel_size = 0.006
		schild.font_size = 48
		schild.outline_size = 10
		schild.text = "Ebene %d · %s" % [ebenen_nummern[i], ebenen_namen[i] if i < ebenen_namen.size() else ""]
		_neu(schild)


# ---------- Geometrie ----------

## Quader an einer Achteck- oder Kreisseite: winkel = Richtung der Seite,
## abstand = Abstand der Mitte vom Zentrum, versatz entlang der Seite.
func _quader_tangential(st: SurfaceTool, winkel: float, abstand: float, versatz: float, laenge: float,
		unten: float, oben: float, staerke: float) -> void:
	if oben <= unten + 0.01 or laenge <= 0.01:
		return
	var w := deg_to_rad(winkel)
	var radial := Vector3(cos(w), 0.0, sin(w))
	var tangente := Vector3(-sin(w), 0.0, cos(w))
	var zentrum := radial * abstand + tangente * versatz + Vector3.UP * (unten + oben) / 2.0
	_quader(st, zentrum, Basis(tangente, Vector3.UP, radial), Vector3(laenge / 2.0, (oben - unten) / 2.0, staerke / 2.0))


## Quader mit beliebiger Ausrichtung: halbe Kantenlängen entlang der Achsen der Basis.
func _quader(st: SurfaceTool, zentrum: Vector3, b: Basis, halb: Vector3) -> void:
	var ax := b.x * halb.x
	var ay := b.y * halb.y
	var az := b.z * halb.z
	var ecken: Array[Vector3] = []
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				ecken.append(zentrum + ax * sx + ay * sy + az * sz)
	# Index = (sx>0)*4 + (sy>0)*2 + (sz>0)
	_viereck(st, ecken[4], ecken[6], ecken[7], ecken[5], b.x)
	_viereck(st, ecken[0], ecken[1], ecken[3], ecken[2], -b.x)
	_viereck(st, ecken[2], ecken[3], ecken[7], ecken[6], b.y)
	_viereck(st, ecken[0], ecken[4], ecken[5], ecken[1], -b.y)
	_viereck(st, ecken[1], ecken[5], ecken[7], ecken[3], b.z)
	_viereck(st, ecken[0], ecken[2], ecken[6], ecken[4], -b.z)


## Ring (oder Scheibe) als Boden: oben und unten, zwischen Kreis und Achteck.
func _ring(st: SurfaceTool, hoehe: float, innen: float, apothem: float) -> void:
	for k in SEGMENTE:
		var w1 := TAU * k / SEGMENTE
		var w2 := TAU * (k + 1) / SEGMENTE
		var a1 := _achteck_rand(w1, apothem)
		var a2 := _achteck_rand(w2, apothem)
		var i1 := Vector3(cos(w1), 0.0, sin(w1)) * innen
		var i2 := Vector3(cos(w2), 0.0, sin(w2)) * innen
		for seite in [[hoehe, Vector3.UP], [hoehe - BODEN_STAERKE, Vector3.DOWN]]:
			var y := Vector3.UP * float(seite[0])
			_viereck(st, i1 + y, a1 + y, a2 + y, i2 + y, seite[1])


## Kreisausschnitt als Boden, von Winkel bis Winkel (Grad).
func _scheibe(st: SurfaceTool, hoehe: float, radius: float, von: float, bis: float) -> void:
	var schritte := int((bis - von) / 10.0)
	for k in schritte:
		var w1 := deg_to_rad(von + (bis - von) * k / schritte)
		var w2 := deg_to_rad(von + (bis - von) * (k + 1) / schritte)
		var a1 := Vector3(cos(w1), 0.0, sin(w1)) * radius
		var a2 := Vector3(cos(w2), 0.0, sin(w2)) * radius
		for seite in [[hoehe, Vector3.UP], [hoehe - BODEN_STAERKE, Vector3.DOWN]]:
			var y := Vector3.UP * float(seite[0])
			_viereck(st, y, a1 + y, a2 + y, y, seite[1])


func _achteck_rand(w: float, apothem: float) -> Vector3:
	var relativ := fposmod(rad_to_deg(w) - achteck_winkel + 22.5, 45.0) - 22.5
	var r := apothem / cos(deg_to_rad(relativ))
	return Vector3(cos(w), 0.0, sin(w)) * r


## Viereck mit Normale. Die Reihenfolge wird so gedreht, dass die Vorderseite
## zur Normale zeigt (Godot: Vorderseite im Uhrzeigersinn).
func _viereck(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normale: Vector3) -> void:
	var punkte := [a, b, c, d]
	if (b - a).cross(c - a).dot(normale) > 0.0:
		punkte = [a, d, c, b]
	st.set_normal(normale)
	for index in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(punkte[index])
