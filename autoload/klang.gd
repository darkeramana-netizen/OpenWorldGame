extends Node
## Geräusche des Spiels (Dateien in klaenge/, erzeugt von werkzeuge/klaenge_erzeugen.py, Quellen in klaenge/QUELLEN.md).
##
## - Einzelne Geräusche an einem Ort: spiele("tuer_auf", ort). Gibt es Varianten (name_1, name_2 …), wird eine davon
##   zufällig gewählt, mit leicht schwankender Tonhöhe und Lautstärke, damit nichts maschinell klingt.
## - Schritte: schritt(ort, untergrund) mit "stein", "erde", "gras" oder "holz"; den Untergrund liefert untergrund().
## - Dauergeräusche an einem Ding (Feuer): dauerklang(eltern, "feuer", ...) hängt eine Klangquelle an.
## - Umgebung (ohne Ort): Wind, sanft überall draußen und stark in der Höhe (Mauern, Türme), Vogelrufe bei Tag um den
##   Hörer herum, Brandung nahe der Meereshöhe; drinnen (Decke über dem Kopf) alles leiser.
## - Glocken zur vollen Stunde (Spielzeit): St. Marien (groß), die Glockenstube des Bergfrieds und der Glockenturm von
##   Gravemarch (klein).
## - Amboss: wo ein Knoten in der Gruppe "klang_amboss" steht (die Schmiede, ausstattung.gd), hämmert tagsüber jemand.
##
## Lautstärke: Busse "Umgebung" und "Geraeusche" unter Master (Schalter im Menü folgen später).

const ORDNER := "res://klaenge/"
const POOL := 24
const SCHLEIFEN := ["wind_sanft", "wind_stark", "feuer", "brandung"]

var _streams := {}                  # Name → AudioStream (oder null, wenn es die Datei nicht gibt)
var _varianten := {}                # Grundname → Anzahl Varianten
var _pool: Array[AudioStreamPlayer3D] = []
var _naechster := 0
var _wind_sanft: AudioStreamPlayer
var _wind_stark: AudioStreamPlayer
var _brandung: AudioStreamPlayer
var _pruef := 0.0
var _drinnen := 0.0                 # 0 draußen .. 1 drinnen (weich)
var _hoehe := 0.0                   # über dem Boden
var _meer_y := NAN
var _vogel_in := 3.0
var _amboss_in := 0.0
var _amboss_folge := 0
var _region: Node = null
var _maske: Image = null
var _maske_ursprung := Vector2.ZERO
var _maske_groesse := Vector2.ONE
var _glocken: Array = []            # [Ort, groß?]
var _glocken_noch := 0
var _glocken_in := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Umgebung", "Geraeusche"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in POOL:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Geraeusche"
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		_pool.append(p)
	_wind_sanft = _umgebung("wind_sanft")
	_wind_stark = _umgebung("wind_stark")
	_brandung = _umgebung("brandung")
	var zeit := get_node_or_null("/root/Spielzeit")
	if zeit != null and zeit.has_signal("minute_vergangen"):
		zeit.minute_vergangen.connect(_minute)


