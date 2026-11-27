shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Efeublätter (efeu.gd): ein Blatt aus dem Atlas texturen/efeu_blatt.png (2 × 2) je Exemplar (INSTANCE_CUSTOM.x),
// Tönung je Exemplar (COLOR), leichtes Zittern im Wind, Licht scheint etwas durch (dünne Blätter).

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform float wind = 1.0;

varying vec3 welt_pos;

void vertex() {
	vec4 inst_ursprung = MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float phase = dot(inst_ursprung.xyz, vec3(1.7, 2.3, 1.1));
	// die Blattspitze (oben im Quad) bewegt sich, der Stiel nicht
	float an_spitze = clamp(UV.y * -1.0 + 1.0, 0.0, 1.0);
	VERTEX += NORMAL * sin(TIME * 2.3 + phase) * 0.012 * an_spitze * wind;
	welt_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Atlasfeld
	float feld = floor(INSTANCE_CUSTOM.x * 4.0 + 0.5);
	UV = (UV + vec2(mod(feld, 2.0), floor(feld / 2.0))) * 0.5;
}

void fragment() {
	vec4 t = texture(atlas, UV);
	if (t.a < 0.5) {
		discard;
	}
	ALBEDO = t.rgb * COLOR.rgb;
	ROUGHNESS = 0.45;
	SPECULAR = 0.45;
	BACKLIGHT = vec3(0.12, 0.2, 0.05);
	AO = 0.85;
}
