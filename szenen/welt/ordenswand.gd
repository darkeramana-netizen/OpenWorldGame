extends Node3D
## Die Ordenswand im Hof (Lore: Alltag 2). Setzt Namenssteine in die Wand.
## Gekerbte Steine (Gefallene) sind dunkler. Der erste Stein links oben ist Jorins.

@export var spalten: int = 14
@export var reihen: int = 5
@export var abstand: Vector2 = Vector2(0.9, 0.6)
## Anteil gefallener Mitglieder, deren Stein eine Kerbe trägt.
@export_range(0.0, 1.0) var anteil_gekerbt: float = 0.25

const GROESSE := Vector3(0.7, 0.4, 0.12)

## Der Platz unten rechts bleibt frei für den eigenen Stein nach dem Haupteid.
var _eigener_platz := Vector3.ZERO
var _eigener_stein: Node3D


func _ready() -> void:
	Spielstand.flag_geaendert.connect(func(_f: String) -> void: _zeige_eigenen_stein())
	var zufall := RandomNumberGenerator.new()
	zufall.seed = 1750
	var mesh := BoxMesh.new()
	mesh.size = GROESSE
	var hell := _material(Color(0.5, 0.48, 0.44))
	var dunkel := _material(Color(0.3, 0.28, 0.26))
	var jorin := _material(Color(0.7, 0.56, 0.3))

	var start := Vector2(-(spalten - 1) * abstand.x / 2.0, 1.0)
	for reihe in reihen:
		for spalte in spalten:
			var platz := Vector3(start.x + spalte * abstand.x, start.y + (reihen - 1 - reihe) * abstand.y, 0.55)
			if reihe == reihen - 1 and spalte == spalten - 1:
				_eigener_platz = platz
				continue
			var stein := MeshInstance3D.new()
			stein.mesh = mesh
			stein.position = platz
			if reihe == 0 and spalte == 0:
				stein.material_override = jorin
			elif zufall.randf() < anteil_gekerbt:
				stein.material_override = dunkel
			else:
				stein.material_override = hell
			add_child(stein)
	_zeige_eigenen_stein()


## Nach dem Haupteid wird der Name des Spielers in einen neuen, hellen Stein geschlagen.
func _zeige_eigenen_stein() -> void:
	if _eigener_stein != null or not Spielstand.hat_flag("eid_waechter"):
		return
	_eigener_stein = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = GROESSE
	_eigener_stein.mesh = mesh
	_eigener_stein.material_override = _material(Color(0.78, 0.76, 0.7))
	_eigener_stein.position = _eigener_platz
	add_child(_eigener_stein)
	var name_schild := Label3D.new()
	# Eingeschlagener Name: dunkle Schrift auf hellem Stein.
	name_schild.text = Spielstand.spieler_name
	name_schild.font_size = 48
	name_schild.pixel_size = 0.004
	name_schild.outline_size = 0
	name_schild.modulate = Color(0.12, 0.1, 0.08)
	name_schild.position = _eigener_platz + Vector3(0, 0, 0.07)
	add_child(name_schild)


func _material(farbe: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = farbe
	material.roughness = 1.0
	return material
