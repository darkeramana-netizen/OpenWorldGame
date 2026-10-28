extends DirectionalLight3D
## Bewegt die Sonne passend zur Spielzeit und dunkelt Himmel und Umgebung nachts ab.

@export var umgebung: WorldEnvironment
## Schwaches, bläuliches Licht, das nachts übernimmt.
@export var mond: DirectionalLight3D

const FARBE_MITTAG := Color(1.0, 0.96, 0.88)
const FARBE_DAEMMERUNG := Color(1.0, 0.55, 0.3)

## Himmelsfarben bei Tag, in der Dämmerung und nachts: [oben, Horizont].
const HIMMEL_TAG := [Color(0.22, 0.38, 0.62), Color(0.66, 0.7, 0.74)]
const HIMMEL_DAEMMERUNG := [Color(0.2, 0.2, 0.32), Color(0.75, 0.45, 0.3)]
const HIMMEL_NACHT := [Color(0.03, 0.05, 0.1), Color(0.12, 0.15, 0.22)]

var _himmel: ProceduralSkyMaterial


func _ready() -> void:
	if umgebung and umgebung.environment.sky:
		_himmel = umgebung.environment.sky.sky_material as ProceduralSkyMaterial


func _process(_delta: float) -> void:
	var anteil := Spielzeit.minuten / 1440.0
	var hoehe := sin((anteil - 0.25) * TAU)  # -1 nachts, 1 mittags
	# Die Sonne geht im Osten auf, steht mittags im Süden höchstens 58° hoch und geht im Westen unter.
	# Nie ganz senkrecht: So werfen Mauern und Türme auch mittags lange, lesbare Schatten.
	rotation_degrees.x = -maxf(hoehe, -0.2) * 58.0
	rotation_degrees.y = 90.0 - (anteil - 0.25) * 360.0
	var tag := clampf(hoehe * 2.0, 0.0, 1.0)
	light_energy = tag * 1.5
	light_color = FARBE_DAEMMERUNG.lerp(FARBE_MITTAG, clampf(hoehe * 3.0, 0.0, 1.0))
	shadow_enabled = tag > 0.05
	if mond:
		mond.light_energy = (1.0 - tag) * 0.45
		mond.visible = tag < 0.99

	if umgebung:
		umgebung.environment.background_energy_multiplier = lerpf(0.6, 1.0, tag)
		umgebung.environment.ambient_light_energy = lerpf(0.5, 1.0, tag)  # nachts bleibt Mondlicht
		umgebung.environment.fog_light_color = Color(0.08, 0.1, 0.15).lerp(Color(0.62, 0.66, 0.72), tag)
	if _himmel:
		# Nachts dunkel, in der Dämmerung warm, am Tag hell.
		var daemmerung := clampf(1.0 - absf(hoehe) * 4.0, 0.0, 1.0)
		var nacht := clampf(-hoehe * 4.0, 0.0, 1.0)
		for i in 2:
			var farbe: Color = HIMMEL_TAG[i].lerp(HIMMEL_DAEMMERUNG[i], daemmerung).lerp(HIMMEL_NACHT[i], nacht)
			if i == 0:
				_himmel.sky_top_color = farbe
			else:
				_himmel.sky_horizon_color = farbe
				_himmel.ground_horizon_color = farbe
