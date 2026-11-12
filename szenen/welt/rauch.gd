class_name Rauch
extends RefCounted
## Rauch aus einem Schornstein: weiche, aufsteigende Rauchwolken als Partikel (Stadthäuser, Burggebäude, Schmiede).
## staerke: wie viele Wolken (1 = ein Herdfeuer, mehr für die Esse einer Schmiede).

static var _mesh: QuadMesh = null


static func erzeuge(p: Vector3, staerke := 1.0) -> GPUParticles3D:
	if _mesh == null:
		_mesh = QuadMesh.new()
		_mesh.size = Vector2(1.2, 1.2)
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		var verlauf := Gradient.new()
		verlauf.set_color(0, Color(1, 1, 1, 1))
		verlauf.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = verlauf
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		m.albedo_texture = tex
		_mesh.material = m
	var t := GPUParticles3D.new()
	t.amount = maxi(4, int(14 * staerke))
	t.lifetime = 7.0
	t.preprocess = 7.0
	t.position = p
	t.draw_pass_1 = _mesh
	t.visibility_range_end = 260.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.2, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0.12, 0.05, 0.04)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var groesse := Curve.new()
	groesse.add_point(Vector2(0, 0.5))
	groesse.add_point(Vector2(1, 2.6))
	var gt := CurveTexture.new()
	gt.curve = groesse
	pm.scale_curve = gt
	var farbe := Gradient.new()
	farbe.set_color(0, Color(0.55, 0.53, 0.5, 0.0))
	farbe.add_point(0.15, Color(0.55, 0.53, 0.5, 0.32))
	farbe.set_color(farbe.get_point_count() - 1, Color(0.7, 0.7, 0.7, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = farbe
	pm.color_ramp = ft
	t.process_material = pm
	return t
