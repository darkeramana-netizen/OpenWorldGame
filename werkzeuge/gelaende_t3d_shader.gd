extends SceneTree
## Erzeugt szenen/welt/gelaende_t3d.gdshader: den Shader von Terrain3D (Gitter, Detailstufen, Höhen und Normalen aus
## den Höhenkarten auf der Grafikkarte) mit unserem Geländematerial (szenen/welt/gelaende_material.gdshaderinc)
## statt der Textur-Mischung von Terrain3D. So sehen eigenes Gelände und Terrain3D gleich aus.
## Neu erzeugen, wenn Terrain3D aktualisiert wird:
##   godot --headless --path . --script res://werkzeuge/gelaende_t3d_shader.gd

const ZIEL := "res://szenen/welt/gelaende_t3d.gdshader"


func _initialize() -> void:
	if not ClassDB.class_exists("Terrain3D"):
		printerr("Terrain3D ist nicht geladen (addons/terrain_3d, einmal --import ausführen).")
		quit(1)
		return
	var t: Node3D = ClassDB.instantiate("Terrain3D")
	t.set("debug_level", 0)
	root.add_child(t)
	await process_frame
	var m: Resource = t.get("material")
	m.set("world_background", 0)          # NONE: außerhalb der Regionen kein Gelände
	m.set("auto_shader_enabled", false)
	m.set("shader_override_enabled", true)
	await process_frame
	var code: String = (m.get("shader_override") as Shader).code
	var version: String = t.call("get_version")
	t.free()

	var a := code.find("float random(")
	var b := code.find("float get_height(const ivec3 index")
	var c := code.find("void fragment() {")
	var d := code.find("\t// Get index control data")
	var e := code.find("void vertex() {")
	if a < 0 or b < a or c < b or d < c or e < 0 or e > a:
		printerr("Der Shader von Terrain3D %s hat einen anderen Aufbau; dieses Werkzeug muss angepasst werden." % version)
		quit(1)
		return
	var kopf := "// ERZEUGT von werkzeuge/gelaende_t3d_shader.gd aus dem Shader von Terrain3D %s, nicht von Hand ändern.\n" % version
	kopf += "// Gitter, Detailstufen, Löcher und Geländenormalen wie bei Terrain3D; Farbe, Normalenkarten und Rauheit aus\n"
	kopf += "// gelaende_material.gdshaderinc (wie beim eigenen Gelände, gelaende.gdshader).\n"
	var neu := kopf + code.substr(0, e)
	neu += "#include \"res://szenen/welt/gelaende_material.gdshaderinc\"\n\n"
	neu += code.substr(e, a - e)
	neu += code.substr(b, d - b)
	neu += "\t// Unser Geländematerial an der Geländeposition mit der Normalen aus den Höhenkarten\n"
	neu += "\tvec3 farbe;\n\tvec3 normale;\n\tfloat rauheit;\n"
	neu += "\tgelaende_material(v_vertex, w_normal, farbe, normale, rauheit);\n"
	neu += "\tNORMAL = normalize((VIEW_MATRIX * vec4(normale, 0.0)).xyz);\n"
	neu += "\tALBEDO = farbe;\n\tROUGHNESS = rauheit;\n}\n"
	var f := FileAccess.open(ZIEL, FileAccess.WRITE)
	f.store_string(neu)
	f.close()
	print("Geschrieben: %s (%d Zeilen, Terrain3D %s)" % [ZIEL, neu.count("\n"), version])
	quit()