func _umgebung(name_: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Umgebung"
	p.stream = stream(name_)
	p.volume_db = -80.0
	add_child(p)
	if p.stream != null:
		p.play(randf() * 5.0)
	return p


## Das Geräusch name (ohne Endung); Schleifen laufen endlos
func stream(name_: String) -> AudioStream:
	if _streams.has(name_):
		return _streams[name_]
	var pfad := ORDNER + name_ + ".ogg"
	var s: AudioStream = load(pfad) if ResourceLoader.exists(pfad) else null
	if s is AudioStreamOggVorbis and name_ in SCHLEIFEN:
		(s as AudioStreamOggVorbis).loop = true
	_streams[name_] = s
	return s


## Anzahl der Varianten name_1, name_2 … (0: keine)
func varianten(name_: String) -> int:
	if not _varianten.has(name_):
		var n := 0
		while ResourceLoader.exists(ORDNER + "%s_%d.ogg" % [name_, n + 1]):
			n += 1
		_varianten[name_] = n
	return _varianten[name_]


## Ein Geräusch am Ort (Welt). reichweite: ab hier nicht mehr zu hören; laut in dB.
func spiele(name_: String, ort: Vector3, laut := 0.0, reichweite := 25.0, tonhoehe := 1.0, streuen := true) -> void:
	var n := varianten(name_)
	var s := stream("%s_%d" % [name_, randi() % n + 1]) if n > 0 else stream(name_)
	if s == null:
		return
	var p := _pool[_naechster]
	_naechster = (_naechster + 1) % POOL
	p.stop()
	p.stream = s
	p.global_position = ort
	p.max_distance = reichweite
	p.unit_size = maxf(reichweite / 6.0, 1.0)
	p.volume_db = laut + (randf_range(-1.5, 1.0) if streuen else 0.0)
	p.pitch_scale = tonhoehe * (randf_range(0.94, 1.06) if streuen else 1.0)
	p.play()


## Ein Schritt am Ort (Fuß), Untergrund "stein", "erde", "gras" oder "holz"
func schritt(ort: Vector3, untergrund_: String, laut := -6.0) -> void:
	spiele("schritt_" + untergrund_, ort, laut, 18.0)


## Untergrund unter einem Punkt: Bauten und Pflaster Stein, Holzböden und Ausstattung Holz, im Gelände nach der Maske
## (Burghof und Stadt gepflastert, Wege Erde, sonst Gras). collider: der Körper, auf dem man steht (oder null).
func untergrund(collider: Object, ort: Vector3) -> String:
	if collider is Node:
		var n := collider as Node
		var pfad := String(n.get_path()) if n.is_inside_tree() else String(n.name)
		if "Steg" in pfad or "Holz" in pfad or "Ausstattung" in pfad or "Schiff" in pfad:
			return "holz"
		if not "Gelaende" in pfad and not "Gelände" in pfad:
			return "stein"
	return untergrund_gelaende(ort)


func untergrund_gelaende(ort: Vector3) -> String:
	_maske_laden()
	if _maske == null:
		return "gras"
	var uv := (Vector2(ort.x, ort.z) - _maske_ursprung) / _maske_groesse
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return "gras"
	var c := _maske.get_pixel(int(uv.x * _maske.get_width()), int(uv.y * _maske.get_height()))
	if c.b > 0.75:
		return "stein"        # Burghof
	if c.r > 0.3:
		return "erde"         # Weg (in der Stadt gepflastert; dort steht man meist auf den Kais und Höfen)
	return "gras"


## Ein Dauergeräusch (Schleife) an einem Ding; gibt die Klangquelle zurück
func dauerklang(eltern: Node3D, name_: String, laut := -8.0, reichweite := 14.0, ort := Vector3.ZERO) -> AudioStreamPlayer3D:
	var s := stream(name_)
	if s == null or eltern == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = "Klang_" + name_
	p.bus = "Geraeusche"
	p.stream = s
	p.volume_db = laut
	p.max_distance = reichweite
	p.unit_size = maxf(reichweite / 6.0, 1.0)
	p.position = ort
	p.autoplay = true
	eltern.add_child(p)
	if p.is_inside_tree() and not p.playing:
		p.play(randf() * 4.0)
	return p


func _process(delta: float) -> void:
	var kamera := get_viewport().get_camera_3d() if get_viewport() != null else null
	if kamera == null:
		_wind_sanft.volume_db = -80.0
		_wind_stark.volume_db = -80.0
		_brandung.volume_db = -80.0
		return
	var k := kamera.global_position
	_pruef -= delta
	if _pruef <= 0.0:
		_pruef = 0.5
		_umgebung_pruefen(kamera)
	# Wind: sanft überall draußen, stark ab etwa 6 m über dem Boden (Wehrgang, Turm), drinnen gedämpft
	var draussen := 1.0 - _drinnen
	var hoch := smoothstep(5.0, 22.0, _hoehe)
	_wind_sanft.volume_db = linear_to_db(maxf(0.22 * draussen + 0.04, 0.0001))
	_wind_stark.volume_db = linear_to_db(maxf(0.45 * hoch * draussen, 0.0001))
	# Brandung: nahe der Meereshöhe
	if not is_nan(_meer_y):
		_brandung.volume_db = linear_to_db(maxf((1.0 - smoothstep(4.0, 70.0, k.y - _meer_y)) * 0.35 * (0.4 + 0.6 * draussen), 0.0001))
	else:
		_brandung.volume_db = -80.0
	_voegel(delta, k)
	_hammer(delta, k)
	_glocken_schlagen(delta)


## Region, Höhe über dem Boden und ob über dem Kopf eine Decke ist (alle halbe Sekunde)
func _umgebung_pruefen(kamera: Camera3D) -> void:
	var szene := get_tree().current_scene
	if szene != _region:
		_region = szene
		_maske = null
		_meer_y = NAN
		_glocken_finden()
		var meer := szene.get_node_or_null("Meer") as Node3D if szene != null else null
		if meer != null:
			_meer_y = meer.global_position.y
	var k := kamera.global_position
	var raum := kamera.get_world_3d().direct_space_state
	var nach_unten := raum.intersect_ray(PhysicsRayQueryParameters3D.create(k, k + Vector3.DOWN * 60.0))
	_hoehe = k.y - nach_unten["position"].y if not nach_unten.is_empty() else 30.0
	var nach_oben := raum.intersect_ray(PhysicsRayQueryParameters3D.create(k + Vector3.UP * 0.3, k + Vector3.UP * 25.0))
	_drinnen = move_toward(_drinnen, 1.0 if not nach_oben.is_empty() else 0.0, 0.5)


func _maske_laden() -> void:
	if _maske != null or _region == null:
		return
	var g := _region.get_node_or_null("Gelaende")
	if g == null:
		return
	for m in g.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).material_override as ShaderMaterial
		if mat == null or mat.get_shader_parameter("maske") == null:
			continue
		var t := mat.get_shader_parameter("maske") as Texture2D
		var bild := t.get_image() if t != null else null
		if bild == null:
			return
		if bild.is_compressed():
			bild.decompress()
		_maske = bild
		_maske_ursprung = mat.get_shader_parameter("welt_ursprung")
		_maske_groesse = mat.get_shader_parameter("welt_groesse")
		return


