shader_type spatial;
// Das Wächtermeer: leichte Wellen, dunkles Blau, glänzende Oberfläche.

uniform vec3 farbe_tief = vec3(0.05, 0.12, 0.18);
uniform vec3 farbe_hell = vec3(0.16, 0.3, 0.38);
uniform float wellenhoehe = 0.15;

varying vec3 welt_pos;

void vertex() {
	welt_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 0.7 + welt_pos.x * 0.06) * wellenhoehe
		+ cos(TIME * 0.5 + welt_pos.z * 0.05) * wellenhoehe;
}

void fragment() {
	float welle = sin(TIME * 0.9 + welt_pos.x * 0.15 + welt_pos.z * 0.08) * 0.5 + 0.5;
	ALBEDO = mix(farbe_tief, farbe_hell, welle * 0.4);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	// Zum Rand hin (flacher Blickwinkel) heller, wie eine Spiegelung des Himmels.
	float rand = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(ALBEDO, vec3(0.45, 0.52, 0.58), rand * 0.5);
}
