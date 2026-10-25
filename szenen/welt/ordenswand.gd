extends Node3D
## Die Ordenswand im Hof (Lore: Alltag 2). Setzt Namenssteine in die Wand.
## Gekerbte Steine (Gefallene) sind dunkler. Der erste Stein links oben ist Jorins.

@export var spalten: int = 14
@export var reihen: int = 5
@export var abstand: Vector2 = Vector2(0.9, 0.6)
## Anteil gefallener Mitglieder, deren Stein eine Kerbe trägt.
@export_range(0.0, 1.0) var anteil_gekerbt: float = 0.25

const GROESSE := Vector3(0.7, 0.4, 0.12)


func _ready() -> void:
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
			var stein := MeshInstance3D.new()
			stein.mesh = mesh
			stein.position = Vector3(start.x + spalte * abstand.x, start.y + (reihen - 1 - reihe) * abstand.y, 0.55)
			if reihe == 0 and spalte == 0:
				stein.material_override = jorin
			elif zufall.randf() < anteil_gekerbt:
				stein.material_override = dunkel
			else:
				stein.material_override = hell
			add_child(stein)


func _material(farbe: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = farbe
	material.roughness = 1.0
	return material
