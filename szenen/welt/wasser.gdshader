shader_type spatial;
// Das Wächtermeer: leichte Wellen, dunkles Blau, glänzende Oberfläche.

uniform vec3 farbe_tief = vec3(0.05, 0.12, 0.18);
uniform vec3 farbe_hell = vec3(0.16, 0.3, 0.38);
uniform float wellenhoehe = 0.15;
// Kein Wasser innerhalb dieses Kreises: Dort steht der Unterbau des Bergfrieds.
uniform vec2 loch_mitte = vec2(250.0, 135.0);
uniform float loch_radius = 19.9;
// Ein zweiter Kreis ohne Wasser, z. B. über einem Ausstieg unter dem Wasserspiegel.
uniform vec2 loch2_mitte = vec2(0.0, 0.0);
uniform float loch2_radius = 0.0;

varying vec3 welt_pos;

void vertex() {
	welt_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 0.7 + welt_pos.x * 0.06) * wellenhoehe
		+ cos(TIME * 0.5 + welt_pos.z * 0.05) * wellenhoehe;
}

void fragment() {
	if (distance(welt_pos.xz, loch_mitte) < loch_radius || distance(welt_pos.xz, loch2_mitte) < loch2_radius) {
		discard;
	}
	float welle = sin(TIME * 0.9 + welt_pos.x * 0.15 + welt_pos.z * 0.08) * 0.5 + 0.5;
	ALBEDO = mix(farbe_tief, farbe_hell, welle * 0.4);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	// Zum Rand hin (flacher Blickwinkel) heller, wie eine Spiegelung des Himmels.
	float rand = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(ALBEDO, vec3(0.45, 0.52, 0.58), rand * 0.5);
}
