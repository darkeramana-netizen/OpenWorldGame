extends RefCounted
## Schattenhülle eines Baus (Phase 1, docs/03-messgrundlage.md): Ein Bau aus vielen Materialien (Putz, Balken, Ziegel,
## Fenster, …) hat je Material eine Oberfläche, und jede wird für den Sonnenschatten in jeder Stufe noch einmal
## gezeichnet. Die Hülle fasst alle Oberflächen, die Schatten werfen sollen, zu einer einzigen zusammen (gleiche Form,
## also gleicher Schatten); sie wird nur in den Schatten gezeichnet, der Bau selbst wirft dann keinen.


## Eine Oberfläche aus allen Oberflächen von mesh, deren Material nach ohne(Name) nicht ausgenommen ist (Namen aus
## namen[i] je Oberfläche). Leer (null), wenn nichts übrig bleibt.
static func aus(mesh: ArrayMesh, namen: PackedStringArray, ohne: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	var etwas := false
	for i in mesh.get_surface_count():
		if i < namen.size() and bool(ohne.call(namen[i])):
			continue
		var arr := mesh.surface_get_arrays(i)
		var nur := []
		nur.resize(Mesh.ARRAY_MAX)
		nur[Mesh.ARRAY_VERTEX] = arr[Mesh.ARRAY_VERTEX]
		nur[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
		var teil := ArrayMesh.new()
		teil.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, nur)
		st.append_from(teil, 0, Transform3D.IDENTITY)
		etwas = true
	if not etwas:
		return null
	return st.commit()


## Stellt eine Anzeige (MeshInstance3D oder MultiMeshInstance3D) auf „keinen Schatten“ und gibt einen Zwilling zurück,
## der nur Schatten wirft (gleiche Lage, gleiche Exemplare), mit der Hülle als Mesh.
static func zwilling(anzeige: GeometryInstance3D, huelle: ArrayMesh) -> GeometryInstance3D:
	anzeige.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var z: GeometryInstance3D
	if anzeige is MultiMeshInstance3D:
		var mm_alt := (anzeige as MultiMeshInstance3D).multimesh
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = huelle
		mm.instance_count = mm_alt.instance_count
		for i in mm_alt.instance_count:
			mm.set_instance_transform(i, mm_alt.get_instance_transform(i))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		z = mmi
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = huelle
		z = mi
	z.name = String(anzeige.name) + "_Schatten"
	z.transform = anzeige.transform
	z.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	z.visibility_range_end = anzeige.visibility_range_end
	return z