## Vogelrufe bei Tag, draußen: alle paar Sekunden einer aus einer Richtung um den Hörer, in Baumhöhe
func _voegel(delta: float, k: Vector3) -> void:
	_vogel_in -= delta
	if _vogel_in > 0.0:
		return
	_vogel_in = randf_range(2.5, 8.0)
	var zeit := get_node_or_null("/root/Spielzeit")
	var stunde := float(zeit.minuten) / 60.0 if zeit != null else 10.0
	if stunde < 5.0 or stunde > 20.5 or _drinnen > 0.5:
		return
	var arten := ["amsel", "amsel", "spatz", "spatz", "meise", "fink", "schwalbe", "kraehe"]
	if stunde < 8.0 or stunde > 18.5:
		arten = ["amsel", "amsel", "amsel", "meise", "kraehe"]   # morgens und abends singen die Amseln
	var w := randf() * TAU
	var r := randf_range(10.0, 35.0)
	spiele("vogel_" + arten[randi() % arten.size()], k + Vector3(cos(w) * r, randf_range(3.0, 12.0), sin(w) * r),
		-9.0, 60.0)


## Amboss: tagsüber (7 bis 18 Uhr) in der nächsten Schmiede in Hörweite Folgen von drei bis sechs Schlägen
func _hammer(delta: float, k: Vector3) -> void:
	_amboss_in -= delta
	if _amboss_in > 0.0:
		return
	var zeit := get_node_or_null("/root/Spielzeit")
	var stunde := float(zeit.minuten) / 60.0 if zeit != null else 10.0
	var naechster: Node3D = null
	for a in get_tree().get_nodes_in_group("klang_amboss"):
		if a is Node3D and (naechster == null or k.distance_to(a.global_position) < k.distance_to(naechster.global_position)):
			naechster = a
	if naechster == null or stunde < 7.0 or stunde > 18.0 or k.distance_to(naechster.global_position) > 50.0:
		_amboss_in = 1.0
		_amboss_folge = 0
		return
	if _amboss_folge <= 0:
		_amboss_folge = randi_range(3, 6)
	spiele("amboss", naechster.global_position + Vector3.UP, -2.0, 50.0)
	_amboss_folge -= 1
	_amboss_in = randf_range(0.42, 0.5) if _amboss_folge > 0 else randf_range(2.0, 6.0)


## Glocken in der Region: Knoten mit bekanntem Namen
func _glocken_finden() -> void:
	_glocken.clear()
	if _region == null:
		return
	# nur nach Namen suchen (nicht jeden Knoten der Region in eine Liste: beim Laden sonst ein Hänger)
	for n in _region.find_children("StMarienTurm", "Node3D", true, false) + _region.find_children("Glocke*", "Node3D", true, false):
		var name_ := String(n.name)
		if name_ == "StMarienTurm":
			var tb: PackedFloat32Array = n.get("torbauten") if n.get("torbauten") != null else PackedFloat32Array()
			if tb.size() >= 6:
				_glocken.append([(n as Node3D).to_global(Vector3(tb[0], tb[5] - 4.0, tb[1])), true])
		elif name_ == "Glocke" or name_ == "Glockenturm":
			_glocken.append([(n as Node3D).global_position, false])


func _minute(minute: int) -> void:
	if minute % 60 != 0 or _glocken.is_empty():
		return
	var stunde := (minute / 60) % 12
	_glocken_noch = 12 if stunde == 0 else stunde
	_glocken_in = 0.0


func _glocken_schlagen(delta: float) -> void:
	if _glocken_noch <= 0:
		return
	_glocken_in -= delta
	if _glocken_in > 0.0:
		return
	for g: Array in _glocken:
		spiele("glocke_gross" if g[1] else "glocke_klein", g[0], 4.0 if g[1] else -2.0, 400.0 if g[1] else 200.0, 1.0, false)
	_glocken_noch -= 1
	_glocken_in = 2.6
