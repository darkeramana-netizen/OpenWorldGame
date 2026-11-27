extends SkeletonModifier3D
## Haltung der realistischen Menschen (figur.gd): Die Animationen sind für die Quaternius-Figuren gemacht (breite
## Schultern, kräftige Statur). Auf den schmaleren MakeHuman-Körpern standen die Arme darum seitlich ab und die Beine
## breit (Rückmeldung 27.11.2026: „Körperbau sieht komisch aus“). Hängende Oberarme werden hier zum Körper hin, die
## Oberschenkel etwas zusammen gedreht; je weniger ein Glied hängt (Hieb, Schritt nach vorn), desto weniger.

@export var arm_winkel := deg_to_rad(11.0)
@export var bein_winkel := deg_to_rad(3.5)

var _glieder: Array = []   # [Knochen, Kind, Winkel]


func _ready() -> void:
	_suche()


func _suche() -> void:
	_glieder.clear()
	var s := get_skeleton()
	if s == null:
		return
	for paar: Array in [["upperarm_l", "lowerarm_l", arm_winkel], ["upperarm_r", "lowerarm_r", arm_winkel],
			["thigh_l", "calf_l", bein_winkel], ["thigh_r", "calf_r", bein_winkel]]:
		var k := s.find_bone(paar[0])
		var c := s.find_bone(paar[1])
		if k >= 0 and c >= 0:
			_glieder.append([k, c, paar[2]])


func _process_modification_with_delta(_delta: float) -> void:
	var s := get_skeleton()
	if s == null:
		return
	if _glieder.is_empty():
		_suche()
	for g: Array in _glieder:
		var k: int = g[0]
		var gp := s.get_bone_global_pose(k)
		var d := s.get_bone_global_pose(g[1]).origin - gp.origin
		if d.length_squared() < 1e-6:
			continue
		d = d.normalized()
		# nur die seitliche Abweichung vom Lot (in der Ebene quer zum Körper) verringern
		var seitlich := Vector3(d.x, d.y, 0.0)
		if seitlich.length_squared() < 1e-6 or d.y > -0.5:
			continue
		seitlich = seitlich.normalized()
		var abstand := seitlich.angle_to(Vector3.DOWN)
		var winkel := minf(float(g[2]), abstand * 0.8) * smoothstep(0.5, 0.85, -d.y)
		if winkel < 0.001:
			continue
		var achse := seitlich.cross(Vector3.DOWN)
		if achse.length_squared() < 1e-8:
			continue
		gp.basis = Basis(achse.normalized(), winkel) * gp.basis
		s.set_bone_global_pose(k, gp)
