extends DirectionalLight3D
## Bewegt die Sonne passend zur Spielzeit und dunkelt die Umgebung nachts ab.

@export var umgebung: WorldEnvironment

const FARBE_MITTAG := Color(1.0, 0.96, 0.88)
const FARBE_DAEMMERUNG := Color(1.0, 0.55, 0.3)


func _process(_delta: float) -> void:
	var anteil := Spielzeit.minuten / 1440.0
	# Mitternacht: Sonne unter dem Horizont, 12 Uhr: Sonne im Zenit.
	rotation_degrees.x = anteil * 360.0 + 90.0
	rotation_degrees.y = -30.0

	var hoehe := sin((anteil - 0.25) * TAU)  # -1 nachts, 1 mittags
	var tag := clampf(hoehe * 2.0, 0.0, 1.0)
	light_energy = tag * 1.2
	light_color = FARBE_DAEMMERUNG.lerp(FARBE_MITTAG, clampf(hoehe * 3.0, 0.0, 1.0))
	shadow_enabled = tag > 0.05

	if umgebung:
		umgebung.environment.background_energy_multiplier = lerpf(0.08, 1.0, tag)
		umgebung.environment.ambient_light_energy = lerpf(0.25, 1.0, tag)
